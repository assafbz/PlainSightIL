import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

export interface HebrewVehicleRecallRecord {
  _id: number;
  RECALL_ID?: number | string;
  TOZAR_CD?: number | string;
  TOZAR_TEUR?: string;
  DEGEM?: string;
  SHNAT_RECALL?: number | string;
  BUILD_BEGIN_A?: string;
  BUILD_END_A?: string;
  SUG_RECALL?: string;
  SUG_TAKALA?: string;
  TEUR_TAKALA?: string;
  OFEN_TIKUN?: string;
  TKINA_EU?: string;
  YEVUAN_TEUR?: string;
  TELEPHONE?: string;
  WEBSITE?: string;
}

export interface VehicleRecallRecord {
  id: string;
  _id: number;
  recallId: number;
  manufacturerCode: number;
  manufacturerName: string;
  modelName: string;
  recallYear: number;
  buildStartDate: string;
  buildEndDate: string;
  recallType: { he: string; en: string };
  defectCategory: string;
  defectDescription: string;
  repairAction: string;
  euCategory: string;
  importerName: string;
  importerPhone: string;
  importerWebsite: string;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

// Clean trailing and extra whitespace
function cleanString(val: unknown): string {
  if (val === undefined || val === null) return "";
  return String(val).replace(/\s+/g, " ").trim();
}

function parseDateString(rawDate: unknown): string {
  if (!rawDate) return "";
  let cleaned = String(rawDate).trim();
  if (cleaned && !cleaned.endsWith("Z")) {
    cleaned = cleaned.includes("T")
      ? `${cleaned}Z`
      : cleaned.includes(" ")
        ? `${cleaned.replace(" ", "T")}Z`
        : `${cleaned}T00:00:00Z`;
  }
  const parsedTime = Date.parse(cleaned);
  if (!isNaN(parsedTime)) {
    return new Date(parsedTime).toISOString();
  }
  return "";
}

export function getTranslatedRecallType(rawValue: string): { he: string; en: string } {
  const normalized = (rawValue || "").trim();
  let english = "Recall";
  if (normalized === "תקלה סידרתית בטיחותית") {
    english = "Safety Recall";
  } else if (normalized === "קמפיין שרות טכני") {
    english = "Technical Service Campaign";
  } else if (normalized) {
    english = normalized;
  }
  return { he: normalized, en: english };
}

export function parseRecallRecord(record: HebrewVehicleRecallRecord): VehicleRecallRecord | null {
  const rawRecallId = record.RECALL_ID;
  const rawId = record._id;

  if (rawRecallId === undefined || rawRecallId === null || rawId === undefined || rawId === null) {
    return null;
  }

  const recallId = Number(rawRecallId) || 0;
  if (recallId === 0) {
    return null;
  }

  const id = String(recallId).trim();
  const manufacturerCode = Number(record.TOZAR_CD) || 0;
  const manufacturerName = cleanString(record.TOZAR_TEUR ?? "לא ידוע");
  const modelName = cleanString(record.DEGEM ?? "לא ידוע");
  const recallYear = Number(record.SHNAT_RECALL) || 0;

  const buildStartDate = parseDateString(record.BUILD_BEGIN_A) || new Date().toISOString();
  const buildEndDate = parseDateString(record.BUILD_END_A) || new Date().toISOString();

  const recallType = getTranslatedRecallType(record.SUG_RECALL ?? "");
  const defectCategory = cleanString(record.SUG_TAKALA ?? "לא ידוע");
  const defectDescription = cleanString(record.TEUR_TAKALA ?? "");
  const repairAction = cleanString(record.OFEN_TIKUN ?? "");
  const euCategory = cleanString(record.TKINA_EU ?? "");
  const importerName = cleanString(record.YEVUAN_TEUR ?? "לא ידוע");
  const importerPhone = cleanString(record.TELEPHONE ?? "");
  const importerWebsite = cleanString(record.WEBSITE ?? "");

  const lastUpdated = buildEndDate || buildStartDate || new Date().toISOString();

  return {
    id,
    _id: rawId,
    recallId,
    manufacturerCode,
    manufacturerName,
    modelName,
    recallYear,
    buildStartDate,
    buildEndDate,
    recallType,
    defectCategory,
    defectDescription,
    repairAction,
    euCategory,
    importerName,
    importerPhone,
    importerWebsite,
    lastUpdated,
  };
}

export async function scrapeAndSyncVehicleRecalls(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.VEHICLE_RECALLS,
  options?: { forceFullSync?: boolean },
): Promise<{ success: boolean; count: number }> {
  const datasetId = resourceId;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  try {
    const targetCollection = DATASET_IDS.VEHICLE_RECALLS;
    logger.info(`Starting vehicle recalls sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const forceFullSync = options?.forceFullSync === true;
    let offset = 0;
    const limit = isEmulator ? 100 : 10000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching vehicle recalls data from: ${url}`);

      let records: HebrewVehicleRecallRecord[] = [];
      if (isEmulator && !forceFullSync) {
        records = [
          {
            _id: 1,
            RECALL_ID: 11020,
            TOZAR_CD: 1,
            TOZAR_TEUR: "TOYOTA",
            DEGEM: "AVENSIS",
            SHNAT_RECALL: 2011,
            BUILD_BEGIN_A: "2000-01-02",
            BUILD_END_A: "2008-12-31",
            SUG_RECALL: "תקלה סידרתית בטיחותית",
            SUG_TAKALA: "מנוע ומערכותיו",
            TEUR_TAKALA: "שסתום צינור דלק אוונסיס",
            OFEN_TIKUN: "החלפה",
            TKINA_EU: "M1",
            YEVUAN_TEUR: "יוניון מוטורס בעמ",
            TELEPHONE: "1-800-22-1514",
            WEBSITE: "WWW.TOYOTA.CO.IL/SERVICE-AND-ACCESSORIES/RECALL",
          },
          {
            _id: 3,
            RECALL_ID: 11029,
            TOZAR_CD: 105,
            TOZAR_TEUR: "SUZUKI MOTORCYCLES",
            DEGEM: "EXEL  SUZUK",
            SHNAT_RECALL: 2011,
            BUILD_BEGIN_A: "2010-01-03",
            BUILD_END_A: "2010-12-31",
            SUG_RECALL: "קמפיין שרות טכני",
            SUG_TAKALA: "מנוע ומערכותיו",
            TEUR_TAKALA: "וסת מתח",
            OFEN_TIKUN: "החלפה",
            TKINA_EU: "L1",
            YEVUAN_TEUR: "אבניר חברה לרכב בעמ",
            TELEPHONE: "03-5158856/7",
            WEBSITE: "WWW.OFERAVNIR.CO.IL/RECALLS",
          },
        ];
      } else {
        const response = await axios.get(url, { timeout: 15000 });
        records = response.data?.result?.records ?? [];
      }

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: VehicleRecallRecord[] = [];
      for (const rec of records) {
        const parsed = parseRecallRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      for (let i = 0; i < parsedRecords.length; i += 500) {
        const chunk = parsedRecords.slice(i, i + 500);
        const docRefs = chunk.map((r) => targetRef.doc(r.id));

        // Lookup existing documents in batch to retain their original createdAt timestamp
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

    logger.info("Updated vehicle recalls metadata. Ingestion complete.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Vehicle recalls scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
