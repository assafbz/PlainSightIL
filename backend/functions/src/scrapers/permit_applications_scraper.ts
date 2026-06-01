import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import axios from "axios";
import proj4 from "proj4";
import { encodeGeohash } from "../utils/geohash";

// Pre-compiled projection converter for ITM (EPSG:2039) to WGS84 (EPSG:4326)
proj4.defs(
  "EPSG:2039",
  "+proj=tmerc +lat_0=31.73439361111111 +lon_0=35.20451694444445 +k=1.0000067 +x_0=219529.584 +y_0=626907.39 +ellps=GRS80 +towgs84=-48,55,52,0,0,0,0 +units=m +no_defs"
);
const itmToWgs84Converter = proj4("EPSG:2039", "EPSG:4326");

export function convertItmToWgs84(xItm: number, yItm: number): { latitude: number; longitude: number } {
  const [longitude, latitude] = itmToWgs84Converter.forward([xItm, yItm]);
  return { latitude, longitude };
}

export function isValidIsraelCoordinates(latitude: number, longitude: number): boolean {
  return (
    latitude >= 29.3 && latitude <= 33.4 &&
    longitude >= 34.2 && longitude <= 35.9
  );
}

// Translation mapping for cellular operator names
const OPERATOR_TRANSLATIONS: Record<string, string> = {
  "PHI (משרת את הוט ופרטנר)": "PHI (HOT & Partner)",
  "פלאפון": "Pelephone",
  "פרטנר": "Partner",
  "סלקום": "Cellcom",
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
  coordinates: admin.firestore.GeoPoint;
  geohash: string;
  jurisdiction: string;
  lastUpdated: string;
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
    siteNumber,
    locality,
    addressDescription,
    focalPointType,
    coordinates: new admin.firestore.GeoPoint(latitude, longitude),
    geohash,
    jurisdiction,
    lastUpdated: new Date().toISOString(),
  };
}

async function purgeCollection(db: admin.firestore.Firestore, collectionPath: string) {
  const collectionRef = db.collection(collectionPath);
  const snapshot = await collectionRef.limit(500).get();

  if (snapshot.size === 0) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  // Recurse to purge remainder
  await purgeCollection(db, collectionPath);
}

export async function scrapeAndSyncPermitApplications(
  db: admin.firestore.Firestore,
  resourceId = "ff398c7e-c522-4ee8-a53a-312b188a573d"
): Promise<{ success: boolean; count: number }> {
  const datasetId = "cellular_permit_applications";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    // 1. Fetch metadata pointer to determine targets
    const metaDoc = await metadataRef.get();
    const currentActive = metaDoc.exists ? metaDoc.data()?.activeCollection : null;

    const targetCollection = currentActive === "permit_apps_blue" ? "permit_apps_green" : "permit_apps_blue";
    logger.info(`Starting sync. Target collection buffer: ${targetCollection}`);

    // 2. Unconditionally Purge Inactive Collection
    await purgeCollection(db, targetCollection);
    logger.info(`Purged target buffer collection: ${targetCollection}`);

    // 3. Paginated API fetch from data.gov.il datastore search
    let offset = 0;
    const limit = 1000;
    let hasMore = true;
    let processedCount = 0;

    let batch = db.batch();
    const targetRef = db.collection(targetCollection);

    while (hasMore) {
      const url = `https://data.gov.il/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching data from: ${url}`);
      
      const response = await axios.get(url);
      const records: HebrewPermitRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      for (const rec of records) {
        const parsed = parsePermitRecord(rec);
        if (parsed) {
          const docRef = targetRef.doc(parsed.id);
          batch.set(docRef, parsed);
          processedCount++;

          if (processedCount % 500 === 0) {
            await batch.commit();
            batch = db.batch();
          }
        }
      }

      offset += limit;
    }

    if (processedCount % 500 !== 0) {
      await batch.commit();
    }

    logger.info(`Successfully parsed and stored ${processedCount} records in ${targetCollection}`);

    // 4. Atomic switch of active collection pointer
    await metadataRef.set(
      {
        id: datasetId,
        activeCollection: targetCollection,
        lastUpdated: new Date().toISOString(),
        recordCount: processedCount,
        status: "idle",
      },
      { merge: true }
    );

    logger.info(`Swapped active pointer to ${targetCollection}. Ingestion complete.`);
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
