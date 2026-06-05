import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parseRecallRecord,
  scrapeAndSyncVehicleRecalls,
  getTranslatedRecallType,
} from "../src/scrapers/vehicle_recalls_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Vehicle Recalls Type Translation", () => {
  it("should translate Safety Recall and Technical Service Campaign correctly", () => {
    expect(getTranslatedRecallType("תקלה סידרתית בטיחותית")).toEqual({
      he: "תקלה סידרתית בטיחותית",
      en: "Safety Recall",
    });
    expect(getTranslatedRecallType("קמפיין שרות טכני")).toEqual({
      he: "קמפיין שרות טכני",
      en: "Technical Service Campaign",
    });
    expect(getTranslatedRecallType("משהו אחר")).toEqual({
      he: "משהו אחר",
      en: "משהו אחר",
    });
  });
});

describe("Vehicle Recalls Record Parser", () => {
  it("should return null if RECALL_ID or _id is missing or invalid", () => {
    const record1 = {
      _id: 1,
      TOZAR_TEUR: "TOYOTA",
    };
    expect(parseRecallRecord(record1 as any)).toBeNull();

    const record2 = {
      RECALL_ID: 11020,
      TOZAR_TEUR: "TOYOTA",
    };
    expect(parseRecallRecord(record2 as any)).toBeNull();
  });

  it("should parse and normalize vehicle recall records correctly", () => {
    const raw = {
      _id: 1,
      RECALL_ID: 11020,
      TOZAR_CD: 1,
      TOZAR_TEUR: "TOYOTA",
      DEGEM: "AVENSIS",
      SHNAT_RECALL: 2011,
      BUILD_BEGIN_A: "2000-01-02",
      BUILD_END_A: "2008-12-31",
      SUG_RECALL: "תקלה סידרתית בטיחותית",
      SUG_TAKALA: "מנוע ומערכותיו",
      TEUR_TAKALA: "שסתום צינור דלק אוונסיס",
      OFEN_TIKUN: "החלפה",
      TKINA_EU: "M1",
      YEVUAN_TEUR: "יוניון מוטורס בעמ",
      TELEPHONE: "1-800-22-1514",
      WEBSITE: "WWW.TOYOTA.CO.IL/SERVICE-AND-ACCESSORIES/RECALL",
    };

    const parsed = parseRecallRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("11020");
      expect(parsed._id).toBe(1);
      expect(parsed.recallId).toBe(11020);
      expect(parsed.manufacturerCode).toBe(1);
      expect(parsed.manufacturerName).toBe("TOYOTA");
      expect(parsed.modelName).toBe("AVENSIS");
      expect(parsed.recallYear).toBe(2011);
      expect(parsed.buildStartDate).toBe("2000-01-02T00:00:00.000Z");
      expect(parsed.buildEndDate).toBe("2008-12-31T00:00:00.000Z");
      expect(parsed.recallType).toEqual({
        he: "תקלה סידרתית בטיחותית",
        en: "Safety Recall",
      });
      expect(parsed.defectCategory).toBe("מנוע ומערכותיו");
      expect(parsed.defectDescription).toBe("שסתום צינור דלק אוונסיס");
      expect(parsed.repairAction).toBe("החלפה");
      expect(parsed.euCategory).toBe("M1");
      expect(parsed.importerName).toBe("יוניון מוטורס בעמ");
      expect(parsed.importerPhone).toBe("1-800-22-1514");
      expect(parsed.importerWebsite).toBe("WWW.TOYOTA.CO.IL/SERVICE-AND-ACCESSORIES/RECALL");
    }
  });
});

describe("Vehicle Recalls Ingest Sync Process", () => {
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
      if (id === DATASET_IDS.VEHICLE_RECALLS) {
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
              RECALL_ID: 11020,
              TOZAR_CD: 1,
              TOZAR_TEUR: "TOYOTA",
              DEGEM: "AVENSIS",
              SHNAT_RECALL: 2011,
              BUILD_BEGIN_A: "2000-01-02",
              BUILD_END_A: "2008-12-31",
              SUG_RECALL: "תקלה סידרתית בטיחותית",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncVehicleRecalls(mockDb, DATASET_IDS.VEHICLE_RECALLS, {
      forceFullSync: true,
    });

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.VEHICLE_RECALLS);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("11020");
    expect(written.manufacturerName).toBe("TOYOTA");

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.VEHICLE_RECALLS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.VEHICLE_RECALLS,
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
        id: "11020",
        data: () => ({ createdAt: initialCreatedAt }),
      },
    ]);

    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 1,
              RECALL_ID: 11020,
              TOZAR_CD: 1,
              TOZAR_TEUR: "TOYOTA",
              DEGEM: "AVENSIS",
              SHNAT_RECALL: 2011,
              BUILD_BEGIN_A: "2000-01-02",
              BUILD_END_A: "2008-12-31",
              SUG_RECALL: "תקלה סידרתית בטיחותית",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncVehicleRecalls(mockDb, DATASET_IDS.VEHICLE_RECALLS, {
      forceFullSync: true,
    });

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
  });

  it("should skip writing if the record already exists and is identical", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      _id: 1,
      RECALL_ID: 11020,
      TOZAR_CD: 1,
      TOZAR_TEUR: "TOYOTA",
      DEGEM: "AVENSIS",
      SHNAT_RECALL: 2011,
      BUILD_BEGIN_A: "2000-01-02",
      BUILD_END_A: "2008-12-31",
      SUG_RECALL: "תקלה סידרתית בטיחותית",
    };

    const parsed = parseRecallRecord(rawRecord)!;
    const existing = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: parsed.lastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "11020",
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

    const result = await scrapeAndSyncVehicleRecalls(mockDb, DATASET_IDS.VEHICLE_RECALLS, {
      forceFullSync: true,
    });

    expect(result.success).toBe(true);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });
});
