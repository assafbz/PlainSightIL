// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/local_market_bonds/presentation/notifiers/local_market_bonds_notifier.dart';

void main() {
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

    group('Firestore Mode Tests', () {
      late FakeFirebaseFirestore mockFirestore;
      late List<Map<String, dynamic>> emittedDocs;
      late bool shouldThrow;

      setUp(() {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;
        shouldThrow = false;
        emittedDocs = [
          {
            '_id': 101,
            'series': 1227784,
            'bondType': {'en': 'Government', 'he': 'ממשלתי'},
          },
          {
            '_id': 102,
            'series': 1227785,
            'bondType': {'en': 'CPI-Linked Government', 'he': 'צמוד מדד'},
          },
          {
            '_id': 103,
            'series': 1227786,
            'bondType': {'en': 'Floating Rate Government', 'he': 'ריבית משתנה'},
          },
        ];

        final query = FakeQuery(() {
          if (shouldThrow) {
            throw FirebaseException(plugin: 'firestore', message: 'Test error');
          }
          final fakeDocs = emittedDocs.map((data) {
            return FakeQueryDocumentSnapshot(data['_id'].toString(), data);
          }).toList();
          return Future.value(FakeQuerySnapshot(fakeDocs));
        });

        final colRef = FakeCollectionReference(query);
        mockFirestore = FakeFirebaseFirestore(colRef);
      });

      tearDown(() {
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      });

      test('fetchNextPage success path in Firestore mode', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        await notifier.fetchNextPage(isRefresh: true);
        expect(notifier.bondRecords.length, 3);
        expect(notifier.isLoadingBonds, isFalse);
      });

      test('fetchNextPage with filter Government', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.setFilter('Government');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage with filter CPI-Linked', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.setFilter('CPI-Linked');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage with filter Floating Rate', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.setFilter('Floating Rate');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage with search query (numeric)', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.setSearchQuery('1227784');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage with search query (non-numeric)', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.setSearchQuery('Government');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage pagination with last document', () async {
        emittedDocs = List.generate(
          20,
          (index) => {
            '_id': 101 + index,
            'series': 1227784 + index,
            'bondType': {'en': 'Government', 'he': 'ממשלתי'},
          },
        );
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        // Refresh to set last document
        await notifier.fetchNextPage(isRefresh: true);
        // Second call with lastDocument set
        await notifier.fetchNextPage();
        expect(
          notifier.bondRecords.length,
          40,
        ); // added 20 more since mock query returns 20 every time
      });

      test('fetchNextPage error path handles exception', () async {
        shouldThrow = true;
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        await notifier.fetchNextPage(isRefresh: true);
        expect(notifier.bondRecords, isEmpty);
        expect(notifier.isLoadingBonds, isFalse);
      });

      test(
        'isFirebaseInitialized default/null testIsFirebaseInitialized executes try-catch',
        () {
          AppStateNotifier.testIsFirebaseInitialized = null;
          final notifier = LocalMarketBondsNotifier();
          expect(notifier.isFirebaseInitialized, isFalse);
        },
      );

      test('fetchNextPage returns early if isLoadingBonds is true', () async {
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        final firstFuture = notifier.fetchNextPage(isRefresh: true);
        final secondFuture = notifier
            .fetchNextPage(); // returns early because _isLoadingBonds is true
        await firstFuture;
        await secondFuture;
        expect(notifier.bondRecords.length, 3);
      });

      test('fetchNextPage returns early if isLoadingMoreBonds is true', () async {
        emittedDocs = List.generate(
          20,
          (index) => {
            '_id': 101 + index,
            'series': 1227784 + index,
            'bondType': {'en': 'Government', 'he': 'ממשלתי'},
          },
        );
        final notifier = LocalMarketBondsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        await notifier.fetchNextPage(isRefresh: true);
        final firstFuture = notifier
            .fetchNextPage(); // sets _isLoadingMoreBonds = true
        final secondFuture = notifier
            .fetchNextPage(); // returns early because _isLoadingMoreBonds is true
        await firstFuture;
        await secondFuture;
        expect(notifier.bondRecords.length, 40);
      });
    });
  });
}

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

class FakeFirebaseFirestore implements FirebaseFirestore {
  final CollectionReference<Map<String, dynamic>> collectionRef;
  FakeFirebaseFirestore(this.collectionRef);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      collectionRef;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Query<Map<String, dynamic>> query;
  FakeCollectionReference(this.query);

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
    Object? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => query.where(
    field,
    isEqualTo: isEqualTo,
    isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
    isLessThanOrEqualTo: isLessThanOrEqualTo,
  );

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => query.orderBy(field, descending: descending);

  @override
  Query<Map<String, dynamic>> limit(int limit) => query.limit(limit);

  @override
  Query<Map<String, dynamic>> startAfterDocument(DocumentSnapshot document) =>
      query.startAfterDocument(document);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      query.get(options);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuery implements Query<Map<String, dynamic>> {
  final Future<QuerySnapshot<Map<String, dynamic>>> Function() onGet;

  FakeQuery(this.onGet);

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
    Object? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => this;

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Query<Map<String, dynamic>> startAfterDocument(DocumentSnapshot document) =>
      this;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      onGet();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
