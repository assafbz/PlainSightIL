import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';

void main() {
  group('BankAtmsNotifier Tests', () {
    test('initBankAtmsListener updates records in offline mock mode', () {
      AppStateNotifier.isTesting = true;
      final notifier = BankAtmsNotifier(isTesting: true);
      notifier.initBankAtmsListener();
      expect(notifier.isLoadingAtms, isFalse);
      expect(notifier.atmRecords.isNotEmpty, isTrue);
      notifier.dispose();
    });
  });
}
