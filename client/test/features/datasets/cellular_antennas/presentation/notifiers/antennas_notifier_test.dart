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
  });
}
