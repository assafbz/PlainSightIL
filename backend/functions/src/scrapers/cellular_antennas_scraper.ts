import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import axios from "axios";
import proj4 from "proj4";
import { encodeGeohash } from "../utils/geohash";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

// Pre-compiled projection converter for ITM (EPSG:2039) to WGS84 (EPSG:4326)
proj4.defs(
  "EPSG:2039",
  "+proj=tmerc +lat_0=31.73439361111111 +lon_0=35.20451694444445 +k=1.0000067 +x_0=219529.584 +y_0=626907.39 +ellps=GRS80 +towgs84=-48,55,52,0,0,0,0 +units=m +no_defs",
);
const itmToWgs84Converter = proj4("EPSG:2039", "EPSG:4326");

export function convertItmToWgs84(
  xItm: number,
  yItm: number,
): { latitude: number; longitude: number } {
  const [longitude, latitude] = itmToWgs84Converter.forward([xItm, yItm]);
  return { latitude, longitude };
}

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

export function getTranslatedOperator(rawValue: string): { he: string; en: string } {
  const normalized = (rawValue || "").trim();
  const english = OPERATOR_TRANSLATIONS[normalized] || normalized;
  return { he: normalized, en: english };
}

export interface HebrewAntennaRecord {
  ID?: number | string;
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
  lastUpdated?: string;
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

export function parseRecord(record: HebrewAntennaRecord): CellularAntenna | null {
  const rawId = record.ID ?? record._id;
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

export async function saveAntennasToFirestore(
  db: admin.firestore.Firestore,
  antennas: CellularAntenna[],
): Promise<void> {
  const collectionRef = db.collection(DATASET_IDS.CELLULAR_ANTENNAS);
  const now = new Date().toISOString();

  // Process in chunks of 500
  for (let i = 0; i < antennas.length; i += 500) {
    const chunk = antennas.slice(i, i + 500);

    // Get doc refs for the chunk
    const docRefs = chunk.map((a) => collectionRef.doc(a.antennaId));

    // Lookup existing documents in batch
    const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
    const existingMap = new Map<string, admin.firestore.DocumentData>();
    for (const snap of snapshots) {
      if (snap.exists) {
        existingMap.set(snap.id, snap.data());
      }
    }

    // Prepare and write chunk
    const batch = db.batch();
    let hasWrites = false;
    for (const a of chunk) {
      const docRef = collectionRef.doc(a.antennaId);
      const existingData = existingMap.get(a.antennaId);

      a.lastUpdated = a.lastUpdated || now;
      if (existingData) {
        const isIdentical = areRecordsEqual(existingData, a);
        if (isIdentical) {
          continue;
        }
        a.createdAt = existingData.createdAt || now;
        a.updatedAt = now;
      } else {
        a.createdAt = now;
        a.updatedAt = now;
      }

      batch.set(docRef, a);
      hasWrites = true;
    }
    if (hasWrites) {
      await batch.commit();
    }
  }
}

export async function scrapeAndSyncAntennas(
  db: admin.firestore.Firestore,
  resourceIdOrUrl: string = DATASET_IDS.CELLULAR_ANTENNAS,
): Promise<{ success: boolean; count: number }> {
  const datasetId = DATASET_IDS.CELLULAR_ANTENNAS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.CELLULAR_ANTENNAS;
    logger.info(`Starting sync. Target collection: ${targetCollection}`);

    // Paginated API fetch from data.gov.il datastore search
    let offset = 0;
    const limit = 1000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    const isUrl = resourceIdOrUrl.startsWith("http");

    while (hasMore) {
      const url = isUrl
        ? resourceIdOrUrl
        : `https://data.gov.il/api/3/action/datastore_search?resource_id=${resourceIdOrUrl}&limit=${limit}&offset=${offset}`;

      logger.info(`Fetching data from: ${url}`);
      const response = await axios.get(url);
      const records: HebrewAntennaRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      // Collect parsed records for this page
      const parsedRecords: CellularAntenna[] = [];
      for (const rec of records) {
        const parsed = parseRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      // Save parsed records in chunks
      if (parsedRecords.length > 0) {
        await saveAntennasToFirestore(db, parsedRecords);
        processedCount += parsedRecords.length;
      }

      if (isUrl) {
        hasMore = false;
      } else {
        offset += limit;
      }
    }

    logger.info(`Successfully parsed and updated ${processedCount} records in ${targetCollection}`);

    // Retrieve total count of documents in the collection
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

    // Atomic update of active collection pointer and count
    await metadataRef.set(
      {
        id: datasetId,
        activeCollection: targetCollection,
        lastUpdated: now,
        recordCount: totalRecords,
        status: "idle",
      },
      { merge: true },
    );

    logger.info("Updated metadata. Ingestion complete.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
