import { describe, it, expect } from "vitest";
import { DATASET_IDS } from "../../src/utils/constants";

describe("DATASET_IDS Constants", () => {
  it("should contain the patent classifications resource ID", () => {
    expect(DATASET_IDS.PATENT_CLASSIFICATIONS).toBe("b2c59e21-c345-4b02-b071-2890a3d431d6");
  });
});
