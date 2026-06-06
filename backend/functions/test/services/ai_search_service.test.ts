import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// 1. Hoist mock functions
const {
  mockVerifyIdToken,
  mockVerifyAppCheckToken,
  mockDbGet,
  mockDbWhere,
  mockDbLimitGet,
  mockFirestoreInstance,
  mockGenerateContent
} = vi.hoisted(() => {
  const verifyAuth = vi.fn().mockResolvedValue({ uid: "mock-user-uid" });
  const verifyAppCheck = vi.fn().mockResolvedValue({ appId: "mock-app-id" });
  const dbGet = vi.fn().mockResolvedValue({
    exists: true,
    data: () => ({
      name: "vehicle_recalls",
      title: "קריאות לתיקון",
      isSupported: true
    })
  });
  const dbLimitGet = vi.fn().mockResolvedValue({
    docs: [
      {
        id: "11020",
        data: () => ({
          manufacturerName: "טויוטה",
          modelName: "אוונסיס",
          defectDescription: "שסתום צינור דלק"
        })
      }
    ]
  });
  const dbWhere = vi.fn().mockReturnValue({
    limit: vi.fn().mockReturnValue({
      get: dbLimitGet
    }),
    get: vi.fn().mockResolvedValue({
      docs: [
        {
          id: "2c33523f-87aa-44ec-a736-edbb0a82975e",
          data: () => ({
            name: "vehicle_recalls",
            title: "קריאות לתיקון",
            isSupported: true
          })
        }
      ]
    })
  });

  const instance = {
    collection: vi.fn().mockReturnValue({
      doc: vi.fn().mockReturnValue({
        get: dbGet
      }),
      where: dbWhere,
      limit: vi.fn().mockReturnValue({
        get: dbLimitGet
      })
    })
  };

  const genMock = vi.fn().mockResolvedValue({
    response: {
      text: () => "{}"
    }
  });

  return {
    mockVerifyIdToken: verifyAuth,
    mockVerifyAppCheckToken: verifyAppCheck,
    mockDbGet: dbGet,
    mockDbWhere: dbWhere,
    mockDbLimitGet: dbLimitGet,
    mockFirestoreInstance: instance,
    mockGenerateContent: genMock
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
      onRequest: triggerMock
    },
    runWith: vi.fn().mockReturnValue({
      https: {
        onRequest: triggerMock
      },
      pubsub: {
        schedule: vi.fn().mockReturnValue({
          onRun: triggerMock
        }),
        topic: vi.fn().mockReturnValue({
          onPublish: triggerMock
        })
      },
      auth: {
        user: vi.fn().mockReturnValue({
          onCreate: triggerMock
        })
      }
    })
  };
});

// 3. Mock @google/generative-ai
vi.mock("@google/generative-ai", () => {
  return {
    GoogleGenerativeAI: class {
      getGenerativeModel = vi.fn().mockReturnValue({
        generateContent: mockGenerateContent
      });
    }
  };
});

// 4. Mock firebase-admin
vi.mock("firebase-admin", () => ({
  initializeApp: vi.fn(),
  firestore: () => mockFirestoreInstance,
  auth: () => ({
    verifyIdToken: mockVerifyIdToken
  }),
  appCheck: () => ({
    verifyToken: mockVerifyAppCheckToken
  })
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
        "x-firebase-appcheck": "mock-appcheck-token"
      },
      body: {
        query: "Toyota recalls",
        lang: "he"
      }
    };

    res = {
      status: statusMock,
      set: setHeaderMock
    };
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
        expect.objectContaining({ error: "Method Not Allowed" })
      );
    });

    it("should enforce App Check validation when not in emulator mode", async () => {
      delete process.env.FUNCTIONS_EMULATOR;
      req.headers["x-firebase-appcheck"] = ""; // Empty App Check token
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({ message: "Missing App Check token." })
      );
    });

    it("should reject invalid ID tokens with 401", async () => {
      mockVerifyIdToken.mockRejectedValueOnce(new Error("Token expired"));
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({ error: "Unauthorized" })
      );
    });

    it("should reject query longer than 200 characters with 400", async () => {
      req.body.query = "a".repeat(201);
      await aiSemanticSearch(req, res);
      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({ error: "Bad Request" })
      );
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
          text: () => JSON.stringify({
            queries: [
              {
                collectionId: DATASET_IDS.VEHICLE_RECALLS,
                field: "manufacturerName",
                operator: "==",
                value: "טויוטה"
              }
            ],
            isRelatedToDatasets: true
          })
        }
      });

      // 2. Stage 2 Mock Output (Context synthesis)
      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () => JSON.stringify({
            answer: "נמצאה קריאה לטויוטה [cit-01]",
            citations: [
              {
                id: "cit-01",
                datasetId: DATASET_IDS.VEHICLE_RECALLS,
                docId: "11020",
                title: "טויוטה אוונסיס 2011"
              }
            ]
          })
        }
      });

      const result = await processAiSearch(mockFirestoreInstance as any, "toyota recalls", "he");
      expect(result.answer).toContain("[cit-01]");
      expect(result.citations).toHaveLength(1);
      expect(result.citations[0].docId).toBe("11020");
    });
  });
});
