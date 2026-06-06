import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';

void main() {
  group('DoctorsNotifier Tests', () {
    test('initDoctorsListener updates records in offline mock mode', () {
      AppStateNotifier.isTesting = true;
      final notifier = DoctorsNotifier(isTesting: true);
      notifier.initDoctorsListener();
      expect(notifier.isLoadingDoctors, isFalse);
      expect(notifier.doctorRecords.isNotEmpty, isTrue);
      notifier.dispose();
    });
  });
}
