import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// 1. Hoist mock functions
const { mockVerifyIdToken, mockDbGet, mockDbSet, mockFirestoreInstance, mockGenerateContent } =
  vi.hoisted(() => {
    const verifyAuth = vi.fn().mockResolvedValue({ uid: "mock-admin-uid" });
    const dbGet = vi.fn().mockResolvedValue({
      exists: true,
      data: () => ({
        title: "תקציב המדינה",
        publisher: "משרד האוצר",
        notes: "תקציב המדינה לשנים האחרונות",
        tags: ["תקציב", "כספים"],
      }),
    });
    const dbSet = vi.fn().mockResolvedValue(true);
    const instance = {
      collection: vi.fn().mockReturnValue({
        doc: vi.fn().mockReturnValue({
          get: dbGet,
          set: dbSet,
        }),
      }),
    };
    const genMock = vi.fn().mockResolvedValue({
      response: {
        text: () =>
          JSON.stringify({
            importance: "High",
            importanceReasoning: "מאגר חשוב מאוד",
            paymentWillingness: "High",
            aiScore: 95,
          }),
      },
    });

    return {
      mockVerifyIdToken: verifyAuth,
      mockDbGet: dbGet,
      mockDbSet: dbSet,
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
    firestore: {
      document: vi.fn().mockReturnValue({
        onCreate: triggerMock,
      }),
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
  firestore: Object.assign(() => mockFirestoreInstance, {
    FieldValue: {
      serverTimestamp: () => "mock-timestamp",
    },
  }),
  auth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

import { getMockRoadmapReview, scoreDatasetWithAi } from "../../src/services/ai_roadmap_service";
import { onDatasetRequestCreate, manualAnalyzeDataset } from "../../src/index";

describe("AI Roadmap Service Unit Tests", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.FUNCTIONS_EMULATOR = "true";

    mockFirestoreInstance.collection = vi.fn().mockReturnValue({
      doc: vi.fn().mockReturnValue({
        get: mockDbGet,
        set: mockDbSet,
      }),
    });
  });

  afterEach(() => {
    delete process.env.FUNCTIONS_EMULATOR;
    delete process.env.GEMINI_API_KEY;
  });

  describe("getMockRoadmapReview logic", () => {
    it("should return high score and priority reasoning for budget/health datasets", () => {
      const review = getMockRoadmapReview("תקציב המדינה");
      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(85);
      expect(review.importanceReasoning).toContain("תקציב");
    });

    it("should return high score and custom reasoning for municipality/transport datasets", () => {
      const review = getMockRoadmapReview("כביש ארנונה ותחבורה");
      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(75);
    });

    it("should return high score and health-focused reasoning for drug/health-basket datasets", () => {
      const review = getMockRoadmapReview("יבוא תרופות");
      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(90);
    });

    it("should return low score and reasoning for cultural/sports datasets", () => {
      const review = getMockRoadmapReview("מוזיאון תל אביב");
      expect(review.importance).toBe("Low");
      expect(review.aiScore).toBe(40);
    });

    it("should fallback to medium values for generic titles", () => {
      const review = getMockRoadmapReview("מאגר גנרי לא מוכר");
      expect(review.importance).toBe("Medium");
      expect(review.aiScore).toBe(50);
    });

    it("should apply publisher and notes boost when available", () => {
      const review = getMockRoadmapReview(
        "מאגר גנרי לא מוכר",
        "תיאור ארוך ומפורט של המאגר הציבורי הזה שמכיל מעל חמישים תווים לטובת בדיקה",
        "משרד הבריאות",
      );
      expect(review.importance).toBe("Medium");
      expect(review.aiScore).toBe(58); // 50 + 5 (publisher) + 3 (notes)
    });

    it("should correctly identify environmental datasets", () => {
      const review = getMockRoadmapReview("מאגר מדידות קרינה סלולרית");
      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(88);
    });

    it("should correctly identify internal administrative/bureaucratic datasets", () => {
      const review = getMockRoadmapReview("פרוטוקול ישיבות פנימיות");
      expect(review.importance).toBe("Low");
      expect(review.aiScore).toBe(25);
    });
  });

  describe("scoreDatasetWithAi service function", () => {
    it("should fallback to mock reviews if GEMINI_API_KEY is not defined", async () => {
      delete process.env.GEMINI_API_KEY;

      // Mock Firestore get to return metadata and existing request
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ title: "תקציב המדינה לשנת 2026" }),
      });
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ requestCount: 5 }),
      });

      const review = await scoreDatasetWithAi("dataset-1", mockFirestoreInstance as any);

      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(85);
      expect(mockDbSet).toHaveBeenCalledWith(
        expect.objectContaining({
          datasetId: "dataset-1",
          compositeScore: 135, // 5 * 10 + 85 = 135
          aiScore: 85,
        }),
        { merge: true },
      );
    });

    it("should query Gemini API if GEMINI_API_KEY is defined", async () => {
      process.env.GEMINI_API_KEY = "test-key";

      // Mock Firestore get to return metadata and existing request
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({
          title: "תקציב המדינה",
          publisher: "משרד האוצר",
          notes: "תיאור קצר",
          tags: ["תקציב"],
        }),
      });
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ requestCount: 3 }),
      });

      mockGenerateContent.mockResolvedValueOnce({
        response: {
          text: () =>
            JSON.stringify({
              importance: "High",
              importanceReasoning: "מאגר חשוב מאוד לענייני שקיפות פיננסית",
              paymentWillingness: "Medium",
              aiScore: 92,
            }),
        },
      });

      const review = await scoreDatasetWithAi("dataset-2", mockFirestoreInstance as any);

      expect(review.importance).toBe("High");
      expect(review.aiScore).toBe(92);
      expect(mockDbSet).toHaveBeenCalledWith(
        expect.objectContaining({
          datasetId: "dataset-2",
          compositeScore: 122, // 3 * 10 + 92 = 122
          aiScore: 92,
          aiImportance: "High",
          aiImportanceReasoning: "מאגר חשוב מאוד לענייני שקיפות פיננסית",
        }),
        { merge: true },
      );
    });

    it("should fallback to mock reviews if Gemini API throws an error", async () => {
      process.env.GEMINI_API_KEY = "test-key";

      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ title: "תרבות וספורט" }),
      });
      mockDbGet.mockResolvedValueOnce({
        exists: false,
        data: () => ({}),
      });

      mockGenerateContent.mockRejectedValueOnce(new Error("Gemini API Overloaded"));

      const review = await scoreDatasetWithAi("dataset-3", mockFirestoreInstance as any);

      expect(review.importance).toBe("Low");
      expect(review.aiScore).toBe(40);
      expect(mockDbSet).toHaveBeenCalledWith(
        expect.objectContaining({
          datasetId: "dataset-3",
          compositeScore: 40, // 0 * 10 + 40 = 40
          aiScore: 40,
        }),
        { merge: true },
      );
    });
  });

  describe("onDatasetRequestCreate trigger", () => {
    it("should trigger scoreDatasetWithAi when a document is created", async () => {
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ title: "תקציב המדינה" }),
      });
      mockDbGet.mockResolvedValueOnce({
        exists: false,
        data: () => ({}),
      });

      const fakeSnap = {
        data: () => ({ datasetTitle: "תקציב המדינה" }),
      };
      const fakeContext = {
        params: { datasetId: "dataset-id-123" },
      };

      await onDatasetRequestCreate(fakeSnap as any, fakeContext as any);

      expect(mockDbSet).toHaveBeenCalledWith(
        expect.objectContaining({
          datasetId: "dataset-id-123",
          aiScore: 85,
        }),
        { merge: true },
      );
    });
  });

  describe("manualAnalyzeDataset HTTPS trigger", () => {
    let req: any;
    let res: any;
    let statusMock: any;
    let jsonMock: any;

    beforeEach(() => {
      jsonMock = vi.fn();
      statusMock = vi.fn().mockReturnValue({ json: jsonMock });
      req = {
        method: "POST",
        headers: {
          authorization: "Bearer mock-token",
        },
        body: {
          datasetId: "dataset-to-analyze",
        },
      };
      res = {
        status: statusMock,
        set: vi.fn(),
      };
    });

    it("should reject non-admin users with 403", async () => {
      // Mock validateAdminRequest: user role is user (not admin)
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ role: "user" }),
      });

      await manualAnalyzeDataset(req, res);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          error: "Forbidden",
        }),
      );
    });

    it("should reject requests without datasetId with 400", async () => {
      // Mock validateAdminRequest: user is admin
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ role: "admin" }),
      });
      req.body = {};

      await manualAnalyzeDataset(req, res);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          error: "Bad Request",
        }),
      );
    });

    it("should successfully run analysis for authorized admin users", async () => {
      // Mock validateAdminRequest: user is admin
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ role: "admin" }),
      });
      // Mock scoreDatasetWithAi calls
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ title: "תקציב המדינה" }),
      });
      mockDbGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ requestCount: 2 }),
      });

      await manualAnalyzeDataset(req, res);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          review: expect.objectContaining({
            importance: "High",
            aiScore: 85,
          }),
        }),
      );
    });
  });
});
