import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewPatentRecord {
  _id: number;
  "מספר בקשה"?: number | string;
  "שם האמצאה בעברית"?: string;
  "שם האמצאה באנגלית"?: string;
  "לבקשה CPC סיווג"?: string;
  "ראשי"?: string;
}

/**
 * Interface representing the normalized and sanitized patent classification record written to Firestore.
 */
export interface PatentClassificationRecord {
  id: string;
  _id: number;
  applicationNumber: number;
  titleHebrew: string;
  titleEnglish: string;
  cpcClassification: string;
  isPrimary: boolean;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Maps a raw Hebrew database record into the clean, typed PatentClassificationRecord format.
 * Sanitizes input and enforces numeric checks.
 *
 * @param record The raw record from the API
 * @returns Mapped record, or null if key fields are missing or invalid
 */
export function parsePatentRecord(record: HebrewPatentRecord): PatentClassificationRecord | null {
  const rawId = record._id;
  const rawAppNum = record["מספר בקשה"];
  const rawCpc = record["לבקשה CPC סיווג"];

  if (rawId === undefined || rawId === null || rawAppNum === undefined || rawAppNum === null || !rawCpc) {
    return null;
  }

  const id = String(rawId).trim();
  const applicationNumber = Number(rawAppNum);
  if (isNaN(applicationNumber) || applicationNumber <= 0) {
    return null;
  }

  const cpcClassification = String(rawCpc).trim();
  if (!cpcClassification) {
    return null;
  }

  const titleHebrew = (record["שם האמצאה בעברית"] ?? "").trim();
  const titleEnglish = (record["שם האמצאה באנגלית"] ?? "").trim();

  // Validate we have at least one title field
  if (!titleHebrew && !titleEnglish) {
    return null;
  }

  const isPrimary = (record["ראשי"] ?? "").trim() === "ראשי";
  const lastUpdated = new Date().toISOString();

  return {
    id,
    _id: rawId,
    applicationNumber,
    titleHebrew,
    titleEnglish,
    cpcClassification,
    isPrimary,
    lastUpdated,
  };
}

/**
 * Scrapes patent applications CPC classifications from data.gov.il datastore API and syncs them in-place.
 * Uses a delta sync strategy by querying newer records first (sorting by _id desc) and stopping
 * once we encounter an _id that is already synced.
 *
 * @param db The Firestore database reference
 * @param resourceId The resource ID for data.gov.il API (defaults to DATASET_IDS.PATENT_CLASSIFICATIONS)
 * @returns Success status and count of processed records
 */
export async function scrapeAndSyncPatentClassifications(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.PATENT_CLASSIFICATIONS,
): Promise<{ success: boolean; count: number }> {
  const datasetId = DATASET_IDS.PATENT_CLASSIFICATIONS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.PATENT_CLASSIFICATIONS;
    logger.info(`Starting patent classifications sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    let offset = 0;
    const limit = isEmulator ? 10 : 1000;
    let hasMore = true;
    let processedCount = 0;
    let newWritesCount = 0;

    // 1. Retrieve the last synced maximum _id to support delta sync
    const metadataDoc = await metadataRef.get();
    let lastSyncedMaxId = 0;
    if (metadataDoc.exists) {
      const data = metadataDoc.data();
      if (data && typeof data.lastSyncedMaxId === "number") {
        lastSyncedMaxId = data.lastSyncedMaxId;
      }
    }
    logger.info(`Delta sync active. Last synced max _id: ${lastSyncedMaxId}`);

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();
    let maxIdInThisRun = lastSyncedMaxId;

    // Loop and page through the datastore
    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      // Fetch sorted by _id desc so we check newest entries first
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}&sort=_id desc`;
      logger.info(`Fetching patent classifications from: ${url}`);

      const response = await axios.get(url);
      const records: HebrewPatentRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: PatentClassificationRecord[] = [];
      let reachedExistingRecords = false;

      for (const rec of records) {
        // Delta sync termination check: if we see an _id we've already synced, we can stop
        if (rec._id <= lastSyncedMaxId) {
          logger.info(`Reached previously synced record (_id: ${rec._id} <= lastSyncedMaxId: ${lastSyncedMaxId}). Stopping sync.`);
          reachedExistingRecords = true;
          hasMore = false;
          break;
        }

        const parsed = parsePatentRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
          if (parsed._id > maxIdInThisRun) {
            maxIdInThisRun = parsed._id;
          }
        }
      }

      // If we got new records, batch write them in chunks of 500
      if (parsedRecords.length > 0) {
        for (let i = 0; i < parsedRecords.length; i += 500) {
          const chunk = parsedRecords.slice(i, i + 500);
          const docRefs = chunk.map((r) => targetRef.doc(r.id));

          // Look up existing docs to maintain createdAt field if they exist
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

            r.lastUpdated = now;
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
            newWritesCount++;
          }

          if (hasWrites) {
            await batch.commit();
          }
        }
      } else {
        // No new records parsed in this batch (e.g. all filtered out or empty)
        if (reachedExistingRecords) {
          hasMore = false;
        }
      }

      if (isEmulator) {
        hasMore = false;
        break;
      }

      if (hasMore) {
        offset += limit;
      }
    }

    logger.info(`Ingestion complete. Processed: ${processedCount}, Wrote: ${newWritesCount} records.`);

    // Retrieve total count of documents in the collection
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

    // Update metadata document
    await metadataRef.set(
      {
        id: datasetId,
        activeCollection: targetCollection,
        lastUpdated: now,
        recordCount: totalRecords,
        status: "idle",
        lastSyncedMaxId: maxIdInThisRun,
      },
      { merge: true },
    );

    logger.info("Updated patent classifications metadata.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Patent classifications scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
