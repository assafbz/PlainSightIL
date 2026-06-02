import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import axios from "axios";

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
    lastUpdated: new Date().toISOString(),
  };
}

export async function scrapeAndSyncCompaniesLiquidation(
  db: admin.firestore.Firestore,
  resourceId = "d8715392-287f-49b7-9ae3-f21ec5bf55f3",
): Promise<{ success: boolean; count: number }> {
  const datasetId = resourceId;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = "d8715392-287f-49b7-9ae3-f21ec5bf55f3";
    logger.info(`Starting sync. Target collection: ${targetCollection}`);

    let offset = 0;
    const limit = 1000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    while (hasMore) {
      const url = `https://data.gov.il/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching data from: ${url}`);

      const response = await axios.get(url);
      const records: HebrewLiquidationRecord[] = response.data?.result?.records ?? [];

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

        const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
        const existingCreatedAtMap = new Map<string, string>();
        for (const snap of snapshots) {
          if (snap.exists) {
            const data = snap.data();
            if (data && data.createdAt) {
              existingCreatedAtMap.set(snap.id, data.createdAt);
            }
          }
        }

        const batch = db.batch();
        for (const r of chunk) {
          const docRef = targetRef.doc(r.id);
          const existingCreatedAt = existingCreatedAtMap.get(r.id);

          r.createdAt = existingCreatedAt || now;
          r.lastUpdated = now;

          batch.set(docRef, r);
          processedCount++;
        }
        await batch.commit();
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
