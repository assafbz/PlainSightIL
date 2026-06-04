import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';

void main() {
  group('TelemetryNotifier Basic Tests', () {
    test('should initialize with correct initial values in testing mode', () {
      final notifier = TelemetryNotifier(isTesting: true);
      expect(notifier.isFirebaseInitialized, isFalse);
      expect(notifier.apiHealth, isEmpty);
      expect(notifier.scraperRuns, isEmpty);
      expect(notifier.directoryRecords, isEmpty);
    });
  });
}
