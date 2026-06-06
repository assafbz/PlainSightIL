import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewLocalMarketBondRecord {
  _id: number;
  ISSUANCEDATE?: string;
  BONDS?: string;
  SERIES?: number | string;
  ACTUALTERMTOMATURITY?: number | string;
  ORIGINALTERMTOMATURITY?: number | string;
  REDEMTIONDATE?: string;
  COUPON?: number | string;
  OFFEREDQUANTITY?: number | string;
  PURCHASEDQUANTITY?: number | string;
  ADDITIONALPURCHASED?: number | string;
  AVERAGEPRICE?: number | string;
  CUTOFFPRICE?: number | string;
  TOTALFUNDING?: number | string;
  DEMANDEDAMOUNT?: number | string;
  COVERRATIO?: number | string;
  GROSSAVGYIELD?: number | string;
  GROSSCUTOFFYIELD?: number | string;
}

/**
 * Interface representing the normalized and sanitized record written to Firestore.
 */
export interface LocalMarketBondRecord {
  id: string;
  _id: number;
  issuanceDate: string;
  bondType: {
    he: string;
    en: string;
  };
  series: number;
  actualTermToMaturity: number;
  originalTermToMaturity: number;
  redemptionDate: string;
  coupon: number;
  offeredQuantity: number;
  purchasedQuantity: number;
  additionalPurchased: number;
  averagePrice: number;
  cutoffPrice: number;
  totalFunding: number;
  demandedAmount: number;
  coverRatio: number;
  grossAvgYield: number;
  grossCutoffYield: number;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

const BOND_TYPE_TRANSLATIONS: Record<string, string> = {
  ממשלתית: "Government",
  "ממשלתית צמודה": "CPI-Linked Government",
  "ממשלתית בריבית משתנה": "Floating Rate Government",
};

/**
 * Translates Hebrew bond type into English representation.
 */
export function getBondTypeTranslation(he: string): { he: string; en: string } {
  const cleanHe = he.trim();
  const en = BOND_TYPE_TRANSLATIONS[cleanHe] || cleanHe;
  return { he: cleanHe, en };
}

/**
 * Parses DD/MM/YYYY date format to standard ISO-8601 string.
 */
export function parseDDMMYYYY(val: unknown): string {
  if (!val) return "";
  const s = String(val).trim();
  const parts = s.split("/");
  if (parts.length === 3) {
    const day = parts[0].padStart(2, "0");
    const month = parts[1].padStart(2, "0");
    const year = parts[2];
    return `${year}-${month}-${day}T00:00:00.000Z`;
  }
  return "";
}

/**
 * Parses YYYY-MM-DDT00:00:00 timestamp format to standard ISO-8601 string.
 */
export function parseIssuanceDate(val: unknown): string {
  if (!val) return "";
  const s = String(val).trim();
  if (s.includes("T")) {
    return s.endsWith(".000Z") ? s : s + ".000Z";
  }
  return s;
}

function parseNum(val: unknown): number {
  if (val === undefined || val === null) return 0;
  const num = Number(val);
  return isNaN(num) ? 0 : num;
}

/**
 * Maps raw Hebrew record into clean, typed LocalMarketBondRecord format.
 */
export function parseLocalMarketBondRecord(
  record: HebrewLocalMarketBondRecord,
): LocalMarketBondRecord | null {
  const rawId = record._id;
  if (rawId === undefined || rawId === null) {
    return null;
  }

  const id = String(rawId).trim();
  const series = parseNum(record.SERIES);
  const issuanceDate = parseIssuanceDate(record.ISSUANCEDATE);
  const redemptionDate = parseDDMMYYYY(record.REDEMTIONDATE);
  const bondType = getBondTypeTranslation(record.BONDS ?? "");

  return {
    id,
    _id: rawId,
    issuanceDate: issuanceDate || new Date().toISOString(),
    bondType,
    series,
    actualTermToMaturity: parseNum(record.ACTUALTERMTOMATURITY),
    originalTermToMaturity: parseNum(record.ORIGINALTERMTOMATURITY),
    redemptionDate: redemptionDate || new Date().toISOString(),
    coupon: parseNum(record.COUPON),
    offeredQuantity: parseNum(record.OFFEREDQUANTITY),
    purchasedQuantity: parseNum(record.PURCHASEDQUANTITY),
    additionalPurchased: parseNum(record.ADDITIONALPURCHASED),
    averagePrice: parseNum(record.AVERAGEPRICE),
    cutoffPrice: parseNum(record.CUTOFFPRICE),
    totalFunding: parseNum(record.TOTALFUNDING),
    demandedAmount: parseNum(record.DEMANDEDAMOUNT),
    coverRatio: parseNum(record.COVERRATIO),
    grossAvgYield: parseNum(record.GROSSAVGYIELD),
    grossCutoffYield: parseNum(record.GROSSCUTOFFYIELD),
    lastUpdated: redemptionDate || new Date().toISOString(),
  };
}

/**
 * Scrapes domestic government bonds from data.gov.il datastore API and syncs them in-place.
 */
export async function scrapeAndSyncLocalMarketBonds(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.LOCAL_MARKET_BONDS,
): Promise<{ success: boolean; count: number; changedCount: number }> {
  const datasetId = DATASET_IDS.LOCAL_MARKET_BONDS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.LOCAL_MARKET_BONDS;
    logger.info(`Starting local market bonds sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    let offset = 0;
    const limit = isEmulator ? 10 : 10000;
    let hasMore = true;
    let processedCount = 0;
    let changedCount = 0;

    // Retrieve the last synced maximum _id to support delta sync
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

    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      // Fetch sorted by _id desc so we check newest entries first
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}&sort=_id desc`;
      logger.info(`Fetching local market bonds from: ${url}`);

      const response = await axios.get(url, { timeout: 15000 });
      const records: HebrewLocalMarketBondRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: LocalMarketBondRecord[] = [];
      let reachedExistingRecords = false;

      for (const rec of records) {
        if (rec._id <= lastSyncedMaxId) {
          logger.info(
            `Reached previously synced record (_id: ${rec._id} <= lastSyncedMaxId: ${lastSyncedMaxId}). Stopping sync.`,
          );
          reachedExistingRecords = true;
          hasMore = false;
          break;
        }

        const parsed = parseLocalMarketBondRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
          if (parsed._id > maxIdInThisRun) {
            maxIdInThisRun = parsed._id;
          }
        }
      }

      if (parsedRecords.length > 0) {
        for (let i = 0; i < parsedRecords.length; i += 500) {
          const chunk = parsedRecords.slice(i, i + 500);
          const docRefs = chunk.map((r) => targetRef.doc(r.id));

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
            changedCount++;
          }

          if (hasWrites) {
            await batch.commit();
          }
        }
      } else {
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

    logger.info(
      `Ingestion complete. Processed: ${processedCount}, Wrote: ${changedCount} records.`,
    );

    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

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

    logger.info("Updated local market bonds metadata.");
    return { success: true, count: processedCount, changedCount };
  } catch (error) {
    logger.error("Local market bonds scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
