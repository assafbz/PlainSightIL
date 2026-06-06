import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parseCarImporterRecord,
  scrapeAndSyncCarImporters,
} from "../src/scrapers/car_importers_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Car Importers Record Parser", () => {
  it("should return null if _id is missing", () => {
    const record = {
      semel_yevuan: 1,
      shem_yevuan: 'קרסו מוטורס בע"מ',
    };
    expect(parseCarImporterRecord(record as any)).toBeNull();
  });

  it("should parse and normalize car importer records correctly", () => {
    const raw = {
      _id: 1,
      semel_yevuan: 1,
      shem_yevuan: 'קרסו מוטורס בע"מ',
      sug_degem: "P",
      tozeret_cd: 928,
      tozeret_nm: "רנו צרפת",
      degem_cd: 1000,
      degem_nm: "C0635P R TWINGO EP",
      shnat_yitzur: 1996,
      mehir: 54950,
      kinuy_mishari: "טווינגו 2.1 YSAE",
    };

    const parsed = parseCarImporterRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("1");
      expect(parsed._id).toBe(1);
      expect(parsed.importerCode).toBe(1);
      expect(parsed.importerName).toBe('קרסו מוטורס בע"מ');
      expect(parsed.modelType).toBe("P");
      expect(parsed.makerCode).toBe(928);
      expect(parsed.makerName).toBe("רנו צרפת");
      expect(parsed.modelCode).toBe(1000);
      expect(parsed.modelName).toBe("C0635P R TWINGO EP");
      expect(parsed.productionYear).toBe(1996);
      expect(parsed.price).toBe(54950);
      expect(parsed.commercialName).toBe("טווינגו 2.1 YSAE");
    }
  });

  it("should handle null optionals and empty strings correctly", () => {
    const raw = {
      _id: 1,
      semel_yevuan: null,
      shem_yevuan: null,
      sug_degem: null,
      tozeret_cd: null,
      tozeret_nm: null,
      degem_cd: null,
      degem_nm: null,
      shnat_yitzur: null,
      mehir: null,
      kinuy_mishari: null,
    };

    const parsed = parseCarImporterRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("1");
      expect(parsed.importerCode).toBeNull();
      expect(parsed.importerName).toBe("");
      expect(parsed.modelType).toBe("");
      expect(parsed.makerCode).toBeNull();
      expect(parsed.makerName).toBe("");
      expect(parsed.modelCode).toBeNull();
      expect(parsed.modelName).toBe("");
      expect(parsed.productionYear).toBeNull();
      expect(parsed.price).toBeNull();
      expect(parsed.commercialName).toBe("");
    }
  });
});

describe("Car Importers Ingest Sync Process", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockMetadataSet: any;
  let mockMetadataGet: any;
  let mockCountGet: any;
  let mockGetAll: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockMetadataSet = vi.fn().mockResolvedValue(true);
    mockMetadataGet = vi.fn().mockResolvedValue({
      exists: false,
      data: () => ({}),
    });

    mockDoc = vi.fn().mockImplementation((id) => {
      if (id === DATASET_IDS.CAR_IMPORTERS) {
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
              semel_yevuan: 1,
              shem_yevuan: 'קרסו מוטורס בע"מ',
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncCarImporters(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.CAR_IMPORTERS);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("1");
    expect(written.importerName).toBe('קרסו מוטורס בע"מ');

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.CAR_IMPORTERS);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.CAR_IMPORTERS,
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
              semel_yevuan: 1,
              shem_yevuan: 'קרסו מוטורס בע"מ',
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncCarImporters(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).toBeDefined();
    expect(written.updatedAt).toBeDefined();
  });
});
