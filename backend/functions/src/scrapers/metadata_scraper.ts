import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import axios from "axios";

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

// Hardcoded list of dataset IDs that are currently visualized/supported in PlainSightIL (resource IDs)
const SUPPORTED_DATASET_IDS = new Set([
  "8935c8e5-ec77-421f-af86-d970583195f8", // Active Cellular Antennas
  "ff398c7e-c522-4ee8-a53a-312b188a573d", // Cellular Antennas Under Construction Permits
  "d8715392-287f-49b7-9ae3-f21ec5bf55f3", // Companies in Liquidation
  "9c64c522-bbc2-48fe-96fb-3b2a8626f59e", // Doctors Licenses
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
    const url = "https://data.gov.il/api/3/action/package_search?rows=1500";
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
      const title = pkg.title.trim();
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
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Dataset metadata sync failed:", error);
    throw error;
  }
}
