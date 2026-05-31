import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { scrapeAndSyncAntennas } from "./scrapers/antennas_scraper";

admin.initializeApp();

const db = admin.firestore();

// Scheduled Cloud Function - runs daily at midnight (Israel timezone)
export const scheduledAntennaScraper = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("Asia/Jerusalem")
  .onRun(async () => {
    await scrapeAndSyncAntennas(db);
  });

// HTTPS Triggered Cloud Function - for manual invocation and dev environment triggers
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
