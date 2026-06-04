import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import { AppLogger as logger } from "./utils/logger";
import axios from "axios";
import { PubSub } from "@google-cloud/pubsub";

import { scrapeAndSyncAntennas } from "./scrapers/cellular_antennas_scraper";
import { scrapeAndSyncPermitApplications } from "./scrapers/cellular_permits_scraper";
import { scrapeAndSyncDatasetMetadata } from "./scrapers/metadata_scraper";
import { scrapeAndSyncCompaniesLiquidation } from "./scrapers/companies_liquidation_scraper";
import { scrapeAndSyncDoctorsLicenses } from "./scrapers/doctors_licenses_scraper";
import { scrapeAndSyncBankAtms } from "./scrapers/bank_atms_scraper";
import { scrapeAndSyncPatentClassifications } from "./scrapers/patent_classifications_scraper";
import { ScraperTelemetryTracker } from "./utils/telemetry";
import { DATASET_IDS } from "./utils/constants";

const scraperRegistry: Record<
  string,
  (db: admin.firestore.Firestore, options?: { forceFullSync?: boolean }) => Promise<{ count: number }>
> = {
  [DATASET_IDS.CELLULAR_ANTENNAS]: (db, opts) =>
    scrapeAndSyncAntennas(db, DATASET_IDS.CELLULAR_ANTENNAS, opts),
  [DATASET_IDS.CELLULAR_PERMITS]: (db, opts) =>
    scrapeAndSyncPermitApplications(db, DATASET_IDS.CELLULAR_PERMITS, opts),
  [DATASET_IDS.COMPANIES_LIQUIDATION]: (db, opts) =>
    scrapeAndSyncCompaniesLiquidation(db, DATASET_IDS.COMPANIES_LIQUIDATION, opts),
  [DATASET_IDS.DOCTORS_LICENSES]: (db, opts) =>
    scrapeAndSyncDoctorsLicenses(db, DATASET_IDS.DOCTORS_LICENSES, opts),
  [DATASET_IDS.BANK_ATMS]: (db, opts) =>
    scrapeAndSyncBankAtms(db, DATASET_IDS.BANK_ATMS, opts),
  [DATASET_IDS.PATENT_CLASSIFICATIONS]: (db) =>
    scrapeAndSyncPatentClassifications(db),
  datasets_metadata: (db) =>
    scrapeAndSyncDatasetMetadata(db),
};

const defaultIntervals: Record<string, number> = {
  [DATASET_IDS.CELLULAR_ANTENNAS]: 24, // Cellular Antennas (daily)
  [DATASET_IDS.CELLULAR_PERMITS]: 168, // Cellular Permit Apps (weekly)
  [DATASET_IDS.COMPANIES_LIQUIDATION]: 168, // Companies Liquidation (weekly)
  [DATASET_IDS.DOCTORS_LICENSES]: 168, // Doctors Licenses (weekly)
  [DATASET_IDS.BANK_ATMS]: 168, // Bank ATMs (weekly)
  [DATASET_IDS.PATENT_CLASSIFICATIONS]: 24, // Patent Classifications (daily)
  datasets_metadata: 168, // Dataset Metadata (weekly)
};

admin.initializeApp();

const db = admin.firestore();

/**
 * Helper to configure CORS headers and automatically resolve preflight OPTIONS requests.
 * Restricts origin to localhost development ports or production domains to prevent CSRF and cross-origin exploits.
 * Returns true if the request was an OPTIONS request and has been completed.
 * @param req Cloud Function HTTPS request object
 * @param res Cloud Function HTTPS response object
 */
function handleCors(req: functions.https.Request, res: functions.Response): boolean {
  const origin = req.headers.origin || "";

  if (!origin) {
    // If no origin is provided (e.g. non-browser requests), default to wildcard or omit
    res.set("Access-Control-Allow-Origin", "*");
  } else {
    const isLocalhost =
      origin.startsWith("http://localhost:") || origin.startsWith("http://127.0.0.1:");
    const isProduction =
      origin === "https://plainsight-il.web.app" ||
      origin === "https://plainsight-il.firebaseapp.com";

    if (isLocalhost || isProduction) {
      res.set("Access-Control-Allow-Origin", origin);
      // Vary header tells caching layers to cache responses differently based on origin
      res.set("Vary", "Origin");
    } else {
      res.set("Access-Control-Allow-Origin", "https://plainsight-il.web.app");
    }
  }

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Max-Age", "3600");
    res.status(204).send("");
    return true;
  }
  return false;
}

/**
 * Benchmark reachability status and response latency of the government open data API,
 * writing health statistics to the system_health collection.
 * @param firestoreDb Firestore database instance
 */
