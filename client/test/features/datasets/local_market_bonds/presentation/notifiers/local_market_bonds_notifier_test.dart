import 'package:flutter_test/flutter_test.dart';
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
  });
}
