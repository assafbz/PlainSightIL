import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';

void main() {
  group('LiquidationNotifier Tests', () {
    test('initLiquidationListener updates records in offline mock mode', () {
      AppStateNotifier.isTesting = true;
      final notifier = LiquidationNotifier(isTesting: true);
      notifier.initLiquidationListener();
      expect(notifier.isLoadingLiquidation, isFalse);
      expect(notifier.liquidationRecords.isNotEmpty, isTrue);
      notifier.dispose();
    });
  });
}
