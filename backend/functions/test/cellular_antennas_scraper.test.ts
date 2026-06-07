import { describe, it, expect, vi, beforeEach } from "vitest";
import * as admin from "firebase-admin";
import axios from "axios";
import { encodeGeohash } from "../src/utils/geohash";
import {
  parseRecord,
  scrapeAndSyncAntennas,
  convertItmToWgs84,
  isValidIsraelCoordinates,
} from "../src/scrapers/cellular_antennas_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Coordinate Conversion & Boundaries", () => {
  it("should convert ITM coordinates (EPSG:2039) to WGS84 coordinates correctly", () => {
    // Jerusalem coordinate sample: X:217320, Y:627507
    const wgs = convertItmToWgs84(217320, 627507);
    expect(wgs.latitude).toBeCloseTo(31.74, 2);
    expect(wgs.longitude).toBeCloseTo(35.181, 2);
  });

  it("should identify valid Israel coordinates correctly", () => {
    // Inside borders
    expect(isValidIsraelCoordinates(31.7455, 35.1812)).toBe(true);
    expect(isValidIsraelCoordinates(32.0853, 34.7818)).toBe(true);

    // Outside borders
    expect(isValidIsraelCoordinates(40.7128, -74.006)).toBe(false);
  });
});

describe("Geohash Utility", () => {
  it("should encode coordinates into correct geohash representation", () => {
    // Tel Aviv center
    const hash = encodeGeohash(32.0853, 34.7818, 9);
    expect(hash).toBe("sv8wx2zq6");
  });
});

describe("Record Parser", () => {
  it("should return null if מזהה or coordinates are missing", () => {
    const incompleteRecord = {
      מזהה: 123,
      X_ITM: 255812,
      // Y_ITM missing
    };
    expect(parseRecord(incompleteRecord)).toBeNull();
  });

  it("should parse and translate Hebrew fields correctly", () => {
    const raw = {
      מזהה: 6793,
      X_ITM: 255812,
      Y_ITM: 732929,
      חברה: "סלקום",
      "מס' אתר": "JC1176A",
      עיר: "אפיקים",
      "כתובת האתר": "קיבוץ אפיקים",
      "היתר קרינה": "יש היתר",
      "טכנולוגיית שידור": "דור 4",
      "בדיקה תקופתית אחרונה": "15/05/2026",
    };

    const parsed = parseRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("6793");
      expect(parsed.antennaId).toBe("6793");
      expect(parsed.siteNumber).toBe("JC1176A");
      expect(parsed.coordinates).toBeInstanceOf(admin.firestore.GeoPoint);
      expect(parsed.coordinates.latitude).toBeCloseTo(32.695, 2);
      expect(parsed.coordinates.longitude).toBeCloseTo(35.592, 2);
      expect(parsed.operatorName).toBe("Cellcom");
      expect(parsed.company).toEqual({ he: "סלקום", en: "Cellcom" });
      expect(parsed.locality).toBe("אפיקים");
      expect(parsed.permitType).toBe("יש היתר");
      expect(parsed.radiationFrequency).toBe(1800);
      expect(parsed.lastTestDate).toBe("2026-05-15T00:00:00.000Z");
      expect(parsed.addressHebrew).toBe("קיבוץ אפיקים");
    }
  });

  it("should handle frequency parsing correctly", () => {
    const raw5g = {
      מזהה: 1,
      X_ITM: 255812,
      Y_ITM: 732929,
      "טכנולוגיית שידור": "דור 5",
    };
    const parsed5g = parseRecord(raw5g);
    expect(parsed5g?.radiationFrequency).toBe(3500);

    const raw3g = {
      מזהה: 2,
      X_ITM: 255812,
      Y_ITM: 732929,
      "טכנולוגיית שידור": "דור 3",
    };
    const parsed3g = parseRecord(raw3g);
    expect(parsed3g?.radiationFrequency).toBe(2100);

    const raw2g = {
      מזהה: 3,
      X_ITM: 255812,
      Y_ITM: 732929,
      "טכנולוגיית שידור": "דור 2",
    };
    const parsed2g = parseRecord(raw2g);
    expect(parsed2g?.radiationFrequency).toBe(900);
  });
});

