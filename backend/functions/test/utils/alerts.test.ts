import { describe, it, expect, vi, beforeEach } from "vitest";
import * as admin from "firebase-admin";
import { createAlert, broadcastAlert, notifySubscribers } from "../../src/utils/alerts";

vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Alerts Utility and Triggers Tests", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockDocGet: any;
  let mockDocSet: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockDocSet = vi.fn().mockResolvedValue(true);
    mockDocGet = vi.fn().mockResolvedValue({
      exists: false,
      data: () => ({}),
    });

    mockDoc = vi.fn().mockImplementation((docId) => ({
      id: docId || "mock-doc-id",
      set: mockDocSet,
      get: mockDocGet,
      collection: mockCollection,
    }));

    mockCollection = vi.fn().mockReturnValue({
      doc: mockDoc,
      where: vi.fn().mockReturnThis(),
      get: vi.fn().mockResolvedValue({
        empty: true,
        docs: [],
      }),
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

  describe("createAlert", () => {
    it("should write an alert document to the user's alerts subcollection", async () => {
      await createAlert(mockDb, "user-123", {
        type: "new_dataset",
        title: { he: "מערכת", en: "System" },
        description: { he: "תיאור", en: "Description" },
        datasetId: "ds-1",
      });

      expect(mockCollection).toHaveBeenCalledWith("users");
      expect(mockDoc).toHaveBeenCalledWith("user-123");
      expect(mockCollection).toHaveBeenCalledWith("alerts");
      expect(mockDocSet).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: "user-123",
          type: "new_dataset",
          datasetId: "ds-1",
          isRead: false,
          createdAt: expect.any(String),
        }),
      );
    });
  });

  describe("broadcastAlert", () => {
    it("should do nothing if there are no registered users", async () => {
      mockCollection.mockReturnValueOnce({
        get: vi.fn().mockResolvedValue({
          empty: true,
          docs: [],
        }),
      });

      await broadcastAlert(mockDb, {
        type: "new_government_dataset",
        title: { he: "מערכת", en: "System" },
        description: { he: "תיאור", en: "Description" },
      });

      expect(mockDb.batch).not.toHaveBeenCalled();
    });

    it("should write alerts to all users in batches of 500", async () => {
      const mockUsers = Array.from({ length: 505 }, (_, i) => ({
        id: `user-${i}`,
      }));

      mockCollection.mockReturnValueOnce({
        get: vi.fn().mockResolvedValue({
          empty: false,
          docs: mockUsers,
        }),
      });

      await broadcastAlert(mockDb, {
        type: "new_government_dataset",
        title: { he: "מערכת", en: "System" },
        description: { he: "תיאור", en: "Description" },
      });

      expect(mockDb.batch).toHaveBeenCalledTimes(2);
      expect(mockBatch.set).toHaveBeenCalledTimes(505);
      expect(mockBatch.commit).toHaveBeenCalledTimes(2);
    });
  });

  describe("notifySubscribers", () => {
    it("should do nothing if there are no subscribers", async () => {
      mockCollection.mockReturnValueOnce({
        where: vi.fn().mockReturnThis(),
        get: vi.fn().mockResolvedValue({
          empty: true,
          docs: [],
        }),
      });

      await notifySubscribers(mockDb, "dataset-1", {
        type: "new_records",
        title: { he: "מערכת", en: "System" },
        description: { he: "תיאור", en: "Description" },
      });

      expect(mockDb.batch).not.toHaveBeenCalled();
    });

    it("should notify all subscribers in batches of 500", async () => {
      const mockSubs = Array.from({ length: 505 }, (_, i) => ({
        data: () => ({ userId: `user-${i}` }),
      }));

      mockCollection.mockReturnValueOnce({
        where: vi.fn().mockReturnThis(),
        get: vi.fn().mockResolvedValue({
          empty: false,
          docs: mockSubs,
        }),
      });

      await notifySubscribers(mockDb, "dataset-1", {
        type: "new_records",
        title: { he: "מערכת", en: "System" },
        description: { he: "תיאור", en: "Description" },
        datasetId: "dataset-1",
      });

      expect(mockDb.batch).toHaveBeenCalledTimes(2);
      expect(mockBatch.set).toHaveBeenCalledTimes(505);
      expect(mockBatch.commit).toHaveBeenCalledTimes(2);
    });
  });
});
