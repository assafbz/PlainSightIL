import { describe, it, expect, vi, beforeEach } from "vitest";
import { ScraperTelemetryTracker } from "../src/utils/telemetry";

vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("ScraperTelemetryTracker", () => {
  let mockDb: any;
  let mockCollection: any;
  let mockAdd: any;

  beforeEach(() => {
    vi.clearAllMocks();
    mockAdd = vi.fn().mockResolvedValue({ id: "mock-run-id" });
    mockCollection = vi.fn().mockReturnValue({
      add: mockAdd,
    });
    mockDb = {
      collection: mockCollection,
    };
  });

  it("should initialize with start method", () => {
    const tracker = ScraperTelemetryTracker.start("ff398c7e-c522-4ee8-a53a-312b188a573d");
    expect(tracker).toBeDefined();
    expect(tracker).toHaveProperty("datasetId", "ff398c7e-c522-4ee8-a53a-312b188a573d");
  });

  it("should compute correct reads/writes and log success for scrapers (e.g. cellular permit)", async () => {
    const tracker = ScraperTelemetryTracker.start("ff398c7e-c522-4ee8-a53a-312b188a573d");
    await tracker.complete(mockDb, 100);

    expect(mockCollection).toHaveBeenCalledWith("scraper_runs");
    expect(mockAdd).toHaveBeenCalledTimes(1);

    const loggedDoc = mockAdd.mock.calls[0][0];
    expect(loggedDoc.datasetId).toBe("ff398c7e-c522-4ee8-a53a-312b188a573d");
    expect(loggedDoc.status).toBe("success");
    expect(loggedDoc.recordsProcessed).toBe(100);
    expect(loggedDoc.firestoreReadsEstimate).toBe(101); // 100 + 1
    expect(loggedDoc.firestoreWritesEstimate).toBe(101); // 100 + 1
    expect(loggedDoc.errorMessage).toBe("");
  });

  it("should compute correct reads/writes and log success for metadata scraper", async () => {
    const tracker = ScraperTelemetryTracker.start("datasets_metadata");
    await tracker.complete(mockDb, 500);

    expect(mockCollection).toHaveBeenCalledWith("scraper_runs");
    const loggedDoc = mockAdd.mock.calls[0][0];
    expect(loggedDoc.datasetId).toBe("datasets_metadata");
    expect(loggedDoc.status).toBe("success");
    expect(loggedDoc.recordsProcessed).toBe(500);
    expect(loggedDoc.firestoreReadsEstimate).toBe(0);
    expect(loggedDoc.firestoreWritesEstimate).toBe(500);
  });

  it("should compute correct fallback reads/writes for unknown datasetId", async () => {
    const tracker = ScraperTelemetryTracker.start("unknown_dataset_id");
    await tracker.complete(mockDb, 50);

    const loggedDoc = mockAdd.mock.calls[0][0];
    expect(loggedDoc.datasetId).toBe("unknown_dataset_id");
    expect(loggedDoc.firestoreReadsEstimate).toBe(50);
    expect(loggedDoc.firestoreWritesEstimate).toBe(50);
  });

  it("should capture error details and log failure run telemetry", async () => {
    const tracker = ScraperTelemetryTracker.start("ff398c7e-c522-4ee8-a53a-312b188a573d");
    const testError = new Error("Failed connecting to government CKAN API");
    await tracker.fail(mockDb, testError);

    expect(mockCollection).toHaveBeenCalledWith("scraper_runs");
    expect(mockAdd).toHaveBeenCalledTimes(1);

    const loggedDoc = mockAdd.mock.calls[0][0];
    expect(loggedDoc.datasetId).toBe("ff398c7e-c522-4ee8-a53a-312b188a573d");
    expect(loggedDoc.status).toBe("error");
    expect(loggedDoc.recordsProcessed).toBe(0);
    expect(loggedDoc.firestoreReadsEstimate).toBe(0);
    expect(loggedDoc.firestoreWritesEstimate).toBe(0);
    expect(loggedDoc.errorMessage).toBe("Failed connecting to government CKAN API");
    expect(loggedDoc.errorStack).toContain("Error: Failed connecting to government CKAN API");
  });
});
