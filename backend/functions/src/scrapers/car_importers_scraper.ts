import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

export interface HebrewCarImporterRecord {
  _id: number;
  semel_yevuan?: number | string | null;
  shem_yevuan?: string | null;
  sug_degem?: string | null;
  tozeret_cd?: number | string | null;
  tozeret_nm?: string | null;
  degem_cd?: number | string | null;
  degem_nm?: string | null;
  shnat_yitzur?: number | string | null;
  mehir?: number | string | null;
  kinuy_mishari?: string | null;
}

export interface CarImporterRecord {
  id: string;
  _id: number;
  importerCode: number | null;
  importerName: string;
  modelType: string;
  makerCode: number | null;
  makerName: string;
  modelCode: number | null;
  modelName: string;
  productionYear: number | null;
  price: number | null;
  commercialName: string;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

export function parseCarImporterRecord(record: HebrewCarImporterRecord): CarImporterRecord | null {
  const rawId = record._id;
  if (rawId === undefined || rawId === null) {
    return null;
  }

  const id = String(rawId).trim();
  const importerCode =
    record.semel_yevuan !== undefined && record.semel_yevuan !== null
      ? Number(record.semel_yevuan)
      : null;
  const importerName = (record.shem_yevuan ?? "").trim();
  const modelType = (record.sug_degem ?? "").trim();
  const makerCode =
    record.tozeret_cd !== undefined && record.tozeret_cd !== null
      ? Number(record.tozeret_cd)
      : null;
  const makerName = (record.tozeret_nm ?? "").trim();
  const modelCode =
    record.degem_cd !== undefined && record.degem_cd !== null ? Number(record.degem_cd) : null;
  const modelName = (record.degem_nm ?? "").trim();
  const productionYear =
    record.shnat_yitzur !== undefined && record.shnat_yitzur !== null
      ? Number(record.shnat_yitzur)
      : null;
  const price = record.mehir !== undefined && record.mehir !== null ? Number(record.mehir) : null;
  const commercialName = (record.kinuy_mishari ?? "").trim();

  const lastUpdated = new Date().toISOString();

  return {
    id,
    _id: rawId,
    importerCode: isNaN(Number(importerCode)) ? null : importerCode,
    importerName,
    modelType,
    makerCode: isNaN(Number(makerCode)) ? null : makerCode,
    makerName,
    modelCode: isNaN(Number(modelCode)) ? null : modelCode,
    modelName,
    productionYear: isNaN(Number(productionYear)) ? null : productionYear,
    price: isNaN(Number(price)) ? null : price,
    commercialName,
    lastUpdated,
  };
}

export async function scrapeAndSyncCarImporters(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.CAR_IMPORTERS,
  options?: { forceFullSync?: boolean },
): Promise<{ success: boolean; count: number }> {
  const datasetId = DATASET_IDS.CAR_IMPORTERS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.CAR_IMPORTERS;
    logger.info(`Starting car importers sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const forceFullSync = options?.forceFullSync === true;
    let offset = 0;
    const limit = isEmulator && !forceFullSync ? 100 : 1000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching car importers data from: ${url}`);

      const response = await axios.get(url, { timeout: 15000 });
      const records: HebrewCarImporterRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: CarImporterRecord[] = [];
      for (const rec of records) {
        const parsed = parseCarImporterRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

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

      if (isEmulator && !forceFullSync) {
        hasMore = false;
        break;
      }

      offset += limit;
    }

    logger.info(`Successfully parsed and updated ${processedCount} records in ${targetCollection}`);

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

    logger.info("Updated car importers metadata. Ingestion complete.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Car importers scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
