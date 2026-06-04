import { logger } from "firebase-functions";

export interface LogMetadata {
  datasetId?: string;
  runId?: string;
  userId?: string;
  statusCode?: number;
  latencyMs?: number;
  [key: string]: unknown;
}

/**
 * Production-grade structured logger for Google Cloud Functions.
 * Formats log entries as JSON payloads matching GCP Logging / Error Reporting standards.
 */
export class AppLogger {
  private static serviceContext = {
    service: "plainsight-backend-functions",
    version: "1.0.5",
  };

  /**
   * Log an informational message.
   */
  static info(message: string, ...args: unknown[]) {
    let meta: Record<string, unknown> = {};
    let formattedMessage = message;

    for (const arg of args) {
      if (typeof arg === "object" && arg !== null) {
        meta = { ...meta, ...(arg as Record<string, unknown>) };
      } else {
        formattedMessage += ` ${arg}`;
      }
    }

    logger.info(formattedMessage, {
      serviceContext: this.serviceContext,
      ...meta,
    });
  }

  /**
   * Log a warning message.
   */
  static warn(message: string, ...args: unknown[]) {
    let meta: Record<string, unknown> = {};
    let formattedMessage = message;

    for (const arg of args) {
      if (typeof arg === "object" && arg !== null) {
        meta = { ...meta, ...(arg as Record<string, unknown>) };
      } else {
        formattedMessage += ` ${arg}`;
      }
    }

    logger.warn(formattedMessage, {
      serviceContext: this.serviceContext,
      ...meta,
    });
  }

  /**
   * Log an error message with contextual details and stack trace.
   * Formats error stack trace so GCP Error Reporting parses and indexes it automatically.
   */
  static error(message: string, ...args: unknown[]) {
    const errorDetails: Record<string, unknown> = {};
    let actualError: unknown = undefined;
    let meta: Record<string, unknown> = {};
    let formattedMessage = message;

    for (const arg of args) {
      if (arg instanceof Error) {
        actualError = arg;
      } else if (typeof arg === "object" && arg !== null) {
        meta = { ...meta, ...(arg as Record<string, unknown>) };
      } else {
        formattedMessage += ` ${arg}`;
      }
    }

    if (actualError instanceof Error) {
      errorDetails.errorMsg = actualError.message;
      errorDetails.stack = actualError.stack;
      errorDetails.message = `${formattedMessage}\n${actualError.stack}`;
    } else if (actualError) {
      errorDetails.errorMsg = String(actualError);
      errorDetails.message = `${formattedMessage}\nContext: ${JSON.stringify(actualError)}`;
    } else {
      errorDetails.message = formattedMessage;
    }

    logger.error(errorDetails.message as string, {
      serviceContext: this.serviceContext,
      ...errorDetails,
      ...meta,
    });
  }
}
