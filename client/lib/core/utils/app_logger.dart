import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Supported severity levels for logging.
enum LogLevel {
  /// Verbose diagnostic messages for development.
  debug,

  /// General operational messages about system status and transitions.
  info,

  /// Non-critical anomalies that do not break operation.
  warning,

  /// Critical runtime errors and exceptions.
  error,
}

/// Centralized utility for structured, informative logging across PlainSightIL.
///
/// Log output format:
/// `[TIMESTAMP] [LEVEL] [CALLER] Message`
/// E.g. `[2026-06-02T09:07:00.000Z] [INFO] [AppStateNotifier._initSharedPreferences] SharedPreferences loaded successfully`
class AppLogger {
  /// The minimum level required for a log to be output.
  /// Set to [LogLevel.debug] by default for all environments.
  static LogLevel minimumLogLevel = LogLevel.debug;

  /// Log a message at the [LogLevel.debug] severity.
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log a message at the [LogLevel.info] severity.
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a message at the [LogLevel.warning] severity.
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log a message at the [LogLevel.error] severity.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Dispatch a log event to the console or log services if thresholds are met.
  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < minimumLogLevel.index) return;

    final String timestamp = DateTime.now().toUtc().toIso8601String();
    final String levelTag = level.name.toUpperCase();
    final String caller = _extractCallerContext();

    var output = '[$timestamp] [$levelTag] [$caller] $message';
    if (error != null) {
      output += '\nContext/Error: $error';
    }
    if (stackTrace != null) {
      output += '\nStackTrace:\n$stackTrace';
    }

    debugPrint(output);

    // Forward warnings and errors to Firebase Crashlytics when available
    if (level == LogLevel.warning || level == LogLevel.error) {
      try {
        if (Firebase.apps.isNotEmpty) {
          final crashlytics = FirebaseCrashlytics.instance;
          if (level == LogLevel.error) {
            crashlytics.recordError(
              error ?? Exception(message),
              stackTrace,
              reason: '[$caller] $message',
              printDetails: false,
            );
          } else {
            crashlytics.log('[$levelTag] [$caller] $message');
            if (error != null) {
              crashlytics.log('Error context: $error');
            }
          }
        }
      } catch (_) {
        // Fall back silently if Firebase or Crashlytics is not initialized or fails (e.g. in test mode)
      }
    }
  }

  /// Parses the current execution stack trace to resolve the caller method.
  static String _extractCallerContext() {
    try {
      final List<String> frames = StackTrace.current.toString().split('\n');
      // Frame index map:
      // 0: AppLogger._extractCallerContext
      // 1: AppLogger._log
      // 2: AppLogger.info / AppLogger.error etc.
      // 3: The actual caller component method
      if (frames.length > 3) {
        final String targetFrame = frames[3].trim();
        // Standard Dart stack trace format:
        // #3      AppStateNotifier._initSharedPreferences (package:plainsight/core/state/app_state.dart:67:7)
        final RegExp pattern = RegExp(r'#\d+\s+([^\s\(]+)');
        final Match? match = pattern.firstMatch(targetFrame);
        if (match != null && match.groupCount >= 1) {
          final String matchedContext = match.group(1)!;
          // Shave off generic/anonymous closure decorators if present
          return matchedContext.replaceAll('<anonymous closure>', 'anonymous');
        }
        return targetFrame;
      }
    } catch (_) {
      // Fall back gracefully if stack trace parsing fails
    }
    return 'UnknownContext';
  }
}
