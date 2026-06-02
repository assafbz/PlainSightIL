import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import { logger } from "firebase-functions";
import axios from "axios";

import { scrapeAndSyncAntennas } from "./scrapers/8935c8e5-ec77-421f-af86-d970583195f8";
import { scrapeAndSyncPermitApplications } from "./scrapers/ff398c7e-c522-4ee8-a53a-312b188a573d";
import { scrapeAndSyncDatasetMetadata } from "./scrapers/metadata_scraper";
import { scrapeAndSyncCompaniesLiquidation } from "./scrapers/d8715392-287f-49b7-9ae3-f21ec5bf55f3";
import { scrapeAndSyncDoctorsLicenses } from "./scrapers/9c64c522-bbc2-48fe-96fb-3b2a8626f59e";
import { ScraperTelemetryTracker } from "./utils/telemetry";

admin.initializeApp();

const db = admin.firestore();

/**
 * Helper to configure CORS headers and automatically resolve preflight OPTIONS requests.
 * Returns true if the request was an OPTIONS request and has been completed.
 */
function handleCors(req: functions.https.Request, res: functions.Response): boolean {
  res.set("Access-Control-Allow-Origin", "*");
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
  const url = "https://data.gov.il";
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

// Scheduled Cloud Function for Active Antennas - runs daily at midnight (Israel timezone)
export const scheduledAntennaScraper = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    logger.info("scheduledAntennaScraper trigger invoked");
    const tracker = ScraperTelemetryTracker.start("8935c8e5-ec77-421f-af86-d970583195f8");
    try {
      const result = await scrapeAndSyncAntennas(db);
      logger.info("scheduledAntennaScraper completed successfully", {
        count: result.count,
      });
      await tracker.complete(db, result.count);
    } catch (error) {
      const err = error as Error;
      logger.error("scheduledAntennaScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      await tracker.fail(db, err);
      throw error;
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
  // eslint-disable-next-line no-undef
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

// HTTPS Triggered Cloud Function for Active Antennas - for manual invocation and dev triggers
export const manualSyncAntennas = functions.https.onRequest(async (req, res) => {
  logger.info("manualSyncAntennas HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "8935c8e5-ec77-421f-af86-d970583195f8";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  const tracker = ScraperTelemetryTracker.start(datasetId);
  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncAntennas(db);
    logger.info("manualSyncAntennas sync completed successfully", {
      count: result.count,
    });
    await tracker.complete(db, result.count);
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    logger.error("manualSyncAntennas sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
    await tracker.fail(db, err);
    res.status(500).json({
      message: "Sync failed",
      error: err.message || String(error),
    });
  }
});

// Scheduled Cloud Function for Permit Applications - runs weekly on Sunday at midnight (Israel timezone)
export const scheduledPermitAppsScraper = functions.pubsub
  .schedule("0 0 * * 0")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    logger.info("scheduledPermitAppsScraper trigger invoked");
    const tracker = ScraperTelemetryTracker.start("ff398c7e-c522-4ee8-a53a-312b188a573d");
    try {
      const result = await scrapeAndSyncPermitApplications(db);
      logger.info("scheduledPermitAppsScraper completed successfully", {
        count: result.count,
      });
      await tracker.complete(db, result.count);
    } catch (error) {
      const err = error as Error;
      logger.error("scheduledPermitAppsScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      await tracker.fail(db, err);
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Permit Applications - for manual invocation and dev triggers
export const manualSyncPermitApps = functions.https.onRequest(async (req, res) => {
  logger.info("manualSyncPermitApps HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "ff398c7e-c522-4ee8-a53a-312b188a573d";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  const tracker = ScraperTelemetryTracker.start(datasetId);
  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncPermitApplications(db);
    logger.info("manualSyncPermitApps sync completed successfully", {
      count: result.count,
    });
    await tracker.complete(db, result.count);
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    logger.error("manualSyncPermitApps sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
    await tracker.fail(db, err);
    res.status(500).json({
      message: "Sync failed",
      error: err.message || String(error),
    });
  }
});

// Scheduled Cloud Function for Dataset Metadata - runs weekly on Sunday at 1:00 AM (Israel timezone)
export const scheduledMetadataScraper = functions.pubsub
  .schedule("0 1 * * 0")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    logger.info("scheduledMetadataScraper trigger invoked");
    const tracker = ScraperTelemetryTracker.start("datasets_metadata");
    try {
      const result = await scrapeAndSyncDatasetMetadata(db);
      logger.info("scheduledMetadataScraper completed successfully", {
        count: result.count,
      });
      await tracker.complete(db, result.count);
    } catch (error) {
      const err = error as Error;
      logger.error("scheduledMetadataScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      await tracker.fail(db, err);
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Dataset Metadata - manual sync
export const manualSyncMetadata = functions.https.onRequest(async (req, res) => {
  logger.info("manualSyncMetadata HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const tracker = ScraperTelemetryTracker.start("datasets_metadata");
  try {
    const result = await scrapeAndSyncDatasetMetadata(db);
    logger.info("manualSyncMetadata sync completed successfully", {
      count: result.count,
    });
    await tracker.complete(db, result.count);
    res.status(200).json({
      message: "Metadata sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    logger.error("manualSyncMetadata sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await tracker.fail(db, err);
    res.status(500).json({
      message: "Metadata sync failed",
      error: err.message || String(error),
    });
  }
});

// Scheduled Cloud Function for Companies in Liquidation - runs weekly on Sunday at 2:00 AM (Israel timezone)
export const scheduledCompaniesLiquidationScraper = functions.pubsub
  .schedule("0 2 * * 0")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    logger.info("scheduledCompaniesLiquidationScraper trigger invoked");
    const tracker = ScraperTelemetryTracker.start("d8715392-287f-49b7-9ae3-f21ec5bf55f3");
    try {
      const result = await scrapeAndSyncCompaniesLiquidation(db);
      logger.info("scheduledCompaniesLiquidationScraper completed successfully", {
        count: result.count,
      });
      await tracker.complete(db, result.count);
    } catch (error) {
      const err = error as Error;
      logger.error("scheduledCompaniesLiquidationScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      await tracker.fail(db, err);
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Companies in Liquidation - manual sync
export const manualSyncCompaniesLiquidation = functions.https.onRequest(async (req, res) => {
  logger.info("manualSyncCompaniesLiquidation HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "d8715392-287f-49b7-9ae3-f21ec5bf55f3";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  const tracker = ScraperTelemetryTracker.start(datasetId);
  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncCompaniesLiquidation(db);
    logger.info("manualSyncCompaniesLiquidation sync completed successfully", {
      count: result.count,
    });
    await tracker.complete(db, result.count);
    res.status(200).json({
      message: "Companies in liquidation sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    logger.error("manualSyncCompaniesLiquidation sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
    await tracker.fail(db, err);
    res.status(500).json({
      message: "Companies in liquidation sync failed",
      error: err.message || String(error),
    });
  }
});

// Scheduled Cloud Function for Doctors Licenses - runs weekly on Sunday at 3:00 AM (Israel timezone)
export const scheduledDoctorsLicensesScraper = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB" })
  .pubsub.schedule("0 3 * * 0")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    logger.info("scheduledDoctorsLicensesScraper trigger invoked");
    const tracker = ScraperTelemetryTracker.start("9c64c522-bbc2-48fe-96fb-3b2a8626f59e");
    try {
      const result = await scrapeAndSyncDoctorsLicenses(db);
      logger.info("scheduledDoctorsLicensesScraper completed successfully", {
        count: result.count,
      });
      await tracker.complete(db, result.count);
    } catch (error) {
      const err = error as Error;
      logger.error("scheduledDoctorsLicensesScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      await tracker.fail(db, err);
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Doctors Licenses - manual sync
export const manualSyncDoctorsLicenses = functions
  .runWith({ timeoutSeconds: 540, memory: "1GB" })
  .https.onRequest(async (req, res) => {
  logger.info("manualSyncDoctorsLicenses HTTPS trigger invoked");
  if (handleCors(req, res)) return;
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "9c64c522-bbc2-48fe-96fb-3b2a8626f59e";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);
  const tracker = ScraperTelemetryTracker.start(datasetId);
  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncDoctorsLicenses(db);
    logger.info("manualSyncDoctorsLicenses sync completed successfully", {
      count: result.count,
    });
    await tracker.complete(db, result.count);
    res.status(200).json({
      message: "Doctors licenses sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    logger.error("manualSyncDoctorsLicenses sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
    await tracker.fail(db, err);
    res.status(500).json({
      message: "Doctors licenses sync failed",
      error: err.message || String(error),
    });
  }
});

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