describe("Scraper and Sync Ingestion", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockGetAll: any;
  let mockMetadataSet: any;
  let mockMetadataGet: any;
  let mockCountGet: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockMetadataSet = vi.fn().mockResolvedValue(true);
    mockMetadataGet = vi.fn().mockResolvedValue({
      exists: false,
      data: () => ({}),
    });

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.CELLULAR_ANTENNAS) {
        return {
          get: mockMetadataGet,
          set: mockMetadataSet,
        };
      }
      return {
        id,
      };
    });

    mockCountGet = vi.fn().mockResolvedValue({
      data: () => ({ count: 2 }),
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
      // By default, documents do not exist
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

  it("should scrape data, parse, and write to Firestore in batch with createdAt and lastUpdated", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              מזהה: "6793",
              X_ITM: 255812,
              Y_ITM: 732929,
              חברה: "פלאפון",
              "היתר קרינה": "יש היתר",
            },
            {
              מזהה: "6794",
              X_ITM: 255812,
              Y_ITM: 732929,
              חברה: "פרטנר",
              "היתר קרינה": "יש היתר",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(2);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.CELLULAR_ANTENNAS);
    expect(mockGetAll).toHaveBeenCalled();
    expect(mockBatch.set).toHaveBeenCalledTimes(2);

    // Verify fields are populated
    const doc1 = mockBatch.set.mock.calls[0][1];
    expect(doc1.antennaId).toBe("6793");
    expect(doc1.createdAt).toBeDefined();
    expect(doc1.lastUpdated).toBeDefined();

    // Verify metadata update
    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.CELLULAR_ANTENNAS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.CELLULAR_ANTENNAS,
        status: "idle",
        recordCount: 2,
      }),
      { merge: true },
    );
  });

  it("should preserve existing createdAt timestamp for existing antennas", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "6793",
        data: () => ({ createdAt: initialCreatedAt }),
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              מזהה: "6793",
              X_ITM: 255812,
              Y_ITM: 732929,
              חברה: "פלאפון",
              "היתר קרינה": "יש היתר",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const doc = mockBatch.set.mock.calls[0][1];
    expect(doc.antennaId).toBe("6793");
    expect(doc.createdAt).toBe(initialCreatedAt);
    expect(doc.lastUpdated).toBeDefined();
    expect(doc.updatedAt).toBeDefined();
  });

  it("should skip writing to Firestore if the existing antenna is identical to the incoming antenna", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      מזהה: "6793",
      X_ITM: 255812,
      Y_ITM: 732929,
      חברה: "פלאפון",
      "מס' אתר": "JC1176A",
      עיר: "אפיקים",
      "כתובת האתר": "קיבוץ אפיקים",
      "היתר קרינה": "יש היתר",
      "טכנולוגיית שידור": "דור 4",
      "בדיקה תקופתית אחרונה": "15/05/2026",
    };

    const parsed = parseRecord(rawRecord)!;
    const existingAntenna = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: parsed.lastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "6793",
        data: () => existingAntenna,
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [rawRecord],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should write to Firestore and update lastUpdated if the existing antenna has different data", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      מזהה: "6793",
      X_ITM: 255812,
      Y_ITM: 732929,
      חברה: "פלאפון",
      "מס' אתר": "JC1176A",
      עיר: "אפיקים",
      "כתובת האתר": "קיבוץ אפיקים",
      "היתר קרינה": "יש היתר",
      "טכנולוגיית שידור": "דור 4",
      "בדיקה תקופתית אחרונה": "15/05/2026",
    };

    const parsed = parseRecord(rawRecord)!;
    const existingAntenna = {
      ...parsed,
      operatorName: "Partner",
      company: { he: "פרטנר", en: "Partner" },
      createdAt: initialCreatedAt,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "6793",
        data: () => existingAntenna,
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [rawRecord],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.operatorName).toBe("Pelephone");
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).not.toBe(initialLastUpdated);
    expect(written.updatedAt).toBeDefined();
  });

  it("should write to Firestore and update updatedAt if ONLY lastUpdated has changed", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      מזהה: "6793",
      X_ITM: 255812,
      Y_ITM: 732929,
      חברה: "פלאפון",
      "מס' אתר": "JC1176A",
      עיר: "אפיקים",
      "כתובת האתר": "קיבוץ אפיקים",
      "היתר קרינה": "יש היתר",
      "טכנולוגיית שידור": "דור 4",
      "בדיקה תקופתית אחרונה": "15/05/2026",
    };

    const parsed = parseRecord(rawRecord)!;
    const existingAntenna = {
      ...parsed,
      createdAt: initialCreatedAt,
      sourceUpdatedAt: initialLastUpdated,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "6793",
        data: () => existingAntenna,
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [rawRecord],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.sourceUpdatedAt).toBe(parsed.sourceUpdatedAt);
    expect(written.lastUpdated).toBe(parsed.sourceUpdatedAt);
    expect(written.updatedAt).toBeDefined();
  });

  it("should handle empty api response gracefully", async () => {
    vi.mocked(axios.get).mockResolvedValue({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(0);
    expect(mockDb.batch).not.toHaveBeenCalled();
  });

  it("should respect custom limit option", async () => {
    const apiResponse = {
      data: { result: { records: [] } },
    };
    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);

    await scrapeAndSyncAntennas(mockDb, DATASET_IDS.CELLULAR_ANTENNAS, { limit: 50 });

    expect(axios.get).toHaveBeenCalledWith(expect.stringContaining("limit=50"), expect.any(Object));
  });

  it("should enforce 10 records and stop after 1 page in emulator mode by default", async () => {
    const originalEmulatorVal = process.env.FUNCTIONS_EMULATOR;
    process.env.FUNCTIONS_EMULATOR = "true";

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              מזהה: "6793",
              X_ITM: 255812,
              Y_ITM: 732929,
              חברה: "פלאפון",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValue(apiResponse);

    try {
      const result = await scrapeAndSyncAntennas(mockDb);
      expect(result.count).toBe(1);
      // Since it's emulator mode and forceFullSync is not true, it should only call axios.get once
      expect(axios.get).toHaveBeenCalledTimes(1);
      expect(axios.get).toHaveBeenCalledWith(
        expect.stringContaining("limit=10"),
        expect.any(Object),
      );
    } finally {
      process.env.FUNCTIONS_EMULATOR = originalEmulatorVal;
    }
  });

  it("should bypass emulator limits and fetch multiple pages when forceFullSync is true", async () => {
    const originalEmulatorVal = process.env.FUNCTIONS_EMULATOR;
    process.env.FUNCTIONS_EMULATOR = "true";

    const apiResponse1 = {
      data: {
        result: {
          records: [
            {
              מזהה: "6793",
              X_ITM: 255812,
              Y_ITM: 732929,
              חברה: "פלאפון",
            },
          ],
        },
      },
    };

    const apiResponse2 = {
      data: {
        result: {
          records: [],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse1);
    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse2);

    try {
      const result = await scrapeAndSyncAntennas(mockDb, DATASET_IDS.CELLULAR_ANTENNAS, {
        forceFullSync: true,
      });
      expect(result.count).toBe(1);
      // Since forceFullSync is true, it should fetch pages recursively until records are empty
      expect(axios.get).toHaveBeenCalledTimes(2);
      expect(axios.get).toHaveBeenCalledWith(
        expect.stringContaining("limit=10000"),
        expect.any(Object),
      );
    } finally {
      process.env.FUNCTIONS_EMULATOR = originalEmulatorVal;
    }
  });
});
