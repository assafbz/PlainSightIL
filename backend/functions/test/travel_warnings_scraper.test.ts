import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  extractWarningLevel,
  parseTravelWarningRecord,
  scrapeAndSyncTravelWarnings,
} from "../src/scrapers/travel_warnings_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Travel Warnings Level Extraction", () => {
  it("should extract level 1-4 from Hebrew recommendations text", () => {
    expect(extractWarningLevel("רמה 4/ איום גבוה ולהימנע מהגעה")).toBe(4);
    expect(extractWarningLevel("המלצה לנקוט באמצעי זהירות, רמה 3/ איום בינוני")).toBe(3);
    expect(extractWarningLevel("איום מזדמן רמה 2/ איום מזדמן")).toBe(2);
    expect(extractWarningLevel("רמה 1/ איום בסיסי")).toBe(1);
  });

  it("should return default level 1 if no level format matches", () => {
    expect(extractWarningLevel("מידע בריאותי עדכני לנוסעים לחוץ לארץ")).toBe(1);
    expect(extractWarningLevel("")).toBe(1);
    expect(extractWarningLevel(null as any)).toBe(1);
  });
});

describe("Travel Warnings Record Parser", () => {
  it("should return null if country or _id is missing", () => {
    const record = {
      _id: 1,
      continent: "אפריקה",
      recommendations: "רמה 1/ איום בסיסי",
    };
    expect(parseTravelWarningRecord(record as any)).toBeNull();

    const recordNoId = {
      continent: "אפריקה",
      country: "אוגנדה",
    };
    expect(parseTravelWarningRecord(recordNoId as any)).toBeNull();
  });

  it("should parse and normalize travel warning records correctly", () => {
    const raw = {
      _id: 2,
      continent: "אפריקה",
      country: "אוגנדה",
      recommendations: "רמה 2/ איום מזדמן: המלצה לנקוט באמצעי זהירות מוגברים.",
      details: "להמלצה באתר המטה לביטחון לאומי",
      logo: "לוגו",
      date: "2026-06-03T06:58:30.099Z",
      משרד: "מל\"ל",
    };

    const parsed = parseTravelWarningRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("2");
      expect(parsed._id).toBe(2);
      expect(parsed.continent).toBe("אפריקה");
      expect(parsed.country).toBe("אוגנדה");
      expect(parsed.recommendations).toBe("רמה 2/ איום מזדמן: המלצה לנקוט באמצעי זהירות מוגברים.");
      expect(parsed.details).toBe("להמלצה באתר המטה לביטחון לאומי");
      expect(parsed.logo).toBe("לוגו");
      expect(parsed.date).toBe("2026-06-03T06:58:30.099Z");
      expect(parsed.office).toBe("מל\"ל");
      expect(parsed.warningLevel).toBe(2);
    }
  });
});

describe("Travel Warnings Ingest Sync Process", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockMetadataSet: any;
  let mockCountGet: any;
  let mockGetAll: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockMetadataSet = vi.fn().mockResolvedValue(true);

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.TRAVEL_WARNINGS) {
        return {
          set: mockMetadataSet,
        };
      }
      return {
        id,
      };
    });

    mockCountGet = vi.fn().mockResolvedValue({
      data: () => ({ count: 1 }),
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

  it("should page through datastore, verify records, and commit to Firestore", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 1,
              continent: "אפריקה",
              country: "אוגנדה",
              recommendations: "רמה 2/ איום מזדמן: המלצה לנקוט באמצעי זהירות מוגברים.",
              date: "2026-06-03T00:00:00Z",
              משרד: "מל\"ל",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncTravelWarnings(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.TRAVEL_WARNINGS);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("1");
    expect(written.country).toBe("אוגנדה");
    expect(written.warningLevel).toBe(2);

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.TRAVEL_WARNINGS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.TRAVEL_WARNINGS,
        status: "idle",
        recordCount: 1,
      }),
      { merge: true },
    );
  });

  it("should preserve initial createdAt timestamp if the record already exists", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "1",
        data: () => ({ createdAt: initialCreatedAt }),
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 1,
              continent: "אפריקה",
              country: "אוגנדה",
              recommendations: "רמה 2",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncTravelWarnings(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).toBeDefined();
    expect(written.updatedAt).toBeDefined();
  });
});
