import { describe, it, expect, vi, beforeEach } from "vitest";
import * as admin from "firebase-admin";
import axios from "axios";
import { encodeGeohash } from "../src/utils/geohash";
import { parseRecord, scrapeAndSyncAntennas } from "../src/scrapers/antennas_scraper";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Geohash Utility", () => {
  it("should encode coordinates into correct geohash representation", () => {
    // Tel Aviv center
    const hash = encodeGeohash(32.0853, 34.7818, 9);
    expect(hash).toBe("sv8wx2zq6");
  });

  it("should throw error for invalid coordinates", () => {
    expect(() => encodeGeohash(-95, 34.7818)).toThrow();
    expect(() => encodeGeohash(32.0853, 200)).toThrow();
  });
});

describe("Record Parser", () => {
  it("should return null if ID or coordinates are missing", () => {
    const incompleteRecord = {
      מזהה_אנטנה: "SITE-1",
      קו_רוחב: "32.0853",
      // longitude missing
    };
    expect(parseRecord(incompleteRecord)).toBeNull();
  });

  it("should parse and translate Hebrew fields correctly", () => {
    const raw = {
      מזהה_אנטנה: "SITE-100",
      קו_רוחב: "32.0853",
      קו_אורך: "34.7818",
      שם_מפעיל: 'סלקום בע"מ',
      סוג_אישור: "הקמה זמנית",
      תדר: "1800",
      תאריך_בדיקה_אחרון: "2026-05-15",
      כתובת_אתר: "דיזנגוף 50, תל אביב",
    };

    const parsed = parseRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.antennaId).toBe("SITE-100");
      expect(parsed.coordinates).toBeInstanceOf(admin.firestore.GeoPoint);
      expect(parsed.coordinates.latitude).toBe(32.0853);
      expect(parsed.coordinates.longitude).toBe(34.7818);
      expect(parsed.geohash).toBe("sv8wx2zq6");
      expect(parsed.operatorName).toBe("Cellcom");
      expect(parsed.permitType).toBe("Permitted");
      expect(parsed.radiationFrequency).toBe(1800);
      expect(parsed.lastTestDate).toBe("2026-05-15T00:00:00.000Z");
      expect(parsed.addressHebrew).toBe("דיזנגוף 50, תל אביב");
      expect(parsed.addressEnglish).toBe("Dizengoff 50, Tel Aviv");
    }
  });

  it("should fallback operator and permit translate properly", () => {
    const raw = {
      מזהה_אנטנה: "SITE-200",
      קו_רוחב: 32.0,
      קו_אורך: 34.0,
      שם_מפעיל: "אורנג'",
      סוג_אישור: "לא ידוע סטטוס",
      תדר: "invalid-freq",
    };

    const parsed = parseRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.operatorName).toBe("אורנג'");
      expect(parsed.permitType).toBe("Under Review");
      expect(parsed.radiationFrequency).toBe(0);
    }
  });
});

describe("Scraper and Sync Ingestion", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockDoc = vi.fn().mockReturnValue({
      id: "mock-doc-id",
    });

    mockCollection = vi.fn().mockReturnValue({
      doc: mockDoc,
    });

    mockBatch = {
      set: vi.fn(),
      commit: vi.fn().mockResolvedValue(true),
    };

    mockDb = {
      collection: mockCollection,
      batch: vi.fn().mockReturnValue(mockBatch),
    };
  });

  it("should scrape data, parse, and write to Firestore in batch", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              מזהה_אנטנה: "CELL-1",
              קו_רוחב: "32.085",
              קו_אורך: "34.781",
              שם_מפעיל: "פלאפון",
              סוג_אישור: "פעיל",
            },
            {
              מזהה_אנטנה: "CELL-2",
              קו_רוחב: "32.086",
              קו_אורך: "34.782",
              שם_מפעיל: "פרטנר",
              סוג_אישור: "פעיל",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValue(apiResponse);

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(2);

    expect(mockDb.collection).toHaveBeenCalledWith("cellular_antennas");
    expect(mockDb.batch).toHaveBeenCalledTimes(1);
    expect(mockBatch.set).toHaveBeenCalledTimes(2);
    expect(mockBatch.commit).toHaveBeenCalledTimes(1);
  });

  it("should handle empty api response gracefully", async () => {
    vi.mocked(axios.get).mockResolvedValue({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncAntennas(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(0);
    expect(mockDb.batch).not.toHaveBeenCalled();
  });
});
