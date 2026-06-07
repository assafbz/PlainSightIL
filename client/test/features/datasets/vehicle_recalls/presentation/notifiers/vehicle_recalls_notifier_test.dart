// ignore_for_file: subtype_of_sealed_class, close_sinks
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/data/models/vehicle_recall_model.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/presentation/notifiers/vehicle_recalls_notifier.dart';

// Fake implementations for Firestore classes
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
  group('VehicleRecallsNotifier Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    tearDown(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test('should initialize with empty records and loading true', () {
      final notifier = VehicleRecallsNotifier();
      expect(notifier.recallRecords, isEmpty);
      expect(notifier.isLoadingRecalls, isTrue);
    });

    test(
      'isFirebaseInitialized returns false when testIsFirebaseInitialized is false',
      () {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = VehicleRecallsNotifier();
        expect(notifier.isFirebaseInitialized, isFalse);
      },
    );

    test(
      'isFirebaseInitialized returns true when testIsFirebaseInitialized is true',
      () {
        AppStateNotifier.testIsFirebaseInitialized = true;
        final notifier = VehicleRecallsNotifier();
        expect(notifier.isFirebaseInitialized, isTrue);
      },
    );

    test(
      'isFirebaseInitialized catches exception when Firebase.apps is unavailable',
      () {
        AppStateNotifier.testIsFirebaseInitialized = null;
        AppStateNotifier.isTesting = false;
        final notifier = VehicleRecallsNotifier();
        expect(notifier.isFirebaseInitialized, isFalse);
        AppStateNotifier.isTesting = true;
      },
    );

    test('initRecallsListener loads mock data in testing mode', () async {
      final notifier = VehicleRecallsNotifier();
      notifier.initRecallsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.recallRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingRecalls, isFalse);
    });

    test(
      'initRecallsListener updates records from testFirestoreStream',
      () async {
        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = VehicleRecallsNotifier(
          testFirestoreStream: streamController.stream,
        );

        notifier.initRecallsListener();
        expect(notifier.isLoadingRecalls, isTrue);

        // Emit data snapshot
        final mapData = {
          'recallId': 12345,
          'recallYear': 2026,
          'manufacturerName': 'Toyota',
          'modelName': 'Corolla',
          'recallType': 'Safety',
          'defectDescription': 'Brake issue',
          'defectCategory': 'Brakes',
          'buildStartDate': '2025-01-01',
          'buildEndDate': '2025-12-31',
          'lastUpdated': '2026-06-01T00:00:00Z',
          'createdAt': '2026-06-01T00:00:00Z',
          'scrapedAt': '2026-06-01T00:00:00Z',
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', mapData);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

        streamController.add(fakeSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingRecalls, isFalse);
        expect(notifier.recallRecords.length, 1);
        expect(notifier.recallRecords.first.recallId, 12345);
        expect(notifier.recallRecords.first.manufacturerName, 'Toyota');

        // Emit error
        streamController.addError('Connection Error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.isLoadingRecalls, isFalse);

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initRecallsListener fallback when stream is null and firebase is not initialized',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = VehicleRecallsNotifier();
        notifier.initRecallsListener();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.recallRecords, isEmpty);
        expect(notifier.isLoadingRecalls, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test('cancelRecallsListener resets state', () async {
      final notifier = VehicleRecallsNotifier();
      notifier.initRecallsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.recallRecords.isNotEmpty, isTrue);

      notifier.cancelRecallsListener();
      expect(notifier.recallRecords, isEmpty);
      expect(notifier.isLoadingRecalls, isTrue);
    });

    test('cancelRecallsListener cancels active subscription', () async {
      final controller =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = VehicleRecallsNotifier(
        testFirestoreStream: controller.stream,
      );

      notifier.initRecallsListener();
      notifier.cancelRecallsListener();
      expect(notifier.recallRecords, isEmpty);
      expect(notifier.isLoadingRecalls, isTrue);

      await controller.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'calling initRecallsListener twice cancels previous subscription',
      () async {
        final notifier = VehicleRecallsNotifier();
        notifier.initRecallsListener();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final firstRecords = notifier.recallRecords.length;

        // Second call should cancel and re-init
        notifier.initRecallsListener();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.recallRecords.length, firstRecords);
      },
    );

    test('dispose prevents further notifications', () async {
      final notifier = VehicleRecallsNotifier();
      notifier.initRecallsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      notifier.dispose();
      expect(() => notifier.notifyListeners(), returnsNormally);
    });

    test('notifyListeners does not throw after dispose', () {
      final notifier = VehicleRecallsNotifier();
      notifier.dispose();
      expect(() => notifier.notifyListeners(), returnsNormally);
    });

    test('notifyListeners schedules microtask when not disposed', () async {
      final notifier = VehicleRecallsNotifier();
      bool listenerCalled = false;
      notifier.addListener(() {
        listenerCalled = true;
      });
      notifier.notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(listenerCalled, isTrue);
      notifier.dispose();
    });

    test('getRecordLastUpdated extraction callback works', () {
      final notifier = VehicleRecallsNotifier(isTesting: true);
      final manager = notifier.syncManagerForTesting;
      expect(
        manager.getRecordLastUpdated(
          VehicleRecallRecordModel.fromMap({'lastUpdated': '2026-06-02'}),
        ),
        '2026-06-02',
      );
      expect(
        manager.getRecordLastUpdated(VehicleRecallRecordModel.fromMap({})),
        '',
      );
      notifier.dispose();
    });
  });
}
