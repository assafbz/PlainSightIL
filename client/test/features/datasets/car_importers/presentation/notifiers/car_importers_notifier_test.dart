// ignore_for_file: subtype_of_sealed_class, inference_failure_on_function_return_type, unused_import, depend_on_referenced_packages, prefer_initializing_formals, unnecessary_non_null_assertion, unused_local_variable, unawaited_futures, close_sinks
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/car_importers/presentation/notifiers/car_importers_notifier.dart';
import 'package:plainsight/features/datasets/car_importers/data/models/car_importer_record_model.dart';

// Fake implementations for Firestore classes using dynamic noSuchMethod delegation
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

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  FakeCollectionReference(this._stream);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return _stream;
    }
    if (invocation.memberName == #orderBy || invocation.memberName == #limit) {
      return this;
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeFirestore implements FirebaseFirestore {
  final CollectionReference<Map<String, dynamic>> _collection;
  FakeFirestore(this._collection);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) {
      return _collection;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('CarImportersNotifier Tests', () {
    test('initCarImportersListener updates car importer records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = CarImportersNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initCarImportersListener();
      expect(notifier.isLoadingCarImporters, isTrue);

      final record = {
        'id': '1',
        '_id': 101,
        'importerCode': 10,
        'importerName': 'קרסו',
        'modelType': 'P',
        'makerCode': 928,
        'makerName': 'רנו',
        'modelCode': 1000,
        'modelName': 'Twingo',
        'productionYear': 1996,
        'price': 54950,
        'commercialName': 'Twingo 2.1',
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingCarImporters, isFalse);
      expect(notifier.carImporterRecords.length, 1);
      expect(notifier.carImporterRecords.first.price, 54950);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingCarImporters, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initCarImportersListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = CarImportersNotifier(isTesting: false);
        notifier.initCarImportersListener();
        expect(notifier.isLoadingCarImporters, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test('cancelCarImportersListener resets status', () {
      final notifier = CarImportersNotifier(isTesting: true);
      notifier.initCarImportersListener();
      expect(notifier.carImporterRecords.isNotEmpty, isTrue);

      notifier.cancelCarImportersListener();
      expect(notifier.carImporterRecords, isEmpty);
      expect(notifier.isLoadingCarImporters, isTrue);
      notifier.dispose();
    });

    test('isFirebaseInitialized returns mock states correctly', () {
      final notifier = CarImportersNotifier();
      AppStateNotifier.testIsFirebaseInitialized = true;
      expect(notifier.isFirebaseInitialized, isTrue);

      AppStateNotifier.testIsFirebaseInitialized = false;
      expect(notifier.isFirebaseInitialized, isFalse);

      AppStateNotifier.testIsFirebaseInitialized = null;
      expect(
        notifier.isFirebaseInitialized,
        isFalse,
      ); // default try-catch fallback in tests
    });

    test(
      'real-time collection reference stream parsing and error handling',
      () async {
        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final fakeCollection = FakeCollectionReference(streamController.stream);
        final fakeFirestore = FakeFirestore(fakeCollection);

        AppStateNotifier.testIsFirebaseInitialized = true;
        AppStateNotifier.isTesting = false;

        final notifier = CarImportersNotifier(testFirestore: fakeFirestore);

        notifier.initCarImportersListener();
        expect(notifier.isLoadingCarImporters, isTrue);

        final record = {
          'id': '10',
          '_id': 10,
          'importerCode': 10,
          'importerName': 'קרסו',
          'modelType': 'P',
          'makerCode': 928,
          'makerName': 'רנו',
          'modelCode': 1000,
          'modelName': 'Twingo',
          'productionYear': 1996,
          'price': 54950,
          'commercialName': 'Twingo 2.1',
        };
        final fakeDoc = FakeQueryDocumentSnapshot('10', record);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

        streamController.add(fakeSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingCarImporters, isFalse);
        expect(notifier.carImporterRecords.length, 1);
        expect(notifier.carImporterRecords.first.id, '10');

        streamController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.isLoadingCarImporters, isFalse);

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'notifyListeners scheduled microtask execution and disposed safety',
      () async {
        final notifier = CarImportersNotifier();
        var count = 0;
        notifier.addListener(() {
          count++;
        });

        notifier.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(count, 1);

        notifier.dispose();
        notifier.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(count, 1); // no additional count increment after dispose
      },
    );

    test(
      'initCarImportersListener handles exceptions in collection retrieval',
      () {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;
        final notifier = CarImportersNotifier(
          testFirestore: ThrowingFirestore(),
        );
        notifier.initCarImportersListener();
        expect(notifier.isLoadingCarImporters, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );
  });
}

class ThrowingFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) {
      throw Exception('Simulated collection lookup failure');
    }
    return super.noSuchMethod(invocation);
  }
}
