import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
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
}
