import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import { AppLogger as logger } from "./utils/logger";
import axios from "axios";
import { PubSub } from "@google-cloud/pubsub";

import { CellularAntennasScraper } from "./scrapers/cellular_antennas_scraper";
import { CellularPermitsScraper } from "./scrapers/cellular_permits_scraper";
import { MetadataScraper } from "./scrapers/metadata_scraper";
import { CompaniesLiquidationScraper } from "./scrapers/companies_liquidation_scraper";
import { DoctorsLicensesScraper } from "./scrapers/doctors_licenses_scraper";
import { BankAtmsScraper } from "./scrapers/bank_atms_scraper";
import { PatentClassificationsScraper } from "./scrapers/patent_classifications_scraper";
import { TravelWarningsScraper } from "./scrapers/travel_warnings_scraper";
import { VehicleRecallsScraper } from "./scrapers/vehicle_recalls_scraper";
import { CarImportersScraper } from "./scrapers/car_importers_scraper";
import { LocalMarketBondsScraper } from "./scrapers/local_market_bonds_scraper";
import { ScraperTelemetryTracker } from "./utils/telemetry";
import { DATASET_IDS } from "./utils/constants";
import { processAiSearch } from "./services/ai_search_service";
import { BaseScraper } from "./scrapers/base_scraper";
import { scoreDatasetWithAi } from "./services/ai_roadmap_service";

const scraperRegistry: Record<string, BaseScraper<any, any>> = {
  [DATASET_IDS.CELLULAR_ANTENNAS]: new CellularAntennasScraper(),
  [DATASET_IDS.CELLULAR_PERMITS]: new CellularPermitsScraper(),
  [DATASET_IDS.COMPANIES_LIQUIDATION]: new CompaniesLiquidationScraper(),
  [DATASET_IDS.DOCTORS_LICENSES]: new DoctorsLicensesScraper(),
  [DATASET_IDS.BANK_ATMS]: new BankAtmsScraper(),
  [DATASET_IDS.PATENT_CLASSIFICATIONS]: new PatentClassificationsScraper(),
  [DATASET_IDS.TRAVEL_WARNINGS]: new TravelWarningsScraper(),
  [DATASET_IDS.VEHICLE_RECALLS]: new VehicleRecallsScraper(),
  [DATASET_IDS.CAR_IMPORTERS]: new CarImportersScraper(),
  [DATASET_IDS.LOCAL_MARKET_BONDS]: new LocalMarketBondsScraper(),
  datasets_metadata: new MetadataScraper(),
};

const defaultIntervals: Record<string, number> = {
  [DATASET_IDS.CELLULAR_ANTENNAS]: 168, // Cellular Antennas (extended to weekly)
  [DATASET_IDS.CELLULAR_PERMITS]: 168, // Cellular Permit Apps (weekly)
  [DATASET_IDS.COMPANIES_LIQUIDATION]: 336, // Companies Liquidation (extended to bi-weekly)
  [DATASET_IDS.DOCTORS_LICENSES]: 336, // Doctors Licenses (extended to bi-weekly)
  [DATASET_IDS.BANK_ATMS]: 336, // Bank ATMs (extended to bi-weekly)
  [DATASET_IDS.PATENT_CLASSIFICATIONS]: 168, // Patent Classifications (extended to weekly)
  [DATASET_IDS.TRAVEL_WARNINGS]: 24, // Travel Warnings (daily)
  [DATASET_IDS.VEHICLE_RECALLS]: 168, // Vehicle Recalls (weekly)
  [DATASET_IDS.CAR_IMPORTERS]: 336, // Car Importers (extended to bi-weekly)
  [DATASET_IDS.LOCAL_MARKET_BONDS]: 24, // Local Market Bonds (daily)
  datasets_metadata: 168, // Dataset Metadata (weekly)
};

admin.initializeApp();

const db = admin.firestore();

