import * as admin from "firebase-admin";
import axios from "axios";
import { AppLogger as logger } from "../utils/logger";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

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
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
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
 *
 * @param he The Hebrew bond type.
 * @returns Localized bond type object.
 */
export function getBondTypeTranslation(he: string): { he: string; en: string } {
  const cleanHe = he.trim();
  const en = BOND_TYPE_TRANSLATIONS[cleanHe] || cleanHe;
  return { he: cleanHe, en };
}

/**
 * Parses DD/MM/YYYY date format to standard ISO-8601 string.
 *
 * @param val Raw value.
 * @returns ISO string or empty string.
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
 *
 * @param val Raw value.
 * @returns ISO string.
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
 *
 * @param record Raw record.
 * @returns Mapped record, or null if invalid.
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
    sourceCreatedAt: issuanceDate || new Date().toISOString(),
    sourceUpdatedAt: issuanceDate || new Date().toISOString(),
  };
}

/**
 * Scraper class for Local Market Bonds dataset.
 * Supports incremental/delta synchronization based on maximum processed _id.
 */
export class LocalMarketBondsScraper extends BaseScraper<
  HebrewLocalMarketBondRecord,
  LocalMarketBondRecord
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.LOCAL_MARKET_BONDS;
  override readonly updateIntervalHours = 24; // daily

  private lastSyncedMaxId = 0;
  private maxIdInThisRun = 0;

  constructor(resourceId = DATASET_IDS.LOCAL_MARKET_BONDS) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Fetches pages sorted by _id desc to check newest records first.
   */
  protected override async fetchPage(
    offset: number,
    limit: number,
    options?: ScraperOptions,
  ): Promise<HebrewLocalMarketBondRecord[]> {
    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

    if (!isEmulator && !baseUrl.startsWith("https://")) {
      throw new Error(`Insecure base URL protocol: ${baseUrl}. Scrapers must use HTTPS.`);
    }

    const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${this.datasetId}&limit=${limit}&offset=${offset}&sort=_id desc`;
    logger.info(`Fetching data for ${this.datasetId} from: ${url}`);

    const response = await this.executeWithRetry(() =>
      axios.get(url, { timeout: options?.timeout || this.requestTimeout }),
    );
    return response.data?.result?.records ?? [];
  }

  protected override async beforeScrape(
    _db: admin.firestore.Firestore,
    _options?: ScraperOptions,
  ): Promise<void> {
    if (this.metadataSnapshot && this.metadataSnapshot.exists) {
      const data = this.metadataSnapshot.data();
      if (data && typeof data.lastSyncedMaxId === "number") {
        this.lastSyncedMaxId = data.lastSyncedMaxId;
      }
    }
    this.maxIdInThisRun = this.lastSyncedMaxId;
    logger.info(`Delta sync active. Last synced max _id: ${this.lastSyncedMaxId}`);
  }

  /**
   * Terminates paging when encountering already-synced records.
   */
  protected override shouldStopPaging(raw: HebrewLocalMarketBondRecord): boolean {
    if (raw._id !== undefined && raw._id !== null && raw._id <= this.lastSyncedMaxId) {
      logger.info(
        `Reached previously synced record (_id: ${raw._id} <= lastSyncedMaxId: ${this.lastSyncedMaxId}). Stopping sync.`,
      );
      return true;
    }
    return false;
  }

  /**
   * Parses raw record and tracks the maximum processed ID.
   */
  parseRecord(raw: HebrewLocalMarketBondRecord): LocalMarketBondRecord | null {
    const parsed = parseLocalMarketBondRecord(raw);
    if (parsed && parsed._id > this.maxIdInThisRun) {
      this.maxIdInThisRun = parsed._id;
    }
    return parsed;
  }

  /**
   * Returns delta sync metadata updates.
   */
  protected override async afterScrape(
    _db: admin.firestore.Firestore,
    _processedCount: number,
    _changedCount: number,
  ): Promise<Record<string, unknown>> {
    return {
      lastSyncedMaxId: this.maxIdInThisRun,
    };
  }
}

/**
 * Scrapes domestic government bonds from data.gov.il datastore API and syncs them in-place.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @param resourceId Official resource identifier from data.gov.il.
 * @param options Synchronizer options.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncLocalMarketBonds(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.LOCAL_MARKET_BONDS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new LocalMarketBondsScraper(resourceId);
  return scraper.scrape(db, options);
}
