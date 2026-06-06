import * as admin from "firebase-admin";
import axios from "axios";
import { AppLogger as logger } from "../utils/logger";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";
import { broadcastAlert } from "../utils/alerts";

/**
 * Interface representing the raw package data format from data.gov.il CKAN API.
 */
export interface CKANPackage {
  id: string;
  name: string;
  title: string;
  notes?: string;
  organization?: {
    title: string;
  };
  num_resources?: number;
  metadata_modified?: string;
  tags?: Array<{ name: string }>;
  resources?: Array<{ id: string; name?: string }>;
}

/**
 * Interface representing the normalized dataset metadata written to Firestore.
 */
export interface DatasetMetadata {
  id: string;
  datasetId: string;
  name: string;
  title: string;
  notes: string;
  publisher: string;
  resourceCount: number;
  lastUpdated: string;
  tags: string[];
  isSupported: boolean;
  createdAt?: string;
  updatedAt?: string;
}

// Central list of dataset IDs that are currently visualized/supported in PlainSightIL (resource IDs)
const SUPPORTED_DATASET_IDS = new Set<string>([
  DATASET_IDS.CELLULAR_ANTENNAS, // Active Cellular Antennas
  DATASET_IDS.CELLULAR_PERMITS, // Cellular Antennas Under Construction Permits
  DATASET_IDS.COMPANIES_LIQUIDATION, // Companies in Liquidation
  DATASET_IDS.DOCTORS_LICENSES, // Doctors Licenses
  DATASET_IDS.PATENT_CLASSIFICATIONS, // Patent Applications CPC Classifications
  DATASET_IDS.TRAVEL_WARNINGS, // Travel Warnings
  DATASET_IDS.CAR_IMPORTERS, // Car Importers
  DATASET_IDS.LOCAL_MARKET_BONDS, // Local Market Bonds
  DATASET_IDS.BANK_ATMS, // Bank ATMs
  DATASET_IDS.VEHICLE_RECALLS, // Vehicle Recalls
]);

/**
 * Sanitizes and strips HTML tags from notes/descriptions to prevent injection.
 *
 * @param rawNotes The raw description notes.
 * @returns Cleaned text string.
 */
export function sanitizeNotes(rawNotes?: string): string {
  if (!rawNotes) return "";
  // Simple regex to strip HTML tags
  return rawNotes.replace(/<[^>]*>/g, "").trim();
}

/**
 * Scraper class for Datasets Metadata.
 * Queries CKAN package API to fetch metadata for all Israeli government datasets.
 */
export class MetadataScraper extends BaseScraper<CKANPackage, DatasetMetadata> {
  readonly datasetId = "datasets_metadata";
  readonly targetCollection = "datasets_metadata";
  override readonly updateIntervalHours = 168; // weekly

  /**
   * Overridden fetchPage to query CKAN package_search directly.
   */
  protected override async fetchPage(
    offset: number,
    limit: number,
    options?: ScraperOptions,
  ): Promise<CKANPackage[]> {
    if (offset > 0) {
      return []; // Return empty to stop pagination loop after page 1
    }

    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

    if (!isEmulator && !baseUrl.startsWith("https://")) {
      throw new Error(`Insecure base URL protocol: ${baseUrl}. Scrapers must use HTTPS.`);
    }

    const url = `${baseUrl}/api/3/action/package_search?rows=1500`;
    logger.info(`Fetching CKAN package list from: ${url}`);

    const response = await this.executeWithRetry(() =>
      axios.get(url, { timeout: options?.timeout || this.requestTimeout }),
    );
    return response.data?.result?.results ?? [];
  }

