import { describe, it, expect } from "vitest";
import { areRecordsEqual } from "../../src/utils/equality";

describe("Equality Utility", () => {
  it("should return true for identical primitives and references", () => {
    expect(areRecordsEqual(1, 1)).toBe(true);
    expect(areRecordsEqual("a", "a")).toBe(true);
    const obj = { x: 1 };
    expect(areRecordsEqual(obj, obj)).toBe(true);
  });

  it("should handle null and undefined cases", () => {
    expect(areRecordsEqual(null, null)).toBe(true);
    expect(areRecordsEqual(undefined, undefined)).toBe(true);
    expect(areRecordsEqual(null, undefined)).toBe(true);
    expect(areRecordsEqual(undefined, null)).toBe(true);
    expect(areRecordsEqual({ x: null }, { x: undefined })).toBe(true);
    expect(areRecordsEqual(null, 1)).toBe(false);
    expect(areRecordsEqual(1, null)).toBe(false);
  });

  it("should handle type differences", () => {
    expect(areRecordsEqual(1, "1")).toBe(false);
    expect(areRecordsEqual({}, [])).toBe(false);
  });

  it("should handle Date structures", () => {
    const d1 = new Date(1717325600000);
    const d2 = new Date(1717325600000);
    const d3 = new Date(1717325700000);
    expect(areRecordsEqual(d1, d2)).toBe(true);
    expect(areRecordsEqual(d1, d3)).toBe(false);
  });

  it("should handle Firestore GeoPoint duck-typing structures", () => {
    const p1 = { latitude: 32.1, longitude: 34.8 };
    const p2 = { latitude: 32.1, longitude: 34.8 };
    const p3 = { latitude: 32.2, longitude: 34.8 };
    const p4 = { latitude: 32.1 };

    expect(areRecordsEqual(p1, p2)).toBe(true);
    expect(areRecordsEqual(p1, p3)).toBe(false);
    expect(areRecordsEqual(p1, p4)).toBe(false);
  });

  it("should handle Array structures", () => {
    expect(areRecordsEqual([1, 2], [1, 2])).toBe(true);
    expect(areRecordsEqual([1, 2], [1, 3])).toBe(false);
    expect(areRecordsEqual([1, 2], [1])).toBe(false);
    expect(areRecordsEqual([1, 2], { 0: 1, 1: 2 })).toBe(false);
  });

  it("should ignore createdAt and updatedAt fields", () => {
    const o1 = { id: "123", createdAt: "2026-06-01", updatedAt: "2026-06-02" };
    const o2 = { id: "123", createdAt: "2026-06-03", updatedAt: "2026-06-04" };
    expect(areRecordsEqual(o1, o2)).toBe(true);
  });
});
