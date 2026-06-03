import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parseDDMMYYYY,
  parseDoctorRecord,
  scrapeAndSyncDoctorsLicenses,
} from "../src/scrapers/doctors_licenses_scraper";
import { DATASET_IDS } from "../src/utils/constants";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Doctors Licenses Date Normalization", () => {
  it("should restore leading zero and convert DDMMYYYY values to ISO dates", () => {
    // 7 digits (missing leading zero)
    expect(parseDDMMYYYY(2121993)).toBe("1993-12-02T00:00:00.000Z");
    expect(parseDDMMYYYY("2121993")).toBe("1993-12-02T00:00:00.000Z");

    // 8 digits
    expect(parseDDMMYYYY(20081974)).toBe("1974-08-20T00:00:00.000Z");
    expect(parseDDMMYYYY("20081974")).toBe("1974-08-20T00:00:00.000Z");
  });

  it("should handle empty or invalid formats gracefully", () => {
    expect(parseDDMMYYYY(null)).toBe("");
    expect(parseDDMMYYYY(undefined)).toBe("");
    expect(parseDDMMYYYY("")).toBe("");
    expect(parseDDMMYYYY(0)).toBe("");
    expect(parseDDMMYYYY("invalid")).toBe("");
    expect(parseDDMMYYYY(123)).toBe("");
    expect(parseDDMMYYYY(99991231)).toBe(""); // Invalid month/day
  });
});

describe("Doctors Licenses Record Parser", () => {
  it("should return null if license number or _id is missing", () => {
    const record = {
      "שם פרטי": "אברהם",
      "שם משפחה": "שטיינברג",
    };
    expect(parseDoctorRecord(record as any)).toBeNull();
  });

  it("should parse and normalize doctors license records correctly", () => {
    const raw = {
      _id: 2,
      "שם פרטי": "אברהם",
      "שם משפחה": "שטיינברג",
      "מספר רישיון רופא": 11116,
      "תאריך רישום רישיון": 20081974,
      "מספר תעודת התמחות": 7656,
      "תאריך רישום התמחות": 21061983,
      "שם התמחות": "רפואת ילדים",
    };

    const parsed = parseDoctorRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("2");
      expect(parsed._id).toBe(2);
      expect(parsed.firstName).toBe("אברהם");
      expect(parsed.lastName).toBe("שטיינברג");
      expect(parsed.licenseNumber).toBe(11116);
      expect(parsed.licenseRegistrationDate).toBe("1974-08-20T00:00:00.000Z");
      expect(parsed.specialtyCertificateNumber).toBe(7656);
      expect(parsed.specialtyRegistrationDate).toBe("1983-06-21T00:00:00.000Z");
      expect(parsed.specialtyName).toBe("רפואת ילדים");
    }
  });

  it("should handle null optionals correctly", () => {
    const raw = {
      _id: 1,
      "שם פרטי": "מריו ה",
      "שם משפחה": "קורוב",
      "מספר רישיון רופא": 4267,
      "תאריך רישום רישיון": 28071969,
      "מספר תעודת התמחות": null,
      "תאריך רישום התמחות": null,
      "שם התמחות": null,
    };

    const parsed = parseDoctorRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("1");
      expect(parsed.specialtyCertificateNumber).toBeNull();
      expect(parsed.specialtyRegistrationDate).toBeNull();
      expect(parsed.specialtyName).toBeNull();
    }
  });
});

describe("Doctors Licenses Ingest Sync Process", () => {
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
      if (id === DATASET_IDS.DOCTORS_LICENSES) {
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
              "שם פרטי": "מריו ה",
              "שם משפחה": "קורוב",
              "מספר רישיון רופא": 4267,
              "תאריך רישום רישיון": 28071969,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncDoctorsLicenses(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith(DATASET_IDS.DOCTORS_LICENSES);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("1");
    expect(written.firstName).toBe("מריו ה");

    expect(mockDoc).toHaveBeenCalledWith(DATASET_IDS.DOCTORS_LICENSES);
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: DATASET_IDS.DOCTORS_LICENSES,
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
              "שם פרטי": "מריו ה",
              "שם משפחה": "קורוב",
              "מספר רישיון רופא": 4267,
              "תאריך רישום רישיון": 28071969,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncDoctorsLicenses(mockDb);

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
      _id: 1,
      "שם פרטי": "מריו ה",
      "שם משפחה": "קורוב",
      "מספר רישיון רופא": 4267,
      "תאריך רישום רישיון": 28071969,
    };

    const parsed = parseDoctorRecord(rawRecord)!;
    const existing = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: parsed.lastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "1",
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

    const result = await scrapeAndSyncDoctorsLicenses(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should write and update lastUpdated if the record exists but has different data", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      _id: 1,
      "שם פרטי": "מריו ה",
      "שם משפחה": "קורוב",
      "מספר רישיון רופא": 4267,
      "תאריך רישום רישיון": 28071969,
    };

    const parsed = parseDoctorRecord(rawRecord)!;
    const existing = {
      ...parsed,
      lastName: "אחר",
      createdAt: initialCreatedAt,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "1",
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

    const result = await scrapeAndSyncDoctorsLicenses(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.lastName).toBe("קורוב");
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).not.toBe(initialLastUpdated);
    expect(written.updatedAt).toBeDefined();
  });

  it("should write and update updatedAt if ONLY lastUpdated has changed", async () => {
    const initialCreatedAt = "2026-05-01T12:00:00.000Z";
    const initialLastUpdated = "2026-05-01T12:00:00.000Z";

    const rawRecord = {
      _id: 1,
      "שם פרטי": "מריו ה",
      "שם משפחה": "קורוב",
      "מספר רישיון רופא": 4267,
      "תאריך רישום רישיון": 28071969,
    };

    const parsed = parseDoctorRecord(rawRecord)!;
    const existing = {
      ...parsed,
      createdAt: initialCreatedAt,
      lastUpdated: initialLastUpdated,
    };

    mockGetAll.mockResolvedValueOnce([
      {
        exists: true,
        id: "1",
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

    const result = await scrapeAndSyncDoctorsLicenses(mockDb);

    expect(result.success).toBe(true);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
    const written = mockBatch.set.mock.calls[0][1];
    expect(written.createdAt).toBe(initialCreatedAt);
    expect(written.lastUpdated).toBe(parsed.lastUpdated);
    expect(written.updatedAt).toBeDefined();
  });
});
