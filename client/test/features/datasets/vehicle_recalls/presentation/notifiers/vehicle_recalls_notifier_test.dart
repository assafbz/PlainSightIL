import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/presentation/notifiers/vehicle_recalls_notifier.dart';

void main() {
  group('VehicleRecallsNotifier Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = true;
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
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'isFirebaseInitialized returns true when testIsFirebaseInitialized is true',
      () {
        AppStateNotifier.testIsFirebaseInitialized = true;
        final notifier = VehicleRecallsNotifier();
        expect(notifier.isFirebaseInitialized, isTrue);
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('initRecallsListener loads mock data in testing mode', () async {
      final notifier = VehicleRecallsNotifier();
      notifier.initRecallsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.recallRecords.isNotEmpty, isTrue);
      expect(notifier.isLoadingRecalls, isFalse);
    });

    test('cancelRecallsListener resets state', () async {
      final notifier = VehicleRecallsNotifier();
      notifier.initRecallsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notifier.recallRecords.isNotEmpty, isTrue);

      notifier.cancelRecallsListener();
      expect(notifier.recallRecords, isEmpty);
      expect(notifier.isLoadingRecalls, isTrue);
    });

    test(
      'initRecallsListener returns early when Firebase not initialized in non-testing mode',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = VehicleRecallsNotifier();
        notifier.initRecallsListener();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notifier.recallRecords, isEmpty);
        expect(notifier.isLoadingRecalls, isFalse);
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test('notifyListeners does not throw after dispose', () {
      final notifier = VehicleRecallsNotifier();
      notifier.dispose();
      expect(() => notifier.notifyListeners(), returnsNormally);
    });
  });
}
