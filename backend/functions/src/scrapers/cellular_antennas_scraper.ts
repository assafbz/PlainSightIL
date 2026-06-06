import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import proj4 from "proj4";
import { encodeGeohash } from "../utils/geohash";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

// Pre-compiled projection converter for ITM (EPSG:2039) to WGS84 (EPSG:4326)
proj4.defs(
  "EPSG:2039",
  "+proj=tmerc +lat_0=31.73439361111111 +lon_0=35.20451694444445 +k=1.0000067 +x_0=219529.584 +y_0=626907.39 +ellps=GRS80 +towgs84=-48,55,52,0,0,0,0 +units=m +no_defs",
);
const itmToWgs84Converter = proj4("EPSG:2039", "EPSG:4326");

/**
 * Converts Israel Transverse Mercator (ITM) coordinates to WGS84 latitude/longitude.
 *
 * @param xItm ITM X coordinate.
 * @param yItm ITM Y coordinate.
 * @returns Object with latitude and longitude.
 */
export function convertItmToWgs84(
  xItm: number,
  yItm: number,
): { latitude: number; longitude: number } {
  const [longitude, latitude] = itmToWgs84Converter.forward([xItm, yItm]);
  return { latitude, longitude };
}

/**
 * Validates whether the coordinates fall inside Israel's approximate bounding box.
 *
 * @param latitude Latitude in WGS84.
 * @param longitude Longitude in WGS84.
 * @returns True if valid, false otherwise.
 */
export function isValidIsraelCoordinates(latitude: number, longitude: number): boolean {
  return latitude >= 29.3 && latitude <= 33.4 && longitude >= 34.2 && longitude <= 35.9;
}

// Translation mapping for cellular operator names
const OPERATOR_TRANSLATIONS: Record<string, string> = {
  "PHI (משרת את הוט ופרטנר)": "PHI (HOT & Partner)",
  פלאפון: "Pelephone",
  פרטנר: "Partner",
  סלקום: "Cellcom",
  "הוט מובייל": "HOT Mobile",
};

/**
 * Normalizes and translates the cellular operator name to English.
 *
 * @param rawValue Raw Hebrew operator name.
 * @returns Localized operator name object.
 */
export function getTranslatedOperator(rawValue: string): { he: string; en: string } {
  const normalized = (rawValue || "").trim();
  const english = OPERATOR_TRANSLATIONS[normalized] || normalized;
  return { he: normalized, en: english };
}

/**
 * Raw record format from the API source.
 */
export interface HebrewAntennaRecord {
  מזהה?: number | string;
  _id?: number;
  חברה?: string;
  "מס' אתר"?: string;
  עיר?: string;
  "כתובת האתר"?: string;
  "רשות מקומית"?: string;
  "תחום שיפוט"?: string;
  X_ITM?: number | string;
  Y_ITM?: number | string;
  "סוג אתר"?: string;
  "תאריך היתר הקמה"?: string;
  "תאריך היתר הפעלה"?: string;
  "בדיקה תקופתית אחרונה"?: string;
  "היתר קרינה"?: string;
  "עוצמה מרבית תיאורטית בµW לסמר"?: number | string;
  "תוצאה מירבית ב% ביחס לסף הבריאות"?: number | string;
  "תאור נקודה בה התקבלה תוצאה מירבית"?: string;
  "קובץ הקמה"?: string;
  "קובץ הפעלה"?: string;
  "טכנולוגיית שידור"?: string;
}

/**
 * Normalized and sanitized cellular antenna record written to Firestore.
 */
export interface CellularAntenna {
  id: string;
  antennaId: string;
  siteNumber: string;
  coordinates: GeoPoint;
  geohash: string;
  operatorName: string;
  company: { he: string; en: string };
  locality: string;
  permitType: string;
  radiationFrequency: number;
  lastTestDate: string;
  addressHebrew: string;
  addressEnglish: string;
  createdAt?: string;
  updatedAt?: string;
  lastUpdated: string;
}

function parseFrequency(tech: string): number {
  const normalized = (tech || "").trim();
  if (normalized.includes("5")) return 3500;
  if (normalized.includes("4")) return 1800;
  if (normalized.includes("3")) return 2100;
  return 900;
}

function parseDdmmyyyyToISO(dateStr: string): string {
  if (!dateStr) return new Date().toISOString();
  try {
    const parts = dateStr.trim().split("/");
    if (parts.length === 3) {
      const day = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10) - 1; // 0-indexed month
      const year = parseInt(parts[2], 10);
      if (!isNaN(day) && !isNaN(month) && !isNaN(year)) {
        return new Date(Date.UTC(year, month, day)).toISOString();
      }
    }
    const timestamp = Date.parse(dateStr);
    if (!isNaN(timestamp)) {
      return new Date(timestamp).toISOString();
    }
  } catch {
    // Ignore and fallback
  }
  return new Date().toISOString();
}

