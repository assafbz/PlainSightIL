// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/config/firebase_config.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/local_storage.dart';
import 'package:plainsight/core/state/local_storage_stub.dart';
import 'package:plainsight/core/state/local_storage_io.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'PlainSight IL',
    packageName: 'il.org.plainsight',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: 'signature',
  );

  group('AppStateNotifier Tests', () {
    late AppStateNotifier appState;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppStateNotifier.isTesting = false;
      appState = AppStateNotifier();
    });

    test('Initial values are set correctly', () {
      expect(appState.locale, 'en');
      expect(appState.activeTab, 0);
      expect(appState.textDirection, TextDirection.ltr);
      expect(appState.isDarkMode, true);
    });

    test('toggleTheme toggles theme mode and notifies listeners', () {
      var listenerCalled = false;
      appState.addListener(() {
        listenerCalled = true;
      });

      expect(appState.isDarkMode, true);
      expect(AppColors.isDark, true);

      appState.toggleTheme();

      expect(appState.isDarkMode, false);
      expect(AppColors.isDark, false);
      expect(listenerCalled, true);

      appState.toggleTheme();

      expect(appState.isDarkMode, true);
      expect(AppColors.isDark, true);
    });

    test('setLocale updates locale and notifies listeners', () {
      var listenerCalled = false;
      appState.addListener(() {
        listenerCalled = true;
      });

      appState.setLocale('he');

      expect(appState.locale, 'he');
      expect(appState.textDirection, TextDirection.rtl);
      expect(listenerCalled, true);
    });

    test('setLocale rejects invalid locales', () {
      var listenerCalled = false;
      appState.addListener(() {
        listenerCalled = true;
      });

      appState.setLocale('fr'); // Invalid locale

      expect(appState.locale, 'en'); // Remains unchanged
      expect(listenerCalled, false);
    });

    test('toggleLocale toggles between en and he and notifies listeners', () {
      var listenerCount = 0;
      appState.addListener(() {
        listenerCount++;
      });

      // Toggle from en -> he
      appState.toggleLocale();
      expect(appState.locale, 'he');
      expect(appState.textDirection, TextDirection.rtl);
      expect(listenerCount, 1);

      // Toggle from he -> en
      appState.toggleLocale();
      expect(appState.locale, 'en');
      expect(appState.textDirection, TextDirection.ltr);
      expect(listenerCount, 2);
    });

    test('setActiveTab updates active tab and notifies listeners', () {
      var listenerCalled = false;
      appState.addListener(() {
        listenerCalled = true;
      });

      appState.setActiveTab(2);

      expect(appState.activeTab, 2);
      expect(listenerCalled, true);
    });

    test('translate returns the correct localized string', () {
      // English check
      expect(appState.translate('app_title'), 'PlainSight IL');
      expect(appState.translate('welcome_back'), 'Welcome Back');
      expect(appState.translate('nav_home'), 'Home');
      expect(appState.translate('badge_active'), 'Active');
      expect(appState.translate('badge_roadmap'), 'Roadmap');
      expect(appState.translate('profile_settings_title'), 'Profile Settings');
      expect(appState.translate('save_profile'), 'Save Profile');
      expect(appState.translate('first_name'), 'First Name');
      expect(appState.translate('car_importers_title'), 'Car Price Lists');

      // Change locale to Hebrew and check translation
      appState.setLocale('he');
      expect(appState.translate('app_title'), 'בגובה העיניים');
      expect(appState.translate('welcome_back'), 'ברוכים הבאים');
      expect(appState.translate('nav_home'), 'בית');
      expect(appState.translate('badge_active'), 'פעיל');
      expect(appState.translate('badge_roadmap'), 'בקרוב');
      expect(appState.translate('profile_settings_title'), 'הגדרות פרופיל');
      expect(appState.translate('save_profile'), 'שמור פרופיל');
      expect(appState.translate('first_name'), 'שם פרטי');
      expect(appState.translate('car_importers_title'), 'מחירוני רכב חדש');
    });

    test('translate returns the key itself if no translation is found', () {
      expect(appState.translate('non_existent_key'), 'non_existent_key');
    });

    test('initAntennaListener initializes antennas in testing mode', () {
      AppStateNotifier.isTesting = true;
      print(
        'DEBUG: AppStateNotifier.isTesting = ${AppStateNotifier.isTesting}, antennaRecords = ${appState.antennaRecords}',
      );
      expect(appState.antennaRecords.isEmpty, true);
      expect(appState.isLoadingAntennas, true);

      appState.initAntennaListener();

      expect(appState.isLoadingAntennas, false);
      expect(appState.antennaRecords.isNotEmpty, true);
      expect(appState.antennaRecords.first['antennaId'], 'CELL-100');
      expect(appState.antennaRecords.first['coordinates'], isNotNull);
    });

    test(
      'initPermitMetadataListener in testing mode triggers initAntennaListener',
      () {
        AppStateNotifier.isTesting = true;
        expect(appState.antennaRecords.isEmpty, true);
        expect(appState.permitRecords.isEmpty, true);

        appState.initPermitMetadataListener();

        expect(appState.isLoadingAntennas, false);
        expect(appState.isLoadingPermits, false);
        expect(appState.antennaRecords.isNotEmpty, true);
        expect(appState.permitRecords.isNotEmpty, true);
        expect(appState.permitRecords.first['coordinates'], isNotNull);
      },
    );

    test(
      'FirebaseOptions local configurations are validly formatted to satisfy auth requirements',
      () {
        final key = localFirebaseOptions.apiKey;
        expect(key.isNotEmpty, isTrue);

        if (key == 'mock-api-key-for-local-emulator' ||
            key == 'AIzaSyMockApiKeyForLocalEmulator_32ch') {
          // Accept mock keys
        } else {
          expect(key, startsWith('AIzaSy'));
          expect(key.length == 37 || key.length == 39, isTrue);

          final RegExp gcloudKeyPattern = RegExp(
            r'^AIzaSy[a-zA-Z0-9_-]{31,33}$',
          );
          expect(gcloudKeyPattern.hasMatch(key), isTrue);
        }
      },
    );

    test(
      'FirebaseOptions dev configurations are validly formatted to satisfy auth requirements',
      () {
        final key = devFirebaseOptions.apiKey;

        if (key.isNotEmpty) {
          expect(key, startsWith('AIzaSy'));
          expect(key.length, 39);

          final RegExp gcloudKeyPattern = RegExp(r'^AIzaSy[a-zA-Z0-9_-]{33}$');
          expect(gcloudKeyPattern.hasMatch(key), isTrue);
        }

        expect(devFirebaseOptions.projectId, 'plainsightil');
        expect(devFirebaseOptions.appId, isNotEmpty);
      },
    );

    test(
      'retrieve user profile updates state when listener triggered',
      () async {
        AppStateNotifier.isTesting = true;
        final appState = AppStateNotifier();

        // Wait for stream event propagation
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(appState.userProfile, isNotNull);
        expect(appState.userProfile?.firstName, 'Assaf');
        expect(appState.userProfile?.email, 'assaf@plainsight.il');
      },
    );

    test('updateUserProfile calls repository and updates state', () async {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final UserProfile originalProfile = appState.userProfile!;
      final UserProfile updatedProfile = originalProfile.copyWith(
        firstName: 'NewFirstName',
        lastName: 'NewLastName',
      );

      var listenerCalled = false;
      appState.addListener(() {
        listenerCalled = true;
      });

      await appState.updateUserProfile(updatedProfile);

      // Wait for stream to emit updated profile
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(appState.userProfile?.firstName, 'NewFirstName');
      expect(appState.userProfile?.lastName, 'NewLastName');
      expect(listenerCalled, isTrue);
    });

    test('delegated getters and methods in testing mode', () async {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      expect(appState.currentUser, isNull);
      expect(appState.isAuthenticated, isTrue);
      expect(appState.isGuestMode, isFalse);
      expect(appState.isAdmin, isTrue);
      expect(appState.favorites, isEmpty);
      expect(appState.recents, isEmpty);
      expect(appState.mockUser, isNotNull);
      expect(appState.isFirebaseInitialized, isFalse);

      expect(appState.isLoadingAntennas, isTrue);
      expect(appState.isLoadingPermits, isTrue);
      expect(appState.permitSyncStatus, 'idle');
      expect(appState.isFirebaseInitialized, isFalse);
      expect(appState.atmRecords, isEmpty);
      expect(appState.isLoadingAtms, isTrue);
      appState.initBankAtmsListener();
      appState.cancelBankAtmsListener();

      appState.initCarImportersListener();
      expect(appState.carImporterRecords.isNotEmpty, isTrue);
      appState.cancelCarImportersListener();
      expect(appState.carImporterRecords, isEmpty);

      appState.initPermitMetadataListener();
      expect(appState.isLoadingAntennas, isFalse);
      expect(appState.isLoadingPermits, isFalse);

      appState.initAdminMetadataListener();
      appState.initDirectoryListener();
      appState.initLiquidationListener();
      appState.initDoctorsListener();
      appState.initTelemetryListeners();
      appState.initBankAtmsListener();

      expect(appState.isLoadingAdminMetadata, isFalse);
      expect(appState.isLoadingTelemetry, isFalse);
      expect(appState.isLoadingDirectory, isFalse);
      expect(appState.isLoadingAtms, isFalse);
      expect(appState.isLoadingCarImporters, isFalse);

      expect(appState.antennaRecords.isNotEmpty, isTrue);
      expect(appState.permitRecords.isNotEmpty, isTrue);
      expect(appState.liquidationRecords.isNotEmpty, isTrue);
      expect(appState.doctorRecords.isNotEmpty, isTrue);
      expect(appState.atmRecords.isNotEmpty, isTrue);
      expect(appState.carImporterRecords.isNotEmpty, isTrue);
      expect(appState.datasetMetadataMap.isNotEmpty, isTrue);
      expect(appState.apiHealth.isNotEmpty, isTrue);
      expect(appState.scraperRuns.isNotEmpty, isTrue);
      expect(appState.directoryRecords.isNotEmpty, isTrue);

      // Verify cancel bank atms listener resets state
      appState.cancelBankAtmsListener();
      expect(appState.atmRecords, isEmpty);
      expect(appState.isLoadingAtms, isTrue);

      // Verify app version is populated
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(appState.appVersion, '1.0.0');

      expect(appState.isFavorite('test-dataset'), isFalse);
      await appState.toggleFavorite('test-dataset');
      expect(appState.isFavorite('test-dataset'), isTrue);
      await appState.toggleFavorite('test-dataset');
      expect(appState.isFavorite('test-dataset'), isFalse);

      // Force context run of addPostFrameCallback inside a widgets binding test environment
      await appState.addRecent('test-dataset');
      expect(appState.recents.contains('test-dataset'), isTrue);

      appState.setGuestMode(true);
      expect(appState.isGuestMode, isTrue);

      await appState.signInWithGoogle();
      expect(appState.isAuthenticated, isTrue);

      AppStateNotifier.isTesting = false;
      await appState.signOut();
      expect(appState.isAuthenticated, isFalse);
      expect(appState.isGuestMode, isFalse);

      AppStateNotifier.isTesting = true;

      expect(appState.getRequestCount('government-budget-dataset-id'), 18);

      expect(appState.isCheckingApiHealth, isFalse);
      final checkFuture = appState.triggerApiHealthCheck();
      expect(appState.isCheckingApiHealth, isTrue);
      await checkFuture;
      expect(appState.isCheckingApiHealth, isFalse);
      expect(appState.apiHealth['isReachable'], isTrue);

      final voteSuccess = await appState.requestDatasetActivation(
        'some-dataset',
        'Some Title',
      );
      expect(voteSuccess, isTrue);

      final syncResult = await appState.triggerManualSync(
        '8935c8e5-ec77-421f-af86-d970583195f8',
      );
      expect(syncResult['success'], isTrue);

      // test updateDatasetScheduler in testing mode
      AppStateNotifier.isTesting = true;
      appState.initAdminMetadataListener(); // Load initial mock data
      expect(
        appState
            .datasetMetadataMap['8935c8e5-ec77-421f-af86-d970583195f8']?['scheduler'],
        isNull,
      );

      await appState.updateDatasetScheduler(
        '8935c8e5-ec77-421f-af86-d970583195f8',
        enabled: true,
        updateIntervalHours: 6,
      );

      final schedulerMap = appState
          .datasetMetadataMap['8935c8e5-ec77-421f-af86-d970583195f8']?['scheduler'];
      expect(schedulerMap, isNotNull);
      expect(schedulerMap['enabled'], isTrue);
      expect(schedulerMap['updateIntervalHours'], 6);
      expect(schedulerMap['nextRun'], isNotNull);

      // test updateDatasetScheduler in non-testing mode when firebase is not initialized
      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = false;

      // This should return immediately without throwing an error
      await appState.updateDatasetScheduler(
        '8935c8e5-ec77-421f-af86-d970583195f8',
        enabled: true,
        updateIntervalHours: 6,
      );

      // Reset values
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;

      appState.setMockProfile(null);
      appState.dispose();
    });

    test('patent classifications delegation works correctly', () async {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      // Verify initial state via delegated getters
      expect(appState.patentRecords, isEmpty);
      expect(appState.isLoadingPatents, isFalse);
      expect(appState.isLoadingMorePatents, isFalse);
      expect(appState.hasMorePatents, isTrue);

      // Initialize and verify data loads
      appState.initPatentClassificationsListener();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(appState.patentRecords.isNotEmpty, isTrue);
      expect(appState.isLoadingPatents, isFalse);

      // Test search query delegation
      appState.setPatentSearchQuery('test');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Test primary filter delegation
      appState.setPatentPrimaryFilter('Primary');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Test reset filters delegation
      appState.resetPatentFilters();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Test fetchNextPage delegation
      await appState.fetchNextPatentPage();

      // Test cancel listener delegation
      appState.cancelPatentClassificationsListener();
      expect(appState.patentRecords, isEmpty);
      expect(appState.isLoadingPatents, isFalse);
      expect(appState.hasMorePatents, isTrue);

      appState.dispose();
    });

    test('locale selection is persisted and loaded correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final state1 = AppStateNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(state1.locale, 'en');

      state1.setLocale('he');
      expect(state1.locale, 'he');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state2 = AppStateNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(state2.locale, 'he');

      state2.toggleLocale();
      expect(state2.locale, 'en');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state3 = AppStateNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(state3.locale, 'en');

      state1.dispose();
      state2.dispose();
      state3.dispose();
    });

    test('handles exceptions gracefully during locale loading', () async {
      LocalStorage.impl = FailingLocalStorage();

      final state = AppStateNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(state.locale, 'en');

      state.dispose();
      LocalStorage.impl = LocalStorageIO();
    });
  });
}

class FailingLocalStorage implements LocalStorageImpl {
  @override
  Future<void> init() async {
    throw Exception('Simulated init failure');
  }

  @override
  List<String> getFavorites() => [];

  @override
  Future<void> saveFavorites(List<String> favorites) async {}

  @override
  List<String> getRecents() => [];

  @override
  Future<void> saveRecents(List<String> recents) async {}

  @override
  bool getGuestMode() => false;

  @override
  Future<void> saveGuestMode(bool enabled) async {}

  @override
  Future<void> clearAll() async {}

  @override
  String? getLastSavedBranch() => null;

  @override
  Future<void> saveLastSavedBranch(String branch) async {}

  @override
  String getLocale() => 'en';

  @override
  Future<void> saveLocale(String locale) async {}
}
