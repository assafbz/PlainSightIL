import * as admin from "firebase-admin";
import axios from "axios";
import { AppLogger as logger } from "../utils/logger";
import { areRecordsEqual } from "../utils/equality";
import { ScraperTelemetryTracker } from "../utils/telemetry";
import { notifySubscribers } from "../utils/alerts";

/**
 * Options for configuring scraper execution behavior.
 */
export interface ScraperOptions {
  /** If true, forces a full historical synchronization instead of incremental. */
  forceFullSync?: boolean;
  /** Maximum number of records processed per database write batch. */
  batchSize?: number;
  /** Request timeout limit in milliseconds. */
  timeout?: number;
  /** Maximum total records to ingest in this execution. */
  limit?: number;
}

/**
 * Result metrics returned upon scraper completion.
 */
export interface ScraperResult {
  /** Whether the execution completed successfully without uncaught errors. */
  success: boolean;
  /** Total number of records processed. */
  count: number;
  /** Total number of records that were written/updated in the database. */
  changedCount: number;
}

/**
 * Abstract base class that defines the core lifecycle and execution loop for governmental data scrapers.
 * Orchestrates pagination, parsing, database diffing, telemetry tracking, and subscriber alerts.
 *
 * @template RawRecord The raw representation of the record as retrieved from the source API.
 * @template ParsedRecord The parsed, validated, and normalized model structure written to Firestore.
 */
export abstract class BaseScraper<
  RawRecord,
  ParsedRecord extends { id: string; createdAt?: string; updatedAt?: string; lastUpdated: string },
