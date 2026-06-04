import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import {
  parseAtmRecord,
  parseHebrewBoolean,
  isValidIsraelCoordinates,
  scrapeAndSyncBankAtms,
} from "../src/scrapers/21fde05f-62e3-401b-81cf-5c385862026d";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

// Mock GeoPoint from firebase-admin/firestore
vi.mock("firebase-admin/firestore", () => ({
  GeoPoint: class GeoPoint {
    constructor(
      public latitude: number,
      public longitude: number,
    ) {}
  },
}));

// Mock geohash utility
vi.mock("../src/utils/geohash", () => ({
  encodeGeohash: vi.fn().mockReturnValue("sv8wrb2ky"),
}));

describe("Bank ATMs Hebrew Boolean Parsing", () => {
  it("should parse כן as true", () => {
    expect(parseHebrewBoolean("כן")).toBe(true);
  });

  it("should parse לא as false", () => {
    expect(parseHebrewBoolean("לא")).toBe(false);
  });

  it("should handle null and undefined as false", () => {
    expect(parseHebrewBoolean(null)).toBe(false);
    expect(parseHebrewBoolean(undefined)).toBe(false);
  });

  it("should handle empty string as false", () => {
    expect(parseHebrewBoolean("")).toBe(false);
  });

  it("should handle whitespace-padded כן correctly", () => {
    expect(parseHebrewBoolean(" כן ")).toBe(true);
  });
});

describe("Bank ATMs Coordinate Validation", () => {
  it("should accept valid Israel coordinates", () => {
    expect(isValidIsraelCoordinates(31.0, 34.8)).toBe(true);
    expect(isValidIsraelCoordinates(29.555192, 34.952591)).toBe(true);
    expect(isValidIsraelCoordinates(33.3, 35.8)).toBe(true);
  });

  it("should reject coordinates outside Israel bounds", () => {
    expect(isValidIsraelCoordinates(28.0, 34.5)).toBe(false); // Too far south
    expect(isValidIsraelCoordinates(34.0, 34.5)).toBe(false); // Too far north
    expect(isValidIsraelCoordinates(31.0, 33.0)).toBe(false); // Too far west
    expect(isValidIsraelCoordinates(31.0, 36.5)).toBe(false); // Too far east
  });
});

