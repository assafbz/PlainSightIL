import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parsePatentRecord,
  scrapeAndSyncPatentClassifications,
} from "../src/scrapers/patent_classifications_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Patent Classifications Record Parser", () => {
  it("should return null if key fields are missing or invalid", () => {
    // Missing application number
    const r1 = {
      _id: 1,
      "שם האמצאה בעברית": "מכשיר",
      "לבקשה CPC סיווג": "F16L",
    };
    expect(parsePatentRecord(r1 as any)).toBeNull();

    // Invalid application number
    const r2 = {
      _id: 1,
      "מספר בקשה": "not-a-number",
      "שם האמצאה בעברית": "מכשיר",
      "לבקשה CPC סיווג": "F16L",
    };
    expect(parsePatentRecord(r2 as any)).toBeNull();

    // Missing classification
    const r3 = {
      _id: 1,
      "מספר בקשה": 12345,
      "שם האמצאה בעברית": "מכשיר",
    };
    expect(parsePatentRecord(r3 as any)).toBeNull();

    // Both titles empty
    const r4 = {
      _id: 1,
      "מספר בקשה": 12345,
      "לבקשה CPC סיווג": "F16L",
    };
    expect(parsePatentRecord(r4 as any)).toBeNull();
  });

  it("should parse and normalize a valid patent classification record", () => {
    const raw = {
      _id: 741210,
      "מספר בקשה": 327015,
      "שם האמצאה בעברית": "שילוב תרופות",
      "שם האמצאה באנגלית": "DRUG COMBINATION",
      "לבקשה CPC סיווג": "A61P35/00",
      ראשי: "ראשי",
    };

    const parsed = parsePatentRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("741210");
      expect(parsed._id).toBe(741210);
      expect(parsed.applicationNumber).toBe(327015);
      expect(parsed.titleHebrew).toBe("שילוב תרופות");
      expect(parsed.titleEnglish).toBe("DRUG COMBINATION");
      expect(parsed.cpcClassification).toBe("A61P35/00");
      expect(parsed.isPrimary).toBe(true);
      expect(parsed.sourceUpdatedAt).toBeDefined();
    }
  });

  it("should correctly handle secondary classifications", () => {
    const raw = {
      _id: 741209,
      "מספר בקשה": 326672,
      "שם האמצאה בעברית": "תכשירים",
      "לבקשה CPC סיווג": "C22C19/05",
      ראשי: "",
    };

    const parsed = parsePatentRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.isPrimary).toBe(false);
    }
  });
});

describe("Patent Classifications Ingest Sync Process", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockMetadataGet: any;
  let mockMetadataSet: any;
  let mockCountGet: any;
  let mockGetAll: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockMetadataSet = vi.fn().mockResolvedValue(true);
    mockMetadataGet = vi.fn().mockResolvedValue({
      exists: true,
      data: () => ({ lastSyncedMaxId: 741200 }),
    });

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.PATENT_CLASSIFICATIONS) {
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
      data: () => ({ count: 5 }),
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

  it("should page through datastore, ingest new records and update metadata", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 741205,
              "מספר בקשה": 327015,
              "שם האמצאה באנגלית": "DRUG COMBINATION",
              "לבקשה CPC סיווג": "A61P35/00",
              ראשי: "ראשי",
            },
            {
              _id: 741199,
              "מספר בקשה": 326672,
              "שם האמצאה בעברית": "תכשירים",
              "לבקשה CPC סיווג": "C22C19/05",
            },
          ],
        },
      },
    };

    // Mock first sync run with no previous synced max id
    mockMetadataGet.mockResolvedValueOnce({
      exists: false,
      data: () => null,
    });

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncPatentClassifications(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(2);
    expect(mockBatch.set).toHaveBeenCalledTimes(2);

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.PATENT_CLASSIFICATIONS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.PATENT_CLASSIFICATIONS,
        status: "idle",
        recordCount: 5,
        lastSyncedMaxId: 741205,
      }),
      { merge: true },
    );
  });

  it("should stop sync immediately if record _id <= lastSyncedMaxId (Delta Sync)", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 741205, // > 741200
              "מספר בקשה": 327015,
              "שם האמצאה באנגלית": "DRUG COMBINATION",
              "לבקשה CPC סיווג": "A61P35/00",
              ראשי: "ראשי",
            },
            {
              _id: 741200, // <= 741200 (Delta Sync boundary)
              "מספר בקשה": 326672,
              "שם האמצאה בעברית": "תכשירים",
              "לבקשה CPC סיווג": "C22C19/05",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);

    const result = await scrapeAndSyncPatentClassifications(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1); // Only 1 record processed because the second record hit the delta sync limit
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        lastSyncedMaxId: 741205,
      }),
      { merge: true },
    );
  });

  it("should handle existing identical records and skip them, or update changed records", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-06T09:00:00.000Z"));

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 741205,
              "מספר בקשה": 327015,
              "שם האמצאה באנגלית": "DRUG COMBINATION",
              "לבקשה CPC סיווג": "A61P35/00",
              ראשי: "ראשי",
            },
            {
              _id: 741206,
              "מספר בקשה": 327015,
              "שם האמצאה באנגלית": "DRUG COMBINATION DIFFERENT",
              "לבקשה CPC סיווג": "A61P35/00",
              ראשי: "ראשי",
            },
          ],
        },
      },
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "741205",
        data: () =>
          parsePatentRecord({
            _id: 741205,
            "מספר בקשה": 327015,
            "שם האמצאה באנגלית": "DRUG COMBINATION",
            "לבקשה CPC סיווג": "A61P35/00",
            ראשי: "ראשי",
          }),
      },
      {
        exists: true,
        id: "741206",
        data: () => ({
          _id: 741206,
          applicationNumber: 327015,
          titleHebrew: "",
          titleEnglish: "DRUG COMBINATION OLD",
          cpcClassification: "A61P35/00",
          isPrimary: true,
          lastUpdated: "2026-06-06T09:00:00.000Z",
          createdAt: "2026-06-01T00:00:00.000Z",
        }),
      },
    ]);

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncPatentClassifications(mockDb);
    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1); // Only 1 record written (741206)

    vi.useRealTimers();
  });

  it("should handle empty API response gracefully", async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncPatentClassifications(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(0);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should handle scraper errors and update metadata status to error", async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error("API Error"));

    await expect(scrapeAndSyncPatentClassifications(mockDb)).rejects.toThrow("API Error");
    expect(mockMetadataSet).toHaveBeenCalledWith({ status: "error" }, { merge: true });
  });

  it("should parse CPC classification empty string as null", () => {
    const raw = {
      _id: 1,
      "מספר בקשה": 12345,
      "שם האמצאה בעברית": "מכשיר",
      "לבקשה CPC סיווג": "   ", // spaces only
    };
    expect(parsePatentRecord(raw as any)).toBeNull();
  });
});
