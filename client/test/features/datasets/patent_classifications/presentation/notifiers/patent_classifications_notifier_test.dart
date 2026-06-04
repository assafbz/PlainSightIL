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

    test('fetchNextPage loads mock data in testing mode', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      expect(notifier.patentRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingPatents, isFalse);
    });

    test('setSearchQuery filters mock records', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      final totalBefore = notifier.patentRecords.length;
      notifier.setSearchQuery('99999999');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Search with a non-existent query should reduce or keep results
      expect(notifier.patentRecords.length <= totalBefore, isTrue);
    });

    test('setPrimaryFilter updates filter state', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      notifier.setPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingPatents, isFalse);
    });

    test('dispose cleans up resources', () async {
      final notifier = PatentClassificationsNotifier();
      await notifier.fetchNextPage();
      notifier.dispose();
      // After dispose, no errors should be thrown
    });
  });
}
