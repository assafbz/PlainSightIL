import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BankAtmsNotifier Tests', () {
    test('initBankAtmsListener updates bank ATM records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = BankAtmsNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initBankAtmsListener();
      expect(notifier.isLoadingAtms, isTrue);

      final record = {
        'id': '1',
        'atmNum': 3777,
        'bankCode': 12,
        'bankName': {'he': 'בנק הפועלים', 'en': 'Bank Hapoalim'},
        'branchCode': 377,
        'address': 'שד\' התמרים 11',
        'addressExtra': 'שדרות התמרים 11',
        'city': 'אילת',
        'atmLocation': {'he': 'בתוך הסניף', 'en': 'Inside Branch'},
        'coordinates': {'latitude': 29.555, 'longitude': 34.952},
        'geohash': 'sv0bh5bpb',
        'hasCommission': false,
        'hasCashWithdrawal': true,
        'hasCashDeposit': true,
        'hasChequeDeposit': true,
        'hasEnvelopeDeposit': true,
        'hasForexTransaction': true,
        'hasAdditionalTransactions': true,
        'hasHandicapAccess': true,
        'lastUpdated': '2026-06-02T09:00:00Z',
        'createdAt': '2026-06-02T09:00:00Z',
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingAtms, isFalse);
      expect(notifier.atmRecords.length, 1);
      expect(notifier.atmRecords.first.atmNum, 3777);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingAtms, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initBankAtmsListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = BankAtmsNotifier(isTesting: false);
        notifier.initBankAtmsListener();
        expect(notifier.isLoadingAtms, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'BankAtmsNotifier handles real Firestore streams and error path',
      () async {
        final bankAtmsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == DatasetIds.bankAtms) {
            return FakeCollectionReference(stream: bankAtmsController.stream);
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = BankAtmsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );

        // Coverage for isFirebaseInitialized lines 33, 38
        AppStateNotifier.testIsFirebaseInitialized = null;
        expect(notifier.isFirebaseInitialized, isA<bool>());
        AppStateNotifier.testIsFirebaseInitialized = true;

        expect(notifier.isLoadingAtms, isTrue);

        notifier.initBankAtmsListener();

        bankAtmsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'id': '1',
              'atmNum': 3777,
              'bankCode': 12,
              'bankName': {'he': 'בנק הפועלים', 'en': 'Bank Hapoalim'},
              'branchCode': 377,
              'address': 'שד\' התמרים 11',
              'addressExtra': 'שדרות התמרים 11',
              'city': 'אילת',
              'atmLocation': {'he': 'בתוך הסניף', 'en': 'Inside Branch'},
              'coordinates': {'latitude': 29.555, 'longitude': 34.952},
              'geohash': 'sv0bh5bpb',
              'hasCommission': false,
              'hasCashWithdrawal': true,
              'hasCashDeposit': true,
              'hasChequeDeposit': true,
              'hasEnvelopeDeposit': true,
              'hasForexTransaction': true,
              'hasAdditionalTransactions': true,
              'hasHandicapAccess': true,
              'lastUpdated': '2026-06-02T09:00:00Z',
              'createdAt': '2026-06-02T09:00:00Z',
            }),
            FakeQueryDocumentSnapshot('doc2', {
              'id': '2',
              'atmNum': 5001,
              'bankCode': 10,
              'bankName': {'he': 'בנק לאומי', 'en': 'Bank Leumi'},
              'branchCode': 800,
              'address': 'דיזנגוף 50',
              'addressExtra': 'דיזנגוף 50',
              'city': 'תל אביב',
              'atmLocation': {'he': 'על קיר הסניף', 'en': 'On Branch Wall'},
              'coordinates': {'latitude': 32.075, 'longitude': 34.774},
              'geohash': 'sv8wrg6p7',
              'hasCommission': true,
              'hasCashWithdrawal': true,
              'hasCashDeposit': false,
              'hasChequeDeposit': false,
              'hasEnvelopeDeposit': false,
              'hasForexTransaction': false,
              'hasAdditionalTransactions': false,
              'hasHandicapAccess': true,
              'lastUpdated': '2026-06-03T09:00:00Z',
              'createdAt': '2026-06-03T09:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAtms, isFalse);
        expect(notifier.atmRecords.first.id, '2');
        expect(notifier.atmRecords.first.atmNum, 5001);

        bankAtmsController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAtms, isFalse);

        notifier.dispose();
        await bankAtmsController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'BankAtmsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = BankAtmsNotifier(isTesting: false);
        notifier.initBankAtmsListener();
        expect(notifier.isLoadingAtms, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('BankAtmsNotifier handles Firestore snapshots exception', () async {
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Collection snapshots exception');
      });
      final notifier = BankAtmsNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifier.initBankAtmsListener();
      expect(notifier.isLoadingAtms, isFalse);
      notifier.dispose();
    });

    test(
      'BankAtmsNotifier cancel listener resets records and loading flags',
      () {
        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });
        final notifier = BankAtmsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initBankAtmsListener();
        notifier.cancelBankAtmsListener();
        expect(notifier.atmRecords, isEmpty);
        expect(notifier.isLoadingAtms, isTrue);
        notifier.dispose();
      },
    );
  });
}
