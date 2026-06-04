import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

// Translation mapping for case statuses
const STATUS_TRANSLATIONS: Record<string, string> = {
  "פירוק פעיל": "Active Winding Up",
  פעיל: "Active",
  סגור: "Closed",
  "תיק סגור": "Closed",
  בוטל: "Cancelled",
  הקפאה: "Frozen",
  "הקפאת הליכים": "Frozen",
};

export function getTranslatedStatus(rawValue: string): { he: string; en: string } {
  const normalized = (rawValue || "").trim();
  const english = STATUS_TRANSLATIONS[normalized] || normalized;
  return { he: normalized, en: english };
}

export interface HebrewLiquidationRecord {
  "מזהה תיק פירוק חברה"?: number | string;
  "עיר פעילות חברה"?: string;
  "סטטוס תיק"?: string;
  "תאריך הגשת הבקשה"?: string;
  "תאריך קבלת צו פירוק"?: string;
  "תאריך ביטול / הקפאת צו פירוק"?: string;
  "תאריך סגירת תיק"?: string;
  "סיבת סגירה"?: string;
  "בית משפט מחוזי בו מתנהל התיק"?: string;
  "שם החברה"?: string;
  "מספר זיהוי של החברה"?: number | string;
  _id?: number;
}

export interface CompaniesLiquidationRecord {
  id: string;
  companyId: number;
  companyName: string;
  liquidationCaseId: number;
  caseStatus: { he: string; en: string };
  submissionDate: string;
  liquidationOrderDate: string;
  cancellationFreezeDate: string | null;
  closureDate: string | null;
  closureReason: string | null;
  districtCourt: string;
  cityOfActivity: string;
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

export function parseLiquidationRecord(
  record: HebrewLiquidationRecord,
): CompaniesLiquidationRecord | null {
  const rawCompanyId = record["מספר זיהוי של החברה"];
  const rawCompanyName = record["שם החברה"];
  const rawCaseId = record["מזהה תיק פירוק חברה"];

  if (rawCompanyId === undefined || rawCompanyName === undefined || rawCaseId === undefined) {
    return null;
  }

  const companyId = Number(rawCompanyId) || 0;
  const companyName = cleanString(rawCompanyName);
  const liquidationCaseId = Number(rawCaseId) || 0;

  if (companyId === 0 || !companyName || liquidationCaseId === 0) {
    return null;
  }

  const id = String(companyId).trim();
  const caseStatus = getTranslatedStatus(record["סטטוס תיק"] ?? "פירוק פעיל");
  const cityOfActivity = cleanString(record["עיר פעילות חברה"] ?? "לא ידוע");
  const districtCourt = cleanString(record["בית משפט מחוזי בו מתנהל התיק"] ?? "לא ידוע");

  const submissionDate = parseDateString(record["תאריך הגשת הבקשה"]);
  const liquidationOrderDate = parseDateString(record["תאריך קבלת צו פירוק"]);
  const cancellationFreezeDate = parseDateString(record["תאריך ביטול / הקפאת צו פירוק"]) || null;
  const closureDate = parseDateString(record["תאריך סגירת תיק"]) || null;
  const closureReason = cleanString(record["סיבת סגירה"]) || null;

  const lastUpdated = liquidationOrderDate || submissionDate || new Date().toISOString();

  return {
    id,
    companyId,
    companyName,
    liquidationCaseId,
    caseStatus,
    submissionDate: submissionDate || new Date().toISOString(),
    liquidationOrderDate: liquidationOrderDate || new Date().toISOString(),
    cancellationFreezeDate,
    closureDate,
    closureReason,
    districtCourt,
    cityOfActivity,
    lastUpdated,
  };
}

export async function scrapeAndSyncCompaniesLiquidation(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.COMPANIES_LIQUIDATION,
): Promise<{ success: boolean; count: number }> {
  const datasetId = resourceId;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  try {
    const targetCollection = DATASET_IDS.COMPANIES_LIQUIDATION;
    logger.info(`Starting sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
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

      let records: HebrewLiquidationRecord[] = [];
      if (isEmulator) {
        records = [
          {
            "מזהה תיק פירוק חברה": 11111,
            "שם החברה": "בשן פרסום ויחסי צבור בע~מ",
            "מספר זיהוי של החברה": 510000001,
            "סטטוס תיק": "פירוק פעיל",
            "תאריך הגשת הבקשה": "2024-05-12T00:00:00",
            "תאריך קבלת צו פירוק": "2024-06-15T00:00:00",
            "בית משפט מחוזי בו מתנהל התיק": "מחוזי תל אביב",
            "עיר פעילות חברה": "תל אביב - יפו",
          },
          {
            "מזהה תיק פירוק חברה": 22222,
            "שם החברה": "מלון הגליל בע~מ",
            "מספר זיהוי של החברה": 510000002,
            "סטטוס תיק": "פירוק פעיל",
            "תאריך הגשת הבקשה": "2024-05-12T00:00:00",
            "תאריך קבלת צו פירוק": "2024-06-15T00:00:00",
            "בית משפט מחוזי בו מתנהל התיק": "מחוזי נצרת",
            "עיר פעילות חברה": "טבריה",
          },
        ];
      } else {
        const response = await axios.get(url);
        records = response.data?.result?.records ?? [];
      }

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: CompaniesLiquidationRecord[] = [];
      for (const rec of records) {
        const parsed = parseLiquidationRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      for (let i = 0; i < parsedRecords.length; i += 500) {
        const chunk = parsedRecords.slice(i, i + 500);
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

    logger.info("Updated metadata. Ingestion complete.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