function translateAddress(hebrewAddress: string): string {
  if (!hebrewAddress) return "";
  let english = hebrewAddress;
  const mappings: { [key: string]: string } = {
    "תל אביב": "Tel Aviv",
    ירושלים: "Jerusalem",
    חיפה: "Haifa",
    "ראשון לציון": "Rishon LeZion",
    "פתח תקווה": "Petah Tikva",
    אשדוד: "Ashdod",
    נתניה: "Netanya",
    "באר שבע": "Beer Sheva",
    חולון: "Holon",
    "רמת גן": "Ramat Gan",
    רחובות: "Rehovot",
    הרצליה: "Herzliya",
    רעננה: "Ra'anana",
    דיזנגוף: "Dizengoff",
    רוטשילד: "Rothschild",
    "בן גוריון": "Ben Gurion",
  };
  for (const [heb, eng] of Object.entries(mappings)) {
    english = english.replace(new RegExp(heb, "g"), eng);
  }
  return english;
}

/**
 * Parses a raw cellular antenna record into the normalized format.
 *
 * @param record Raw Hebrew record.
 * @returns Normalized CellularAntenna object, or null if invalid.
 */
export function parseRecord(record: HebrewAntennaRecord): CellularAntenna | null {
  const rawId = record.מזהה ?? record._id;
  const x = record.X_ITM;
  const y = record.Y_ITM;

  if (rawId === undefined || x === undefined || y === undefined) {
    return null;
  }

  const id = String(rawId).trim();
  const antennaId = id;
  const siteNumber = (record["מס' אתר"] ?? "לא ידוע").trim();

  const xItm = typeof x === "string" ? parseFloat(x) : x;
  const yItm = typeof y === "string" ? parseFloat(y) : y;

  if (isNaN(xItm) || isNaN(yItm)) {
    return null;
  }

  const { latitude, longitude } = convertItmToWgs84(xItm, yItm);
  if (!isValidIsraelCoordinates(latitude, longitude)) {
    return null;
  }

  const geohash = encodeGeohash(latitude, longitude);

  const company = getTranslatedOperator(record.חברה ?? "לא ידוע");
  const operatorName = company.en;

  const permitType = (record["היתר קרינה"] ?? "יש היתר").trim();

  const tech = record["טכנולוגיית שידור"] ?? "";
  const radiationFrequency = parseFrequency(tech);

  const rawDate = record["בדיקה תקופתית אחרונה"] ?? "";
  const lastTestDate = parseDdmmyyyyToISO(rawDate);

  const locality = (record.עיר ?? "לא ידוע").trim();
  const addressHebrew = (record["כתובת האתר"] ?? "").trim() || locality;
  const addressEnglish = translateAddress(addressHebrew);

  return {
    id,
    antennaId,
    siteNumber,
    coordinates: new GeoPoint(latitude, longitude),
    geohash,
    operatorName,
    company,
    locality,
    permitType,
    radiationFrequency,
    lastTestDate,
    addressHebrew,
    addressEnglish,
    lastUpdated: lastTestDate,
  };
}

/**
 * Scraper class for Cellular Antennas dataset.
 */
export class CellularAntennasScraper extends BaseScraper<HebrewAntennaRecord, CellularAntenna> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.CELLULAR_ANTENNAS;
  override readonly updateIntervalHours = 24; // daily
  override readonly lastUpdatedSource = "parsed";

  constructor(resourceIdOrUrl: string = DATASET_IDS.CELLULAR_ANTENNAS) {
    super();
    this.datasetId = resourceIdOrUrl;
  }

  /**
   * Overridden fetchPage to support direct URL execution.
   */
  protected override async fetchPage(
    offset: number,
    limit: number,
    options?: ScraperOptions,
  ): Promise<HebrewAntennaRecord[]> {
    const isUrl = this.datasetId.startsWith("http");
    if (isUrl && offset > 0) {
      return []; // Return empty to stop pagination loop after page 1
    }

    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const url = isUrl
      ? this.datasetId
      : `${baseUrl}/api/3/action/datastore_search?resource_id=${this.datasetId}&limit=${limit}&offset=${offset}`;

    logger.info(`Fetching cellular antennas data from: ${url}`);
    const response = await this.executeWithRetry(() =>
      axios.get(url, { timeout: options?.timeout || this.requestTimeout }),
    );
    return response.data?.result?.records ?? [];
  }

  /**
   * Parses raw record.
   */
  parseRecord(raw: HebrewAntennaRecord): CellularAntenna | null {
    return parseRecord(raw);
  }
}

/**
 * Scrapes cellular antennas from data.gov.il API and syncs them to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @param resourceIdOrUrl Resource ID or direct API URL.
 * @param options Synchronizer options.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncAntennas(
  db: admin.firestore.Firestore,
  resourceIdOrUrl: string = DATASET_IDS.CELLULAR_ANTENNAS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new CellularAntennasScraper(resourceIdOrUrl);
  return scraper.scrape(db, options);
}
