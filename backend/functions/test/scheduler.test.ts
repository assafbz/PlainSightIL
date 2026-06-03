import { describe, it, expect, vi, beforeEach } from "vitest";
import * as admin from "firebase-admin";
import { updateSchedulerOnComplete } from "../src/index";

vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("Scraper Scheduler Calculations", () => {
  let mockDb: any;
  let mockDoc: any;
  let mockCollection: any;
  let mockSet: any;
  let mockGet: any;

  beforeEach(() => {
    vi.clearAllMocks();

    mockSet = vi.fn().mockResolvedValue(true);
    mockGet = vi.fn().mockResolvedValue({
      exists: false,
      data: () => ({}),
    });

    mockDoc = vi.fn().mockReturnValue({
      get: mockGet,
      set: mockSet,
    });

    mockCollection = vi.fn().mockReturnValue({
      doc: mockDoc,
    });

    mockDb = {
      collection: mockCollection,
    };
  });

  it("should calculate and update nextRun using the default offset (e.g. 24h for Cellular Antennas) when doc does not exist", async () => {
    const datasetId = "8935c8e5-ec77-421f-af86-d970583195f8"; // Cellular Antennas
    const beforeTime = Date.now();

    await updateSchedulerOnComplete(mockDb, datasetId, "idle");

    expect(mockCollection).toHaveBeenCalledWith("dataset_metadata");
    expect(mockDoc).toHaveBeenCalledWith(datasetId);
    expect(mockSet).toHaveBeenCalledTimes(1);

    const callArgs = mockSet.mock.calls[0][0];
    expect(callArgs.status).toBe("idle");
    expect(callArgs.scheduler.enabled).toBe(true);
    expect(callArgs.scheduler.updateIntervalHours).toBe(24);

    const nextRunTime = Date.parse(callArgs.scheduler.nextRun);
    const expectedTime = beforeTime + 24 * 60 * 60 * 1000;
    // Allow small 5-second assertion window
    expect(nextRunTime).toBeGreaterThanOrEqual(expectedTime - 5000);
    expect(nextRunTime).toBeLessThanOrEqual(expectedTime + 5000);
  });

  it("should calculate and update nextRun using a custom updateIntervalHours stored in Firestore", async () => {
    const datasetId = "ff398c7e-c522-4ee8-a53a-312b188a573d"; // Cellular Permits (default is 168)
    // Mock the doc to exist and return a custom 12-hour interval
    mockGet.mockResolvedValueOnce({
      exists: true,
      data: () => ({
        scheduler: {
          enabled: true,
          updateIntervalHours: 12,
        },
      }),
    });

    const beforeTime = Date.now();

    await updateSchedulerOnComplete(mockDb, datasetId, "idle");

    expect(mockSet).toHaveBeenCalledTimes(1);
    const callArgs = mockSet.mock.calls[0][0];
    expect(callArgs.scheduler.updateIntervalHours).toBe(12);

    const nextRunTime = Date.parse(callArgs.scheduler.nextRun);
    const expectedTime = beforeTime + 12 * 60 * 60 * 1000;
    expect(nextRunTime).toBeGreaterThanOrEqual(expectedTime - 5000);
    expect(nextRunTime).toBeLessThanOrEqual(expectedTime + 5000);
  });

  it("should calculate and update nextRun on failure with error status", async () => {
    const datasetId = "9c64c522-bbc2-48fe-96fb-3b2a8626f59e"; // Doctors Licenses

    await updateSchedulerOnComplete(mockDb, datasetId, "error");

    expect(mockSet).toHaveBeenCalledTimes(1);
    const callArgs = mockSet.mock.calls[0][0];
    expect(callArgs.status).toBe("error");
  });
});
