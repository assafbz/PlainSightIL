import { describe, it, expect } from "vitest";
import { DATASET_IDS } from "../../src/utils/constants";

describe("DATASET_IDS Constants", () => {
  it("should contain the patent classifications resource ID", () => {
    expect(DATASET_IDS.PATENT_CLASSIFICATIONS).toBe("b2c59e21-c345-4b02-b071-2890a3d431d6");
  });

  it("should contain the local market bonds resource ID", () => {
    expect(DATASET_IDS.LOCAL_MARKET_BONDS).toBe("c92fdda2-0939-4110-8ebc-edfcf35e8723");
  });
});
