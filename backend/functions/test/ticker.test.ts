import { describe, it, expect, vi, beforeEach } from "vitest";

// 1. Hoist mock variables to make them available inside vi.mock calls
const {
  mockDbGet,
  mockDbSet,
  mockFirestoreInstance,
  mockTopicPublishMessage,
  mockTopicCreate,
  mockTrackerFail,
} = vi.hoisted(() => {
  const get = vi.fn().mockResolvedValue({
    docs: [],
  });
  const set = vi.fn().mockResolvedValue(true);
  const publishMessage = vi.fn().mockResolvedValue("msg-id");
  const createTopic = vi.fn().mockResolvedValue(true);
  const trackerFail = vi.fn().mockResolvedValue(true);
  const instance = {
    collection: vi.fn().mockReturnValue({
      where: vi.fn().mockReturnThis(),
      get,
      doc: vi.fn().mockReturnValue({
        get: vi.fn().mockResolvedValue({
          exists: false,
          data: () => ({}),
        }),
        set,
      }),
    }),
  };
  return {
    mockDbGet: get,
    mockDbSet: set,
    mockTopicPublishMessage: publishMessage,
    mockTopicCreate: createTopic,
    mockTrackerFail: trackerFail,
    mockFirestoreInstance: instance,
  };
});

// 2. Mock pubsub with a proper constructor function
vi.mock("@google-cloud/pubsub", () => {
  return {
    PubSub: vi.fn().mockImplementation(function () {
      return {
        topic: vi.fn().mockReturnValue({
          create: mockTopicCreate,
          publishMessage: mockTopicPublishMessage,
        }),
      };
    }),
  };
});

// 3. Mock firebase-functions partially, ensuring all runWith return properties are defined
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

// 4. Mock telemetry and scheduler utility functions using hoisted mocks
vi.mock("../src/utils/telemetry", () => ({
  ScraperTelemetryTracker: {
    start: vi.fn().mockReturnValue({
      complete: vi.fn().mockResolvedValue(true),
      fail: mockTrackerFail,
    }),
  },
}));

// 5. Mock firebase-admin using hoisted mocks
vi.mock("firebase-admin", () => ({
  initializeApp: vi.fn(),
  firestore: () => mockFirestoreInstance,
}));

// Import scheduledScraperTicker after mocking
import { scheduledScraperTicker } from "../src/index";

describe("scheduledScraperTicker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("should trigger scraper sync when due and status is not syncing", async () => {
    const mockDocs = [
      {
        id: "dataset-1",
        ref: { set: mockDbSet },
        data: () => ({
          status: "idle",
          scheduler: {
            enabled: true,
            nextRun: new Date(Date.now() - 60000).toISOString(), // due (1 minute in the past)
          },
        }),
      },
    ];
    mockDbGet.mockResolvedValueOnce({ docs: mockDocs });

    await scheduledScraperTicker();

    // Verify Firestore status set to syncing
    expect(mockDbSet).toHaveBeenCalledWith(
      expect.objectContaining({
        status: "syncing",
        syncStartedAt: expect.any(String),
      }),
      { merge: true },
    );

    // Verify message published to Pub/Sub
    expect(mockTopicPublishMessage).toHaveBeenCalledWith({
      data: expect.any(Buffer),
    });
    const publishedPayload = JSON.parse(mockTopicPublishMessage.mock.calls[0][0].data.toString());
    expect(publishedPayload.datasetId).toBe("dataset-1");
  });

  it("should NOT trigger scraper sync if dataset is already syncing and not stuck", async () => {
    const mockDocs = [
      {
        id: "dataset-2",
        ref: { set: mockDbSet },
        data: () => ({
          status: "syncing",
          syncStartedAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(), // syncing for 5 mins
          scheduler: {
            enabled: true,
            nextRun: new Date(Date.now() - 60000).toISOString(),
          },
        }),
      },
    ];
    mockDbGet.mockResolvedValueOnce({ docs: mockDocs });

    await scheduledScraperTicker();

    expect(mockDbSet).not.toHaveBeenCalled();
    expect(mockTopicPublishMessage).not.toHaveBeenCalled();
  });

  it("should reset a stuck dataset to error and log telemetry if syncing for more than 1 hour", async () => {
    const stuckTime = new Date(Date.now() - 65 * 60 * 1000).toISOString(); // 65 mins ago (stuck)
    const mockDocs = [
      {
        id: "dataset-3",
        ref: { set: mockDbSet },
        data: () => ({
          status: "syncing",
          syncStartedAt: stuckTime,
          scheduler: {
            enabled: true,
            nextRun: new Date(Date.now() - 10 * 60 * 1000).toISOString(),
          },
        }),
      },
    ];
    mockDbGet.mockResolvedValueOnce({ docs: mockDocs });

    await scheduledScraperTicker();

    // Verify that the scraper was not triggered/published
    expect(mockTopicPublishMessage).not.toHaveBeenCalled();

    // Verify that it logged a failure to telemetry
    expect(mockTrackerFail).toHaveBeenCalledWith(mockFirestoreInstance, expect.any(Error));
    expect(mockTrackerFail.mock.calls[0][1].message).toContain("stuck in syncing");
  });
});
