import * as admin from "firebase-admin";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
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

/**
 * Interface representing the normalized and sanitized record written to Firestore.
 */
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
 * Translates and normalizes raw Hebrew recall type.
 *
 * @param rawValue The raw Hebrew recall type.
 * @returns Localized recall type object.
 */
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

/**
 * Maps a raw Hebrew database record into the clean, typed VehicleRecallRecord format.
 * Sanitizes input and enforces numeric checks.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
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

  const nowStr = new Date().toISOString();

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
    sourceCreatedAt: nowStr,
    sourceUpdatedAt: nowStr,
  };
}

/**
 * Scraper class for Vehicle Recalls dataset.
 */
export class VehicleRecallsScraper extends BaseScraper<
  HebrewVehicleRecallRecord,
  VehicleRecallRecord
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.VEHICLE_RECALLS;
  override readonly updateIntervalHours = 168; // weekly

  constructor(resourceId = DATASET_IDS.VEHICLE_RECALLS) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw vehicle recall record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewVehicleRecallRecord): VehicleRecallRecord | null {
    return parseRecallRecord(raw);
  }

  /**
   * Returns mock records for emulator seeding.
   *
   * @returns Array of mock records.
   */
  protected override getMockRecords(): HebrewVehicleRecallRecord[] {
    return [
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
  }
}

/**
 * Scrapes vehicle recalls from data.gov.il datastore API and syncs them in-place to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db The Firestore database reference.
 * @param resourceId The resource ID for data.gov.il API.
 * @param options Synchronizer options.
 * @returns Success status and count of processed records.
 */
export async function scrapeAndSyncVehicleRecalls(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.VEHICLE_RECALLS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new VehicleRecallsScraper(resourceId);
  return scraper.scrape(db, options);
}
