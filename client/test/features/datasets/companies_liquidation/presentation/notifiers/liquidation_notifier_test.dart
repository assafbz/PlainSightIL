import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiquidationNotifier Tests', () {
    test('initLiquidationListener updates liquidation records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = LiquidationNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initLiquidationListener();
      expect(notifier.isLoadingLiquidation, isTrue);

      final record = {
        'liquidationCaseId': 12345,
        'cityOfActivity': 'תל אביב',
        'districtCourt': 'מחוזי תל אביב',
        'companyName': 'אלברט לוי',
        'companyId': 512345678,
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingLiquidation, isFalse);
      expect(notifier.liquidationRecords.length, 1);
      expect(notifier.liquidationRecords.first.liquidationCaseId, 12345);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingLiquidation, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initLiquidationListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = LiquidationNotifier(isTesting: false);
        notifier.initLiquidationListener();
        expect(notifier.isLoadingLiquidation, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'LiquidationNotifier handles real Firestore stream and error path',
      () async {
        final liquidationController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3') {
            return FakeCollectionReference(
              stream: liquidationController.stream,
            );
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = LiquidationNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );

        // Coverage for isFirebaseInitialized lines 33, 38
        AppStateNotifier.testIsFirebaseInitialized = null;
        expect(notifier.isFirebaseInitialized, isA<bool>());
        AppStateNotifier.testIsFirebaseInitialized = true;

        notifier.initLiquidationListener();

        liquidationController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('liq1', {
              'liquidationCaseId': 999,
              'companyName': 'Liquidation Case 1',
              'companyId': 512345678,
              'lastUpdated': '2026-06-01T00:00:00Z',
            }),
            FakeQueryDocumentSnapshot('liq2', {
              'liquidationCaseId': 1000,
              'companyName': 'Liquidation Case 2',
              'companyId': 512345679,
              'lastUpdated': '2026-06-02T00:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingLiquidation, isFalse);
        expect(notifier.liquidationRecords.first.liquidationCaseId, 1000);

        liquidationController.addError('Liquidation Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingLiquidation, isFalse);

        notifier.dispose();
        await liquidationController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'LiquidationNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = LiquidationNotifier(isTesting: false);
        notifier.initLiquidationListener();
        expect(notifier.isLoadingLiquidation, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('LiquidationNotifier handles snapshots exception', () async {
      AppStateNotifier.isTesting = false;
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Firestore exception');
      });
      final notifierLiq = LiquidationNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifierLiq.initLiquidationListener();
      expect(notifierLiq.isLoadingLiquidation, isFalse);
      notifierLiq.dispose();
      AppStateNotifier.isTesting = true;
    });
  });
}
