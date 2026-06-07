import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// 1. Hoist mock functions
const {
  mockVerifyIdToken,
  mockVerifyAppCheckToken,
  mockDbGet,
  mockDbWhere,
  mockDbLimitGet,
  mockFirestoreInstance,
  mockGenerateContent,
} = vi.hoisted(() => {
  const verifyAuth = vi.fn().mockResolvedValue({ uid: "mock-user-uid" });
  const verifyAppCheck = vi.fn().mockResolvedValue({ appId: "mock-app-id" });
  const dbGet = vi.fn().mockResolvedValue({
    exists: true,
    data: () => ({
      name: "vehicle_recalls",
      title: "קריאות לתיקון",
      isSupported: true,
    }),
  });
  const dbLimitGet = vi.fn().mockResolvedValue({
    docs: [
      {
        id: "11020",
        data: () => ({
          manufacturerName: "טויוטה",
          modelName: "אוונסיס",
          defectDescription: "שסתום צינור דלק",
        }),
      },
    ],
  });
  const dbWhere = vi.fn().mockReturnValue({
    limit: vi.fn().mockReturnValue({
      get: dbLimitGet,
    }),
    get: vi.fn().mockResolvedValue({
      docs: [
        {
          id: "2c33523f-87aa-44ec-a736-edbb0a82975e",
          data: () => ({
            name: "vehicle_recalls",
            title: "קריאות לתיקון",
            isSupported: true,
          }),
        },
      ],
    }),
  });

  const instance = {
    collection: vi.fn().mockReturnValue({
      doc: vi.fn().mockReturnValue({
        get: dbGet,
      }),
      where: dbWhere,
      limit: vi.fn().mockReturnValue({
        get: dbLimitGet,
      }),
    }),
  };

  const genMock = vi.fn().mockResolvedValue({
    response: {
      text: () => "{}",
    },
  });

  return {
    mockVerifyIdToken: verifyAuth,
    mockVerifyAppCheckToken: verifyAppCheck,
    mockDbGet: dbGet,
    mockDbWhere: dbWhere,
    mockDbLimitGet: dbLimitGet,
    mockFirestoreInstance: instance,
    mockGenerateContent: genMock,
  };
});

// 2. Mock firebase-functions partially
vi.mock("firebase-functions/v1", async (importOriginal) => {
  const actual = await importOriginal<typeof import("firebase-functions/v1")>();
  const triggerMock = vi.fn().mockImplementation((handler) => handler);
  return {
    ...actual,
    https: {
      ...actual.https,
      onRequest: triggerMock,
    },
    runWith: vi.fn().mockReturnValue({
      https: {
        onRequest: triggerMock,
      },
      firestore: {
        document: vi.fn().mockReturnValue({
          onCreate: triggerMock,
        }),
      },
      pubsub: {
        schedule: vi.fn().mockReturnValue({
          onRun: triggerMock,
        }),
        topic: vi.fn().mockReturnValue({
          onPublish: triggerMock,
        }),
      },
      auth: {
        user: vi.fn().mockReturnValue({
          onCreate: triggerMock,
        }),
      },
    }),
  };
});

// 3. Mock @google/generative-ai
vi.mock("@google/generative-ai", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@google/generative-ai")>();
  return {
    ...actual,
    GoogleGenerativeAI: class {
      getGenerativeModel = vi.fn().mockReturnValue({
        generateContent: mockGenerateContent,
      });
    },
  };
});

// 4. Mock firebase-admin
vi.mock("firebase-admin", () => ({
  initializeApp: vi.fn(),
  firestore: () => mockFirestoreInstance,
  auth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
  appCheck: () => ({
    verifyToken: mockVerifyAppCheckToken,
  }),
}));

import { aiSemanticSearch } from "../../src/index";
import { processAiSearch } from "../../src/services/ai_search_service";
import { DATASET_IDS } from "../../src/utils/constants";