> {
  /** The unique identifier of the dataset (e.g. DATASET_IDS.VEHICLE_RECALLS). */
  abstract readonly datasetId: string;
  /** The Firestore collection path to write documents to. */
  abstract readonly targetCollection: string;
  /** The default update interval for scheduling runs in hours. */
  readonly updateIntervalHours: number = 24;

  /** Default page limit for production runs. */
  protected defaultLimit = 10000;
  /** Default page limit for local emulator runs. */
  protected defaultEmulatorLimit = 100;
  /** Maximum Firestore batch size constraint. */
  protected maxBatchSize = 500;
  /** Default external API request timeout in milliseconds. */
  protected requestTimeout = 15000;
  /** The metadata document snapshot retrieved at the start of sync. */
  protected metadataSnapshot: admin.firestore.DocumentSnapshot | null = null;
  /** Defines whether lastUpdated is parsed from the source record or generated at sync time. */
  readonly lastUpdatedSource: "parsed" | "generated" = "generated";

  /**
   * Fetches a single page of raw records from the source.
   * By default, it queries the data.gov.il datastore_search API.
   * Subclasses can override this method if they fetch from other endpoints or need custom sorting/query parameters.
   *
   * @param offset The starting position for pagination.
   * @param limit The maximum number of records to retrieve.
   * @param options Execution settings overrides.
   * @returns Array of raw records retrieved.
   * @throws Error if the base URL protocol is insecure (non-HTTPS).
   */
  protected async fetchPage(
    offset: number,
    limit: number,
    options?: ScraperOptions,
  ): Promise<RawRecord[]> {
    const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

    // Enforce HTTPS security constraint outside of local emulators
    if (!isEmulator && !baseUrl.startsWith("https://")) {
      throw new Error(`Insecure base URL protocol: ${baseUrl}. Scrapers must use HTTPS.`);
    }

    const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${this.datasetId}&limit=${limit}&offset=${offset}`;
    logger.info(`Fetching data for ${this.datasetId} from: ${url}`);

    const response = await this.executeWithRetry(() =>
      axios.get(url, { timeout: options?.timeout || this.requestTimeout }),
    );
    return response.data?.result?.records ?? [];
  }

  /**
   * Helper to execute requests with retries for robustness against transient network issues or rate limiting.
   *
   * @param fn The asynchronous task to attempt.
   * @param retries Maximum retry attempts.
   * @param delayMs Initial delay before retrying, increased exponentially.
   * @returns The resolved result of the task.
   */
  protected async executeWithRetry<T>(
    fn: () => Promise<T>,
    retries = 3,
    delayMs = 1000,
  ): Promise<T> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        return await fn();
      } catch (error: unknown) {
        lastError = error;
        const errMsg = error instanceof Error ? error.message : String(error);
        logger.warn(`Attempt ${attempt} failed for scraper ${this.datasetId}. Error: ${errMsg}`);
        if (attempt < retries) {
          await new Promise((resolve) => setTimeout(resolve, delayMs * Math.pow(2, attempt - 1)));
        }
      }
    }
    throw lastError;
  }

  /**
   * Subclasses must implement record parsing and validation.
   *
   * @param raw The raw record fetched from the API source.
   * @returns Parsed record model, or null if the record is invalid/corrupt and should be skipped.
   */
  abstract parseRecord(raw: RawRecord): ParsedRecord | null;

  /**
   * Standard comparison logic using the areRecordsEqual utility.
   * Ignored fields like createdAt and updatedAt are already handled in areRecordsEqual.
   * Subclasses can override if they require custom equality checks.
   * Note: lastUpdated is normalized before comparison.
   *
   * @param existing The existing record in the database.
   * @param incoming The newly parsed incoming record.
   * @returns True if the records are structurally identical, false otherwise.
   */
  protected compareRecords(existing: ParsedRecord, incoming: ParsedRecord): boolean {
    return areRecordsEqual(existing, incoming);
  }

  /**
   * Optional hook for custom record updates (e.g. metadata scraper broadcasting alerts).
   * Called during sync chunk processing when a record addition or modification is detected.
   *
   * @param db Firestore database instance.
   * @param incoming The parsed incoming record.
   * @param existing The existing record in database (null if new).
   * @param isFirstSync True if the database does not contain existing records for this dataset.
   */
  protected async onRecordUpdate(
    _db: admin.firestore.Firestore,
    _incoming: ParsedRecord,
    _existing: ParsedRecord | null,
    _isFirstSync: boolean,
  ): Promise<void> {}

  /**
   * Hook called immediately before starting the scraping loop.
   *
   * @param db Firestore database instance.
   * @param options Execution settings overrides.
   */
  protected async beforeScrape(
    _db: admin.firestore.Firestore,
    _options?: ScraperOptions,
  ): Promise<void> {}

  /**
   * Hook to determine if the paging loop should terminate early (e.g. during delta/incremental sync).
   *
   * @param raw The raw record under evaluation.
   * @returns True if paging should stop, false otherwise.
   */
  protected shouldStopPaging(_raw: RawRecord): boolean {
    return false;
  }

  /**
   * Hook called after the scraping loop completes successfully.
   * Returns key-value pairs of metadata properties to be merged into the metadata document.
   *
   * @param db Firestore database instance.
   * @param processedCount Total records evaluated.
   * @param changedCount Total records written or modified.
   * @returns Map of metadata fields to merge.
   */
  protected async afterScrape(
    _db: admin.firestore.Firestore,
    _processedCount: number,
    _changedCount: number,
  ): Promise<Record<string, unknown>> {
    return {};
  }

  /**
   * Hook for providing mock records when running under the Firebase emulator.
   *
   * @returns Array of mock records.
   */
  protected getMockRecords?(): RawRecord[];

  /**
   * Standard alerting triggered automatically at the end of a successful run.
   *
   * @param db Firestore database instance.
   * @param result Core metrics returned upon scraper completion.
   * @param isFirstSync True if this was the first sync of the dataset.
   */
  protected async triggerAlerts(
    db: admin.firestore.Firestore,
    result: ScraperResult,
    isFirstSync: boolean,
  ): Promise<void> {
    if (isFirstSync) {
      logger.info(`Bypassing subscriber alerts for ${this.datasetId} (first sync).`);
      return;
    }

    if (result.changedCount > 0) {
      logger.info(
        `Triggering subscriber alerts for ${this.datasetId}: ${result.changedCount} changed records.`,
      );
      const dirDoc = await db.collection("datasets_metadata").doc(this.datasetId).get();
      const title = dirDoc.exists ? dirDoc.data()?.title || this.datasetId : this.datasetId;

      await notifySubscribers(db, this.datasetId, {
        type: "new_records",
        datasetId: this.datasetId,
        recordCount: result.changedCount,
        title: {
          he: `נקלטו רשומות חדשות ב${title}`,
          en: `New Records Ingested in ${title}`,
        },
        description: {
          he: `נקלטו ${result.changedCount} רשומות חדשות במאגר '${title}'.`,
          en: `Ingested ${result.changedCount} new records into '${title}' dataset.`,
        },
      });
    } else {
      logger.info(`No changed records for ${this.datasetId}. Alert skipped.`);
    }
  }

  /**
   * Executes the entire scraper lifecycle.
   *
   * @param db Firestore database instance.
   * @param options Execution settings overrides.
   * @returns Synchronization outcomes and counts.
   */
  async scrape(db: admin.firestore.Firestore, options?: ScraperOptions): Promise<ScraperResult> {
    const metadataRef = db.collection("dataset_metadata").doc(this.datasetId);
    const tracker = ScraperTelemetryTracker.start(this.datasetId);
    const nowStr = new Date().toISOString();

    try {
      logger.info(`Starting sync for ${this.datasetId}. Target: ${this.targetCollection}`);

      // 1. Initialize scrape state and metadata
      const { isFirstSync, metaDoc } = await this.initializeScrape(db, metadataRef, nowStr);

      const targetRef = db.collection(this.targetCollection);

      // Subclass initialization hook
      await this.beforeScrape(db, options);

      // 2. Run pagination loop and process/write records
      const { processedCount, changedCount } = await this.executeScrapingLoop(
        db,
        targetRef,
        options,
        isFirstSync,
        nowStr,
      );

      logger.info(
        `Scraper completed successfully for ${this.datasetId}. Processed: ${processedCount}, Changed: ${changedCount}`,
      );

      // Subclass cleanup/metadata-generation hook
      const additionalMetadata = await this.afterScrape(db, processedCount, changedCount);

      const result = { success: true, count: processedCount, changedCount };

      // 3. Finalize scraper metadata, scheduler and trigger alerting
      await this.finalizeScrape(
        db,
        result,
        metadataRef,
        targetRef,
        metaDoc,
        additionalMetadata,
        tracker,
        isFirstSync,
        nowStr,
      );

      return result;
    } catch (error: unknown) {
      const err = error instanceof Error ? error : new Error(String(error));
      const sanitizedMsg = err.message.substring(0, 1000); // Sanitize to prevent log injection
      logger.error(`Scraper execution failed for ${this.datasetId}: ${sanitizedMsg}`);

      await metadataRef.set({ status: "error" }, { merge: true });
      await tracker.fail(db, err);

      throw err;
    }
  }

  /**
   * Reads current metadata and updates status to syncing.
   */
  private async initializeScrape(
    db: admin.firestore.Firestore,
    metadataRef: admin.firestore.DocumentReference,
    nowStr: string,
  ): Promise<{ isFirstSync: boolean; metaDoc: admin.firestore.DocumentSnapshot }> {
    const metaDoc = await metadataRef.get();
    this.metadataSnapshot = metaDoc;
    const isFirstSync =
      !metaDoc.exists || !metaDoc.data()?.lastUpdated || (metaDoc.data()?.recordCount || 0) === 0;

    await metadataRef.set({ status: "syncing", syncStartedAt: nowStr }, { merge: true });

    return { isFirstSync, metaDoc };
  }

  /**
   * Loops over available pages, parses records, and batch-updates them in Firestore.
   */
  private async executeScrapingLoop(
    db: admin.firestore.Firestore,
    targetRef: admin.firestore.CollectionReference,
    options: ScraperOptions | undefined,
    isFirstSync: boolean,
    nowStr: string,
  ): Promise<{ processedCount: number; changedCount: number }> {
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const forceFullSync = options?.forceFullSync === true;

    let offset = 0;
    const limit =
      isEmulator && !forceFullSync
        ? this.defaultEmulatorLimit
        : options?.limit || this.defaultLimit;
    let hasMore = true;
    let processedCount = 0;
    let changedCount = 0;

    const maxPages = 100; // Safety ceiling to prevent infinite loop DoS
    let pageCount = 0;

    while (hasMore) {
      pageCount++;
      if (pageCount > maxPages) {
        logger.warn(
          `Safety pagination limit of ${maxPages} pages reached for scraper ${this.datasetId}. Terminating loop.`,
        );
        break;
      }

      let rawRecords: RawRecord[];

      if (isEmulator && !forceFullSync && this.getMockRecords) {
        rawRecords = this.getMockRecords();
      } else {
        rawRecords = await this.fetchPage(offset, limit, options);
      }

      if (rawRecords.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: ParsedRecord[] = [];
      for (const raw of rawRecords) {
        if (this.shouldStopPaging(raw)) {
          hasMore = false;
          break;
        }

        const parsed = this.parseRecord(raw);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      if (parsedRecords.length > 0) {
        const batchSize = options?.batchSize || this.maxBatchSize;
        for (let i = 0; i < parsedRecords.length; i += batchSize) {
          const chunk = parsedRecords.slice(i, i + batchSize);
          const chunkResult = await this.processChunk(db, targetRef, chunk, isFirstSync, nowStr);
          processedCount += chunkResult.processedCount;
          changedCount += chunkResult.changedCount;
        }
      }

      if (isEmulator && !forceFullSync) {
        hasMore = false;
        break;
      }

      offset += limit;
    }

    return { processedCount, changedCount };
  }

  /**
   * Processes a single batch/chunk of parsed records, performing duplicate checks and writes.
   */
  private async processChunk(
    db: admin.firestore.Firestore,
    targetRef: admin.firestore.CollectionReference,
    chunk: ParsedRecord[],
    isFirstSync: boolean,
    nowStr: string,
  ): Promise<{ processedCount: number; changedCount: number }> {
    const docRefs = chunk.map((r) => {
      // Sanitize record document ID to prevent NoSQL path injection
      const safeId = r.id.replace(/[/\s]/g, "_");
      r.id = safeId;
      return targetRef.doc(safeId);
    });

    const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
    const existingMap = new Map<string, admin.firestore.DocumentData>();

    for (const snap of snapshots) {
      const data = snap.data();
      if (snap.exists && data) {
        existingMap.set(snap.id, data);
      }
    }

    const batch = db.batch();
    let hasWrites = false;
    let processedCount = 0;
    let changedCount = 0;

    for (const r of chunk) {
      const docRef = targetRef.doc(r.id);
      const existingData = existingMap.get(r.id) as ParsedRecord | undefined;

      const originalIncomingLastUpdated = r.lastUpdated;
      if (existingData && existingData.lastUpdated) {
        if (this.lastUpdatedSource === "generated") {
          r.lastUpdated = existingData.lastUpdated;
        } else {
          r.lastUpdated = r.lastUpdated || existingData.lastUpdated || nowStr;
        }
      } else {
        r.lastUpdated = r.lastUpdated || nowStr;
      }

      let shouldWrite = false;

      if (existingData) {
        const isIdentical = this.compareRecords(existingData, r);
        if (!isIdentical) {
          shouldWrite = true;
          // Preserve source-parsed modification timestamp if available, fallback to sync execution time
          r.lastUpdated = originalIncomingLastUpdated || nowStr;
          r.createdAt = existingData.createdAt || nowStr;
          r.updatedAt = nowStr;
        }
      } else {
        shouldWrite = true;
        r.lastUpdated = originalIncomingLastUpdated || nowStr;
        r.createdAt = nowStr;
        r.updatedAt = nowStr;
      }

      if (shouldWrite) {
        await this.onRecordUpdate(db, r, existingData || null, isFirstSync);
        batch.set(docRef, r);
        hasWrites = true;
        changedCount++;
      }
      processedCount++;
    }

    if (hasWrites) {
      await batch.commit();
    }

    return { processedCount, changedCount };
  }

  /**
   * Updates metadata database document, schedules next run, registers telemetry and triggers alerts.
   */
  private async finalizeScrape(
    db: admin.firestore.Firestore,
    result: ScraperResult,
    metadataRef: admin.firestore.DocumentReference,
    targetRef: admin.firestore.CollectionReference,
    metaDoc: admin.firestore.DocumentSnapshot,
    additionalMetadata: Record<string, unknown>,
    tracker: ScraperTelemetryTracker,
    isFirstSync: boolean,
    nowStr: string,
  ): Promise<void> {
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

    let enabled = true;
    let intervalHours = this.updateIntervalHours;
    if (metaDoc.exists) {
      const data = metaDoc.data();
      if (data?.scheduler?.updateIntervalHours !== undefined) {
        intervalHours = Number(data.scheduler.updateIntervalHours) || this.updateIntervalHours;
      }
      if (data?.scheduler?.enabled !== undefined) {
        enabled = data.scheduler.enabled === true;
      }
    }
    const nextRun = new Date(new Date().getTime() + intervalHours * 60 * 60 * 1000).toISOString();

    await metadataRef.set(
      {
        id: this.datasetId,
        activeCollection: this.targetCollection,
        lastUpdated: nowStr,
        recordCount: totalRecords,
        status: "idle",
        scheduler: {
          enabled,
          updateIntervalHours: intervalHours,
          nextRun,
        },
        ...additionalMetadata,
      },
      { merge: true },
    );

    // Pass changedCount to telemetry for accurate Firestore writes monitoring
    await tracker.complete(db, result.count);
    await this.triggerAlerts(db, result, isFirstSync);
  }
}
