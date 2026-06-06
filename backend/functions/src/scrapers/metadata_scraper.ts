import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";
import { broadcastAlert } from "../utils/alerts";

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
  DATASET_IDS.CAR_IMPORTERS, // Car Importers
  DATASET_IDS.LOCAL_MARKET_BONDS, // Local Market Bonds
  DATASET_IDS.BANK_ATMS, // Bank ATMs
  DATASET_IDS.VEHICLE_RECALLS, // Vehicle Recalls
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
): Promise<{ success: boolean; count: number; changedCount: number }> {
  const collectionName = "datasets_metadata";
  logger.info(`Starting dataset metadata sync. Target collection: ${collectionName}`);

  try {
    const targetRef = db.collection(collectionName);
    const now = new Date().toISOString();

    const metadataRef = db.collection("dataset_metadata").doc(collectionName);
    const existingMetaDoc = await metadataRef.get();
    const isFirstSync = !existingMetaDoc.exists || !existingMetaDoc.data()?.lastUpdated;

    // Query CKAN package_search to fetch all packages.
    // Since there are ~1200 datasets, fetching rows=1500 in one request is efficient and avoids rate limit issues.
    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const url = `${baseUrl}/api/3/action/package_search?rows=1500`;
    logger.info(`Fetching CKAN package list from: ${url}`);

    const response = await axios.get(url);
    const packages: CKANPackage[] = response.data?.result?.results ?? [];

    if (packages.length === 0) {
      logger.warn("No packages returned from CKAN API.");
      return { success: true, count: 0, changedCount: 0 };
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
    let changedCount = 0;

    for (let i = 0; i < parsedDatasets.length; i += 500) {
      const chunk = parsedDatasets.slice(i, i + 500);
      const docRefs = chunk.map((d) => targetRef.doc(d.id));

      const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
      const existingMap = new Map<string, admin.firestore.DocumentData>();
      for (const snap of snapshots) {
        if (snap.exists) {
          existingMap.set(snap.id, snap.data()!);
        }
      }

      const batch = db.batch();
      let hasWrites = false;

      for (const dataset of chunk) {
        const docRef = targetRef.doc(dataset.id);
        const existingData = existingMap.get(dataset.id);

        let shouldWrite = false;

        if (!existingData) {
          shouldWrite = true;
          if (!isFirstSync) {
            // New government dataset alert
            await broadcastAlert(db, {
              type: "new_government_dataset",
              datasetId: dataset.id,
              title: {
                he: `נתגלה מאגר מידע ממשלתי חדש: ${dataset.title}`,
                en: `New Government Dataset Discovered: ${dataset.title}`,
              },
              description: {
                he: `המאגר '${dataset.title}' פורסם על ידי ${dataset.publisher} ב-data.gov.il.`,
                en: `The dataset '${dataset.title}' was published by ${dataset.publisher} on data.gov.il.`,
              },
            });

            if (dataset.isSupported) {
              // Visualizer supported alert
              await broadcastAlert(db, {
                type: "new_dataset",
                datasetId: dataset.id,
                title: {
                  he: `מאגר מידע חדש זמין לצפייה: ${dataset.title}`,
                  en: `New Visualizer Supported: ${dataset.title}`,
                },
                description: {
                  he: `מאגר '${dataset.title}' זמין כעת לצפייה והדמיות אינטראקטיביות באפליקציה!`,
                  en: `The dataset '${dataset.title}' is now available for interactive visualization in the app!`,
                },
              });
            }
          }
        } else {
          const isIdentical = areRecordsEqual(existingData, dataset);
          if (!isIdentical) {
            shouldWrite = true;
            const wasSupported = existingData.isSupported === true;
            const isNowSupported = dataset.isSupported === true;
            if (!wasSupported && isNowSupported && !isFirstSync) {
              // Visualizer supported transition alert
              await broadcastAlert(db, {
                type: "new_dataset",
                datasetId: dataset.id,
                title: {
                  he: `מאגר מידע חדש זמין לצפייה: ${dataset.title}`,
                  en: `New Visualizer Supported: ${dataset.title}`,
                },
                description: {
                  he: `מאגר '${dataset.title}' זמין כעת לצפייה והדמיות אינטראקטיביות באפליקציה!`,
                  en: `The dataset '${dataset.title}' is now available for interactive visualization in the app!`,
                },
              });
            }
          }
        }

        if (shouldWrite) {
          batch.set(docRef, dataset, { merge: true });
          changedCount++;
          hasWrites = true;
        }
        processedCount++;
      }

      if (hasWrites) {
        await batch.commit();
      }
    }
    logger.info(
      `Successfully synced ${processedCount} dataset metadata records. Changes: ${changedCount}`,
    );

    // Retrieve total count of documents in the collection
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

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

    return { success: true, count: processedCount, changedCount };
  } catch (error) {
    logger.error("Dataset metadata sync failed:", error);
    throw error;
  }
}
