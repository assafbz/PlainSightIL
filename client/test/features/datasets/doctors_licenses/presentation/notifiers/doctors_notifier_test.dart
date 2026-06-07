import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DoctorsNotifier Tests', () {
    test('initDoctorsListener updates doctor records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = DoctorsNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initDoctorsListener();
      expect(notifier.isLoadingDoctors, isTrue);

      final record = {
        'id': '1',
        '_id': 101,
        'firstName': 'מריו',
        'lastName': 'קורוב',
        'licenseNumber': 4267,
        'licenseRegistrationDate': '1969-07-28T00:00:00.000Z',
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingDoctors, isFalse);
      expect(notifier.doctorRecords.length, 1);
      expect(notifier.doctorRecords.first.licenseNumber, 4267);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingDoctors, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initDoctorsListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = DoctorsNotifier(isTesting: false);
        notifier.initDoctorsListener();
        expect(notifier.isLoadingDoctors, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'DoctorsNotifier handles real Firestore stream and error path',
      () async {
        final doctorsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == '9c64c522-bbc2-48fe-96fb-3b2a8626f59e') {
            return FakeCollectionReference(stream: doctorsController.stream);
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = DoctorsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );

        // Coverage for isFirebaseInitialized lines 33, 38
        AppStateNotifier.testIsFirebaseInitialized = null;
        expect(notifier.isFirebaseInitialized, isA<bool>());
        AppStateNotifier.testIsFirebaseInitialized = true;

        notifier.initDoctorsListener();

        doctorsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'id': 'doc1',
              'licenseNumber': 8888,
              'lastUpdated': '2026-06-01T00:00:00Z',
            }),
            FakeQueryDocumentSnapshot('doc2', {
              'id': 'doc2',
              'licenseNumber': 9999,
              'lastUpdated': '2026-06-02T00:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingDoctors, isFalse);
        expect(notifier.doctorRecords.first.licenseNumber, 9999);

        doctorsController.addError('Doctors Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingDoctors, isFalse);

        notifier.dispose();
        await doctorsController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'DoctorsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = DoctorsNotifier(isTesting: false);
        notifier.initDoctorsListener();
        expect(notifier.isLoadingDoctors, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('DoctorsNotifier handles snapshots exception', () async {
      AppStateNotifier.isTesting = false;
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Firestore exception');
      });
      final notifierDoc = DoctorsNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifierDoc.initDoctorsListener();
      expect(notifierDoc.isLoadingDoctors, isFalse);
      notifierDoc.dispose();
      AppStateNotifier.isTesting = true;
    });
  });
}
