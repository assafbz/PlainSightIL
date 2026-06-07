import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AntennasNotifier Tests', () {
    test(
      'initAntennaListener updates records from testFirestoreStream',
      () async {
        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = AntennasNotifier(
          isTesting: false,
          testFirestoreStream: streamController.stream,
        );

        expect(notifier.isLoadingAntennas, isTrue);
        notifier.initAntennaListener();

        // Emit data snapshot
        final mapData = {
          'antennaId': 'CELL-100',
          'addressHebrew': 'Dizengoff 50',
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', mapData);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

        streamController.add(fakeSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingAntennas, isFalse);
        expect(notifier.antennaRecords.length, 1);
        expect(notifier.antennaRecords.first['antennaId'], 'CELL-100');

        // Emit error
        streamController.addError('Connection Error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          notifier.isLoadingAntennas,
          isFalse,
        ); // Keeps loading state as false

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initAntennaListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = AntennasNotifier(isTesting: false);
        notifier.initAntennaListener();
        expect(notifier.isLoadingAntennas, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'AntennasNotifier handles real Firestore streams and error path',
      () async {
        final antennaController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

        final mockFirestoreOptions = FakeFirebaseFirestore((path) {
          if (path == '8935c8e5-ec77-421f-af86-d970583195f8') {
            return FakeCollectionReference(stream: antennaController.stream);
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = AntennasNotifier(
          isTesting: false,
          testFirestore: mockFirestoreOptions,
        );
        expect(notifier.isLoadingAntennas, isTrue);

        notifier.initAntennaListener();

        antennaController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'antennaId': 'CELL-200',
              'operatorName': 'Partner',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAntennas, isFalse);
        expect(notifier.antennaRecords.first['antennaId'], 'CELL-200');

        antennaController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAntennas, isFalse);

        notifier.dispose();
        await antennaController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'AntennasNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = AntennasNotifier(isTesting: false);
        notifier.initAntennaListener();
        expect(notifier.isLoadingAntennas, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('AntennasNotifier handles Firestore snapshots exception', () async {
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Collection snapshots exception');
      });
      final notifier = AntennasNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifier.initAntennaListener();
      expect(notifier.isLoadingAntennas, isFalse);
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
