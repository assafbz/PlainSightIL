import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import axios from "axios";
import {
  getTranslatedStatus,
  parseLiquidationRecord,
  scrapeAndSyncCompaniesLiquidation,
} from "../src/scrapers/companies_liquidation_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Status Translation & Localization", () => {
  it("should translate Hebrew case statuses to English counterparts", () => {
    expect(getTranslatedStatus("פירוק פעיל")).toEqual({
      he: "פירוק פעיל",
      en: "Active Winding Up",
    });
    expect(getTranslatedStatus("פעיל")).toEqual({ he: "פעיל", en: "Active" });
    expect(getTranslatedStatus("סגור")).toEqual({ he: "סגור", en: "Closed" });
    expect(getTranslatedStatus("תיק סגור")).toEqual({ he: "תיק סגור", en: "Closed" });
    expect(getTranslatedStatus("בוטל")).toEqual({ he: "בוטל", en: "Cancelled" });
    expect(getTranslatedStatus("הקפאה")).toEqual({ he: "הקפאה", en: "Frozen" });
    expect(getTranslatedStatus("הקפאת הליכים")).toEqual({ he: "הקפאת הליכים", en: "Frozen" });
  });

  it("should return the trimmed raw value for unknown status names", () => {
    expect(getTranslatedStatus("סטטוס מיוחד  ")).toEqual({ he: "סטטוס מיוחד", en: "סטטוס מיוחד" });
  });
});

describe("Liquidation Record Parser", () => {
  it("should return null if companyId, companyName, or caseId is missing", () => {
    const record = {
      "שם החברה": 'משה שירותי בנייה בע"מ',
    };
    expect(parseLiquidationRecord(record)).toBeNull();
  });

  it("should parse and normalize companies liquidation records correctly", () => {
    const raw = {
      "מזהה תיק פירוק חברה": 12345,
      "עיר פעילות חברה": "תל אביב - יפו",
      "סטטוס תיק": "פירוק פעיל",
      "תאריך הגשת הבקשה": "2024-05-12T00:00:00",
      "תאריך קבלת צו פירוק": "2024-06-15T00:00:00",
      "בית משפט מחוזי בו מתנהל התיק": "מחוזי תל אביב",
      "שם החברה": '  אלברט לוי הנדסה בע"מ  ',
      "מספר זיהוי של החברה": 512345678,
    };

    const parsed = parseLiquidationRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("512345678");
      expect(parsed.companyId).toBe(512345678);
      expect(parsed.companyName).toBe('אלברט לוי הנדסה בע"מ');
      expect(parsed.liquidationCaseId).toBe(12345);
      expect(parsed.caseStatus).toEqual({ he: "פירוק פעיל", en: "Active Winding Up" });
      expect(parsed.cityOfActivity).toBe("תל אביב - יפו");
      expect(parsed.districtCourt).toBe("מחוזי תל אביב");
      expect(parsed.submissionDate).toBe("2024-05-12T00:00:00.000Z");
      expect(parsed.liquidationOrderDate).toBe("2024-06-15T00:00:00.000Z");
      expect(parsed.cancellationFreezeDate).toBeNull();
      expect(parsed.closureDate).toBeNull();
      expect(parsed.closureReason).toBeNull();
    }
  });

  it("should parse optionals (closureReason, cancellationFreezeDate, closureDate) correctly", () => {
    const raw = {
      "מזהה תיק פירוק חברה": 12345,
      "עיר פעילות חברה": "תל אביב - יפו",
      "סטטוס תיק": "סגור",
      "תאריך הגשת הבקשה": "2024-05-12T00:00:00",
      "תאריך קבלת צו פירוק": "2024-06-15T00:00:00",
      "תאריך ביטול / הקפאת צו פירוק": "2024-07-20T00:00:00",
      "תאריך סגירת תיק": "2025-01-10T00:00:00",
      "סיבת סגירה": "הסדר נושים",
      "בית משפט מחוזי בו מתנהל התיק": "מחוזי תל אביב",
      "שם החברה": 'אלברט לוי הנדסה בע"מ',
      "מספר זיהוי של החברה": 512345678,
    };

    const parsed = parseLiquidationRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.caseStatus).toEqual({ he: "סגור", en: "Closed" });
      expect(parsed.cancellationFreezeDate).toBe("2024-07-20T00:00:00.000Z");
      expect(parsed.closureDate).toBe("2025-01-10T00:00:00.000Z");
      expect(parsed.closureReason).toBe("הסדר נושים");
    }
  });
});

