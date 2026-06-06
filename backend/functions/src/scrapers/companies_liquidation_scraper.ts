import * as admin from "firebase-admin";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

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

/**
 * Translates a raw Hebrew case status.
 *
 * @param rawValue The raw Hebrew status string.
 * @returns Localized status object.
 */
export function getTranslatedStatus(rawValue: string): { he: string; en: string } {
  const normalized = (rawValue || "").trim();
  const english = STATUS_TRANSLATIONS[normalized] || normalized;
  return { he: normalized, en: english };
}

/**
 * Raw record format received from companies liquidation API.
 */
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

/**
 * Normalized and sanitized companies liquidation record written to Firestore.
 */
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
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
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

/**
 * Maps a raw Hebrew companies liquidation record into the clean, typed CompaniesLiquidationRecord format.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
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

  const sourceCreatedAt = submissionDate || new Date().toISOString();
  const sourceUpdatedAt = liquidationOrderDate || submissionDate || new Date().toISOString();

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
    sourceCreatedAt,
    sourceUpdatedAt,
  };
}

/**
 * Scraper class for Companies Liquidation dataset.
 */
export class CompaniesLiquidationScraper extends BaseScraper<
  HebrewLiquidationRecord,
  CompaniesLiquidationRecord
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.COMPANIES_LIQUIDATION;
  override readonly updateIntervalHours = 168; // weekly
  override readonly lastUpdatedSource = "parsed";

  constructor(resourceId = DATASET_IDS.COMPANIES_LIQUIDATION) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw companies liquidation record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewLiquidationRecord): CompaniesLiquidationRecord | null {
    return parseLiquidationRecord(raw);
  }

  /**
   * Returns mock records for emulator seeding.
   *
   * @returns Array of mock records.
   */
  protected override getMockRecords(): HebrewLiquidationRecord[] {
    return [
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
  }
}

/**
 * Scrapes companies liquidation from data.gov.il datastore API and syncs them in-place.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @param resourceId Official resource identifier from data.gov.il.
 * @param options Synchronizer options.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncCompaniesLiquidation(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.COMPANIES_LIQUIDATION,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new CompaniesLiquidationScraper(resourceId);
  return scraper.scrape(db, options);
}
