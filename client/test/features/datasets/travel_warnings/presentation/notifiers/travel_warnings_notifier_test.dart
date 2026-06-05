import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/travel_warnings/presentation/notifiers/travel_warnings_notifier.dart';

class FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  });
}