describe("Companies Liquidation Scraper Ingestion", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockMetadataSet: any;
  let mockCountGet: any;
  let mockGetAll: any;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-04T12:00:00.000Z"));
    vi.clearAllMocks();

    mockMetadataSet = vi.fn().mockResolvedValue(true);

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.COMPANIES_LIQUIDATION) {
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

  afterEach(() => {
    vi.useRealTimers();
  });

  it("should scrape companies in liquidation, check existence and sync to Firestore", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              "מזהה תיק פירוק חברה": 12345,
              "שם החברה": 'אלברט לוי הנדסה בע"מ',
              "מספר זיהוי של החברה": 512345678,
              "סטטוס תיק": "פירוק פעיל",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncCompaniesLiquidation(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.COMPANIES_LIQUIDATION);
    expect(mockGetAll).toHaveBeenCalled();
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("512345678");
    expect(written.createdAt).toBeDefined();
    expect(written.lastUpdated).toBeDefined();

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.COMPANIES_LIQUIDATION);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.COMPANIES_LIQUIDATION,
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
        id: "512345678",
        data: () => ({ createdAt: initialCreatedAt }),
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              "מזהה תיק פירוק חברה": 12345,
              "שם החברה": 'אלברט לוי הנדסה בע"מ',
              "מספר זיהוי של החברה": 512345678,
              "סטטוס תיק": "פירוק פעיל",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncCompaniesLiquidation(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).toBeDefined();
    expect(written.updatedAt).toBeDefined();
  });

  it("should skip writing if the record already exists and is identical", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      "מזהה תיק פירוק חברה": 12345,
      "שם החברה": 'אלברט לוי הנדסה בע"מ',
      "מספר זיהוי של החברה": 512345678,
      "סטטוס תיק": "פירוק פעיל",
    };

    const parsed = parseLiquidationRecord(rawRecord)!;
    const existing = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: parsed.lastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "512345678",
        data: () => existing,
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

    const result = await scrapeAndSyncCompaniesLiquidation(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should write and update lastUpdated if the record exists but has different data", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      "מזהה תיק פירוק חברה": 12345,
      "שם החברה": 'אלברט לוי הנדסה בע"מ',
      "מספר זיהוי של החברה": 512345678,
      "סטטוס תיק": "פירוק פעיל",
    };

    const parsed = parseLiquidationRecord(rawRecord)!;
    const existing = {
      ...parsed,
      cityOfActivity: "ירושלים",
      createdAt: initialCreatedAt,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "512345678",
        data: () => existing,
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

    const result = await scrapeAndSyncCompaniesLiquidation(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.cityOfActivity).toBe("לא ידוע");
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).not.toBe(initialLastUpdated);
    expect(written.updatedAt).toBeDefined();
  });

  it("should write and update updatedAt if ONLY lastUpdated has changed", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      "מזהה תיק פירוק חברה": 12345,
      "שם החברה": 'אלברט לוי הנדסה בע"מ',
      "מספר זיהוי של החברה": 512345678,
      "סטטוס תיק": "פירוק פעיל",
      "תאריך קבלת צו פירוק": "2026-05-15 00:00:00",
    };

    const parsed = parseLiquidationRecord(rawRecord)!;
    const existing = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "512345678",
        data: () => existing,
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

    const result = await scrapeAndSyncCompaniesLiquidation(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).toBe(parsed.lastUpdated);
    expect(written.updatedAt).toBeDefined();
  });
});
