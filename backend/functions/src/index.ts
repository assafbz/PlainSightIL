import * as admin from "firebase-admin";
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
    await scrapeAndSyncAntennas(db);
  });

// HTTPS Triggered Cloud Function for Active Antennas - for manual invocation and dev triggers
export const manualSyncAntennas = functions.https.onRequest(async (req, res) => {
  try {
    const result = await scrapeAndSyncAntennas(db);
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
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
    await scrapeAndSyncPermitApplications(db);
  });

// HTTPS Triggered Cloud Function for Permit Applications - for manual invocation and dev triggers
export const manualSyncPermitApps = functions.https.onRequest(async (req, res) => {
  try {
    const result = await scrapeAndSyncPermitApplications(db);
    res.status(200).json({
      message: "Sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
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
    await scrapeAndSyncDatasetMetadata(db);
  });

// HTTPS Triggered Cloud Function for Dataset Metadata - manual sync
export const manualSyncMetadata = functions.https.onRequest(async (req, res) => {
  try {
    const result = await scrapeAndSyncDatasetMetadata(db);
    res.status(200).json({
      message: "Metadata sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
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
    await scrapeAndSyncCompaniesLiquidation(db);
  });

// HTTPS Triggered Cloud Function for Companies in Liquidation - manual sync
export const manualSyncCompaniesLiquidation = functions.https.onRequest(async (req, res) => {
  try {
    const result = await scrapeAndSyncCompaniesLiquidation(db);
    res.status(200).json({
      message: "Companies in liquidation sync completed successfully",
      count: result.count,
    });
  } catch (error) {
    const err = error as Error;
    res.status(500).json({
      message: "Companies in liquidation sync failed",
      error: err.message || String(error),
    });
  }
});