describe("Bank ATMs Record Parser", () => {
  it("should return null if _id is missing", () => {
    const record = {
      Bank_Code: 14,
      Bank_Name: 'בנק אוצר החייל בע"מ',
      X_Coordinate: "29.555192",
      Y_Coordinate: 34.952591,
    };
    expect(parseAtmRecord(record as any)).toBeNull();
  });

  it("should return null if Bank_Code is missing", () => {
    const record = {
      _id: 1,
      Bank_Name: 'בנק אוצר החייל בע"מ',
      X_Coordinate: "29.555192",
      Y_Coordinate: 34.952591,
    };
    expect(parseAtmRecord(record as any)).toBeNull();
  });

  it("should return null if coordinates are missing", () => {
    const record = {
      _id: 1,
      Bank_Code: 14,
      Bank_Name: 'בנק אוצר החייל בע"מ',
    };
    expect(parseAtmRecord(record as any)).toBeNull();
  });

  it("should return null if coordinates are outside Israel bounds", () => {
    const record = {
      _id: 1,
      Bank_Code: 14,
      Bank_Name: 'בנק אוצר החייל בע"מ',
      X_Coordinate: "10.0",
      Y_Coordinate: 20.0,
    };
    expect(parseAtmRecord(record as any)).toBeNull();
  });

  it("should parse and normalize a valid ATM record correctly", () => {
    const raw = {
      _id: 1,
      Bank_Code: 14,
      Bank_Name: 'בנק אוצר החייל בע"מ',
      Branch_Code: 377,
      Sub_Branch_Code: 0,
      Atm_Num: 3777,
      ATM_Address: "שד' התמרים 11",
      ATM_Address_Extra: "שדרות התמרים 11",
      City: "אילת",
      Commission: "לא",
      Casd_Withdrawal: "כן",
      Cash_Deposit: "כן",
      Cheque_Deposit: "כן",
      Envelope_Deposit: "כן",
      Forex_Transaction: "כן",
      Additional_Transactions: "כן",
      ATM_Location: "בתוך הסניף",
      Handicap_Access: "כן",
      X_Coordinate: "29.555192",
      Y_Coordinate: 34.952591,
    };

    const parsed = parseAtmRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("1");
      expect(parsed._id).toBe(1);
      expect(parsed.bankCode).toBe(14);
      expect(parsed.bankName.he).toBe('בנק אוצר החייל בע"מ');
      expect(parsed.bankName.en).toBe("Bank Otsar HaHayal");
      expect(parsed.branchCode).toBe(377);
      expect(parsed.subBranchCode).toBe(0);
      expect(parsed.atmNumber).toBe(3777);
      expect(parsed.address).toBe("שד' התמרים 11");
      expect(parsed.addressExtra).toBe("שדרות התמרים 11");
      expect(parsed.city).toBe("אילת");
      expect(parsed.commission).toBe(false);
      expect(parsed.cashWithdrawal).toBe(true);
      expect(parsed.cashDeposit).toBe(true);
      expect(parsed.chequeDeposit).toBe(true);
      expect(parsed.envelopeDeposit).toBe(true);
      expect(parsed.forexTransaction).toBe(true);
      expect(parsed.additionalTransactions).toBe(true);
      expect(parsed.atmLocation.he).toBe("בתוך הסניף");
      expect(parsed.atmLocation.en).toBe("Inside Branch");
      expect(parsed.handicapAccess).toBe(true);
      expect(parsed.coordinates.latitude).toBe(29.555192);
      expect(parsed.coordinates.longitude).toBe(34.952591);
      expect(parsed.geohash).toBe("sv8wrb2ky");
    }
  });

  it("should handle missing optional fields gracefully", () => {
    const raw = {
      _id: 5,
      Bank_Code: 12,
      X_Coordinate: 31.5,
      Y_Coordinate: 34.8,
    };

    const parsed = parseAtmRecord(raw);
    expect(parsed).not.toBeNull();
    if (parsed) {
      expect(parsed.id).toBe("5");
      expect(parsed.bankName.he).toBe("");
      expect(parsed.address).toBe("");
      expect(parsed.city).toBe("");
      expect(parsed.commission).toBe(false);
      expect(parsed.cashWithdrawal).toBe(false);
    }
  });

  it("should return null if coordinates are not numbers", () => {
    const record = {
      _id: 1,
      Bank_Code: 14,
      Bank_Name: 'בנק אוצר החייל בע"מ',
      X_Coordinate: "not a number",
      Y_Coordinate: 34.952591,
    };
    expect(parseAtmRecord(record as any)).toBeNull();
  });
});

