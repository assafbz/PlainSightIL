import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { AppLogger as logger } from "../utils/logger";
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
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

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
    lastUpdated: submissionDate,
  };
}

export async function scrapeAndSyncPermitApplications(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.CELLULAR_PERMITS,
): Promise<{ success: boolean; count: number }> {
  const datasetId = DATASET_IDS.CELLULAR_PERMITS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.CELLULAR_PERMITS;
    logger.info(`Starting sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    // Paginated API fetch from data.gov.il datastore search
    let offset = 0;
    const limit = isEmulator ? 10 : 1000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching data from: ${url}`);

      const response = await axios.get(url);
      const records: HebrewPermitRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      // Collect parsed records for this page
      const parsedRecords: CellularPermitApplication[] = [];
      for (const rec of records) {
        const parsed = parsePermitRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      // Process parsed records in chunks of 500
      for (let i = 0; i < parsedRecords.length; i += 500) {
        const chunk = parsedRecords.slice(i, i + 500);

        // Get doc refs for the chunk
        const docRefs = chunk.map((r) => targetRef.doc(r.id));

        // Lookup existing documents in batch
        const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
        const existingMap = new Map<string, admin.firestore.DocumentData>();
        for (const snap of snapshots) {
          const data = snap.data();
          if (snap.exists && data) {
            existingMap.set(snap.id, data);
          }
        }

        // Prepare and write chunk
        const batch = db.batch();
        let hasWrites = false;
        for (const r of chunk) {
          const docRef = targetRef.doc(r.id);
          const existingData = existingMap.get(r.id);

          r.lastUpdated = r.lastUpdated || now;
          if (existingData) {
            const isIdentical = areRecordsEqual(existingData, r);
            if (isIdentical) {
              processedCount++;
              continue;
            }
            r.createdAt = existingData.createdAt || now;
            r.updatedAt = now;
          } else {
            r.createdAt = now;
            r.updatedAt = now;
          }

          batch.set(docRef, r);
          hasWrites = true;
          processedCount++;
        }
        if (hasWrites) {
          await batch.commit();
        }
      }

      if (isEmulator) {
        hasMore = false;
        break;
      }

      offset += limit;
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