// Define the service account to run the functions since the default compute service account was deleted.
// By default we use the App Engine default service account which typically exists.
const SERVICE_ACCOUNT = "plainsightil@appspot.gserviceaccount.com";

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
      origin === "https://plainsightil.web.app" ||
      origin === "https://plainsightil.firebaseapp.com" ||
      origin === "https://plainsight-il.web.app" ||
      origin === "https://plainsight-il.firebaseapp.com";

    if (isLocalhost || isProduction) {
      res.set("Access-Control-Allow-Origin", origin);
      // Vary header tells caching layers to cache responses differently based on origin
      res.set("Vary", "Origin");
    } else {
      res.set("Access-Control-Allow-Origin", "https://plainsightil.web.app");
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
export const scheduledApiHealthCheck = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .pubsub.schedule("*/15 * * * *")
  .onRun(async () => {
    logger.info("scheduledApiHealthCheck trigger invoked");
    await checkAndLogApiReachability(db);
  });

/**
 * HTTPS Cloud Function for manually triggering an API reachability check.
 */
export const manualApiHealthCheck = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(async (req, res) => {
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
export const scheduledScraperTicker = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .pubsub.schedule("*/15 * * * *")
  .onRun(async () => {
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

        // Check if stuck in syncing state (syncStartedAt older than 1 hour)
        if (data.status === "syncing") {
          const syncStartedAt = data.syncStartedAt || data.lastUpdated;
          if (syncStartedAt) {
            const startTime = new Date(syncStartedAt).getTime();
            const elapsedMs = Date.now() - startTime;
            const STUCK_THRESHOLD_MS = 60 * 60 * 1000; // 1 hour
            if (elapsedMs > STUCK_THRESHOLD_MS) {
              logger.warn(
                `Dataset ${datasetId} has been stuck in syncing for ${Math.round(elapsedMs / 60000)} minutes. Resetting to error.`,
              );
              // Telemetry tracker log failure
              const tracker = ScraperTelemetryTracker.start(datasetId);
              (tracker as any).startTime = new Date(syncStartedAt);
              await tracker.fail(db, new Error("Sync timed out / stuck in syncing state"));

              // Reset status using updateSchedulerOnComplete
              await updateSchedulerOnComplete(db, datasetId, "error");
              continue;
            }
          }
        }

        if (nextRun && nextRun <= now && data.status !== "syncing") {
          logger.info(`Dataset ${datasetId} is due. Triggering sync.`);

          // Update status to syncing in Firestore immediately
          await doc.ref.set(
            { status: "syncing", syncStartedAt: new Date().toISOString() },
            { merge: true },
          );

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
export const runScraperPubSub = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .pubsub.topic("run-scraper-topic")
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

    try {
      const result = await scraper.scrape(db, { forceFullSync: true });
      logger.info(`runScraperPubSub completed for dataset: ${datasetId}`, {
        count: result.count,
        changedCount: result.changedCount,
      });
    } catch (error) {
      const err = error as Error;
      logger.error(`runScraperPubSub failed for dataset: ${datasetId}`, {
        error: err.message,
        stack: err.stack,
      });
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
            `Dataset ${datasetId} is already seeded and not due yet (nextRun: ${nextRun}). Skipping startup sync.`,
          );
          return true;
        }
      }
    }
  } catch (err) {
    logger.warn(
      `Failed to check existing metadata for ${datasetId} on startup seeder check, proceeding with sync.`,
      err,
    );
  }
  return false;
}

/**
 * Factory function to create a standardized manual sync RequestHandler.
 */
function createManualSyncHandler(
  datasetId: string,
  options: { enableSeederBypass?: boolean } = {},
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

    try {
      const scraper = scraperRegistry[datasetId];
      if (!scraper) {
        throw new Error(`No scraper found registered for dataset: ${datasetId}`);
      }

      const forceFullSync = auth.uid !== "emulator-seeder";
      const result = await scraper.scrape(db, { forceFullSync });
      logger.info(`manualSync for ${datasetId} sync completed successfully`, {
        count: result.count,
        changedCount: result.changedCount,
      });

      res.status(200).json({
        message: "Sync completed successfully",
        count: result.count,
        changedCount: result.changedCount,
      });
    } catch (error) {
      const err = error as Error;
      logger.error(`manualSync for ${datasetId} sync failed`, {
        error: err.message,
        stack: err.stack,
      });
      res.status(500).json({
        message: "Sync failed",
        error: err.message || String(error),
      });
    }
  };
}

// Export the HTTPS manual sync Cloud Functions
export const manualSyncAntennas = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(
    createManualSyncHandler(DATASET_IDS.CELLULAR_ANTENNAS, { enableSeederBypass: true }),
  );

export const manualSyncPermitApps = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(
    createManualSyncHandler(DATASET_IDS.CELLULAR_PERMITS, { enableSeederBypass: true }),
  );

export const manualSyncMetadata = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler("datasets_metadata"));

export const manualSyncCompaniesLiquidation = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.COMPANIES_LIQUIDATION));

export const manualSyncDoctorsLicenses = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.DOCTORS_LICENSES));

export const manualSyncBankAtms = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.BANK_ATMS));

export const manualSyncPatentClassifications = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.PATENT_CLASSIFICATIONS));

export const manualSyncTravelWarnings = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.TRAVEL_WARNINGS));

export const manualSyncVehicleRecalls = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.VEHICLE_RECALLS));

export const manualSyncCarImporters = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(
    createManualSyncHandler(DATASET_IDS.CAR_IMPORTERS, { enableSeederBypass: true }),
  );

export const manualSyncLocalMarketBonds = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB", serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(createManualSyncHandler(DATASET_IDS.LOCAL_MARKET_BONDS));

/**
 * Cloud Function trigger running on user registration.
 * Creates an initial user profile in the users Firestore collection.
 */