describe("AI Semantic Search Unit Tests", () => {
  let req: any;
  let res: any;
  let statusMock: any;
  let jsonMock: any;
  let setHeaderMock: any;

  beforeEach(() => {
    vi.clearAllMocks();
    process.env.FUNCTIONS_EMULATOR = "true";

    jsonMock = vi.fn();
    statusMock = vi.fn().mockReturnValue({ json: jsonMock });
    setHeaderMock = vi.fn();

    req = {
      method: "POST",
      headers: {
        authorization: "Bearer mock-auth-token",
        "x-firebase-appcheck": "mock-appcheck-token",
      },
      body: {
        query: "Toyota recalls",
        lang: "he",
      },
    };

    res = {
      status: statusMock,
      set: setHeaderMock,
    };

    mockFirestoreInstance.collection = vi.fn().mockReturnValue({
      doc: vi.fn().mockReturnValue({ get: mockDbGet }),
      where: mockDbWhere,
      limit: vi.fn().mockReturnValue({ get: mockDbLimitGet }),
    });
  });

  afterEach(() => {
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.GEMINI_API_KEY;
  });

  describe("Cloud Function Request Handling & Safety", () => {
    it("should reject non-POST request methods with 405", async () => {
      req.method = "GET";
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(405);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({ error: "Method Not Allowed" }),
      );
    });

    it("should enforce App Check validation when not in emulator mode", async () => {
      delete process.env.FUNCTIONS_EMULATOR;
      req.headers["x-firebase-appcheck"] = ""; // Empty App Check token
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({ message: "Missing App Check token." }),
      );
    });

    it("should reject invalid ID tokens with 401", async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new Error("Token expired"));
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({ error: "Unauthorized" }));
    });

    it("should reject query longer than 200 characters with 400", async () => {
      req.body.query = "a".repeat(201);
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({ error: "Bad Request" }));
    });
  });

  describe("processAiSearch Core Service", () => {
    it("should fallback to mock response when GEMINI_API_KEY is not defined", async () => {
      delete process.env.GEMINI_API_KEY;
      const result = await processAiSearch(mockFirestoreInstance as any, "toyota recalls", "he");
      expect(result.answer).toContain("טויוטה");
      expect(result.citations).toHaveLength(1);
      expect(result.citations[0].datasetId).toBe(DATASET_IDS.VEHICLE_RECALLS);
    });

    it("should return correct synthesis using Gemini model when key is defined", async () => {
      process.env.GEMINI_API_KEY = "test-key";

      // 1. Stage 1 Mock Output (Query instructions)
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              queries: [
                {
                  collectionId: DATASET_IDS.VEHICLE_RECALLS,
                  field: "manufacturerName",
                  operator: "==",
                  value: "טויוטה",
                },
              ],
              isRelatedToDatasets: true,
            }),
        },
      });

      // 2. Stage 2 Mock Output (Context synthesis)
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              answer: "נמצאה קריאה לטויוטה [cit-01]",
              citations: [
                {
                  id: "cit-01",
                  datasetId: DATASET_IDS.VEHICLE_RECALLS,
                  docId: "11020",
                  title: "טויוטה אוונסיס 2011",
                },
              ],
            }),
        },
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "toyota recalls", "he");
      expect(result.answer).toContain("[cit-01]");
      expect(result.citations).toHaveLength(1);
      expect(result.citations[0].docId).toBe("11020");
    });

    it("should return Turkey mock response when query contains turkey", async () => {
      delete process.env.GEMINI_API_KEY;
      const result = await processAiSearch(
        mockFirestoreInstance as any,
        "turkey travel warnings",
        "he",
      );
      expect(result.answer).toContain("טורקיה");
    });

    it("should return Cellular mock response when query contains antenna", async () => {
      delete process.env.GEMINI_API_KEY;
      const result = await processAiSearch(mockFirestoreInstance as any, "cellular antennas", "en");
      expect(result.answer).toContain("cellular");
    });

    it("should return fallback mock response when query is unrelated", async () => {
      delete process.env.GEMINI_API_KEY;
      const result = await processAiSearch(mockFirestoreInstance as any, "unrelated query", "he");
      expect(result.answer).toContain("לא נמצאו תוצאות");
    });

    it("should return warning response when no supported datasets are found", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockDbWhere.mockReturnValueOnce({
        get: vi.fn().mockResolvedValueOnce({ docs: [] }),
      });
      const result = await processAiSearch(mockFirestoreInstance as any, "toyota", "he");
      expect(result.answer).toContain("אין כרגע מאגרי מידע נתמכים");
    });

    it("should handle dataset without queryable fields and numeric values", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockDbWhere.mockReturnValueOnce({
        get: vi.fn().mockResolvedValueOnce({
          docs: [
            {
              id: "unsupported-id",
              data: () => ({ name: "unsupported", title: "Unqueryable", isSupported: true }),
            },
            {
              id: DATASET_IDS.VEHICLE_RECALLS,
              data: () => ({ name: "vehicle_recalls", title: "Recalls", isSupported: true }),
            },
          ],
        }),
      });

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              queries: [
                {
                  collectionId: DATASET_IDS.VEHICLE_RECALLS,
                  field: "recallYear",
                  operator: "==",
                  value: "2011",
                },
              ],
              isRelatedToDatasets: true,
            }),
        },
      });

      mockDbLimitGet.mockResolvedValueOnce({
        docs: [
          {
            id: "doc1",
            data: () => ({ recallYear: 2011, manufacturerName: "Toyota" }),
          },
        ],
      });

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              answer: "Found recall in 2011 [cit-01]",
              citations: [
                {
                  id: "cit-01",
                  datasetId: DATASET_IDS.VEHICLE_RECALLS,
                  docId: "doc1",
                  title: "Toyota 2011",
                },
              ],
            }),
        },
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "toyota 2011", "en");
      expect(result.answer).toBe("Found recall in 2011 [cit-01]");
    });

    it("should fallback to mock response when Stage 1 parse fails", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () => "invalid json",
        },
      });
      const result = await processAiSearch(mockFirestoreInstance as any, "toyota", "he");
      expect(result.answer).toContain("נמצאו קריאות פעילות");
    });

    it("should return unsupported search answer when Stage 1 determines query is unrelated", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () => JSON.stringify({ queries: [], isRelatedToDatasets: false }),
        },
      });
      const result = await processAiSearch(
        mockFirestoreInstance as any,
        "what is capital of France",
        "he",
      );
      expect(result.answer).toContain("חיפוש זה אינו נתמך");
    });

    it("should bypass unsupported collection, malformed field, handle query error, and return no records answer", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              queries: [
                {
                  collectionId: "unsupported-collection-id",
                  field: "someField",
                  operator: "==",
                  value: "test",
                },
                {
                  collectionId: DATASET_IDS.VEHICLE_RECALLS,
                  field: "field; injection",
                  operator: "==",
                  value: "test",
                },
                {
                  collectionId: DATASET_IDS.VEHICLE_RECALLS,
                  field: "manufacturerName",
                  operator: "==",
                  value: "error-trigger",
                },
              ],
              isRelatedToDatasets: true,
            }),
        },
      });

      const dbLimitGetWithError = vi
        .fn()
        .mockRejectedValueOnce(new Error("Firestore connection lost"));
      mockFirestoreInstance.collection = vi.fn().mockImplementation((name) => {
        if (name === "datasets_metadata") {
          return {
            where: vi.fn().mockReturnValue({
              get: vi.fn().mockResolvedValue({
                docs: [
                  {
                    id: DATASET_IDS.VEHICLE_RECALLS,
                    data: () => ({ name: "vehicle_recalls", title: "Recalls", isSupported: true }),
                  },
                ],
              }),
            }),
          };
        }
        if (name === DATASET_IDS.VEHICLE_RECALLS) {
          return {
            where: vi.fn().mockReturnValue({
              limit: vi.fn().mockReturnValue({
                get: dbLimitGetWithError,
              }),
            }),
          };
        }
        return {
          where: vi.fn().mockReturnValue({
            limit: vi.fn().mockReturnValue({
              get: vi.fn().mockResolvedValue({ docs: [] }),
            }),
          }),
        };
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "query", "he");
      expect(result.answer).toContain("לא נמצאו רשומות רלוונטיות");

      mockFirestoreInstance.collection = vi.fn().mockReturnValue({
        doc: vi.fn().mockReturnValue({ get: mockDbGet }),
        where: mockDbWhere,
        limit: vi.fn().mockReturnValue({ get: mockDbLimitGet }),
      });
    });

    it("should synthesize correct titles for travel warnings and other datasets", async () => {
      process.env.GEMINI_API_KEY = "test-key";
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              queries: [
                {
                  collectionId: DATASET_IDS.TRAVEL_WARNINGS,
                  field: "country",
                  operator: "==",
                  value: "טורקיה",
                },
                {
                  collectionId: "companies",
                  field: "companyName",
                  operator: "==",
                  value: "חברת הבדיקה",
                },
                {
                  collectionId: "generic",
                  field: "titleHebrew",
                  operator: "==",
                  value: "כותרת גנרית",
                },
              ],
              isRelatedToDatasets: true,
            }),
        },
      });

      mockFirestoreInstance.collection = vi.fn().mockImplementation((name) => {
        if (name === "datasets_metadata") {
          return {
            where: vi.fn().mockReturnValue({
              get: vi.fn().mockResolvedValue({
                docs: [
                  {
                    id: DATASET_IDS.TRAVEL_WARNINGS,
                    data: () => ({ name: "travel_warnings", title: "Warnings", isSupported: true }),
                  },
                  {
                    id: "companies",
                    data: () => ({ name: "companies", title: "Companies", isSupported: true }),
                  },
                  {
                    id: "generic",
                    data: () => ({ name: "generic", title: "Generic", isSupported: true }),
                  },
                ],
              }),
            }),
          };
        }
        return {
          where: vi.fn().mockReturnValue({
            limit: vi.fn().mockReturnValue({
              get: vi.fn().mockImplementation(() => {
                if (name === DATASET_IDS.TRAVEL_WARNINGS) {
                  return Promise.resolve({
                    docs: [
                      {
                        id: "tw1",
                        data: () => ({ country: "טורקיה" }),
                      },
                    ],
                  });
                }
                if (name === "companies") {
                  return Promise.resolve({
                    docs: [
                      {
                        id: "co1",
                        data: () => ({ companyName: "חברת הבדיקה" }),
                      },
                    ],
                  });
                }
                if (name === "generic") {
                  return Promise.resolve({
                    docs: [
                      {
                        id: "gen1",
                        data: () => ({ titleHebrew: "כותרת גנרית" }),
                      },
                    ],
                  });
                }
                return Promise.resolve({ docs: [] });
              }),
            }),
          }),
        };
      });

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              answer: "נמצאה אזהרת מסע [cit-01] וחברה [cit-02] וגנרי [cit-03]",
              citations: [
                {
                  id: "cit-01",
                  datasetId: DATASET_IDS.TRAVEL_WARNINGS,
                  docId: "tw1",
                  title: "טורקיה",
                },
                { id: "cit-02", datasetId: "companies", docId: "co1", title: "חברה" },
                { id: "cit-03", datasetId: "generic", docId: "gen1", title: "גנרי" },
              ],
            }),
        },
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "turkey warning", "he");
      expect(result.answer).toContain("[cit-01]");

      mockFirestoreInstance.collection = vi.fn().mockReturnValue({
        doc: vi.fn().mockReturnValue({ get: mockDbGet }),
        where: mockDbWhere,
        limit: vi.fn().mockReturnValue({ get: mockDbLimitGet }),
      });
    });

    it("should fallback to mock response when Stage 2 parse fails", async () => {
      process.env.GEMINI_API_KEY = "test-key";

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              queries: [
                {
                  collectionId: DATASET_IDS.VEHICLE_RECALLS,
                  field: "manufacturerName",
                  operator: "==",
                  value: "טויוטה",
                },
              ],
              isRelatedToDatasets: true,
            }),
        },
      });

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () => "invalid json stage 2",
        },
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "toyota", "he");
      expect(result.answer).toContain("נמצאו קריאות פעילות");
    });
  });
});
