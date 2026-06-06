import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parseLocalMarketBondRecord,
  scrapeAndSyncLocalMarketBonds,
  getBondTypeTranslation,
  parseDDMMYYYY,
  parseIssuanceDate,
} from "../src/scrapers/local_market_bonds_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Local Market Bonds Date and Type Parsers", () => {
  it("should translate bond types correctly", () => {
    expect(getBondTypeTranslation("ממשלתית")).toEqual({ he: "ממשלתית", en: "Government" });
    expect(getBondTypeTranslation("ממשלתית צמודה")).toEqual({
      he: "ממשלתית צמודה",
      en: "CPI-Linked Government",
    });
    expect(getBondTypeTranslation("ממשלתית בריבית משתנה")).toEqual({
      he: "ממשלתית בריבית משתנה",
      en: "Floating Rate Government",
    });
    expect(getBondTypeTranslation("אחר")).toEqual({ he: "אחר", en: "אחר" });
  });

  it("should parse DD/MM/YYYY dates to ISO strings", () => {
    expect(parseDDMMYYYY("31/10/2035")).toBe("2035-10-31T00:00:00.000Z");
    expect(parseDDMMYYYY("02/06/2026")).toBe("2026-06-02T00:00:00.000Z");
    expect(parseDDMMYYYY("invalid-date-format")).toBe("");
    expect(parseDDMMYYYY("")).toBe("");
    expect(parseDDMMYYYY(null)).toBe("");
  });

  it("should parse issuance dates to ISO strings", () => {
    expect(parseIssuanceDate("2026-06-02T00:00:00")).toBe("2026-06-02T00:00:00.000Z");
    expect(parseIssuanceDate("2026-06-02T00:00:00.000Z")).toBe("2026-06-02T00:00:00.000Z");
    expect(parseIssuanceDate("2026-06-02")).toBe("2026-06-02");
    expect(parseIssuanceDate("")).toBe("");
    expect(parseIssuanceDate(null)).toBe("");
  });
});

describe("Local Market Bonds Record Parser", () => {
  it("should return null if _id is missing", () => {
    const raw = {
      SERIES: 1227784,
    };
    expect(parseLocalMarketBondRecord(raw as any)).toBeNull();
  });

  it("should parse and normalize a valid local market bond record", () => {
    const raw = {
      _id: 1,
      ISSUANCEDATE: "2026-06-02T00:00:00",
      BONDS: "ממשלתית",
      SERIES: 1227784,
      ACTUALTERMTOMATURITY: 9.4,
      ORIGINALTERMTOMATURITY: 10,
      REDEMTIONDATE: "31/10/2035",
      COUPON: 4.15,
      OFFEREDQUANTITY: 106,
      PURCHASEDQUANTITY: 105.8,
      ADDITIONALPURCHASED: -0.1,
      AVERAGEPRICE: 105.73,
      CUTOFFPRICE: 105.73,
      TOTALFUNDING: 111.9,
      DEMANDEDAMOUNT: 105.8,
      COVERRATIO: 1,
      GROSSAVGYIELD: 3.73,
      GROSSCUTOFFYIELD: 3.73,
    };

    const parsed = parseLocalMarketBondRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("1");
      expect(parsed._id).toBe(1);
      expect(parsed.issuanceDate).toBe("2026-06-02T00:00:00.000Z");
      expect(parsed.bondType).toEqual({ he: "ממשלתית", en: "Government" });
      expect(parsed.series).toBe(1227784);
      expect(parsed.actualTermToMaturity).toBe(9.4);
      expect(parsed.originalTermToMaturity).toBe(10);
      expect(parsed.redemptionDate).toBe("2035-10-31T00:00:00.000Z");
      expect(parsed.coupon).toBe(4.15);
      expect(parsed.offeredQuantity).toBe(106);
      expect(parsed.purchasedQuantity).toBe(105.8);
      expect(parsed.additionalPurchased).toBe(-0.1);
      expect(parsed.averagePrice).toBe(105.73);
      expect(parsed.cutoffPrice).toBe(105.73);
      expect(parsed.totalFunding).toBe(111.9);
      expect(parsed.demandedAmount).toBe(105.8);
      expect(parsed.coverRatio).toBe(1);
      expect(parsed.grossAvgYield).toBe(3.73);
      expect(parsed.grossCutoffYield).toBe(3.73);
      expect(parsed.lastUpdated).toBe("2035-10-31T00:00:00.000Z");
    }
  });
});