export const onUserCreate = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .auth.user()
  .onCreate(async (user) => {
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
      role: process.env.FUNCTIONS_EMULATOR === "true" ? "admin" : "user",
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

/**
 * HTTPS Cloud Function for executing AI-powered semantic search across public datasets.
 * Enforces Firebase App Check and user authorization.
 */
export const aiSemanticSearch = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(async (req, res) => {
    logger.info("aiSemanticSearch HTTPS trigger invoked");
    if (handleCors(req, res)) return;

    // 1. Validate request method
    if (req.method !== "POST") {
      logger.warn(`Rejected aiSemanticSearch request: method ${req.method} is not allowed.`);
      res.status(405).json({
        error: "Method Not Allowed",
        message: "Semantic search must be a POST request.",
      });
      return;
    }

    // 2. Validate Firebase App Check token (only if not running in emulator)
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
      const appCheckToken = req.headers["x-firebase-appcheck"] as string;
      if (!appCheckToken) {
        logger.warn("Rejected aiSemanticSearch request: missing App Check token.");
        res.status(401).json({
          error: "Unauthorized",
          message: "Missing App Check token.",
        });
        return;
      }
      try {
        await admin.appCheck().verifyToken(appCheckToken);
      } catch (error) {
        logger.error("Rejected aiSemanticSearch request: invalid App Check token.", error);
        res.status(401).json({
          error: "Unauthorized",
          message: "Invalid App Check token.",
        });
        return;
      }
    } else {
      logger.info("Bypassing App Check token validation (emulator mode).");
    }

    // 3. Validate user authentication (Bearer token)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      logger.warn("Rejected aiSemanticSearch request: missing or invalid authorization header.");
      res.status(401).json({
        error: "Unauthorized",
        message: "Missing or invalid authorization header.",
      });
      return;
    }

    const token = authHeader.split("Bearer ")[1];
    try {
      await admin.auth().verifyIdToken(token);
    } catch (error) {
      logger.error("Rejected aiSemanticSearch request: invalid ID token.", error);
      res.status(401).json({
        error: "Unauthorized",
        message: "Invalid ID token.",
      });
      return;
    }

    // 4. Validate body parameters
    const { query, lang } = req.body || {};
    if (
      !query ||
      typeof query !== "string" ||
      query.trim().length === 0 ||
      query.trim().length > 200
    ) {
      logger.warn(
        "Rejected aiSemanticSearch request: query must be a non-empty string under 200 characters.",
      );
      res.status(400).json({
        error: "Bad Request",
        message: "Query must be a non-empty string under 200 characters.",
      });
      return;
    }

    const cleanQuery = query
      .trim()
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
    const cleanLang = lang === "en" ? "en" : "he";

    try {
      const searchResult = await processAiSearch(db, cleanQuery, cleanLang);
      res.status(200).json(searchResult);
    } catch (error) {
      const err = error as Error;
      logger.error("AI semantic search execution failed:", err);
      res.status(500).json({
        error: "Internal Server Error",
        message: "AI semantic search execution failed.",
        details: err.message || String(error),
      });
    }
  });

/**
 * Cloud Function trigger running on creation of a dataset request.
 * Automatically runs AI priority scoring on the newly requested dataset.
 */
export const onDatasetRequestCreate = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .firestore.document("dataset_requests/{datasetId}")
  .onCreate(async (snap, context) => {
    const datasetId = context.params.datasetId;
    logger.info(`onDatasetRequestCreate trigger invoked for datasetId: ${datasetId}`);
    try {
      await scoreDatasetWithAi(datasetId, db);
    } catch (error) {
      logger.error(`Automatic AI scoring failed for dataset ${datasetId}:`, error);
    }
  });

/**
 * HTTPS Cloud Function for manually triggering AI scoring & priority assessment
 * of an unsupported dataset. Authorized only for admin users.
 */
export const manualAnalyzeDataset = functions
  .runWith({ serviceAccount: SERVICE_ACCOUNT })
  .https.onRequest(async (req, res) => {
    logger.info("manualAnalyzeDataset HTTPS trigger invoked");
    if (handleCors(req, res)) return;

    const auth = await validateAdminRequest(req, res);
    if (!auth) return;

    const { datasetId } = req.body || {};
    if (!datasetId || typeof datasetId !== "string" || datasetId.trim().length === 0) {
      logger.warn("Rejected manualAnalyzeDataset request: missing or invalid datasetId.");
      res.status(400).json({
        error: "Bad Request",
        message: "Missing or invalid datasetId parameter.",
      });
      return;
    }

    try {
      const review = await scoreDatasetWithAi(datasetId, db);
      res.status(200).json({
        success: true,
        message: "AI analysis completed successfully.",
        review,
      });
    } catch (error) {
      const err = error as Error;
      logger.error(`manualAnalyzeDataset failed for dataset: ${datasetId}`, err);
      res.status(500).json({
        error: "Internal Server Error",
        message: "AI analysis execution failed.",
        details: err.message || String(error),
      });
    }
  });