async function checkAndLogApiReachability(
  firestoreDb: admin.firestore.Firestore,
): Promise<{ isReachable: boolean; statusCode: number; latencyMs: number }> {
  const url = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
  const startTime = Date.now();
  try {
    logger.info(`Pinging government open data API at: ${url}`);
    // Pinging package_search endpoint with row limit of 1 to minimize payload size and avoid rate limiting
    const response = await axios.get(`${url}/api/3/action/package_search?rows=1`, {
      timeout: 10000,
    });
    const latencyMs = Date.now() - startTime;
    const statusCode = response.status;
    const isReachable = statusCode >= 200 && statusCode < 400;

    await firestoreDb.collection("system_health").doc("data_gov_il").set({
      url,
      isReachable,
      statusCode,
      latencyMs,
      lastChecked: new Date().toISOString(),
    });

    logger.info("API reachability check passed successfully", { statusCode, latencyMs });
    return { isReachable, statusCode, latencyMs };
  } catch (error) {
    const latencyMs = Date.now() - startTime;
    const err = error as { response?: { status: number }; message?: string };
    const statusCode = err.response ? err.response.status : 500;

    await firestoreDb.collection("system_health").doc("data_gov_il").set({
      url,
      isReachable: false,
      statusCode,
      latencyMs,
      lastChecked: new Date().toISOString(),
    });

    logger.error("API reachability check failed", { statusCode, error: err.message });
    return { isReachable: false, statusCode, latencyMs };
  }
}

/**
 * Scheduled Cloud Function checking the health of the government open data API every 15 minutes.
 */
export const scheduledApiHealthCheck = functions.pubsub.schedule("*/15 * * * *").onRun(async () => {
  logger.info("scheduledApiHealthCheck trigger invoked");
  await checkAndLogApiReachability(db);
});

/**
 * HTTPS Cloud Function for manually triggering an API reachability check.
 */
export const manualApiHealthCheck = functions.https.onRequest(async (req, res) => {
  logger.info("manualApiHealthCheck HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  try {
    const result = await checkAndLogApiReachability(db);
    res.status(200).json(result);
  } catch (error) {
    const err = error as Error;
    res.status(500).json({
      message: "API check execution failed",
      error: err.message || String(error),
    });
  }
});

/**
 * Helper to update the scheduler settings for a dataset upon completion or failure.
 * Calculates nextRun = now + updateIntervalHours (defaults to 24 or dataset default if not specified)
 * and updates Firestore dataset_metadata document.
 */
export async function updateSchedulerOnComplete(
  firestoreDb: admin.firestore.Firestore,
  datasetId: string,
  status: "idle" | "error",
): Promise<void> {
  const metadataRef = firestoreDb.collection("dataset_metadata").doc(datasetId);
  const now = new Date();

  try {
    const doc = await metadataRef.get();
    let updateIntervalHours = defaultIntervals[datasetId] || 24;
    let enabled = true;

    if (doc.exists) {
      const data = doc.data();
      if (data?.scheduler?.updateIntervalHours !== undefined) {
        updateIntervalHours = Number(data.scheduler.updateIntervalHours) || 24;
      }
      if (data?.scheduler?.enabled !== undefined) {
        enabled = data.scheduler.enabled === true;
      }
    }

    const nextRun = new Date(now.getTime() + updateIntervalHours * 60 * 60 * 1000).toISOString();

    await metadataRef.set(
      {
        status,
        lastUpdated: now.toISOString(),
        scheduler: {
          enabled,
          updateIntervalHours,
          nextRun,
        },
      },
      { merge: true },
    );
    logger.info(
      `Updated scheduler for dataset ${datasetId}: status=${status}, enabled=${enabled}, nextRun=${nextRun}`,
    );
  } catch (error) {
    logger.error(`Failed to update scheduler metadata for ${datasetId}`, error);
  }
}

/**
 * Scheduled Cloud Function running every 15 minutes to check which scrapers are due to run.
 */
export const scheduledScraperTicker = functions.pubsub.schedule("*/15 * * * *").onRun(async () => {
  logger.info("scheduledScraperTicker trigger invoked");
  const now = new Date().toISOString();
  try {
    const snapshot = await db
      .collection("dataset_metadata")
      .where("scheduler.enabled", "==", true)
      .get();

    const pubsub = new PubSub();
    const topic = pubsub.topic("run-scraper-topic");

    try {
      await topic.create();
    } catch (e: unknown) {
      const err = e as { code?: number; message?: string };
      if (err.code !== 6) {
        logger.warn(`Error creating topic: ${err.message}`);
      }
    }

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const datasetId = doc.id;
      const nextRun = data.scheduler?.nextRun;

      if (nextRun && nextRun <= now && data.status !== "syncing") {
        logger.info(`Dataset ${datasetId} is due. Triggering sync.`);

        // Update status to syncing in Firestore immediately
        await doc.ref.set({ status: "syncing" }, { merge: true });

        // Publish event to Pub/Sub topic
        const dataBuffer = Buffer.from(JSON.stringify({ datasetId }));
        await topic.publishMessage({ data: dataBuffer });
      }
    }
  } catch (error) {
    logger.error("scheduledScraperTicker execution failed", error);
  }
});

