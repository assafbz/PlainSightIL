import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';

void main() {
  group('PermitsNotifier Tests', () {
    test('initPermitMetadataListener updates records in offline mock mode', () {
      AppStateNotifier.isTesting = true;
      final notifier = PermitsNotifier(isTesting: true);
      notifier.initPermitMetadataListener();
      expect(notifier.isLoadingPermits, isFalse);
      expect(notifier.permitRecords.isNotEmpty, isTrue);
      notifier.dispose();
    });
  });
}
