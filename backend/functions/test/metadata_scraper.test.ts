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

  beforeEach(() => {
    vi.clearAllMocks();

    mockDoc = vi.fn().mockReturnValue({
      id: "mock-doc-id",
    });

    mockCollection = vi.fn().mockReturnValue({
      doc: mockDoc,
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
    expect(firstSetCall[0]).toEqual({ id: "mock-doc-id" });
    expect(mockDoc).toHaveBeenNthCalledWith(1, "8935c8e5-ec77-421f-af86-d970583195f8");
    expect(firstSetCall[1].isSupported).toBe(true);
    expect(firstSetCall[1].notes).toBe("HTML stripped notes description"); // HTML sanitized
    expect(firstSetCall[1].publisher).toBe("Ministry of Communications");

    // Verify second package (indirectly supported via resource)
    const secondSetCall = mockBatch.set.mock.calls[1];
    expect(mockDoc).toHaveBeenNthCalledWith(2, "ff398c7e-c522-4ee8-a53a-312b188a573d"); // Resolves resource ID as document key
    expect(secondSetCall[1].isSupported).toBe(true);

    // Verify third package (not supported)
    const thirdSetCall = mockBatch.set.mock.calls[2];
    expect(mockDoc).toHaveBeenNthCalledWith(3, "completely-unsupported-pkg-id");
    expect(thirdSetCall[1].isSupported).toBe(false);

    expect(mockBatch.commit).toHaveBeenCalledTimes(1);
  });
});
