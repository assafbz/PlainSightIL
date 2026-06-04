import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { AppLogger } from "../../src/utils/logger";
import { logger } from "firebase-functions";

// Mock firebase-functions logger methods
vi.mock("firebase-functions", () => {
  return {
    logger: {
      info: vi.fn(),
      warn: vi.fn(),
      error: vi.fn(),
    },
  };
});

describe("AppLogger Utility", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("should log info message and interpolate non-object arguments", () => {
    AppLogger.info("Hello", "world", 123);
    expect(logger.info).toHaveBeenCalledWith(
      "Hello world 123",
      expect.objectContaining({
        serviceContext: {
          service: "plainsight-backend-functions",
          version: "1.0.5",
        },
      }),
    );
  });

  it("should merge object metadata arguments in AppLogger.info", () => {
    AppLogger.info("Hello", { datasetId: "test-id" }, { latencyMs: 50 });
    expect(logger.info).toHaveBeenCalledWith(
      "Hello",
      expect.objectContaining({
        serviceContext: {
          service: "plainsight-backend-functions",
          version: "1.0.5",
        },
        datasetId: "test-id",
        latencyMs: 50,
      }),
    );
  });

  it("should log warn message and merge object metadata", () => {
    AppLogger.warn("Warning", { userId: "user-1" }, "extra");
    expect(logger.warn).toHaveBeenCalledWith(
      "Warning extra",
      expect.objectContaining({
        userId: "user-1",
      }),
    );
  });

  it("should log error message and format Error instance correctly", () => {
    const errorObj = new Error("Something went wrong");
    errorObj.stack = "MockErrorStack";

    AppLogger.error("Action failed", errorObj, { operation: "sync" });

    expect(logger.error).toHaveBeenCalledWith(
      expect.stringContaining("Action failed\nMockErrorStack"),
      expect.objectContaining({
        errorMsg: "Something went wrong",
        stack: "MockErrorStack",
        operation: "sync",
      }),
    );
  });

  it("should merge generic object as metadata in AppLogger.error", () => {
    AppLogger.error("Fail", { details: "bad format" });

    expect(logger.error).toHaveBeenCalledWith(
      "Fail",
      expect.objectContaining({
        details: "bad format",
        serviceContext: {
          service: "plainsight-backend-functions",
          version: "1.0.5",
        },
      }),
    );
  });
});
