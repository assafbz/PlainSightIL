import { describe, it, expect, vi, beforeEach } from "vitest";
import axios from "axios";
import { scrapeAndSyncDatasetMetadata } from "../src/scrapers/metadata_scraper";

vi.mock("axios");
vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("scrapeAndSyncDatasetMetadata", () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockDoc: any;
  let mockDocSet: any;
  let mockCountGet: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockDocSet = vi.fn().mockResolvedValue(true);

    const mockGet = vi.fn().mockResolvedValue({
      exists: false,
    });

    mockDoc = vi.fn().mockImplementation((docId) => {
      if (docId === "datasets_metadata") {
        return {
          id: docId,
          set: mockDocSet,
          get: mockGet,
        };
      }
      return {
        id: "mock-doc-id",
        get: mockGet,
      };
    });

    mockCountGet = vi.fn().mockResolvedValue({
      data: () => ({ count: 3 }),
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

    mockDb = {
      collection: mockCollection,
      batch: vi.fn().mockReturnValue(mockBatch),
      getAll: vi.fn().mockImplementation(async (...refs) => {
        return refs.map((ref) => ({
          id: ref.id,
          exists: false,
          data: () => ({}),
        }));
      }),
    };
  });

  it("should return success and count 0 if no packages are returned from CKAN API", async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: {
        result: {
          results: [],
        },
      },
    });

    const result = await scrapeAndSyncDatasetMetadata(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(0);
    expect(mockCollection).toHaveBeenCalledWith("datasets_metadata");
    expect(mockBatch.commit).not.toHaveBeenCalled();
  });

  it("should parse and sync CKAN packages, marking supported datasets correctly", async () => {
    const packagesResponse = {
      data: {
        result: {
          results: [
            {
              id: "8935c8e5-ec77-421f-af86-d970583195f8", // Directly supported ID
              name: "cellular-antennas",
              title: "Cellular Antennas Active",
              notes: "<p>HTML stripped notes description</p>",
              organization: { title: "Ministry of Communications" },
              num_resources: 2,
              metadata_modified: "2026-05-01T12:00:00.000Z",
              tags: [{ name: "antennas" }, { name: "radiation" }],
              resources: [{ id: "8935c8e5-ec77-421f-af86-d970583195f8" }],
            },
            {
              id: "unsupported-dataset-pkg-id",
              name: "unsupported-name",
              title: "Unsupported Title",
              notes: "Regular notes description",
              organization: { title: "Some Ministry" },
              num_resources: 1,
              metadata_modified: "2026-05-02T12:00:00.000Z",
              tags: [{ name: "unrelated" }],
              resources: [
                { id: "ff398c7e-c522-4ee8-a53a-312b188a573d" }, // Contains supported resource ID
              ],
            },
            {
              id: "completely-unsupported-pkg-id",
              name: "completely-unsupported",
              title: "Completely Unsupported Dataset",
              notes: "Description",
              organization: { title: "Unrelated Org" },
              num_resources: 1,
              metadata_modified: "2026-05-03T12:00:00.000Z",
              tags: [],
              resources: [{ id: "some-other-id" }],
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(packagesResponse);

    const result = await scrapeAndSyncDatasetMetadata(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(3);

    expect(mockDb.batch).toHaveBeenCalledTimes(1);
    expect(mockBatch.set).toHaveBeenCalledTimes(3);

    // Verify first package (directly supported)
    const firstSetCall = mockBatch.set.mock.calls[0];
    expect(firstSetCall[0].id).toBe("mock-doc-id");
    expect(mockDoc).toHaveBeenCalledWith("8935c8e5-ec77-421f-af86-d970583195f8");
    expect(firstSetCall[1].isSupported).toBe(true);
    expect(firstSetCall[1].notes).toBe("HTML stripped notes description"); // HTML sanitized
    expect(firstSetCall[1].publisher).toBe("Ministry of Communications");

    // Verify second package (indirectly supported via resource)
    const secondSetCall = mockBatch.set.mock.calls[1];
    expect(mockDoc).toHaveBeenCalledWith("ff398c7e-c522-4ee8-a53a-312b188a573d"); // Resolves resource ID as document key
    expect(secondSetCall[1].isSupported).toBe(true);

    // Verify third package (not supported)
    const thirdSetCall = mockBatch.set.mock.calls[2];
    expect(mockDoc).toHaveBeenCalledWith("completely-unsupported-pkg-id");
    expect(thirdSetCall[1].isSupported).toBe(false);

    expect(mockBatch.commit).toHaveBeenCalledTimes(1);

    // Verify metadata document updates
    expect(mockCollection).toHaveBeenCalledWith("dataset_metadata");
    expect(mockDoc).toHaveBeenCalledWith("datasets_metadata");
    expect(mockDocSet).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "datasets_metadata",
        activeCollection: "datasets_metadata",
        recordCount: 3,
        status: "idle",
      }),
      { merge: true },
    );
  });

  it("should trigger alerts on subsequent syncs for new and modified/supported datasets", async () => {
    // 1. Mock isFirstSync = false
    const mockGet = vi.fn().mockResolvedValue({
      exists: true,
      data: () => ({ lastUpdated: "2026-06-05T00:00:00Z" }),
    });

    mockDoc = vi.fn().mockImplementation((docId) => {
      return {
        id: docId,
        set: mockDocSet,
        get: mockGet,
      };
    });

    mockCollection = vi.fn().mockImplementation((name) => {
      if (name === "users") {
        return {
          get: vi.fn().mockResolvedValue({
            empty: false,
            docs: [{ id: "user-123" }],
          }),
          doc: vi.fn().mockReturnValue({
            collection: vi.fn().mockReturnValue({
              doc: vi.fn().mockReturnValue({
                set: vi.fn().mockResolvedValue(true),
              }),
            }),
          }),
        };
      }
      return {
        doc: mockDoc,
        count: vi.fn().mockReturnValue({
          get: mockCountGet,
        }),
      };
    });

    // 2. Mock some datasets already existing, and one visualizer transition
    mockDb.collection = mockCollection;
    mockDb.getAll = vi.fn().mockImplementation(async (...refs) => {
      return refs.map((ref) => {
        if (ref.id === "completely-unsupported-pkg-id") {
          // Exists and identical
          return {
            id: ref.id,
            exists: true,
            data: () => ({
              id: ref.id,
              datasetId: ref.id,
              name: "completely-unsupported",
              title: "Completely Unsupported Dataset",
              notes: "Description",
              publisher: "Unrelated Org",
              resourceCount: 1,
              lastUpdated: "2026-05-03T12:00:00.000Z",
              isSupported: false,
              tags: [],
            }),
          };
        }
        if (ref.id === "ff398c7e-c522-4ee8-a53a-312b188a573d") {
          // Exists but transition from not supported to supported
          return {
            id: ref.id,
            exists: true,
            data: () => ({
              id: ref.id,
              datasetId: "unsupported-dataset-pkg-id",
              name: "unsupported-name",
              title: "Unsupported Title",
              notes: "Regular notes description",
              publisher: "Some Ministry",
              resourceCount: 1,
              lastUpdated: "2026-05-02T12:00:00.000Z",
              isSupported: false, // was false, now true
              tags: [],
            }),
          };
        }
        // Others don't exist (e.g. 8935c8e5-ec77-421f-af86-d970583195f8 which is new and supported)
        return {
          id: ref.id,
          exists: false,
          data: () => ({}),
        };
      });
    });

    const packagesResponse = {
      data: {
        result: {
          results: [
            {
              id: "8935c8e5-ec77-421f-af86-d970583195f8", // New and supported
              name: "cellular-antennas",
              title: "Cellular Antennas Active",
              notes: "Cellular Antennas Active",
              organization: { title: "Ministry of Communications" },
              num_resources: 1,
              metadata_modified: "2026-05-01T12:00:00.000Z",
              tags: [],
              resources: [{ id: "8935c8e5-ec77-421f-af86-d970583195f8" }],
            },
            {
              id: "unsupported-dataset-pkg-id", // New and not supported
              name: "unsupported-name",
              title: "Unsupported Title",
              notes: "Regular notes description",
              organization: { title: "Some Ministry" },
              num_resources: 1,
              metadata_modified: "2026-05-02T12:00:00.000Z",
              tags: [],
              resources: [
                { id: "ff398c7e-c522-4ee8-a53a-312b188a573d" }, // Maps to supported ID
              ],
            },
            {
              id: "completely-unsupported-pkg-id", // Exists and identical, should not write
              name: "completely-unsupported",
              title: "Completely Unsupported Dataset",
              notes: "Description",
              organization: { title: "Unrelated Org" },
              num_resources: 1,
              metadata_modified: "2026-05-03T12:00:00.000Z",
              tags: [],
              resources: [{ id: "some-other-id" }],
            },
          ],
        },
      },
    };

    vi.mocked(axios.get).mockResolvedValueOnce(packagesResponse);

    const result = await scrapeAndSyncDatasetMetadata(mockDb);
    expect(result.success).toBe(true);
    expect(result.count).toBe(3);
    expect(result.changedCount).toBe(2); // New supported, and transition supported. Identical unsupported is skipped.

    // Verify batch commits
    expect(mockDb.batch).toHaveBeenCalledTimes(4); // 1 for metadata scraper, 3 for broadcast alerts
    expect(mockBatch.set).toHaveBeenCalledTimes(5); // 2 for metadata updates, 3 for alert creations
  });
});