/**
 * Pub/Sub topic-triggered Cloud Function that executes the actual scraping.
 */
export const runScraperPubSub = functions.pubsub
  .topic("run-scraper-topic")
  .onPublish(async (message) => {
    let datasetId: string;
    try {
      const data = message.json;
      datasetId = (data as { datasetId?: string })?.datasetId || "";
    } catch (err) {
      logger.error("Failed to parse Pub/Sub message json", err);
      return;
    }

    if (!datasetId) {
      logger.error("No datasetId found in Pub/Sub message");
      return;
    }

    logger.info(`runScraperPubSub invoked for dataset: ${datasetId}`);

    const scraper = scraperRegistry[datasetId];
    if (!scraper) {
      logger.error(`No scraper registered for datasetId: ${datasetId}`);
      await db
        .collection("dataset_metadata")
        .doc(datasetId)
        .set({ status: "error" }, { merge: true });
      return;
    }

    const tracker = ScraperTelemetryTracker.start(datasetId);
    try {
      // Ensure status is set to syncing in database
      await db
        .collection("dataset_metadata")
        .doc(datasetId)
        .set({ status: "syncing" }, { merge: true });

      const result = await scraper(db, { forceFullSync: true });
      logger.info(`runScraperPubSub completed for dataset: ${datasetId}`, {
        count: result.count,
      });
      await tracker.complete(db, result.count);
      await updateSchedulerOnComplete(db, datasetId, "idle");
    } catch (error) {
      const err = error as Error;
      logger.error(`runScraperPubSub failed for dataset: ${datasetId}`, {
        error: err.message,
        stack: err.stack,
      });
      await updateSchedulerOnComplete(db, datasetId, "error");
      await tracker.fail(db, err);
    }
  });

/**
 * Helper to validate if the incoming request is an authenticated POST request made by an admin.
 * Returns the decoded token if valid, otherwise sends an error response and returns null.
 */
async function validateAdminRequest(
  req: functions.https.Request,
  res: functions.Response,
): Promise<{ uid: string } | null> {
  // Allow unauthenticated GET requests in local emulator for seeding/development

  if (process.env.FUNCTIONS_EMULATOR === "true" && req.method === "GET") {
    functions.logger.info("Bypassing admin check for emulator seeding via GET request.");
    return { uid: "emulator-seeder" };
  }

  // 1. Enforce POST request method
  if (req.method !== "POST") {
    functions.logger.warn(`Rejected manual sync request: method ${req.method} is not allowed.`);
    res.status(405).json({
      error: "Method Not Allowed",
      message: "Sync request must be a POST request.",
    });
    return null;
  }

  // 2. Extract authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    functions.logger.warn("Rejected manual sync request: missing or invalid authorization header.");
    res.status(401).json({
      error: "Unauthorized",
      message: "Missing or invalid authorization header.",
    });
    return null;
  }

  const token = authHeader.split("Bearer ")[1];
  try {
    // 3. Verify Firebase ID Token
    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;

    // 4. Retrieve user document from Firestore users collection
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      functions.logger.warn(`Rejected manual sync request: user ${uid} document not found.`);
      res.status(403).json({
        error: "Forbidden",
        message: "User profile not found in database.",
      });
      return null;
    }

    const userData = userDoc.data();
    if (!userData || userData.role !== "admin") {
      functions.logger.warn(`Rejected manual sync request: user ${uid} does not have admin role.`);
      res.status(403).json({
        error: "Forbidden",
        message: "Caller is not authorized to trigger manual sync.",
      });
      return null;
    }

    return { uid };
  } catch (error) {
    const err = error as Error;
    functions.logger.error("Authorization check failed with error:", err.message);
    res.status(401).json({
      error: "Unauthorized",
      message: "Token verification failed.",
      details: err.message,
    });
    return null;
  }
}

/**
 * Helper to check if the emulator startup seeder sync should be bypassed.
 * Returns true if we already have records and the schedule next run is in the future.
 */
