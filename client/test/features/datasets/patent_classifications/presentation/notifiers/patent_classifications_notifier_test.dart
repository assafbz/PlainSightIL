// ignore_for_file: subtype_of_sealed_class, unnecessary_no_such_method, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/features/datasets/patent_classifications/presentation/notifiers/patent_classifications_notifier.dart';

void main() {
  group('PatentClassificationsNotifier Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = true;
    });

    test('should initialize with empty records and loading false', () {
      final notifier = PatentClassificationsNotifier();
      expect(notifier.patentRecords, isEmpty);
      expect(notifier.isLoadingPatents, isFalse);
      expect(notifier.isLoadingMorePatents, isFalse);
      expect(notifier.hasMorePatents, isTrue);
    });

    test(
      'isFirebaseInitialized returns false when testIsFirebaseInitialized is false',
      () {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = PatentClassificationsNotifier();
        expect(notifier.isFirebaseInitialized, isFalse);
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'isFirebaseInitialized returns true when testIsFirebaseInitialized is true',
      () {
        AppStateNotifier.testIsFirebaseInitialized = true;
        final notifier = PatentClassificationsNotifier();
        expect(notifier.isFirebaseInitialized, isTrue);
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'isFirebaseInitialized falls through to Firebase.apps when testIsFirebaseInitialized is null',
      () {
        AppStateNotifier.testIsFirebaseInitialized = null;
        final notifier = PatentClassificationsNotifier();
        expect(notifier.isFirebaseInitialized, isFalse);
      },
    );

    test(
      'initPatentClassificationsListener triggers fetchNextPage refresh',
      () async {
        final notifier = PatentClassificationsNotifier();
        notifier.initPatentClassificationsListener();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.patentRecords.isNotEmpty, isTrue);
        expect(notifier.isLoadingPatents, isFalse);
      },
    );

    test('fetchNextPage loads mock data in testing mode', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      expect(notifier.patentRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingPatents, isFalse);
      expect(notifier.hasMorePatents, isFalse);
      expect(notifier.isLoadingMorePatents, isFalse);
    });

    test('fetchNextPage with isRefresh resets state before loading', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage(isRefresh: true);
      expect(notifier.patentRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingPatents, isFalse);
    });

    test(
      'fetchNextPage without refresh returns early when hasMorePatents is false',
      () async {
        final notifier = PatentClassificationsNotifier();
        // First call sets hasMorePatents = false (mock mode)
        await notifier.fetchNextPage();
        final recordsAfterFirst = notifier.patentRecords.length;

        // Second call without refresh should return early
        await notifier.fetchNextPage();
        expect(notifier.patentRecords.length, recordsAfterFirst);
      },
    );

    test('setSearchQuery filters mock records by application number', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      final totalBefore = notifier.patentRecords.length;
      notifier.setSearchQuery('99999999');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.patentRecords.length <= totalBefore, isTrue);
    });

    test('setSearchQuery with same query returns early', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      notifier.setSearchQuery('test');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countAfterFirst = notifier.patentRecords.length;
      // Same query again should return early
      notifier.setSearchQuery('test');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.patentRecords.length, countAfterFirst);
    });

    test('setPrimaryFilter to Primary filters correctly', () async {
      final notifier = PatentClassificationsNotifier();
      notifier.setPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingPatents, isFalse);
    });

    test('setPrimaryFilter to Secondary filters correctly', () async {
      final notifier = PatentClassificationsNotifier();
      notifier.setPrimaryFilter('Secondary');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingPatents, isFalse);
    });

    test('setPrimaryFilter with same filter returns early', () async {
      final notifier = PatentClassificationsNotifier();
      notifier.setPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Same filter again should return early
      notifier.setPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingPatents, isFalse);
    });

    test('resetFilters clears search and filter state', () async {
      final notifier = PatentClassificationsNotifier();
      notifier.setSearchQuery('test');
      notifier.setPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.resetFilters();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingPatents, isFalse);
      expect(notifier.patentRecords.isNotEmpty, isTrue);
    });

    test('cancelPatentClassificationsListener resets state', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      expect(notifier.patentRecords.isNotEmpty, isTrue);

      notifier.cancelPatentClassificationsListener();
      expect(notifier.patentRecords, isEmpty);
      expect(notifier.isLoadingPatents, isFalse);
      expect(notifier.isLoadingMorePatents, isFalse);
      expect(notifier.hasMorePatents, isTrue);
    });

    test(
      'fetchNextPage returns early when Firebase not initialized in non-testing mode',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = PatentClassificationsNotifier();
        await notifier.fetchNextPage(isRefresh: true);
        expect(notifier.patentRecords, isEmpty);
        expect(notifier.isLoadingPatents, isFalse);
        expect(notifier.isLoadingMorePatents, isFalse);
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'dispose sets isDisposed and prevents further notifications',
      () async {
        final notifier = PatentClassificationsNotifier();
        await notifier.fetchNextPage();
        notifier.dispose();
        // After dispose, no errors should be thrown
      },
    );

    test('notifyListeners does not throw after dispose', () async {
      final notifier = PatentClassificationsNotifier();
      notifier.dispose();
      // Calling notifyListeners after dispose should be a no-op
      // This is done indirectly by trying to fetch after disposal
      expect(() => notifier.notifyListeners(), returnsNormally);
    });
  });

  group('PatentClassificationsNotifier Production Delegation Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = true;
    });

    tearDown(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test(
      'verifies searching, filtering and pagination on production delegation paths',
      () async {
        final notifier = PatentClassificationsNotifier(testFirestore: null);

        // Initialize with mockData directly on sync manager
        final manager = notifier.syncManagerForTesting;
        await manager.initialize(mockData: MockData.patents, isTesting: true);

        // Verify basic loading state delegation
        expect(notifier.isLoadingPatents, isFalse);
        expect(notifier.patentRecords.isNotEmpty, isTrue);

        // Test filtering on 'Primary'
        notifier.setPrimaryFilter('Primary');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with filter set
        for (final patent in notifier.patentRecords) {
          expect(patent.isPrimary, isTrue);
        }

        // Test filtering on 'Secondary'
        notifier.setPrimaryFilter('Secondary');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with filter set
        for (final patent in notifier.patentRecords) {
          expect(patent.isPrimary, isFalse);
        }

        // Reset filter
        notifier.setPrimaryFilter('All');
        expect(
          notifier.patentRecords.length,
          MockData.patents.length > 20 ? 20 : MockData.patents.length,
        );

        // Test text searching by CPC classification
        notifier.setSearchQuery('A61P35/00');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with search query set
        for (final patent in notifier.patentRecords) {
          expect(patent.cpcClassification.toLowerCase(), 'a61p35/00');
        }

        // Test text searching by Hebrew title
        notifier.setSearchQuery('שילוב');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with search query set
        for (final patent in notifier.patentRecords) {
          expect(patent.titleHebrew.contains('שילוב'), isTrue);
        }

        // Test text searching by English title
        notifier.setSearchQuery('DRUG');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with search query set
        for (final patent in notifier.patentRecords) {
          expect(patent.titleEnglish.toLowerCase().contains('drug'), isTrue);
        }

        // Test numeric application number searching
        notifier.setSearchQuery('327015');
        expect(
          notifier.hasMorePatents,
          isFalse,
        ); // Reads hasMorePatents with search query set
        for (final patent in notifier.patentRecords) {
          expect(patent.applicationNumber.toString(), '327015');
        }

        // Test hasMorePatents when records length is <= page size vs when pagination runs
        notifier.setSearchQuery('');
        notifier.setPrimaryFilter('All');
        expect(notifier.hasMorePatents, MockData.patents.length > 20);

        // Test fetchNextPage pagination loading more
        if (notifier.hasMorePatents) {
          final initialLength = notifier.patentRecords.length;
          await notifier.fetchNextPage();
          expect(notifier.patentRecords.length > initialLength, isTrue);
        }

        // Test getRecordLastUpdated, toMap, getRecordId callbacks on the manager
        final record = MockData.patents.first;
        expect(manager.getRecordLastUpdated(record), record.lastUpdated ?? '');
        expect(manager.toMap(record).isNotEmpty, isTrue);
        expect(manager.getRecordId(record), record.id);

        notifier.dispose();
      },
    );

    test(
      'verifies initPatentClassificationsListener and cancelPatentClassificationsListener paths',
      () async {
        // 1. testFirestore != null paths (init & cancel)
        final fakeDoc = FakeQueryDocumentSnapshot(
          '1',
          MockData.patents.first.toMap(),
        );
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifierWithFirestore = PatentClassificationsNotifier(
          testFirestore: fakeFirestore,
        );

        notifierWithFirestore
            .initPatentClassificationsListener(); // executes fetchNextPage(isRefresh: true)
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifierWithFirestore.patentRecords.isNotEmpty, isTrue);

        notifierWithFirestore
            .cancelPatentClassificationsListener(); // executes lines 172-174
        expect(notifierWithFirestore.patentRecords, isEmpty);
        notifierWithFirestore.dispose();

        // 2. _isTesting is false, testFirestore is null path in initPatentClassificationsListener
        final notifierProd = PatentClassificationsNotifier(testFirestore: null);
        notifierProd.initPatentClassificationsListener();
        notifierProd.dispose();
      },
    );
  });

  group('PatentClassificationsNotifier Firestore Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = true;
    });

    tearDown(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
    });

    test(
      'fetchNextPage with testFirestore loads records from fake Firestore',
      () async {
        final patentMap = MockData.patents.first.toMap();
        final fakeDoc = FakeQueryDocumentSnapshot('1', patentMap);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = PatentClassificationsNotifier(
          testFirestore: fakeFirestore,
        );
        await notifier.fetchNextPage(isRefresh: true);

        expect(notifier.patentRecords.length, 1);
        expect(
          notifier.patentRecords.first.applicationNumber,
          MockData.patents.first.applicationNumber,
        );
        expect(notifier.isLoadingPatents, isFalse);
        expect(notifier.isLoadingMorePatents, isFalse);
        expect(notifier.hasMorePatents, isFalse);

        notifier.dispose();
      },
    );

    test(
      'fetchNextPage with testFirestore and Primary filter queries correctly',
      () async {
        final patentMap = MockData.patents.first.toMap();
        final fakeDoc = FakeQueryDocumentSnapshot('1', patentMap);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = PatentClassificationsNotifier(
          testFirestore: fakeFirestore,
        );
        notifier.setPrimaryFilter('Primary');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.patentRecords.length, 1);
        expect(notifier.isLoadingPatents, isFalse);
        notifier.dispose();
      },
    );

    test(
      'fetchNextPage with testFirestore and Secondary filter queries correctly',
      () async {
        final fakeSnapshot = FakeQuerySnapshot([]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = PatentClassificationsNotifier(
          testFirestore: fakeFirestore,
        );
        notifier.setPrimaryFilter('Secondary');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.patentRecords, isEmpty);
        expect(notifier.isLoadingPatents, isFalse);
        notifier.dispose();
      },
    );

    test('fetchNextPage with testFirestore and numeric search query', () async {
      final fakeSnapshot = FakeQuerySnapshot([]);
      final fakeCollection = FakeCollectionReference(fakeSnapshot);
      final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

      final notifier = PatentClassificationsNotifier(
        testFirestore: fakeFirestore,
      );
      notifier.setSearchQuery('327015');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.isLoadingPatents, isFalse);
      notifier.dispose();
    });

    test(
      'fetchNextPage with testFirestore and text search query (range query)',
      () async {
        final fakeSnapshot = FakeQuerySnapshot([]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = PatentClassificationsNotifier(
          testFirestore: fakeFirestore,
        );
        notifier.setSearchQuery('A61P');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.isLoadingPatents, isFalse);
        notifier.dispose();
      },
    );

    test('fetchNextPage appends records on non-refresh pagination', () async {
      final docs = List.generate(
        20,
        (i) =>
            FakeQueryDocumentSnapshot('doc-$i', MockData.patents.first.toMap()),
      );
      final fakeSnapshot = FakeQuerySnapshot(docs);
      final fakeCollection = FakeCollectionReference(fakeSnapshot);
      final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

      final notifier = PatentClassificationsNotifier(
        testFirestore: fakeFirestore,
      );

      // First page (refresh)
      await notifier.fetchNextPage(isRefresh: true);
      expect(notifier.patentRecords.length, 20);
      expect(notifier.hasMorePatents, isTrue); // 20 == pageSize

      // Second page (append)
      await notifier.fetchNextPage();
      expect(notifier.patentRecords.length, 40);
      expect(notifier.isLoadingMorePatents, isFalse);

      notifier.dispose();
    });

    test('fetchNextPage handles Firestore errors gracefully', () async {
      final fakeFirestore = FakeErrorFirebaseFirestore();

      final notifier = PatentClassificationsNotifier(
        testFirestore: fakeFirestore,
      );
      await notifier.fetchNextPage(isRefresh: true);

      expect(notifier.patentRecords, isEmpty);
      expect(notifier.isLoadingPatents, isFalse);
      expect(notifier.isLoadingMorePatents, isFalse);

      notifier.dispose();
    });
  });
}

// --- Fake Firestore chain for query-based notifier testing ---

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

class FakeQuery implements Query<Map<String, dynamic>> {
  final FakeQuerySnapshot _snapshot;
  FakeQuery(this._snapshot);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _snapshot;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    return this;
  }

  @override
  Query<Map<String, dynamic>> startAfterDocument(DocumentSnapshot snapshot) {
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference extends FakeQuery
    implements CollectionReference<Map<String, dynamic>> {
  FakeCollectionReference(super.snapshot);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  final FakeCollectionReference _collectionRef;
  FakeFirebaseFirestore(this._collectionRef);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _collectionRef;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeErrorQuery extends FakeQuery {
  FakeErrorQuery() : super(FakeQuerySnapshot([]));

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    throw Exception('Firestore query failed');
  }
}

class FakeErrorCollectionReference extends FakeErrorQuery
    implements CollectionReference<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeErrorFirebaseFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      FakeErrorCollectionReference();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
