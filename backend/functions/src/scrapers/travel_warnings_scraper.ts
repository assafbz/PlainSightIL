import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewTravelWarningRecord {
  _id: number;
  continent?: string;
  country?: string;
  recommendations?: string;
  details?: string;
  logo?: string;
  date?: string | null;
  משרד?: string;
}

/**
 * Interface representing the normalized travel warning record written to Firestore.
 */
export interface TravelWarningRecord {
  id: string;
  _id: number;
  continent: string;
  country: string;
  recommendations: string;
  details: string;
  logo: string;
  date: string | null;
  office: string;
  warningLevel: number;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Extracts warning level (1 to 4) from recommendations text.
 * @param recommendations The recommendations description text
 * @returns Mapped warning level (1-4)
 */
export function extractWarningLevel(recommendations: string): number {
  if (!recommendations) return 1;
  const match = recommendations.match(/רמה\s+([1-4])/);
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return 1;
}

/**
 * Maps a raw Hebrew travel warning record into the clean, typed TravelWarningRecord format.
 * Sanitizes input and enforces default values.
 *
 * @param record The raw record from the API
 * @returns Mapped record, or null if key fields are missing or invalid
 */
export function parseTravelWarningRecord(
  record: HebrewTravelWarningRecord,
): TravelWarningRecord | null {
  const rawId = record._id;
  if (rawId === undefined || rawId === null) {
    return null;
  }

  const id = String(rawId).trim();
  const continent = (record.continent ?? "").trim();
  const country = (record.country ?? "").trim();
  const recommendations = (record.recommendations ?? "").trim();
  const details = (record.details ?? "").trim();
  const logo = (record.logo ?? "").trim();
  const date = record.date ? String(record.date).trim() : null;
  const office = (record["משרד"] ?? "").trim();

  // Enforce country name exists
  if (!country) {
    return null;
  }

  const warningLevel = extractWarningLevel(recommendations);
  const lastUpdated = date || new Date().toISOString();

  return {
    id,
    _id: rawId,
    continent,
    country,
    recommendations,
    details,
    logo,
    date,
    office,
    warningLevel,
    lastUpdated,
  };
}

/**
 * Scrapes travel warnings from data.gov.il datastore API and syncs them in-place to Firestore.
 * Performs paginated queries to handle imports.
 *
 * @param db The Firestore database reference
 * @param resourceId The resource ID for data.gov.il API (defaults to 2a01d234-b2b0-4d46-baa0-cec05c401e7d)
 * @returns Success status and count of processed records
 */
export async function scrapeAndSyncTravelWarnings(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.TRAVEL_WARNINGS,
  options?: { forceFullSync?: boolean },
): Promise<{ success: boolean; count: number; changedCount: number }> {
  const datasetId = DATASET_IDS.TRAVEL_WARNINGS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.TRAVEL_WARNINGS;
    logger.info(`Starting travel warnings sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const forceFullSync = options?.forceFullSync === true;
    let offset = 0;
    const limit = isEmulator && !forceFullSync ? 100 : 10000;
    let hasMore = true;
    let processedCount = 0;
    let changedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    // Loop and page through the datastore
    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching travel warnings data from: ${url}`);

      const response = await axios.get(url, { timeout: 15000 });
      const records: HebrewTravelWarningRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: TravelWarningRecord[] = [];
      for (const rec of records) {
        const parsed = parseTravelWarningRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      // Batch set documents in chunks of 500
      for (let i = 0; i < parsedRecords.length; i += 500) {
        const chunk = parsedRecords.slice(i, i + 500);
        const docRefs = chunk.map((r) => targetRef.doc(r.id));

        // Read existing entries to retain their original createdAt timestamp
        const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
        const existingMap = new Map<string, admin.firestore.DocumentData>();
        for (const snap of snapshots) {
          const data = snap.data();
          if (snap.exists && data) {
            existingMap.set(snap.id, data);
          }
        }

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
          changedCount++;
        }
        if (hasWrites) {
          await batch.commit();
        }
      }

      if (isEmulator && !forceFullSync) {
        hasMore = false;
        break;
      }

      offset += limit;
    }

    logger.info(`Successfully parsed and updated ${processedCount} records in ${targetCollection}`);

    // Update document total record counts dynamically
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

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

    logger.info("Updated travel warnings metadata. Ingestion complete.");
    return { success: true, count: processedCount, changedCount };
  } catch (error) {
    logger.error("Travel warnings scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
