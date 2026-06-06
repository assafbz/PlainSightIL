import * as admin from "firebase-admin";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

/**
 * Raw record format received from data.gov.il CKAN datastore API.
 */
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

/**
 * Normalized and sanitized record written to Firestore.
 */
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

/**
 * Maps a raw Hebrew car importer record into the clean, typed CarImporterRecord format.
 *
 * @param record Raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
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

/**
 * Scraper class for Car Importers dataset.
 */
export class CarImportersScraper extends BaseScraper<HebrewCarImporterRecord, CarImporterRecord> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.CAR_IMPORTERS;
  override readonly updateIntervalHours = 168; // weekly

  constructor(resourceId = DATASET_IDS.CAR_IMPORTERS) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw car importer record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewCarImporterRecord): CarImporterRecord | null {
    return parseCarImporterRecord(raw);
  }
}

/**
 * Scrapes car importers from data.gov.il datastore API and syncs them in-place.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @param resourceId Official resource identifier from data.gov.il.
 * @param options Synchronizer options.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncCarImporters(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.CAR_IMPORTERS,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new CarImportersScraper(resourceId);
  return scraper.scrape(db, options);
}
