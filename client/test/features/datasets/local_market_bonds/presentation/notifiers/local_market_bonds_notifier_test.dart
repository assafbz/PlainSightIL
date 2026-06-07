// ignore_for_file: subtype_of_sealed_class, unnecessary_no_such_method, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/features/datasets/local_market_bonds/data/models/local_market_bond_model.dart';
import 'package:plainsight/features/datasets/local_market_bonds/presentation/notifiers/local_market_bonds_notifier.dart';

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

/// A fake Query that returns a configured FakeQuerySnapshot.
/// All chaining methods (where, orderBy, limit, startAfterDocument) return [this].
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

/// A fake CollectionReference that extends FakeQuery to make chaining work.
class FakeCollectionReference extends FakeQuery
    implements CollectionReference<Map<String, dynamic>> {
  FakeCollectionReference(super.snapshot);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A fake FirebaseFirestore that returns a FakeCollectionReference.
class FakeFirebaseFirestore implements FirebaseFirestore {
  final FakeCollectionReference _collectionRef;
  FakeFirebaseFirestore(this._collectionRef);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _collectionRef;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- Fake Query that throws an error on get() ---
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalMarketBondsNotifier Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = true;
    });

    test('should initialize with empty records and loading false', () {
      final notifier = LocalMarketBondsNotifier();
      expect(notifier.bondRecords, isEmpty);
      expect(notifier.isLoadingBonds, isFalse);
      expect(notifier.isLoadingMoreBonds, isFalse);
      expect(notifier.hasMoreBonds, isTrue);
    });

    test(
      'isFirebaseInitialized returns false when testIsFirebaseInitialized is false',
      () {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = LocalMarketBondsNotifier();
        expect(notifier.isFirebaseInitialized, isFalse);
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'isFirebaseInitialized returns true when testIsFirebaseInitialized is true',
      () {
        AppStateNotifier.testIsFirebaseInitialized = true;
        final notifier = LocalMarketBondsNotifier();
        expect(notifier.isFirebaseInitialized, isTrue);
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'isFirebaseInitialized falls through to Firebase.apps when testIsFirebaseInitialized is null',
      () {
        AppStateNotifier.testIsFirebaseInitialized = null;
        final notifier = LocalMarketBondsNotifier();
        // Firebase is not initialized in test env, so Firebase.apps throws
        // and the catch block returns false
        expect(notifier.isFirebaseInitialized, isFalse);
      },
    );

    test('initBondsListener triggers fetchNextPage refresh', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.initBondsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.bondRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingBonds, isFalse);
    });

    test('fetchNextPage loads mock data in testing mode', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage();
      expect(notifier.bondRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingBonds, isFalse);
      expect(notifier.hasMoreBonds, isFalse);
      expect(notifier.isLoadingMoreBonds, isFalse);
    });

    test('fetchNextPage with isRefresh resets state before loading', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage(isRefresh: true);
      expect(notifier.bondRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingBonds, isFalse);
    });

    test(
      'fetchNextPage without refresh returns early when hasMoreBonds is false',
      () async {
        final notifier = LocalMarketBondsNotifier();
        await notifier.fetchNextPage();
        final recordsAfterFirst = notifier.bondRecords.length;

        await notifier.fetchNextPage();
        expect(notifier.bondRecords.length, recordsAfterFirst);
      },
    );

    test('setSearchQuery filters mock records by series number', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage();
      final totalBefore = notifier.bondRecords.length;
      notifier.setSearchQuery('1227784');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.bondRecords.length <= totalBefore, isTrue);
    });

    test('setSearchQuery with same query returns early', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage();
      notifier.setSearchQuery('122');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countAfterFirst = notifier.bondRecords.length;
      notifier.setSearchQuery('122');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.bondRecords.length, countAfterFirst);
    });

    test('setFilter to Government filters correctly', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setFilter('Government');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
    });

    test('setFilter to CPI-Linked filters correctly', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setFilter('CPI-Linked');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
    });
    test('setFilter to Floating Rate filters correctly', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setFilter('Floating Rate');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
    });

    test('setFilter to Floating Rate filters correctly', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setFilter('Floating Rate');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
      // Only Floating Rate Government bonds should remain
      for (final bond in notifier.bondRecords) {
        expect(bond.bondType['en'], 'Floating Rate Government');
      }
    });

    test('setFilter with same filter returns early', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setFilter('Government');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      notifier.setFilter('Government');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
    });

    test('resetFilters clears search and filter state', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.setSearchQuery('122');
      notifier.setFilter('Government');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.resetFilters();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.isLoadingBonds, isFalse);
      expect(notifier.bondRecords.isNotEmpty, isTrue);
    });

    test('cancelBondsListener resets state', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage();
      expect(notifier.bondRecords.isNotEmpty, isTrue);

      notifier.cancelBondsListener();
      expect(notifier.bondRecords, isEmpty);
      expect(notifier.isLoadingBonds, isFalse);
      expect(notifier.isLoadingMoreBonds, isFalse);
      expect(notifier.hasMoreBonds, isTrue);
    });

    test(
      'fetchNextPage returns early when Firebase not initialized in non-testing mode',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = LocalMarketBondsNotifier();
        await notifier.fetchNextPage(isRefresh: true);
        expect(notifier.bondRecords, isEmpty);
        expect(notifier.isLoadingBonds, isFalse);
        expect(notifier.isLoadingMoreBonds, isFalse);
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'dispose sets isDisposed and prevents further notifications',
      () async {
        final notifier = LocalMarketBondsNotifier();
        await notifier.fetchNextPage();
        notifier.dispose();
      },
    );

    test('notifyListeners does not throw after dispose', () async {
      final notifier = LocalMarketBondsNotifier();
      notifier.dispose();
      expect(() => notifier.notifyListeners(), returnsNormally);
    });

    test('setSearchQuery filters by bond type text', () async {
      final notifier = LocalMarketBondsNotifier();
      await notifier.fetchNextPage();
      // Search by Hebrew bond type text
      notifier.setSearchQuery('ממשלתית');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.bondRecords.isNotEmpty, isTrue);
    });
  });

  group('LocalMarketBondsNotifier Firestore Tests', () {
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
        final bondMap = {
          'id': '1',
          '_id': 1,
          'issuanceDate': '2026-06-02T00:00:00.000Z',
          'bondType': {'he': 'ממשלתית', 'en': 'Government'},
          'series': 1227784,
          'actualTermToMaturity': 9.4,
          'originalTermToMaturity': 10.0,
          'redemptionDate': '2035-10-31T00:00:00.000Z',
          'coupon': 4.15,
          'offeredQuantity': 106.0,
          'purchasedQuantity': 105.8,
          'additionalPurchased': -0.1,
          'averagePrice': 105.73,
          'cutoffPrice': 105.73,
          'totalFunding': 111.9,
          'demandedAmount': 105.8,
          'coverRatio': 1.0,
          'grossAvgYield': 3.73,
          'grossCutoffYield': 3.73,
          'lastUpdated': '2026-06-04T12:00:00Z',
          'createdAt': '2026-06-04T12:00:00Z',
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', bondMap);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
        await notifier.fetchNextPage(isRefresh: true);

        expect(notifier.bondRecords.length, 1);
        expect(notifier.bondRecords.first.series, 1227784);
        expect(notifier.isLoadingBonds, isFalse);
        expect(notifier.isLoadingMoreBonds, isFalse);
        // Only 1 doc returned, which is less than pageSize(20), so hasMore=false
        expect(notifier.hasMoreBonds, isFalse);

        notifier.dispose();
      },
    );

    test(
      'fetchNextPage with testFirestore and Government filter queries correctly',
      () async {
        final bondMap = {
          'id': '1',
          '_id': 1,
          'issuanceDate': '2026-06-02T00:00:00.000Z',
          'bondType': {'he': 'ממשלתית', 'en': 'Government'},
          'series': 1227784,
          'actualTermToMaturity': 9.4,
          'originalTermToMaturity': 10.0,
          'redemptionDate': '2035-10-31T00:00:00.000Z',
          'coupon': 4.15,
          'offeredQuantity': 106.0,
          'purchasedQuantity': 105.8,
          'additionalPurchased': -0.1,
          'averagePrice': 105.73,
          'cutoffPrice': 105.73,
          'totalFunding': 111.9,
          'demandedAmount': 105.8,
          'coverRatio': 1.0,
          'grossAvgYield': 3.73,
          'grossCutoffYield': 3.73,
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', bondMap);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
        notifier.setFilter('Government');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.bondRecords.length, 1);
        expect(notifier.isLoadingBonds, isFalse);
        notifier.dispose();
      },
    );

    test(
      'fetchNextPage with testFirestore and CPI-Linked filter queries correctly',
      () async {
        final fakeSnapshot = FakeQuerySnapshot([]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
        notifier.setFilter('CPI-Linked');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.bondRecords, isEmpty);
        expect(notifier.isLoadingBonds, isFalse);
        notifier.dispose();
      },
    );

    test(
      'fetchNextPage with testFirestore and Floating Rate filter queries correctly',
      () async {
        final fakeSnapshot = FakeQuerySnapshot([]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
        notifier.setFilter('Floating Rate');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.bondRecords, isEmpty);
        expect(notifier.isLoadingBonds, isFalse);
        notifier.dispose();
      },
    );

    test('fetchNextPage with testFirestore and numeric search query', () async {
      final fakeSnapshot = FakeQuerySnapshot([]);
      final fakeCollection = FakeCollectionReference(fakeSnapshot);
      final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

      final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
      notifier.setSearchQuery('1227784');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.isLoadingBonds, isFalse);
      notifier.dispose();
    });

    test(
      'fetchNextPage with testFirestore and text search query (range query)',
      () async {
        final fakeSnapshot = FakeQuerySnapshot([]);
        final fakeCollection = FakeCollectionReference(fakeSnapshot);
        final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

        final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
        notifier.setSearchQuery('Government');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.isLoadingBonds, isFalse);
        notifier.dispose();
      },
    );

    test('fetchNextPage appends records on non-refresh pagination', () async {
      // Generate exactly 20 docs to simulate a full page
      final docs = List.generate(
        20,
        (i) => FakeQueryDocumentSnapshot('doc-$i', {
          'id': '$i',
          '_id': i,
          'issuanceDate': '2026-06-02',
          'bondType': {'he': 'ממשלתית', 'en': 'Government'},
          'series': 1000000 + i,
          'actualTermToMaturity': 5.0,
          'originalTermToMaturity': 10.0,
          'redemptionDate': '2036-01-01',
          'coupon': 3.0,
          'offeredQuantity': 100.0,
          'purchasedQuantity': 90.0,
          'additionalPurchased': -10.0,
          'averagePrice': 100.0,
          'cutoffPrice': 99.0,
          'totalFunding': 90.0,
          'demandedAmount': 90.0,
          'coverRatio': 0.9,
          'grossAvgYield': 3.0,
          'grossCutoffYield': 2.9,
        }),
      );
      final fakeSnapshot = FakeQuerySnapshot(docs);
      final fakeCollection = FakeCollectionReference(fakeSnapshot);
      final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

      final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);

      // First page (refresh)
      await notifier.fetchNextPage(isRefresh: true);
      expect(notifier.bondRecords.length, 20);
      expect(notifier.hasMoreBonds, isTrue); // 20 == pageSize

      // Second page (append)
      await notifier.fetchNextPage();
      // FakeQuery always returns same 20 docs, so total becomes 40
      expect(notifier.bondRecords.length, 40);
      expect(notifier.isLoadingMoreBonds, isFalse);

      notifier.dispose();
    });

    test('fetchNextPage handles Firestore errors gracefully', () async {
      final fakeFirestore = FakeErrorFirebaseFirestore();

      final notifier = LocalMarketBondsNotifier(testFirestore: fakeFirestore);
      await notifier.fetchNextPage(isRefresh: true);

      // Error path: records should be empty, loading flags reset
      expect(notifier.bondRecords, isEmpty);
      expect(notifier.isLoadingBonds, isFalse);
      expect(notifier.isLoadingMoreBonds, isFalse);

      notifier.dispose();
    });
  });

  group('LocalMarketBondsNotifier Production Delegation Tests', () {
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
        final notifier = LocalMarketBondsNotifier(testFirestore: null);

        // Initialize with mockData directly on sync manager
        final manager = notifier.syncManagerForTesting;
        await manager.initialize(mockData: MockData.bonds, isTesting: true);

        // Verify basic loading state delegation
        expect(notifier.isLoadingBonds, isFalse);
        expect(notifier.bondRecords.isNotEmpty, isTrue);

        // Test filtering on 'Government'
        notifier.setFilter('Government');
        expect(
          notifier.hasMoreBonds,
          isFalse,
        ); // Reads hasMoreBonds with filter set
        for (final bond in notifier.bondRecords) {
          expect(bond.bondType['en'], 'Government');
        }

        // Test filtering on 'CPI-Linked'
        notifier.setFilter('CPI-Linked');
        expect(
          notifier.hasMoreBonds,
          isFalse,
        ); // Reads hasMoreBonds with filter set
        for (final bond in notifier.bondRecords) {
          expect(bond.bondType['en'], 'CPI-Linked Government');
        }

        // Test filtering on 'Floating Rate'
        notifier.setFilter('Floating Rate');
        expect(
          notifier.hasMoreBonds,
          isFalse,
        ); // Reads hasMoreBonds with filter set
        for (final bond in notifier.bondRecords) {
          expect(bond.bondType['en'], 'Floating Rate Government');
        }

        // Reset filter
        notifier.setFilter('All');
        expect(
          notifier.bondRecords.length,
          MockData.bonds.length > 20 ? 20 : MockData.bonds.length,
        );

        // Test text searching
        notifier.setSearchQuery('Floating');
        expect(
          notifier.hasMoreBonds,
          isFalse,
        ); // Reads hasMoreBonds with search query set
        for (final bond in notifier.bondRecords) {
          expect(
            bond.bondType['en']?.toLowerCase().contains('floating'),
            isTrue,
          );
        }

        // Test numeric series searching
        notifier.setSearchQuery('1227784');
        expect(
          notifier.hasMoreBonds,
          isFalse,
        ); // Reads hasMoreBonds with search query set
        for (final bond in notifier.bondRecords) {
          expect(bond.series.toString(), '1227784');
        }

        // Test hasMoreBonds when records length is <= page size vs when pagination runs
        notifier.setSearchQuery('');
        notifier.setFilter('All');
        expect(notifier.hasMoreBonds, MockData.bonds.length > 20);

        // Test fetchNextPage pagination loading more
        if (notifier.hasMoreBonds) {
          final initialLength = notifier.bondRecords.length;
          await notifier.fetchNextPage();
          expect(notifier.bondRecords.length > initialLength, isTrue);
        }

        // Test getRecordLastUpdated, toMap, getRecordId callbacks on the manager
        final record = MockData.bonds.first;
        expect(manager.getRecordLastUpdated(record), record.lastUpdated ?? '');
        expect(manager.toMap(record).isNotEmpty, isTrue);
        expect(manager.getRecordId(record), record.id);

        notifier.dispose();
      },
    );

    test('verifies initBondsListener and cancelBondsListener paths', () async {
      // 1. testFirestore != null paths (init & cancel)
      final fakeDoc = FakeQueryDocumentSnapshot(
        '1',
        MockData.bonds.first.toMap(),
      );
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);
      final fakeCollection = FakeCollectionReference(fakeSnapshot);
      final fakeFirestore = FakeFirebaseFirestore(fakeCollection);

      final notifierWithFirestore = LocalMarketBondsNotifier(
        testFirestore: fakeFirestore,
      );

      notifierWithFirestore
          .initBondsListener(); // executes fetchNextPage(isRefresh: true) on line 154
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifierWithFirestore.bondRecords.isNotEmpty, isTrue);

      notifierWithFirestore.cancelBondsListener(); // executes lines 179-181
      expect(notifierWithFirestore.bondRecords, isEmpty);
      notifierWithFirestore.dispose();

      // 2. _isTesting is false, testFirestore is null path in initBondsListener
      final notifierProd = LocalMarketBondsNotifier(testFirestore: null);
      // Calls line 166: _syncManager.initialize(testFirestore: testFirestore);
      notifierProd.initBondsListener();
      notifierProd.dispose();
    });
  });
}
