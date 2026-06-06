import * as admin from "firebase-admin";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewTravelWarningRecord {
  _id: number;
  continent?: string;
  country?: string;
  recommendations?: string;
  details?: string;
  logo?: string;
  date?: string | null;
  משרד?: string;
}

/**
 * Interface representing the normalized travel warning record written to Firestore.
 */
export interface TravelWarningRecord {
  id: string;
  _id: number;
  continent: string;
  country: string;
  recommendations: string;
  details: string;
  logo: string;
  date: string | null;
  office: string;
  warningLevel: number;
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Extracts warning level (1 to 4) from recommendations text.
 *
 * @param recommendations The recommendations description text.
 * @returns Mapped warning level (1-4).
 */
export function extractWarningLevel(recommendations: string): number {
  if (!recommendations) return 1;
  const match = recommendations.match(/רמה\s+([1-4])/);
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return 1;
}

/**
 * Maps a raw Hebrew travel warning record into the clean, typed TravelWarningRecord format.
 * Sanitizes input and enforces default values.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
export function parseTravelWarningRecord(
  record: HebrewTravelWarningRecord,
): TravelWarningRecord | null {
  const rawId = record._id;
  if (rawId === undefined || rawId === null) {
    return null;
  }

  const id = String(rawId).trim();
  const continent = (record.continent ?? "").trim();
  const country = (record.country ?? "").trim();
  const recommendations = (record.recommendations ?? "").trim();
  const details = (record.details ?? "").trim();
  const logo = (record.logo ?? "").trim();
  const date = record.date ? String(record.date).trim() : null;
  const office = (record["משרד"] ?? "").trim();

  // Enforce country name exists
  if (!country) {
    return null;
  }

  const warningLevel = extractWarningLevel(recommendations);
  const sourceDate = date || new Date().toISOString();

  return {
    id,
    _id: rawId,
    continent,
    country,
    recommendations,
    details,
    logo,
    date,
    office,
    warningLevel,
    sourceCreatedAt: sourceDate,
    sourceUpdatedAt: sourceDate,
  };
}

/**
 * Scraper class for Travel Warnings dataset.
 */
export class TravelWarningsScraper extends BaseScraper<
  HebrewTravelWarningRecord,
  TravelWarningRecord
> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.TRAVEL_WARNINGS;
  override readonly updateIntervalHours = 24; // daily

  constructor(resourceId = DATASET_IDS.TRAVEL_WARNINGS) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw travel warning record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewTravelWarningRecord): TravelWarningRecord | null {
    return parseTravelWarningRecord(raw);
  }
}

/**
 * Scrapes travel warnings from data.gov.il datastore API and syncs them in-place to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db The Firestore database reference.
 * @param resourceId The resource ID for data.gov.il API.
 * @param options Synchronizer options.
 * @returns Success status and count of processed records.
 */
export async function scrapeAndSyncTravelWarnings(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.TRAVEL_WARNINGS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new TravelWarningsScraper(resourceId);
  return scraper.scrape(db, options);
}
