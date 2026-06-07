import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
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
 * @returns True if coordinates are valid, false otherwise.
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
 * Raw record format received from cellular permits API.
 */
export interface HebrewPermitRecord {
  ID?: number | string;
  _id?: number;
  "תאריך הגשת הבקשה"?: string;
  "מס' סימוכין"?: number | string;
  חברה?: string;
  "סוג  היתר"?: string;
  "מספר האתר"?: string;
  ישוב?: string;
  "כתובת + תאור"?: string;
  "סוג המוקד"?: string;
  X_ITM?: number | string;
  Y_ITM?: number | string;
  "תחום שיפוט"?: string;
}

/**
 * Normalized and sanitized cellular permit application record written to Firestore.
 */
export interface CellularPermitApplication {
  id: string;
  submissionDate: string;
  referenceNumber: number;
  company: { he: string; en: string };
  permitType: string;
  siteNumber: string;
  locality: string;
  addressDescription: string;
  focalPointType: string;
  coordinates: GeoPoint;
  geohash: string;
  jurisdiction: string;
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Maps a raw Hebrew permit record into the clean, typed CellularPermitApplication format.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
export function parsePermitRecord(record: HebrewPermitRecord): CellularPermitApplication | null {
  const rawId = record.ID ?? record._id;
  const rawRef = record["מס' סימוכין"];
  const x = record.X_ITM;
  const y = record.Y_ITM;

  if (rawId === undefined || x === undefined || y === undefined) {
    return null;
  }

  const id = String(rawId).trim();
  const referenceNumber = Number(rawRef) || 0;
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

  const rawDate = record["תאריך הגשת הבקשה"] ?? "";
  let submissionDate = new Date().toISOString();
  if (rawDate) {
    const parsedTime = Date.parse(rawDate);
    if (!isNaN(parsedTime)) {
      submissionDate = new Date(parsedTime).toISOString();
    }
  }

  const company = getTranslatedOperator(record.חברה ?? "לא ידוע");
  const permitType = (record["סוג  היתר"] ?? "היתר הקמה").trim();
  const siteNumber = (record["מספר האתר"] ?? "לא ידוע").trim();
  const locality = (record.ישוב ?? "לא ידוע").trim();
  const addressDescription = (record["כתובת + תאור"] ?? "").trim();
  const focalPointType = (record["סוג המוקד"] ?? "לא ידוע").trim();
  const jurisdiction = (record["תחום שיפוט"] ?? "").trim();

  return {
    id,
    submissionDate,
    referenceNumber,
    company,
    permitType,
    locality,
    addressDescription,
    focalPointType,
    coordinates: new GeoPoint(latitude, longitude),
    geohash,
    jurisdiction,
    siteNumber,
    sourceCreatedAt: submissionDate,
    sourceUpdatedAt: submissionDate,
  };
}

/**
 * Scraper class for Cellular Permit Applications dataset.
 */
export class CellularPermitsScraper extends BaseScraper<
  HebrewPermitRecord,
  CellularPermitApplication
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.CELLULAR_PERMITS;
  override readonly updateIntervalHours = 168; // weekly
  override readonly lastUpdatedSource = "parsed";

  constructor(resourceId = DATASET_IDS.CELLULAR_PERMITS) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw cellular permit record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewPermitRecord): CellularPermitApplication | null {
    return parsePermitRecord(raw);
  }
}

/**
 * Scrapes Cellular Permit Applications from data.gov.il API and syncs them to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @param resourceId Resource ID.
 * @param options Synchronizer options.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncPermitApplications(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.CELLULAR_PERMITS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new CellularPermitsScraper(resourceId);
  return scraper.scrape(db, options);
}
