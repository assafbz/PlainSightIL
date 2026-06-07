import * as admin from "firebase-admin";
import axios from "axios";
import { AppLogger as logger } from "../utils/logger";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewPatentRecord {
  _id: number;
  "מספר בקשה"?: number | string;
  "שם האמצאה בעברית"?: string;
  "שם האמצאה באנגלית"?: string;
  "לבקשה CPC סיווג"?: string;
  ראשי?: string;
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
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Maps a raw Hebrew database record into the clean, typed PatentClassificationRecord format.
 * Sanitizes input and enforces numeric checks.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
export function parsePatentRecord(record: HebrewPatentRecord): PatentClassificationRecord | null {
  const rawId = record._id;
  const rawAppNum = record["מספר בקשה"];
  const rawCpc = record["לבקשה CPC סיווג"];

  if (
    rawId === undefined ||
    rawId === null ||
    rawAppNum === undefined ||
    rawAppNum === null ||
    !rawCpc
  ) {
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
  const nowStr = new Date().toISOString();

  return {
    id,
    _id: rawId,
    applicationNumber,
    titleHebrew,
    titleEnglish,
    cpcClassification,
    isPrimary,
    sourceCreatedAt: nowStr,
    sourceUpdatedAt: nowStr,
  };
}

/**
 * Scraper class for Patent Classifications dataset.
 * Implements incremental delta synchronization based on maximum processed _id.
 */
export class PatentClassificationsScraper extends BaseScraper<
  HebrewPatentRecord,
  PatentClassificationRecord
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.PATENT_CLASSIFICATIONS;
  override readonly updateIntervalHours = 24; // daily

  private lastSyncedMaxId = 0;
  private maxIdInThisRun = 0;

  constructor(resourceId = DATASET_IDS.PATENT_CLASSIFICATIONS) {
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
  ): Promise<HebrewPatentRecord[]> {
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

  /**
   * Reads the last processed max ID before sync execution starts.
   */
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
  protected override shouldStopPaging(raw: HebrewPatentRecord): boolean {
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
  parseRecord(raw: HebrewPatentRecord): PatentClassificationRecord | null {
    const parsed = parsePatentRecord(raw);
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
 * Scrapes patent applications CPC classifications from data.gov.il datastore API and syncs them in-place.
 * Backward-compatible wrapper function.
 *
 * @param db The Firestore database reference.
 * @param resourceId The resource ID for data.gov.il API.
 * @param options Synchronizer options.
 * @returns Success status and count of processed records.
 */
export async function scrapeAndSyncPatentClassifications(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.PATENT_CLASSIFICATIONS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new PatentClassificationsScraper(resourceId);
  return scraper.scrape(db, options);
}
