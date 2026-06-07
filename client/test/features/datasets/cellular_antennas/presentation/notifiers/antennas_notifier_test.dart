import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';

void main() {
  group('AntennasNotifier Tests', () {
    test('initAntennaListener updates records in offline mock mode', () {
      AppStateNotifier.isTesting = true;
      final notifier = AntennasNotifier(isTesting: true);
      notifier.initAntennaListener();
      expect(notifier.isLoadingAntennas, isFalse);
      expect(notifier.antennaRecords.isNotEmpty, isTrue);
      notifier.dispose();
    });

    test(
      'getRecordLastUpdated extraction callback and isFirebaseInitialized fallback works',
      () {
        final notifier = AntennasNotifier(isTesting: true);
        final manager = notifier.syncManagerForTesting;
        expect(
          manager.getRecordLastUpdated({'lastUpdated': '2026-06-02'}),
          '2026-06-02',
        );
        expect(manager.getRecordLastUpdated({}), '');

        // Test isFirebaseInitialized when testIsFirebaseInitialized is null
        AppStateNotifier.testIsFirebaseInitialized = null;
        expect(notifier.isFirebaseInitialized, isFalse);

        notifier.dispose();
      },
    );
  });
}