describe("Local Market Bonds Ingest Sync Process", () => {
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
      data: () => ({ lastSyncedMaxId: 100 }),
    });

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.LOCAL_MARKET_BONDS) {
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
      data: () => ({ count: 12 }),
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

  it("should page, parse, ingest records and update metadata doc", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 105,
              ISSUANCEDATE: "2026-06-02T00:00:00",
              BONDS: "ממשלתית",
              SERIES: 1227784,
              REDEMTIONDATE: "31/10/2035",
            },
            {
              _id: 99, // Should be ignored in delta-sync (<= 100)
              ISSUANCEDATE: "2026-06-02T00:00:00",
              BONDS: "ממשלתית צמודה",
              SERIES: 1220722,
              REDEMTIONDATE: "30/04/2031",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);

    const result = await scrapeAndSyncLocalMarketBonds(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1); // Only 1 record since _id: 99 <= 100 (delta sync limit)
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.LOCAL_MARKET_BONDS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.LOCAL_MARKET_BONDS,
        status: "idle",
        recordCount: 12,
        lastSyncedMaxId: 105,
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
              _id: 105,
              ISSUANCEDATE: "2026-06-02T00:00:00",
              BONDS: "ממשלתית",
              SERIES: 1227784,
              REDEMTIONDATE: "31/10/2035",
            },
            {
              _id: 106,
              ISSUANCEDATE: "2026-06-02T00:00:00",
              BONDS: "ממשלתית",
              SERIES: 9999999,
              REDEMTIONDATE: "31/10/2035",
            },
          ],
        },
      },
    };

    const parsed105 = parseLocalMarketBondRecord({
      _id: 105,
      ISSUANCEDATE: "2026-06-02T00:00:00",
      BONDS: "ממשלתית",
      SERIES: 1227784,
      REDEMTIONDATE: "31/10/2035",
    })!;
    parsed105.lastUpdated = "2026-06-06T09:00:00.000Z";

    // Mock existing records in database: 105 is identical, 106 is different
    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "105",
        data: () => parsed105,
      },
      {
        exists: true,
        id: "106",
        data: () => ({
          _id: 106,
          issuanceDate: "2026-06-02T00:00:00.000Z",
          bondType: { he: "ממשלתית", en: "Government" },
          series: 8888888, // Different series
          actualTermToMaturity: 0,
          originalTermToMaturity: 0,
          redemptionDate: "2035-10-31T00:00:00.000Z",
          coupon: 0,
          offeredQuantity: 0,
          purchasedQuantity: 0,
          additionalPurchased: 0,
          averagePrice: 0,
          cutoffPrice: 0,
          totalFunding: 0,
          demandedAmount: 0,
          coverRatio: 0,
          grossAvgYield: 0,
          grossCutoffYield: 0,
          lastUpdated: "2026-06-06T09:00:00.000Z",
          createdAt: "2026-06-01T00:00:00.000Z",
        }),
      },
    ]);

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncLocalMarketBonds(mockDb);
    expect(result.success).toBe(true);
    // Wrote 1 record (106 differed, 105 was identical and skipped)
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    vi.useRealTimers();
  });

  it("should handle empty API response", async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncLocalMarketBonds(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(0);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should handle scraper errors and update metadata status to error", async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error("API Timeout"));

    await expect(scrapeAndSyncLocalMarketBonds(mockDb)).rejects.toThrow("API Timeout");
    expect(mockMetadataSet).toHaveBeenCalledWith({ status: "error" }, { merge: true });
  });
});
