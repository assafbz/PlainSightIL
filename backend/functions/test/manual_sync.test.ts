import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// 1. Hoist the mock variables to make them available inside vi.mock calls
const { mockVerifyIdToken, mockDbGet, mockDbSet, mockDbLimitGet, mockFirestoreInstance } =
  vi.hoisted(() => {
    const verify = vi.fn().mockResolvedValue({ uid: "mock-admin-uid" });
    const get = vi.fn().mockResolvedValue({
      exists: false,
      data: () => ({}),
    });
    const set = vi.fn().mockResolvedValue(true);
    const limitGet = vi.fn().mockResolvedValue({ empty: false });
    const instance = {
      collection: vi.fn().mockReturnValue({
        doc: vi.fn().mockReturnValue({
          get,
          set,
        }),
        limit: vi.fn().mockReturnValue({
          get: limitGet,
        }),
      }),
    };
    return {
      mockVerifyIdToken: verify,
      mockDbGet: get,
      mockDbSet: set,
      mockDbLimitGet: limitGet,
      mockFirestoreInstance: instance,
    };
  });

// 2. Mock firebase-functions partially
vi.mock("firebase-functions/v1", async (importOriginal) => {
  const actual = await importOriginal<typeof import("firebase-functions/v1")>();
  const triggerMock = vi.fn().mockImplementation((handler) => handler);
  return {
    ...actual,
    https: {
      ...actual.https,
      onRequest: triggerMock,
    },
    runWith: vi.fn().mockReturnValue({
      https: {
        onRequest: triggerMock,
      },
      pubsub: {
        schedule: vi.fn().mockReturnValue({
          onRun: triggerMock,
        }),
        topic: vi.fn().mockReturnValue({
          onPublish: triggerMock,
        }),
      },
      auth: {
        user: vi.fn().mockReturnValue({
          onCreate: triggerMock,
        }),
      },
    }),
  };
});

// 3. Mock individual scraper modules
vi.mock("../src/scrapers/cellular_antennas_scraper", () => ({
  scrapeAndSyncAntennas: vi.fn().mockResolvedValue({ count: 12 }),
}));
vi.mock("../src/scrapers/cellular_permits_scraper", () => ({
  scrapeAndSyncPermitApplications: vi.fn().mockResolvedValue({ count: 24 }),
}));
vi.mock("../src/scrapers/metadata_scraper", () => ({
  scrapeAndSyncDatasetMetadata: vi.fn().mockResolvedValue({ count: 0 }),
}));
vi.mock("../src/scrapers/companies_liquidation_scraper", () => ({
  scrapeAndSyncCompaniesLiquidation: vi.fn().mockResolvedValue({ count: 5 }),
}));
vi.mock("../src/scrapers/doctors_licenses_scraper", () => ({
  scrapeAndSyncDoctorsLicenses: vi.fn().mockResolvedValue({ count: 10 }),
}));
vi.mock("../src/scrapers/bank_atms_scraper", () => ({
  scrapeAndSyncBankAtms: vi.fn().mockResolvedValue({ count: 8 }),
}));
vi.mock("../src/scrapers/patent_classifications_scraper", () => ({
  scrapeAndSyncPatentClassifications: vi.fn().mockResolvedValue({ count: 15 }),
}));
vi.mock("../src/scrapers/car_importers_scraper", () => ({
  scrapeAndSyncCarImporters: vi.fn().mockResolvedValue({ count: 50 }),
}));

// 4. Mock telemetry and scheduler utility functions
vi.mock("../src/utils/telemetry", () => ({
  ScraperTelemetryTracker: {
    start: vi.fn().mockReturnValue({
      complete: vi.fn().mockResolvedValue(true),
      fail: vi.fn().mockResolvedValue(true),
    }),
  },
}));

// 5. Mock firebase-admin using hoisted mocks
vi.mock("firebase-admin", () => ({
  initializeApp: vi.fn(),
  firestore: () => mockFirestoreInstance,
  auth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

// 6. Now import functions under test
import { manualSyncAntennas, manualSyncMetadata, manualSyncDoctorsLicenses, manualSyncCarImporters } from "../src/index";

describe("Manual Sync Cloud Functions Factory", () => {
  let req: any;
  let res: any;
  let statusMock: any;
  let jsonMock: any;
  let setHeaderMock: any;

  beforeEach(() => {
    vi.clearAllMocks();
    process.env.FUNCTIONS_EMULATOR = "true";

    jsonMock = vi.fn();
    statusMock = vi.fn().mockReturnValue({ json: jsonMock });
    setHeaderMock = vi.fn();

    req = {
      method: "POST",
      headers: {
        authorization: "Bearer mock-token",
      },
    };

    res = {
      status: statusMock,
      set: setHeaderMock,
    };
  });

  afterEach(() => {
    delete process.env.FUNCTIONS_EMULATOR;
  });

  it("should successfully run manual sync for admin POST requests", async () => {
    // Mock user profile check: user exists and is an admin
    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({ role: "admin" }),
    });

    await manualSyncAntennas(req, res);

    expect(mockDbSet).toHaveBeenCalledWith({ status: "syncing" }, { merge: true });
    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith({
      message: "Sync completed successfully",
      count: 12,
    });
  });

  it("should bypass emulator seeder on GET request if already seeded and nextRun is in the future", async () => {
    req.method = "GET"; // trigger seeder bypass logic

    // Mock seeder check Firestore reads:
    // 1. User doc retrieve (skipped because GET in emulator)
    // 2. Metadata doc get:
    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({
        scheduler: {
          enabled: true,
          nextRun: new Date(Date.now() + 100000).toISOString(), // nextRun in future
        },
      }),
    });
    // 3. Collection record check (hasRecords = true) -> limit(1).get() returns not empty
    mockDbLimitGet.mockResolvedValueOnce({ empty: false });

    await manualSyncAntennas(req, res);

    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith({
      message: "Sync skipped (schedule not due and data exists)",
      count: 0,
    });
  });

  it("should NOT bypass emulator seeder if nextRun is in the past", async () => {
    req.method = "GET";

    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({
        scheduler: {
          enabled: true,
          nextRun: new Date(Date.now() - 100000).toISOString(), // nextRun in past
        },
      }),
    });

    await manualSyncAntennas(req, res);

    expect(mockDbSet).toHaveBeenCalledWith({ status: "syncing" }, { merge: true });
    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith({
      message: "Sync completed successfully",
      count: 12,
    });
  });

  it("should support custom runWith options (e.g., Doctors Licenses trigger should be callable)", async () => {
    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({ role: "admin" }),
    });

    await manualSyncDoctorsLicenses(req, res);

    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith({
      message: "Sync completed successfully",
      count: 10,
    });
  });

  it("should support manualSyncCarImporters trigger", async () => {
    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({ role: "admin" }),
    });

    await manualSyncCarImporters(req, res);

    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith({
      message: "Sync completed successfully",
      count: 50,
    });
  });

  it("should reject unauthorized requests with 403", async () => {
    // Mock user profile check: user exists but is NOT an admin
    mockDbGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({ role: "user" }),
    });

    await manualSyncMetadata(req, res);

    expect(statusMock).toHaveBeenCalledWith(403);
    expect(jsonMock).toHaveBeenCalledWith(
      expect.objectContaining({
        error: "Forbidden",
      }),
    );
  });
});
