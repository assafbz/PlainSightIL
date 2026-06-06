// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

// Reuse mock Firestore classes from feature tests
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

class FakeFirebaseFirestore implements FirebaseFirestore {
  final CollectionReference Function(String) collectionBuilder;
  FakeFirebaseFirestore(this.collectionBuilder);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return collectionBuilder(path) as CollectionReference<Map<String, dynamic>>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  FakeCollectionReference({this.stream});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      return this;
    }
    if (invocation.memberName == #snapshots) {
      return stream ??
          const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return super.noSuchMethod(invocation);
  }
}

// Simple record class for generic testing
class TestRecord {
  final String id;
  final String lastUpdated;
  final String val;

  TestRecord({required this.id, required this.lastUpdated, required this.val});

  factory TestRecord.fromMap(Map<String, dynamic> map) {
    return TestRecord(
      id: map['id'] as String? ?? '',
      lastUpdated: map['lastUpdated'] as String? ?? '',
      val: map['val'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'lastUpdated': lastUpdated, 'val': val};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatasetSyncManager Tests', () {
    const String datasetId = 'test_dataset_id';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    tearDown(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test('should initialize with loading true and empty records', () {
      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {},
      );

      expect(manager.records, isEmpty);
      expect(manager.isLoading, isTrue);
      expect(manager.isSyncing, isFalse);
    });

    test('should load mock data directly in testing mode', () async {
      final mockList = [
        TestRecord(id: '1', lastUpdated: '2026-06-01T00:00:00Z', val: 'A'),
        TestRecord(id: '2', lastUpdated: '2026-06-02T00:00:00Z', val: 'B'),
      ];

      bool callbackCalled = false;
      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {
          callbackCalled = true;
        },
      );

      await manager.initialize(mockData: mockList, isTesting: true);

      expect(manager.records.length, 2);
      expect(manager.records.first.id, '1');
      expect(manager.isLoading, isFalse);
      expect(manager.isSyncing, isFalse);
      expect(callbackCalled, isTrue);
    });

    test('should parse cache and sync updates from stream', () async {
      final prefs = await SharedPreferences.getInstance();
      // Setup initial cache
      const cachedJson =
          '[{"id":"1","lastUpdated":"2026-06-01T00:00:00Z","val":"A"}]';
      await prefs.setString('dataset_cache_$datasetId', cachedJson);

      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      bool stateChanged = false;

      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {
          stateChanged = true;
        },
      );

      // Initialize with testing = false but using stream injection
      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      // Verify cached record loaded immediately
      expect(stateChanged, isTrue);
      expect(manager.isLoading, isFalse);
      expect(manager.records.length, 1);
      expect(manager.records.first.val, 'A');

      // Inject update snapshot containing:
      // - an update to existing record '1'
      // - a new record '2'
      final updateDocs = [
        FakeQueryDocumentSnapshot('1', {
          'id': '1',
          'lastUpdated': '2026-06-03T00:00:00Z',
          'val': 'A-Updated',
        }),
        FakeQueryDocumentSnapshot('2', {
          'id': '2',
          'lastUpdated': '2026-06-04T00:00:00Z',
          'val': 'B',
        }),
      ];
      final snapshot = FakeQuerySnapshot(updateDocs);

      streamController.add(snapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify merged, sorted (newest first by lastUpdated)
      expect(manager.records.length, 2);
      expect(manager.records[0].id, '2'); // B is newer (June 4)
      expect(manager.records[0].val, 'B');
      expect(manager.records[1].id, '1'); // A-Updated is older (June 3)
      expect(manager.records[1].val, 'A-Updated');

      // Verify it writes back to cache
      final newCache = prefs.getString('dataset_cache_$datasetId');
      expect(newCache, contains('A-Updated'));
      expect(newCache, contains('B'));

      // Clean up
      await manager.cancel();
      expect(manager.records, isEmpty);
      expect(manager.isLoading, isTrue);

      await streamController.close();
      manager.dispose();
    });

    test('should handle custom comparator sorting', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {},
        // Custom sort by value ascending
        sortComparator: (a, b) => a.val.compareTo(b.val),
      );

      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      final docs = [
        FakeQueryDocumentSnapshot('1', {
          'id': '1',
          'lastUpdated': '2026-06-01T00:00:00Z',
          'val': 'Z',
        }),
        FakeQueryDocumentSnapshot('2', {
          'id': '2',
          'lastUpdated': '2026-06-02T00:00:00Z',
          'val': 'K',
        }),
        FakeQueryDocumentSnapshot('3', {
          'id': '3',
          'lastUpdated': '2026-06-03T00:00:00Z',
          'val': 'M',
        }),
      ];
      streamController.add(FakeQuerySnapshot(docs));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Sorted alphabetically: K, M, Z
      expect(manager.records[0].val, 'K');
      expect(manager.records[1].val, 'M');
      expect(manager.records[2].val, 'Z');

      await streamController.close();
      manager.dispose();
    });

    test('should notify listeners and print error on stream failure', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      bool stateChanged = false;

      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {
          stateChanged = true;
        },
      );

      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      stateChanged = false;
      streamController.addError('Connection issues');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(manager.isSyncing, isFalse);
      expect(stateChanged, isTrue);

      await streamController.close();
      manager.dispose();
    });

    Future<void> waitForCondition(
      bool Function() condition, {
      int timeoutMs = 1000,
    }) async {
      final startTime = DateTime.now();
      while (!condition()) {
        if (DateTime.now().difference(startTime).inMilliseconds > timeoutMs) {
          throw TimeoutException('Condition not met within $timeoutMs ms');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test(
      'should run production path with forceProductionAsync and fetch delta',
      () async {
        final prefs = await SharedPreferences.getInstance();
        // Setup initial cache
        const cachedJson =
            '[{"id":"1","lastUpdated":"2026-06-01T00:00:00Z","val":"A"}]';
        await prefs.setString('dataset_cache_$datasetId', cachedJson);

        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference(stream: streamController.stream);
        });

        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = true;

        await manager.initialize(
          isTesting: false,
          testFirestore: mockFirestore,
          forceProductionAsync: true,
        );

        // Verify cached records loaded
        await waitForCondition(() => manager.records.length == 1);
        expect(manager.records.first.val, 'A');

        // Add updates to stream
        final updateDocs = [
          FakeQueryDocumentSnapshot('1', {
            'id': '1',
            'lastUpdated': '2026-06-03T00:00:00Z',
            'val': 'A-Updated',
          }),
          FakeQueryDocumentSnapshot('2', {
            'id': '2',
            'lastUpdated': '2026-06-04T00:00:00Z',
            'val': 'B',
          }),
        ];
        streamController.add(FakeQuerySnapshot(updateDocs));
        await waitForCondition(() => manager.records.length == 2);

        expect(manager.records[0].val, 'B');

        await streamController.close();
        manager.dispose();
      },
    );

    test(
      'should run production path with forceProductionAsync when Firebase is not initialized',
      () async {
        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = false;

        await manager.initialize(isTesting: false, forceProductionAsync: true);

        await waitForCondition(() => !manager.isLoading);
        expect(manager.isLoading, isFalse);
        expect(manager.isSyncing, isFalse);
        manager.dispose();
      },
    );

    test(
      'should handle exceptions in production path when Firestore query throws',
      () async {
        final mockFirestore = FakeFirebaseFirestore((path) {
          throw Exception('Collection query exception');
        });

        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = true;

        await manager.initialize(
          isTesting: false,
          testFirestore: mockFirestore,
          forceProductionAsync: true,
        );

        await waitForCondition(() => !manager.isLoading);
        expect(manager.isLoading, isFalse);
        expect(manager.isSyncing, isFalse);
        manager.dispose();
      },
    );

    test('should cancel existing subscription on re-initialization', () async {
      final streamController1 =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final streamController2 =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {},
      );

      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController1.stream,
      );

      // Initialize again to trigger subscription cancellation
      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController2.stream,
      );

      await streamController1.close();
      await streamController2.close();
      manager.dispose();
    });

    test('should handle empty snapshot and update state', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {},
      );

      await manager.initialize(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      streamController.add(FakeQuerySnapshot([]));
      await waitForCondition(() => !manager.isLoading);

      expect(manager.records, isEmpty);
      expect(manager.isLoading, isFalse);
      expect(manager.isSyncing, isFalse);

      await streamController.close();
      manager.dispose();
    });

    test(
      'should handle cache parsing exceptions gracefully in production path',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dataset_cache_$datasetId', '{corrupted_json');

        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference(stream: streamController.stream);
        });

        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = true;

        await manager.initialize(
          isTesting: false,
          testFirestore: mockFirestore,
          forceProductionAsync: true,
        );

        streamController.add(FakeQuerySnapshot([]));
        await waitForCondition(() => !manager.isLoading);
        expect(manager.records, isEmpty);

        await streamController.close();
        manager.dispose();
      },
    );

    test(
      'should skip sync in production path if Firebase is not initialized',
      () async {
        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = false;

        await manager.initialize(
          isTesting: false,
          testFirestoreStream: const Stream.empty(),
          forceProductionAsync: true,
        );

        await waitForCondition(() => !manager.isLoading);
        expect(manager.isLoading, isFalse);
        expect(manager.isSyncing, isFalse);
        manager.dispose();
      },
    );

    test(
      'should fallback to FirebaseFirestore.instance and handle exception if Firebase is not initialized',
      () async {
        final manager = DatasetSyncManager<TestRecord>(
          datasetId: datasetId,
          fromMap: TestRecord.fromMap,
          toMap: (r) => r.toMap(),
          getRecordId: (r) => r.id,
          getRecordLastUpdated: (r) => r.lastUpdated,
          onStateChanged: () {},
        );

        AppStateNotifier.testIsFirebaseInitialized = true;

        await manager.initialize(
          isTesting: false,
          testFirestore: null,
          forceProductionAsync: true,
        );

        await waitForCondition(() => !manager.isLoading);
        expect(manager.isLoading, isFalse);
        expect(manager.isSyncing, isFalse);
        manager.dispose();
      },
    );

    test('should handle stream errors in production path', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final mockFirestore = FakeFirebaseFirestore((path) {
        return FakeCollectionReference(stream: streamController.stream);
      });

      final manager = DatasetSyncManager<TestRecord>(
        datasetId: datasetId,
        fromMap: TestRecord.fromMap,
        toMap: (r) => r.toMap(),
        getRecordId: (r) => r.id,
        getRecordLastUpdated: (r) => r.lastUpdated,
        onStateChanged: () {},
      );

      AppStateNotifier.testIsFirebaseInitialized = true;

      await manager.initialize(
        isTesting: false,
        testFirestore: mockFirestore,
        forceProductionAsync: true,
      );

      streamController.addError('Production path stream error');
      await waitForCondition(() => !manager.isSyncing);

      expect(manager.isLoading, isFalse);
      expect(manager.isSyncing, isFalse);

      await streamController.close();
      manager.dispose();
    });
  });
}
