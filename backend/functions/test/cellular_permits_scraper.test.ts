import { describe, it, expect, vi, beforeEach } from "vitest";
import * as admin from "firebase-admin";
import axios from "axios";
import {
  convertItmToWgs84,
  isValidIsraelCoordinates,
  getTranslatedOperator,
  parsePermitRecord,
  scrapeAndSyncPermitApplications,
} from "../src/scrapers/cellular_permits_scraper";
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

    // Outside borders (e.g. USA, Ocean, Europe)
    expect(isValidIsraelCoordinates(40.7128, -74.006)).toBe(false);
    expect(isValidIsraelCoordinates(0, 0)).toBe(false);
  });
});

describe("Operator Translation & Localization", () => {
  it("should translate Hebrew operator names to English counterparts", () => {
    expect(getTranslatedOperator("פלאפון")).toEqual({ he: "פלאפון", en: "Pelephone" });
    expect(getTranslatedOperator("סלקום")).toEqual({ he: "סלקום", en: "Cellcom" });
    expect(getTranslatedOperator("פרטנר")).toEqual({ he: "פרטנר", en: "Partner" });
    expect(getTranslatedOperator("PHI (משרת את הוט ופרטנר)")).toEqual({
      he: "PHI (משרת את הוט ופרטנר)",
      en: "PHI (HOT & Partner)",
    });
  });

  it("should return the trimmed raw value for unknown operator names", () => {
    expect(getTranslatedOperator("מפעיל חדש  ")).toEqual({ he: "מפעיל חדש", en: "מפעיל חדש" });
  });
});

describe("Permit Record Parser", () => {
  it("should return null if ID or coordinates are missing or invalid", () => {
    const record = {
      ID: 101,
      X_ITM: "invalid",
      Y_ITM: 627507,
    };
    expect(parsePermitRecord(record)).toBeNull();
  });

  it("should parse and normalize permit records correctly", () => {
    const raw = {
      ID: "50",
      "תאריך הגשת הבקשה": "2025-09-01 00:00:00",
      "מס' סימוכין": 2081659,
      חברה: "פלאפון",
      "סוג  היתר": "היתר הקמה",
      "מספר האתר": "NN1845A",
      ישוב: "אפיקים",
      "כתובת + תאור": "קיבוץ אפיקים",
      "סוג המוקד": "קרקעי",
      X_ITM: 255812,
      Y_ITM: 732929,
      "תחום שיפוט": "עמק הירדן",
    };

    const parsed = parsePermitRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("50");
      expect(parsed.referenceNumber).toBe(2081659);
      expect(parsed.coordinates).toBeInstanceOf(admin.firestore.GeoPoint);
      expect(parsed.coordinates.latitude).toBeCloseTo(32.695, 2);
      expect(parsed.coordinates.longitude).toBeCloseTo(35.592, 2);
      expect(parsed.company).toEqual({ he: "פלאפון", en: "Pelephone" });
      expect(parsed.permitType).toBe("היתר הקמה");
      expect(parsed.siteNumber).toBe("NN1845A");
      expect(parsed.locality).toBe("אפיקים");
      expect(parsed.addressDescription).toBe("קיבוץ אפיקים");
      expect(parsed.focalPointType).toBe("קרקעי");
      expect(parsed.jurisdiction).toBe("עמק הירדן");
      expect(parsed.geohash).toBeDefined();
    }
  });
});

describe("Incremental Update Scraper Ingestion", () => {
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
      if (id === DATASET_IDS.CELLULAR_PERMITS) {
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

  it("should scrape cellular permits, check existence using db.getAll, and write to cellular_permit_applications", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              ID: "50",
              "תאריך הגשת הבקשה": "2025-09-01 00:00:00",
              "מס' סימוכין": 2081659,
              חברה: "סלקום",
              X_ITM: 255812,
              Y_ITM: 732929,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncPermitApplications(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.CELLULAR_PERMITS);
    expect(mockGetAll).toHaveBeenCalled();
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    // Verify that the record is written with createdAt and lastUpdated
    const writtenRecord = mockBatch.set.mock.calls[0][1];
    expect(writtenRecord.id).toBe("50");
    expect(writtenRecord.createdAt).toBeDefined();
    expect(writtenRecord.lastUpdated).toBeDefined();

    // Verify metadata update
    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.CELLULAR_PERMITS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.CELLULAR_PERMITS,
        status: "idle",
        recordCount: 1,
      }),
      { merge: true },
    );
  });

  it("should preserve initial createdAt timestamp if the record already exists", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";

    // Setup db.getAll to return that the document exists with the initialCreatedAt timestamp
    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "50",
        data: () => ({ createdAt: initialCreatedAt }),
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              ID: "50",
              "תאריך הגשת הבקשה": "2025-09-01 00:00:00",
              "מס' סימוכין": 2081659,
              חברה: "סלקום",
              X_ITM: 255812,
              Y_ITM: 732929,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncPermitApplications(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const writtenRecord = mockBatch.set.mock.calls[0][1];
    expect(writtenRecord.id).toBe("50");
    // Verify that createdAt is preserved
    expect(writtenRecord.createdAt).toBe(initialCreatedAt);
    expect(writtenRecord.lastUpdated).toBeDefined();
    // lastUpdated should be different from initialCreatedAt (we'll assume now is used)
    expect(writtenRecord.lastUpdated).not.toBe(initialCreatedAt);
  });
});