  /**
   * Parses a raw CKAN package record.
   */
  parseRecord(raw: CKANPackage): DatasetMetadata | null {
    if (!raw.id || !raw.title) {
      return null;
    }

    let id = raw.id.trim();
    let isSupported = false;

    // Check if the package ID itself is one of the supported dataset IDs
    if (SUPPORTED_DATASET_IDS.has(id)) {
      isSupported = true;
    } else {
      // Find if any resource ID in the package is in the supported dataset list
      const matchedResource = (raw.resources ?? []).find(
        (r) => r.id && SUPPORTED_DATASET_IDS.has(r.id.trim()),
      );
      if (matchedResource) {
        id = matchedResource.id.trim();
        isSupported = true;
      }
    }

    const name = (raw.name ?? "").trim();
    let title = raw.title.trim();
    if (id === DATASET_IDS.COMPANIES_LIQUIDATION) {
      title = "חברות בפירוק";
    }
    const notes = sanitizeNotes(raw.notes);
    const publisher = (raw.organization?.title ?? "לא ידוע").trim();
    const resourceCount = raw.num_resources ?? 0;
    const lastUpdated = raw.metadata_modified ?? new Date().toISOString();
    const tags = (raw.tags ?? []).map((t) => (t.name ?? "").trim()).filter(Boolean);

    return {
      id,
      datasetId: raw.id.trim(),
      name,
      title,
      notes,
      publisher,
      resourceCount,
      lastUpdated,
      tags,
      isSupported,
    };
  }

  /**
   * Overrides triggerAlerts to bypass standard subscriber alerts.
   */
  protected override async triggerAlerts(
    _db: admin.firestore.Firestore,
    _result: ScraperResult,
    _isFirstSync: boolean,
  ): Promise<void> {}

  /**
   * Triggers specific global system alerts when a new dataset is found or supported.
   */
  protected override async onRecordUpdate(
    db: admin.firestore.Firestore,
    incoming: DatasetMetadata,
    existing: DatasetMetadata | null,
    isFirstSync: boolean,
  ): Promise<void> {
    if (isFirstSync) {
      return;
    }

    if (!existing) {
      // New government dataset alert
      await broadcastAlert(db, {
        type: "new_government_dataset",
        datasetId: incoming.id,
        title: {
          he: `נתגלה מאגר מידע ממשלתי חדש: ${incoming.title}`,
          en: `New Government Dataset Discovered: ${incoming.title}`,
        },
        description: {
          he: `המאגר '${incoming.title}' פורסם על ידי ${incoming.publisher} ב-data.gov.il.`,
          en: `The dataset '${incoming.title}' was published by ${incoming.publisher} on data.gov.il.`,
        },
      });

      if (incoming.isSupported) {
        // Visualizer supported alert
        await broadcastAlert(db, {
          type: "new_dataset",
          datasetId: incoming.id,
          title: {
            he: `מאגר מידע חדש זמין לצפייה: ${incoming.title}`,
            en: `New Visualizer Supported: ${incoming.title}`,
          },
          description: {
            he: `מאגר '${incoming.title}' זמין כעת לצפייה והדמיות אינטראקטיביות באפליקציה!`,
            en: `The dataset '${incoming.title}' is now available for interactive visualization in the app!`,
          },
        });
      }
    } else {
      const wasSupported = existing.isSupported === true;
      const isNowSupported = incoming.isSupported === true;
      if (!wasSupported && isNowSupported) {
        // Visualizer supported transition alert
        await broadcastAlert(db, {
          type: "new_dataset",
          datasetId: incoming.id,
          title: {
            he: `מאגר מידע חדש זמין לצפייה: ${incoming.title}`,
            en: `New Visualizer Supported: ${incoming.title}`,
          },
          description: {
            he: `מאגר '${incoming.title}' זמין כעת לצפייה והדמיות אינטראקטיביות באפליקציה!`,
            en: `The dataset '${incoming.title}' is now available for interactive visualization in the app!`,
          },
        });
      }
    }
  }
}

/**
 * Scrapes dataset metadata from data.gov.il CKAN API and syncs to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db Firestore database instance.
 * @returns Execution outcome metrics.
 */
export async function scrapeAndSyncDatasetMetadata(
  db: admin.firestore.Firestore,
): Promise<ScraperResult> {
  const scraper = new MetadataScraper();
  return scraper.scrape(db);
}