async function shouldBypassEmulatorSeeder(datasetId: string): Promise<boolean> {
  try {
    const metaDoc = await db.collection("dataset_metadata").doc(datasetId).get();
    const countSnap = await db.collection(datasetId).limit(1).get();
    const hasRecords = !countSnap.empty;

    if (metaDoc.exists) {
      const metaData = metaDoc.data();
      const nextRun = metaData?.scheduler?.nextRun;
      const enabled = metaData?.scheduler?.enabled !== false;
      if (hasRecords && nextRun && enabled) {
        const nowStr = new Date().toISOString();
        if (nextRun > nowStr) {
          logger.info(
            `Dataset ${datasetId} is already seeded and not due yet (nextRun: ${nextRun}). Skipping startup sync.`
          );
          return true;
        }
      }
    }
  } catch (err) {
    logger.warn(
      `Failed to check existing metadata for ${datasetId} on startup seeder check, proceeding with sync.`,
      err
    );
  }
  return false;
}

/**
 * Factory function to create a standardized manual sync RequestHandler.
 */
function createManualSyncHandler(
  datasetId: string,
  options: { enableSeederBypass?: boolean } = {}
): (req: functions.https.Request, res: functions.Response) => Promise<void> {
  return async (req, res) => {
    logger.info(`manualSync for ${datasetId} HTTPS trigger invoked`);
    if (handleCors(req, res)) return;
    const auth = await validateAdminRequest(req, res);
    if (!auth) return;

    if (options.enableSeederBypass && auth.uid === "emulator-seeder") {
      const bypass = await shouldBypassEmulatorSeeder(datasetId);
      if (bypass) {
        res.status(200).json({
          message: "Sync skipped (schedule not due and data exists)",
          count: 0,
        });
        return;
      }
    }

    const tracker = ScraperTelemetryTracker.start(datasetId);
    try {
      // Set status to syncing in Firestore immediately
      await db
        .collection("dataset_metadata")
        .doc(datasetId)
        .set({ status: "syncing" }, { merge: true });

      const scraper = scraperRegistry[datasetId];
      if (!scraper) {
        throw new Error(`No scraper found registered for dataset: ${datasetId}`);
      }

      const forceFullSync = auth.uid !== "emulator-seeder";
      const result = await scraper(db, { forceFullSync });
      logger.info(`manualSync for ${datasetId} sync completed successfully`, {
        count: result.count,
      });
      await tracker.complete(db, result.count);
      await updateSchedulerOnComplete(db, datasetId, "idle");
      res.status(200).json({
        message: "Sync completed successfully",
        count: result.count,
      });
    } catch (error) {
      const err = error as Error;
      logger.error(`manualSync for ${datasetId} sync failed`, {
        error: err.message,
        stack: err.stack,
      });
      await updateSchedulerOnComplete(db, datasetId, "error");
      await tracker.fail(db, err);
      res.status(500).json({
        message: "Sync failed",
        error: err.message || String(error),
      });
    }
  };
}

// Export the HTTPS manual sync Cloud Functions
export const manualSyncAntennas = functions.https.onRequest(
  createManualSyncHandler(DATASET_IDS.CELLULAR_ANTENNAS, { enableSeederBypass: true })
);

export const manualSyncPermitApps = functions.https.onRequest(
  createManualSyncHandler(DATASET_IDS.CELLULAR_PERMITS, { enableSeederBypass: true })
);

export const manualSyncMetadata = functions.https.onRequest(
  createManualSyncHandler("datasets_metadata")
);

export const manualSyncCompaniesLiquidation = functions.https.onRequest(
  createManualSyncHandler(DATASET_IDS.COMPANIES_LIQUIDATION)
);

export const manualSyncDoctorsLicenses = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB" })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.DOCTORS_LICENSES));

export const manualSyncBankAtms = functions.https.onRequest(
  createManualSyncHandler(DATASET_IDS.BANK_ATMS)
);

export const manualSyncPatentClassifications = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB" })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.PATENT_CLASSIFICATIONS));

/**
 * Cloud Function trigger running on user registration.
 * Creates an initial user profile in the users Firestore collection.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  logger.info("onUserCreate triggered with user:", JSON.stringify(user));
  const uid = user.uid;
  const email = user.email || "";
  const displayName = user.displayName || "";

  // Gracefully parse displayName into firstName and lastName
  const nameParts = displayName.trim().split(/\s+/);
  const firstName = nameParts[0] || "";
  const lastName = nameParts.slice(1).join(" ") || "";

  const userDoc = {
    uid,
    firstName,
    lastName,
    email,
    role: "user", // defaults to standard user role
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  try {
    await admin.firestore().collection("users").doc(uid).set(userDoc);
    logger.info(`Initialized user profile document for UID: ${uid}`);
  } catch (error) {
    logger.error(`Failed to initialize user profile document for UID: ${uid}`, error);
  }
});

// Export internal helpers for testing purposes
export { handleCors };
