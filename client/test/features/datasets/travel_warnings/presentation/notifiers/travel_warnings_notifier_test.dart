import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/travel_warnings/presentation/notifiers/travel_warnings_notifier.dart';
import 'package:plainsight/features/datasets/travel_warnings/data/models/travel_warning_model.dart';
import '../../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TravelWarningsNotifier Tests', () {
    test(
      'initTravelWarningsListener updates records in offline mock mode',
      () async {
        AppStateNotifier.isTesting = true;
        final notifier = TravelWarningsNotifier();
        notifier.initTravelWarningsListener();
        expect(notifier.isLoadingWarnings, isFalse);
        expect(notifier.warningRecords.isNotEmpty, isTrue);
        expect(notifier.warningRecords.first.country, 'אוגנדה');
        notifier.dispose();
      },
    );

    test(
      'initTravelWarningsListener with custom testFirestoreStream',
      () async {
        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        AppStateNotifier.isTesting = false;
        final notifier = TravelWarningsNotifier(
          isTesting: false,
          testFirestoreStream: streamController.stream,
        );

        notifier.initTravelWarningsListener();
        expect(notifier.isLoadingWarnings, isTrue);

        final record = {
          'id': '1',
          '_id': 1,
          'continent': 'אפריקה',
          'country': 'אוגנדה',
          'recommendations': 'רמה 2/ איום מזדמן',
          'details': 'פרטים',
          'logo': 'לוגו',
          'date': '2026-06-03',
          'office': 'מל"ל',
          'warningLevel': 2,
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', record);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

        streamController.add(fakeSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(notifier.isLoadingWarnings, isFalse);
        expect(notifier.warningRecords.length, 1);
        expect(notifier.warningRecords.first.country, 'אוגנדה');

        streamController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingWarnings, isFalse);

        notifier.cancelTravelWarningsListener();
        expect(notifier.warningRecords, isEmpty);
        expect(notifier.isLoadingWarnings, isTrue);

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'TravelWarningsNotifier handles real Firestore stream and error path',
      () async {
        final travelWarningsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == '2a01d234-b2b0-4d46-baa0-cec05c401e7d') {
            return FakeCollectionReference(
              stream: travelWarningsController.stream,
            );
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = TravelWarningsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initTravelWarningsListener();

        travelWarningsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'id': '1',
              '_id': 1,
              'continent': 'אפריקה',
              'country': 'אוגנדה',
              'recommendations': 'רמה 2/ איום מזדמן',
              'details': 'פרטים',
              'logo': 'לוגו',
              'date': '2026-06-03',
              'office': 'מל"ל',
              'warningLevel': 2,
              'lastUpdated': '2026-06-03T00:00:00Z',
            }),
            FakeQueryDocumentSnapshot('doc2', {
              'id': '2',
              '_id': 2,
              'continent': 'אירופה',
              'country': 'צרפת',
              'recommendations': 'רמה 1/ איום פוטנציאלי',
              'details': 'פרטים צרפת',
              'logo': 'לוגו צרפת',
              'date': '2026-06-04',
              'office': 'מל"ל',
              'warningLevel': 1,
              'lastUpdated': '2026-06-04T00:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingWarnings, isFalse);
        expect(notifier.warningRecords.first.id, '2');
        expect(notifier.warningRecords.first.country, 'צרפת');
        expect(notifier.warningRecords.first.warningLevel, 1);

        travelWarningsController.addError('Warnings Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingWarnings, isFalse);

        notifier.cancelTravelWarningsListener();
        expect(notifier.warningRecords, isEmpty);
        expect(notifier.isLoadingWarnings, isTrue);

        notifier.dispose();
        await travelWarningsController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'TravelWarningsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = TravelWarningsNotifier(isTesting: false);
        notifier.initTravelWarningsListener();
        expect(notifier.isLoadingWarnings, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'TravelWarningsNotifier isFirebaseInitialized handles default Firebase.apps check',
      () {
        AppStateNotifier.testIsFirebaseInitialized = null;
        final notifier = TravelWarningsNotifier(isTesting: false);
        final isInit = notifier.isFirebaseInitialized;
        expect(isInit, isA<bool>());
        notifier.dispose();
      },
    );

    test('AppStateNotifier travel warnings delegates coverage', () async {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = true;
      final appState = AppStateNotifier();

      expect(appState.warningRecords, isA<List<TravelWarningRecordModel>>());
      expect(appState.isLoadingWarnings, isA<bool>());

      appState.initTravelWarningsListener();
      appState.cancelTravelWarningsListener();

      appState.dispose();
    });

    test(
      'TravelWarningsNotifier handles Firestore snapshots exception',
      () async {
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Collection snapshots exception');
        });
        final notifier = TravelWarningsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifier.initTravelWarningsListener();
        expect(notifier.isLoadingWarnings, isFalse);
        notifier.dispose();
      },
    );
  });
}
