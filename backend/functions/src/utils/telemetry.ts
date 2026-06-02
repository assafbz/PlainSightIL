import * as admin from "firebase-admin";
import { logger } from "firebase-functions";

/**
 * Tracks execution metrics and computes database operation quota estimates
 * for active ingestion pipeline runs, writing telemetry records to Firestore.
 */
export class ScraperTelemetryTracker {
  private datasetId: string;
  private startTime: Date;

  private constructor(datasetId: string) {
    this.datasetId = datasetId;
    this.startTime = new Date();
  }

  /**
   * Initialize a new telemetry tracker for a scraper pipeline run.
   * @param datasetId Unique identifier of the dataset (e.g. 'cellular_antennas')
   */
  static start(datasetId: string): ScraperTelemetryTracker {
    return new ScraperTelemetryTracker(datasetId);
  }

  /**
   * Log a successful scraper execution. Computes estimated database reads/writes.
   * @param db Firestore database reference
   * @param recordsProcessed Total number of records scraped and synchronized
   */
  async complete(db: admin.firestore.Firestore, recordsProcessed: number): Promise<void> {
    const endTime = new Date();
    const durationMs = endTime.getTime() - this.startTime.getTime();

    // Determine estimated reads and writes using the architectural formulas
    let firestoreReadsEstimate: number;
    let firestoreWritesEstimate: number;

    switch (this.datasetId) {
      case "8935c8e5-ec77-421f-af86-d970583195f8":
      case "ff398c7e-c522-4ee8-a53a-312b188a573d":
      case "d8715392-287f-49b7-9ae3-f21ec5bf55f3":
        // 1 read for existence check and 1 write per record.
        // Plus 1 read for count query and 1 write for metadata document update.
        firestoreReadsEstimate = recordsProcessed + 1;
        firestoreWritesEstimate = recordsProcessed + 1;
        break;
      case "datasets_metadata":
        // Sets documents directly in batch. Updates metadata document at end.
        firestoreReadsEstimate = 0;
        firestoreWritesEstimate = recordsProcessed;
        break;
      default:
        firestoreReadsEstimate = recordsProcessed;
        firestoreWritesEstimate = recordsProcessed;
    }

    const runDoc = {
      datasetId: this.datasetId,
      startTime: this.startTime.toISOString(),
      endTime: endTime.toISOString(),
      durationMs,
      status: "success",
      recordsProcessed,
      firestoreReadsEstimate,
      firestoreWritesEstimate,
      errorMessage: "",
      errorStack: "",
    };

    try {
      await db.collection("scraper_runs").add(runDoc);
    } catch (err) {
      logger.error(`Failed to write success telemetry for ${this.datasetId}:`, err);
    }
  }

  /**
   * Log a failed scraper execution, capturing the error message and stack trace.
   * @param db Firestore database reference
   * @param error Execution error encountered
   */
  async fail(db: admin.firestore.Firestore, error: Error): Promise<void> {
    const endTime = new Date();
    const durationMs = endTime.getTime() - this.startTime.getTime();

    // Trapping and truncating message and stack to prevent document bloat
    const errorMessage = (error.message || String(error)).substring(0, 1000);
    const errorStack = (error.stack || "").substring(0, 3000);

    const runDoc = {
      datasetId: this.datasetId,
      startTime: this.startTime.toISOString(),
      endTime: endTime.toISOString(),
      durationMs,
      status: "error",
      recordsProcessed: 0,
      firestoreReadsEstimate: 0,
      firestoreWritesEstimate: 0,
      errorMessage,
      errorStack,
    };

    try {
      await db.collection("scraper_runs").add(runDoc);
    } catch (err) {
      logger.error(`Failed to write failure telemetry for ${this.datasetId}:`, err);
    }
  }
}
