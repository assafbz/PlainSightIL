import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import { scrapeAndSyncAntennas } from "./scrapers/8935c8e5-ec77-421f-af86-d970583195f8";
import { scrapeAndSyncPermitApplications } from "./scrapers/ff398c7e-c522-4ee8-a53a-312b188a573d";
import { scrapeAndSyncDatasetMetadata } from "./scrapers/metadata_scraper";
import { scrapeAndSyncCompaniesLiquidation } from "./scrapers/d8715392-287f-49b7-9ae3-f21ec5bf55f3";

admin.initializeApp();

const db = admin.firestore();

// Scheduled Cloud Function for Active Antennas - runs daily at midnight (Israel timezone)
export const scheduledAntennaScraper = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    functions.logger.info("scheduledAntennaScraper trigger invoked");
    try {
      const result = await scrapeAndSyncAntennas(db);
      functions.logger.info("scheduledAntennaScraper completed successfully", {
        count: result.count,
      });
    } catch (error) {
      const err = error as Error;
      functions.logger.error("scheduledAntennaScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      throw error;
    }
  });

/**
 * Helper to validate if the incoming request is an authenticated POST request made by an admin.
 * Returns the decoded token if valid, otherwise sends an error response and returns null.
 */
async function validateAdminRequest(
  req: functions.https.Request,
  res: any,
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

// HTTPS Triggered Cloud Function for Active Antennas - for manual invocation and dev triggers
export const manualSyncAntennas = functions.https.onRequest(async (req, res) => {
  functions.logger.info("manualSyncAntennas HTTPS trigger invoked");
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "cellular_antennas";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncAntennas(db);
    functions.logger.info("manualSyncAntennas sync completed successfully", {
      count: result.count,
    });
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    functions.logger.error("manualSyncAntennas sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
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
    functions.logger.info("scheduledPermitAppsScraper trigger invoked");
    try {
      const result = await scrapeAndSyncPermitApplications(db);
      functions.logger.info("scheduledPermitAppsScraper completed successfully", {
        count: result.count,
      });
    } catch (error) {
      const err = error as Error;
      functions.logger.error("scheduledPermitAppsScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Permit Applications - for manual invocation and dev triggers
export const manualSyncPermitApps = functions.https.onRequest(async (req, res) => {
  functions.logger.info("manualSyncPermitApps HTTPS trigger invoked");
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "cellular_permit_applications";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncPermitApplications(db);
    functions.logger.info("manualSyncPermitApps sync completed successfully", {
      count: result.count,
    });
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    functions.logger.error("manualSyncPermitApps sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
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
    functions.logger.info("scheduledMetadataScraper trigger invoked");
    try {
      const result = await scrapeAndSyncDatasetMetadata(db);
      functions.logger.info("scheduledMetadataScraper completed successfully", {
        count: result.count,
      });
    } catch (error) {
      const err = error as Error;
      functions.logger.error("scheduledMetadataScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Dataset Metadata - manual sync
export const manualSyncMetadata = functions.https.onRequest(async (req, res) => {
  functions.logger.info("manualSyncMetadata HTTPS trigger invoked");
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  try {
    const result = await scrapeAndSyncDatasetMetadata(db);
    functions.logger.info("manualSyncMetadata sync completed successfully", {
      count: result.count,
    });
    res.status(200).json({
      message: "Metadata sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    functions.logger.error("manualSyncMetadata sync failed", {
      error: err.message,
      stack: err.stack,
    });
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
    functions.logger.info("scheduledCompaniesLiquidationScraper trigger invoked");
    try {
      const result = await scrapeAndSyncCompaniesLiquidation(db);
      functions.logger.info("scheduledCompaniesLiquidationScraper completed successfully", {
        count: result.count,
      });
    } catch (error) {
      const err = error as Error;
      functions.logger.error("scheduledCompaniesLiquidationScraper execution failed", {
        error: err.message,
        stack: err.stack,
      });
      throw error;
    }
  });

// HTTPS Triggered Cloud Function for Companies in Liquidation - manual sync
export const manualSyncCompaniesLiquidation = functions.https.onRequest(async (req, res) => {
  functions.logger.info("manualSyncCompaniesLiquidation HTTPS trigger invoked");
  const auth = await validateAdminRequest(req, res);
  if (!auth) return;

  const datasetId = "d8715392-287f-49b7-9ae3-f21ec5bf55f3";
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    // Set status to syncing in Firestore immediately
    await metadataRef.set({ status: "syncing" }, { merge: true });

    const result = await scrapeAndSyncCompaniesLiquidation(db);
    functions.logger.info("manualSyncCompaniesLiquidation sync completed successfully", {
      count: result.count,
    });
    res.status(200).json({
      message: "Companies in liquidation sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    functions.logger.error("manualSyncCompaniesLiquidation sync failed", {
      error: err.message,
      stack: err.stack,
    });
    await metadataRef.set({ status: "error" }, { merge: true });
    res.status(500).json({
      message: "Companies in liquidation sync failed",
      error: err.message || String(error),
    });
  }
});

/**
 * Cloud Function trigger running on user registration.
 * Creates an initial user profile in the users Firestore collection.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  functions.logger.info("onUserCreate triggered with user:", JSON.stringify(user));
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
    functions.logger.info(`Initialized user profile document for UID: ${uid}`);
  } catch (error) {
    functions.logger.error(`Failed to initialize user profile document for UID: ${uid}`, error);
  }
});