describe("Bank ATMs Ingest Sync Process", () => {
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
      if (id === "21fde05f-62e3-401b-81cf-5c385862026d") {
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
              Bank_Code: 14,
              Bank_Name: 'בנק אוצר החייל בע"מ',
              Branch_Code: 377,
              Sub_Branch_Code: 0,
              Atm_Num: 3777,
              ATM_Address: "שד' התמרים 11",
              City: "אילת",
              Commission: "לא",
              Casd_Withdrawal: "כן",
              Cash_Deposit: "כן",
              Cheque_Deposit: "כן",
              Envelope_Deposit: "כן",
              Forex_Transaction: "כן",
              Additional_Transactions: "כן",
              ATM_Location: "בתוך הסניף",
              Handicap_Access: "כן",
              X_Coordinate: "29.555192",
              Y_Coordinate: 34.952591,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    const result = await scrapeAndSyncBankAtms(mockDb);

    expect(result.success).toBe(true);
    expect(result.count).toBe(1);

    expect(mockCollection).toHaveBeenCalledWith("21fde05f-62e3-401b-81cf-5c385862026d");
    expect(mockBatch.set).toHaveBeenCalledTimes(1);

    const written = mockBatch.set.mock.calls[0][1];
    expect(written.id).toBe("1");
    expect(written.bankCode).toBe(14);
    expect(written.bankName.en).toBe("Bank Otsar HaHayal");
    expect(written.cashWithdrawal).toBe(true);
    expect(written.commission).toBe(false);

    expect(mockDoc).toHaveBeenCalledWith("21fde05f-62e3-401b-81cf-5c385862026d");
    expect(mockMetadataSet).toHaveBeenCalledWith(
      expect.objectContaining({
        activeCollection: "21fde05f-62e3-401b-81cf-5c385862026d",
        status: "idle",
        recordCount: 1,
      }),
      { merge: true },
    );
  });

  it("should handle existing records and skip writing if identical", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 1,
              Bank_Code: 14,
              Bank_Name: 'בנק אוצר החייל בע"מ',
              X_Coordinate: 31.0,
              Y_Coordinate: 34.8,
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    mockGetAll.mockImplementationOnce((...refs) => {
      return Promise.resolve(
        refs.map((ref) => ({
          exists: true,
          id: ref.id,
          data: () => ({
            id: "1",
            _id: 1,
            bankCode: 14,
            bankName: { he: 'בנק אוצר החייל בע"מ', en: "Bank Otsar HaHayal" },
            branchCode: 0,
            subBranchCode: 0,
            atmNumber: 0,
            address: "",
            addressExtra: "",
            city: "",
            commission: false,
            cashWithdrawal: false,
            cashDeposit: false,
            chequeDeposit: false,
            envelopeDeposit: false,
            forexTransaction: false,
            additionalTransactions: false,
            atmLocation: { he: "", en: "" },
            handicapAccess: false,
            coordinates: { latitude: 31.0, longitude: 34.8 },
            geohash: "sv8wrb2ky",
            lastUpdated: "old-date",
            createdAt: "old-created-date",
          }),
        })),
      );
    });

    const result = await scrapeAndSyncBankAtms(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(1);
    expect(mockBatch.set).not.toHaveBeenCalled();
  });

  it("should handle existing records and write if they are different", async () => {
    const apiResponse = {
      data: {
        result: {
          records: [
            {
              _id: 1,
              Bank_Code: 14,
              Bank_Name: 'בנק אוצר החייל בע"מ',
              X_Coordinate: 31.0,
              Y_Coordinate: 34.8,
              City: "אילת",
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(apiResponse);
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { result: { records: [] } } });

    mockGetAll.mockImplementationOnce((...refs) => {
      return Promise.resolve(
        refs.map((ref) => ({
          exists: true,
          id: ref.id,
          data: () => ({
            id: "1",
            _id: 1,
            bankCode: 14,
            bankName: { he: 'בנק אוצר החייל בע"מ', en: "Bank Otsar HaHayal" },
            branchCode: 0,
            subBranchCode: 0,
            atmNumber: 0,
            address: "",
            addressExtra: "",
            city: "תל אביב",
            commission: false,
            cashWithdrawal: false,
            cashDeposit: false,
            chequeDeposit: false,
            envelopeDeposit: false,
            forexTransaction: false,
            additionalTransactions: false,
            atmLocation: { he: "", en: "" },
            handicapAccess: false,
            coordinates: { latitude: 31.0, longitude: 34.8 },
            geohash: "sv8wrb2ky",
            lastUpdated: "old-date",
            createdAt: "old-created-date",
          }),
        })),
      );
    });

    const result = await scrapeAndSyncBankAtms(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(1);
    expect(mockBatch.set).toHaveBeenCalledTimes(1);
  });

  it("should handle sync failure and update metadata status to error", async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error("Network Error"));

    await expect(scrapeAndSyncBankAtms(mockDb)).rejects.toThrow("Network Error");
    expect(mockDoc).toHaveBeenCalledWith("21fde05f-62e3-401b-81cf-5c385862026d");
    expect(mockMetadataSet).toHaveBeenCalledWith({ status: "error" }, { merge: true });
  });
});
