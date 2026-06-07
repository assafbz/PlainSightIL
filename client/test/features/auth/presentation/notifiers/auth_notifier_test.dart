import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../notifiers_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AuthNotifier Tests', () {
    test(
      'Constructor initialization with custom repository and stream',
      () async {
        final mockRepo = FakeUserProfileRepository(tProfile);
        final authStreamController = StreamController<User?>();

        AppStateNotifier.isTesting = false;
        final notifier = AuthNotifier(
          isTesting: false,
          testProfileRepository: mockRepo,
          testAuthChangesStream: authStreamController.stream,
        );

        expect(notifier.isAuthenticated, isFalse);
        expect(notifier.userProfile, isNull);

        // Emit authenticated user
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        authStreamController.add(fakeUser);

        // Allow stream to process
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isAuthenticated, isTrue);
        expect(notifier.currentUser?.uid, 'user_123');
        expect(notifier.userProfile, tProfile);

        // Update User Profile
        final updatedProfile = tProfile.copyWith(firstName: 'Assaf New');
        await notifier.updateUserProfile(updatedProfile);
        expect(mockRepo.lastUpdated, updatedProfile);
        expect(notifier.userProfile?.firstName, 'Assaf New');

        // Guest Mode Toggle
        notifier.setGuestMode(true);
        expect(notifier.isGuestMode, isTrue);

        // Sign In with Google
        await notifier.signInWithGoogle();
        expect(notifier.isGuestMode, isFalse);

        // Sign Out
        AppStateNotifier.isTesting = false;
        await notifier.signOut();
        authStreamController.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.isAuthenticated, isFalse);
        expect(notifier.userProfile, isNull);

        AppStateNotifier.isTesting = true;

        await authStreamController.close();
        notifier.dispose();
      },
    );

    test('Favorites and Recents list toggling and saving', () async {
      final mockRepo = FakeUserProfileRepository(tProfile);
      final notifier = AuthNotifier(
        isTesting: true,
        testProfileRepository: mockRepo,
      );

      // Favorites
      expect(notifier.isFavorite('dataset-1'), isFalse);
      await notifier.toggleFavorite('dataset-1');
      expect(notifier.isFavorite('dataset-1'), isTrue);
      await notifier.toggleFavorite('dataset-1');
      expect(notifier.isFavorite('dataset-1'), isFalse);

      // Recents
      await notifier.addRecent('dataset-2');
      await notifier.addRecent('dataset-3');
      await notifier.addRecent('dataset-4');
      await notifier.addRecent('dataset-5');
      await notifier.addRecent('dataset-6');
      await notifier.addRecent('dataset-7');
      expect(notifier.recents.length, 5);
      expect(notifier.recents.first, 'dataset-7');

      notifier.dispose();
    });

    test(
      'AuthNotifier behaves correctly when isFirebaseInitialized is false',
      () async {
        AppStateNotifier.isTesting = false;
        final mockRepo = FakeUserProfileRepository(tProfile);
        final streamController = StreamController<User?>();
        final notifier = AuthNotifier(
          isTesting: false,
          testProfileRepository: mockRepo,
          testAuthChangesStream: streamController.stream,
        );
        expect(notifier.isAuthenticated, isFalse);

        // trigger auth stream exception path
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');

        streamController.addError('Connection failed');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await notifier.signInWithGoogle();
        expect(notifier.isAuthenticated, isTrue);

        await notifier.signOut();
        expect(notifier.isAuthenticated, isFalse);

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test('AuthNotifier handles real Firebase and Firestore flows', () async {
      AppStateNotifier.isTesting = false;
      final authStreamController = StreamController<User?>.broadcast();
      final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
      final fakeAuth = FakeFirebaseAuth(
        mockCurrentUser: fakeUser,
        authChanges: authStreamController.stream,
      );
      final mockRepo = FakeUserProfileRepository(tProfile);

      final notifier = AuthNotifier(
        isTesting: false,
        testAuthChangesStream: authStreamController.stream,
        testProfileRepository: mockRepo,
        testAuth: fakeAuth,
      );

      authStreamController.add(fakeUser);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isAuthenticated, isTrue);

      await notifier.signInWithGoogle();
      await notifier.signOut();

      authStreamController.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isAuthenticated, isFalse);

      authStreamController.addError('Auth Error');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.dispose();
      await authStreamController.close();
      AppStateNotifier.isTesting = true;
    });

    test(
      'AuthNotifier covers remote data source initialization, errors in local storage, and other operations',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;
        final authStreamController = StreamController<User?>.broadcast();
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        final fakeAuth = FakeFirebaseAuth(
          mockCurrentUser: fakeUser,
          authChanges: authStreamController.stream,
        );

        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });

        // Verify remote data source is instantiated
        final notifier = AuthNotifier(
          isTesting: false,
          testAuthChangesStream: authStreamController.stream,
          testFirestore: mockFirestore,
          testAuth: fakeAuth,
        );
        expect(notifier.isAuthenticated, isFalse);

        // Wait for LocalStorage.init() to complete successfully first
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 2. Set platform to throwing implementation for writes
        final originalPlatform = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance =
            ThrowingSharedPreferencesStore();

        await notifier.toggleFavorite('fav-dataset');
        await notifier.addRecent('recent-dataset');
        notifier.setGuestMode(true);

        // Restore platform
        SharedPreferencesStorePlatform.instance = originalPlatform;
        notifier.dispose();
        await authStreamController.close();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'AuthNotifier covers SharedPreferences initialization exceptions and listener errors',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });

        // 1. SharedPreferences initialization throws exception (by setting mock initial values with wrong types)
        SharedPreferences.setMockInitialValues({
          'favorites':
              123, // getStringList on integer will throw a cast/type error
          'recents': 'not-a-list', // getStringList on string will throw
          'guest_mode': 'not-a-bool', // getBool on string will throw
        });

        final notifier = AuthNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 2. Auth changes stream listener onError callback
        final authStreamController = StreamController<User?>.broadcast();
        final fakeAuth = FakeFirebaseAuth(
          mockCurrentUser: null,
          authChanges: authStreamController.stream,
        );
        final notifier2 = AuthNotifier(
          isTesting: false,
          testAuth: fakeAuth,
          testProfileRepository: FakeUserProfileRepository(tProfile),
        );

        // Trigger success user login first to cover success listener path
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        authStreamController.add(fakeUser);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        authStreamController.addError(Exception('Auth stream failure'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 3. User profile update exception path
        final mockRepo = FakeUserProfileRepository(tProfile);
        mockRepo.throwOnUpdate = true;
        final notifier3 = AuthNotifier(
          isTesting: false,
          testAuthChangesStream: authStreamController.stream,
          testProfileRepository: mockRepo,
        );

        // Add user to trigger profile listener setup so it listens to mockRepo.controller
        authStreamController.add(fakeUser);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(() => notifier3.updateUserProfile(tProfile), throwsException);

        // 4. Profile listen stream onError callback
        mockRepo.controller.addError(
          Exception('Profile stream listener error'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 5. Sign in and sign out errors
        final fakeAuthError = FakeFirebaseAuth(
          mockCurrentUser: null,
          authChanges: authStreamController.stream,
          onSignInWithPopup: () => throw Exception('Google sign in error'),
          onSignOut: () => throw Exception('Sign out error'),
        );
        final notifier4 = AuthNotifier(
          isTesting: false,
          testAuth: fakeAuthError,
          testProfileRepository: mockRepo,
        );

        expect(() => notifier4.signInWithGoogle(), throwsException);
        await notifier4.signOut();

        notifier.dispose();
        notifier2.dispose();
        notifier3.dispose();
        notifier4.dispose();
        await authStreamController.close();

        // Clean up mock values
        SharedPreferences.setMockInitialValues({});
        AppStateNotifier.isTesting = true;
      },
    );
  });
}
