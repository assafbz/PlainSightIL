import { describe, it, expect, vi, beforeEach } from "vitest";
import { handleCors } from "../src/index";

vi.mock("firebase-functions", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

describe("CORS Handling Security Policy", () => {
  let mockRes: any;
  let headers: Record<string, string>;
  let responseStatus: number;
  let responseData: any;

  beforeEach(() => {
    headers = {};
    responseStatus = 200;
    responseData = null;

    mockRes = {
      set: vi.fn().mockImplementation((key, val) => {
        headers[key] = val;
        return mockRes;
      }),
      status: vi.fn().mockImplementation((code) => {
        responseStatus = code;
        return mockRes;
      }),
      send: vi.fn().mockImplementation((data) => {
        responseData = data;
        return mockRes;
      }),
    };
  });

  it("should set Access-Control-Allow-Origin to * if no origin header is provided", () => {
    const mockReq = {
      headers: {},
      method: "GET",
    } as any;

    const result = handleCors(mockReq, mockRes);

    expect(result).toBe(false);
    expect(headers["Access-Control-Allow-Origin"]).toBe("*");
  });

  it("should allow matching localhost origins with dynamic ports", () => {
    const mockReq = {
      headers: {
        origin: "http://localhost:8080",
      },
      method: "GET",
    } as any;

    const result = handleCors(mockReq, mockRes);

    expect(result).toBe(false);
    expect(headers["Access-Control-Allow-Origin"]).toBe("http://localhost:8080");
    expect(headers["Vary"]).toBe("Origin");
  });

  it("should allow matching 127.0.0.1 origins", () => {
    const mockReq = {
      headers: {
        origin: "http://127.0.0.1:5000",
      },
      method: "GET",
    } as any;

    const result = handleCors(mockReq, mockRes);

    expect(result).toBe(false);
    expect(headers["Access-Control-Allow-Origin"]).toBe("http://127.0.0.1:5000");
    expect(headers["Vary"]).toBe("Origin");
  });

  it("should allow production web.app and firebaseapp domains", () => {
    const mockReq1 = {
      headers: {
        origin: "https://plainsightil.web.app",
      },
      method: "GET",
    } as any;

    handleCors(mockReq1, mockRes);
    expect(headers["Access-Control-Allow-Origin"]).toBe("https://plainsightil.web.app");

    const mockReq2 = {
      headers: {
        origin: "https://plainsightil.firebaseapp.com",
      },
      method: "GET",
    } as any;

    handleCors(mockReq2, mockRes);
    expect(headers["Access-Control-Allow-Origin"]).toBe("https://plainsightil.firebaseapp.com");

    const mockReq3 = {
      headers: {
        origin: "https://plainsight-il.web.app",
      },
      method: "GET",
    } as any;

    handleCors(mockReq3, mockRes);
    expect(headers["Access-Control-Allow-Origin"]).toBe("https://plainsight-il.web.app");
  });

  it("should block non-whitelisted domains by fallback to production domain", () => {
    const mockReq = {
      headers: {
        origin: "https://maliciousdomain.com",
      },
      method: "GET",
    } as any;

    handleCors(mockReq, mockRes);
    expect(headers["Access-Control-Allow-Origin"]).toBe("https://plainsightil.web.app");
  });

  it("should handle OPTIONS pre-flight requests correctly", () => {
    const mockReq = {
      headers: {
        origin: "http://localhost:8080",
      },
      method: "OPTIONS",
    } as any;

    const result = handleCors(mockReq, mockRes);

    expect(result).toBe(true);
    expect(headers["Access-Control-Allow-Origin"]).toBe("http://localhost:8080");
    expect(headers["Access-Control-Allow-Methods"]).toBe("GET, POST, OPTIONS");
    expect(headers["Access-Control-Allow-Headers"]).toBe(
      "Content-Type, Authorization, x-firebase-appcheck",
    );
    expect(headers["Access-Control-Max-Age"]).toBe("3600");
    expect(responseStatus).toBe(204);
    expect(responseData).toBe("");
  });
});
