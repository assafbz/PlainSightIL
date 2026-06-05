import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";

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
}

// Central list of dataset IDs that are currently visualized/supported in PlainSightIL (resource IDs)
const SUPPORTED_DATASET_IDS = new Set<string>([
  DATASET_IDS.CELLULAR_ANTENNAS, // Active Cellular Antennas
  DATASET_IDS.CELLULAR_PERMITS, // Cellular Antennas Under Construction Permits
  DATASET_IDS.COMPANIES_LIQUIDATION, // Companies in Liquidation
  DATASET_IDS.DOCTORS_LICENSES, // Doctors Licenses
  DATASET_IDS.PATENT_CLASSIFICATIONS, // Patent Applications CPC Classifications
  DATASET_IDS.TRAVEL_WARNINGS, // Travel Warnings
  DATASET_IDS.LOCAL_MARKET_BONDS, // Local Market Bonds
  "21fde05f-62e3-401b-81cf-5c385862026d", // Bank ATMs
]);

/**
 * Sanitizes and strips HTML tags from notes/descriptions to prevent injection.
 */
function sanitizeNotes(rawNotes?: string): string {
  if (!rawNotes) return "";
  // Simple regex to strip HTML tags
  return rawNotes.replace(/<[^>]*>/g, "").trim();
}

export async function scrapeAndSyncDatasetMetadata(
  db: admin.firestore.Firestore,
): Promise<{ success: boolean; count: number }> {
  const collectionName = "datasets_metadata";
  logger.info(`Starting dataset metadata sync. Target collection: ${collectionName}`);

  try {
    const targetRef = db.collection(collectionName);
    const now = new Date().toISOString();

    // Query CKAN package_search to fetch all packages.
    // Since there are ~1200 datasets, fetching rows=1500 in one request is efficient and avoids rate limit issues.
    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const url = `${baseUrl}/api/3/action/package_search?rows=1500`;
    logger.info(`Fetching CKAN package list from: ${url}`);

    const response = await axios.get(url);
    const packages: CKANPackage[] = response.data?.result?.results ?? [];

    if (packages.length === 0) {
      logger.warn("No packages returned from CKAN API.");
      return { success: true, count: 0 };
    }

    logger.info(`Fetched ${packages.length} packages from CKAN. Processing updates...`);

    const parsedDatasets: DatasetMetadata[] = [];

    for (const pkg of packages) {
      if (!pkg.id || !pkg.title) {
        continue;
      }

      let id = pkg.id.trim();
      let isSupported = false;

      // Check if the package ID itself is one of the supported dataset IDs
      if (SUPPORTED_DATASET_IDS.has(id)) {
        isSupported = true;
      } else {
        // Find if any resource ID in the package is in the supported dataset list
        const matchedResource = (pkg.resources ?? []).find(
          (r) => r.id && SUPPORTED_DATASET_IDS.has(r.id.trim()),
        );
        if (matchedResource) {
          id = matchedResource.id.trim();
          isSupported = true;
        }
      }

      const name = (pkg.name ?? "").trim();
      let title = pkg.title.trim();
      if (id === DATASET_IDS.COMPANIES_LIQUIDATION) {
        title = "חברות בפירוק";
      }
      const notes = sanitizeNotes(pkg.notes);
      const publisher = (pkg.organization?.title ?? "לא ידוע").trim();
      const resourceCount = pkg.num_resources ?? 0;
      const lastUpdated = pkg.metadata_modified ?? now;
      const tags = (pkg.tags ?? []).map((t) => (t.name ?? "").trim()).filter(Boolean);

      parsedDatasets.push({
        id,
        datasetId: pkg.id.trim(),
        name,
        title,
        notes,
        publisher,
        resourceCount,
        lastUpdated,
        tags,
        isSupported,
      });
    }

    // Process parsed datasets in chunks of 500 for Firestore batched writes
    let processedCount = 0;
    for (let i = 0; i < parsedDatasets.length; i += 500) {
      const chunk = parsedDatasets.slice(i, i + 500);
      const batch = db.batch();

      for (const dataset of chunk) {
        const docRef = targetRef.doc(dataset.id);
        batch.set(docRef, dataset, { merge: true });
        processedCount++;
      }

      await batch.commit();
    }
    logger.info(`Successfully synced ${processedCount} dataset metadata records.`);

    // Retrieve total count of documents in the collection
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

    const metadataRef = db.collection("dataset_metadata").doc(collectionName);
    await metadataRef.set(
      {
        id: collectionName,
        activeCollection: collectionName,
        lastUpdated: now,
        recordCount: totalRecords,
        status: "idle",
      },
      { merge: true },
    );

    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Dataset metadata sync failed:", error);
    throw error;
  }
}
