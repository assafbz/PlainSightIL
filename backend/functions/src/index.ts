import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { scrapeAndSyncAntennas } from "./scrapers/antennas_scraper";
import { scrapeAndSyncPermitApplications } from "./scrapers/permit_applications_scraper";

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
