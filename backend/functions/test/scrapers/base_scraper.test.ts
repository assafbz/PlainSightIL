import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import axios from "axios";
import * as admin from "firebase-admin";
import { BaseScraper, ScraperOptions, ScraperResult } from "../../src/scrapers/base_scraper";
import { ScraperTelemetryTracker } from "../../src/utils/telemetry";
import { notifySubscribers } from "../../src/utils/alerts";

vi.mock("axios");
vi.mock("../../src/utils/logger", () => ({
  AppLogger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

vi.mock("../../src/utils/telemetry", () => {
  const mockTrackerInstance = {
    complete: vi.fn().mockResolvedValue(undefined),
    fail: vi.fn().mockResolvedValue(undefined),
  };
  return {
    ScraperTelemetryTracker: {
      start: vi.fn().mockReturnValue(mockTrackerInstance),
      instance: mockTrackerInstance,
    },
  };
});

vi.mock("../../src/utils/alerts", () => ({
  notifySubscribers: vi.fn().mockResolvedValue(undefined),
  broadcastAlert: vi.fn().mockResolvedValue(undefined),
}));

interface RawDoc {
  _id: number;
  name: string;
}

interface ParsedDoc {
  id: string;
  _id: number;
  name: string;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

class TestScraper extends BaseScraper<RawDoc, ParsedDoc> {
  readonly datasetId = "test_dataset";
  readonly targetCollection = "test_collection";
  override readonly updateIntervalHours = 48;

  mockRawPages: RawDoc[][] = [];
  mockRecordsHook = vi.fn();
  stopPagingAtId: number | null = null;

  parseRecord(raw: RawDoc): ParsedDoc | null {
    if (raw.name === "invalid") return null;
    return {
      id: String(raw._id),
      _id: raw._id,
      name: raw.name,
      lastUpdated: new Date().toISOString(),
    };
  }

  protected override async beforeScrape(
    db: admin.firestore.Firestore,
    options?: ScraperOptions,
  ): Promise<void> {
    this.mockRecordsHook();
  }

  protected override shouldStopPaging(raw: RawDoc): boolean {
    return this.stopPagingAtId !== null && raw._id === this.stopPagingAtId;
  }

  protected override getMockRecords(): RawDoc[] {
    return this.mockRawPages[0] || [];
  }
}

describe("BaseScraper Class", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockMetadataSet: any;
  let mockMetadataGet: any;
  let mockCountGet: any;
  let mockGetAll: any;
  let scraper: TestScraper;
  let originalEmulator: string | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();

    originalEmulator = process.env.FUNCTIONS_EMULATOR;
    process.env.FUNCTIONS_EMULATOR = "true";

    scraper = new TestScraper();

    mockMetadataSet = vi.fn().mockResolvedValue(true);
    mockMetadataGet = vi.fn().mockResolvedValue({
      exists: true,
      data: () => ({
        lastUpdated: "2026-06-01T12:00:00.000Z",
        recordCount: 5,
        scheduler: { enabled: true, updateIntervalHours: 48 },
      }),
    });

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === "test_dataset" || id === "datasets_metadata") {
        return {
          set: mockMetadataSet,
          get: mockMetadataGet,
        };
      }
      return { id };
    });

    mockCountGet = vi.fn().mockResolvedValue({
      data: () => ({ count: 10 }),
    });

    mockCollection = vi.fn().mockReturnValue({
      doc: mockDoc,
      count: vi.fn().mockReturnValue({
        get: mockCountGet,
      }),
    });

    mockBatch = {
      set: vi.fn(),
      commit: vi.fn().mockResolvedValue(true),
    };

    mockGetAll = vi.fn().mockImplementation((...refs) => {
      return Promise.resolve(
        refs.map((ref) => ({
          exists: false,
          id: ref.id,
          data: () => ({}),
        })),
      );
    });

    mockDb = {
      collection: mockCollection,
      batch: vi.fn().mockReturnValue(mockBatch),
      getAll: mockGetAll,
    };
  });

  afterEach(() => {
    if (originalEmulator === undefined) {
      delete process.env.FUNCTIONS_EMULATOR;
    } else {
      process.env.FUNCTIONS_EMULATOR = originalEmulator;
    }
  });

  it("should initialize, page through records, compare, write batch, and finalize metadata", async () => {
    scraper.mockRawPages = [
      [
        { _id: 101, name: "Antenna A" },
        { _id: 102, name: "invalid" }, // should be skipped by parseRecord
        { _id: 103, name: "Antenna B" },
      ],
    ];

    const result = await scraper.scrape(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(2); // processed successfully
    expect(result.changedCount).toBe(2);

    expect(scraper.mockRecordsHook).toHaveBeenCalled();
    expect(mockBatch.set).toHaveBeenCalledTimes(2);

    // Verify metadata was updated twice (once syncing, once idle at end)
    expect(mockMetadataSet).toHaveBeenCalledTimes(2);
    expect(mockMetadataSet).toHaveBeenLastCalledWith(
      expect.objectContaining({
        id: "test_dataset",
        activeCollection: "test_collection",
        status: "idle",
        recordCount: 7,
        scheduler: expect.objectContaining({
          enabled: true,
          updateIntervalHours: 48,
        }),
      }),
      { merge: true },
    );

    // Verify Telemetry Tracker calls
    expect(ScraperTelemetryTracker.start).toHaveBeenCalledWith("test_dataset");
    const telemetryInstance = (ScraperTelemetryTracker as any).instance;
    expect(telemetryInstance.complete).toHaveBeenCalledWith(mockDb, 2);

    // Verify alert triggers
    expect(notifySubscribers).toHaveBeenCalledTimes(1);
  });

  it("should prevent duplicate writes if records are identical", async () => {
    scraper.mockRawPages = [[{ _id: 101, name: "Antenna A" }]];

    // Mock that record 101 already exists in firestore and is identical
    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "101",
        data: () => ({
          id: "101",
          _id: 101,
          name: "Antenna A",
          lastUpdated: "2026-06-01T12:00:00Z",
        }),
      },
    ]);

    const result = await scraper.scrape(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);
    expect(result.changedCount).toBe(0); // identical, so 0 writes
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should update record if fields differ", async () => {
    scraper.mockRawPages = [[{ _id: 101, name: "New Name" }]];

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "101",
        data: () => ({
          id: "101",
          _id: 101,
          name: "Old Name",
          createdAt: "2026-05-01T12:00:00Z",
          lastUpdated: "2026-05-01T12:00:00Z",
        }),
      },
    ]);

    const result = await scraper.scrape(mockDb);

    expect(result.success).toBe(true);
    expect(result.changedCount).toBe(1); // modified, so written
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.name).toBe("New Name");
    expect(written.createdAt).toBe("2026-05-01T12:00:00Z");
  });

  it("should reject insecure non-HTTPS base URLs outside of emulator", async () => {
    process.env.DATA_GOV_IL_BASE_URL = "http://insecure-api.gov.il";
    process.env.FUNCTIONS_EMULATOR = "false";

    // Subclass that calls fetchPage
    class FailingScraper extends TestScraper {
      protected override async fetchPage(offset: number, limit: number): Promise<RawDoc[]> {
        return super.fetchPage(offset, limit);
      }
      protected override getMockRecords(): any {
        return undefined; // force fetchPage call
      }
    }

    const failingScraper = new FailingScraper();
    await expect(failingScraper.scrape(mockDb)).rejects.toThrow("Insecure base URL protocol");

    // Clean up
    delete process.env.DATA_GOV_IL_BASE_URL;
  });

  it("should prevent infinite pagination loops using safety ceilings", async () => {
    process.env.FUNCTIONS_EMULATOR = "false";

    // Mock Axios returning a single element forever
    vi.mocked(axios.get).mockResolvedValue({
      data: {
        result: {
          records: [{ _id: 100, name: "Infinite" }],
        },
      },
    });

    class UnlimitedScraper extends TestScraper {
      protected override getMockRecords(): any {
        return undefined; // force fetchPage
      }
    }

    const unlimitedScraper = new UnlimitedScraper();
    const result = await unlimitedScraper.scrape(mockDb, { limit: 1 });

    expect(result.success).toBe(true);
    // Should have terminated at the 100 safety ceiling page count
    expect(result.count).toBeLessThanOrEqual(100);
  });

  it("should retry requests upon encountering transient API failures", async () => {
    process.env.FUNCTIONS_EMULATOR = "false";

    // Force axios.get to fail twice then succeed on the third attempt
    vi.mocked(axios.get)
      .mockRejectedValueOnce(new Error("Transient Timeout"))
      .mockRejectedValueOnce(new Error("Rate Limit Exceeded"))
      .mockResolvedValueOnce({
        data: {
          result: {
            records: [{ _id: 201, name: "Retry Success" }],
          },
        },
      })
      .mockResolvedValueOnce({ data: { result: { records: [] } } });

    class NetworkScraper extends TestScraper {
      protected override getMockRecords(): any {
        return undefined; // force fetchPage/axios
      }
    }

    const networkScraper = new NetworkScraper();

    // We run the scrape, advancing the fake timers to resolve delay promises
    const promise = networkScraper.scrape(mockDb);
    await vi.runAllTimersAsync();
    const result = await promise;

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);
    expect(vi.mocked(axios.get)).toHaveBeenCalledTimes(4); // 3 attempts for page 1, 1 attempt for empty page 2
  });

  it("should sanitize document path IDs to prevent NoSQL injection", async () => {
    scraper.mockRawPages = [
      [
        { _id: 1, name: "Valid ID" },
        // ID containing slashes should be sanitized to protect NoSQL hierarchy
        { _id: 2, name: "Injectable ID" },
      ],
    ];

    // Inject unsafe slash into parsing logic
    vi.spyOn(scraper, "parseRecord").mockImplementation((raw) => {
      return {
        id: raw._id === 2 ? "2/subcollection_escape" : String(raw._id),
        _id: raw._id,
        name: raw.name,
        lastUpdated: new Date().toISOString(),
      };
    });

    const result = await scraper.scrape(mockDb);
    expect(result.success).toBe(true);

    // Verify document IDs written in mock batch
    expect(mockDoc).toHaveBeenCalledWith("1");
    expect(mockDoc).toHaveBeenCalledWith("2_subcollection_escape");
    expect(mockDoc).not.toHaveBeenCalledWith("2/subcollection_escape");
  });

  it("should deduplicate record IDs in chunks to prevent duplicate docRefs in db.getAll()", async () => {
    scraper.mockRawPages = [
      [
        { _id: 101, name: "Antenna A" },
        { _id: 101, name: "Antenna A Duplicate" },
        { _id: 102, name: "Antenna B" },
      ],
    ];

    const result = await scraper.scrape(mockDb);

    expect(result.success).toBe(true);
    // Only 2 unique records should be counted and changed
    expect(result.count).toBe(2);
    expect(result.changedCount).toBe(2);

    // Verify mockGetAll was called with only unique references (length 2)
    expect(mockGetAll).toHaveBeenCalled();
    const calls = mockGetAll.mock.calls;
    const passedRefs = calls[0];
    expect(passedRefs.length).toBe(2);
    expect(passedRefs.map((r: any) => r.id)).toEqual(["101", "102"]);

    // Verify that the duplicate record in the batch uses the latest (last) data in the chunk
    expect(mockBatch.set).toHaveBeenCalledTimes(2);
    const setCalls = mockBatch.set.mock.calls;
    const record101Call = setCalls.find((call: any) => call[0].id === "101");
    expect(record101Call).toBeDefined();
    expect(record101Call[1].name).toBe("Antenna A Duplicate");
  });
});
