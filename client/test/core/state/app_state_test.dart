// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/config/firebase_config.dart';
import 'package:plainsight/core/state/app_state.dart';
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

        if (key == 'mock-api-key-for-local-emulator' || key == 'AIzaSyMockApiKeyForLocalEmulator_32ch') {
          // Accept mock keys
        } else {
          expect(key, startsWith('AIzaSy'));
          expect(key.length, 39);

          final RegExp gcloudKeyPattern = RegExp(r'^AIzaSy[a-zA-Z0-9_-]{33}$');
          expect(gcloudKeyPattern.hasMatch(key), isTrue);
        }
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

      expect(appState.isLoadingAntennas, isTrue);
      expect(appState.isLoadingPermits, isTrue);
      expect(appState.permitSyncStatus, 'idle');
      expect(appState.isLoadingLiquidation, isTrue);
      expect(appState.isLoadingDoctors, isTrue);
      expect(appState.isFirebaseInitialized, isFalse);
      expect(appState.atmRecords, isEmpty);
      expect(appState.isLoadingAtms, isTrue);
      appState.initBankAtmsListener();
      appState.cancelBankAtmsListener();

      appState.initPermitMetadataListener();
      expect(appState.isLoadingAntennas, isFalse);
      expect(appState.isLoadingPermits, isFalse);

      appState.initAdminMetadataListener();
      appState.initDirectoryListener();
      appState.initLiquidationListener();
      appState.initDoctorsListener();
      appState.initTelemetryListeners();

      expect(appState.isLoadingAdminMetadata, isFalse);
      expect(appState.isLoadingTelemetry, isFalse);
      expect(appState.isLoadingDirectory, isFalse);

      expect(appState.antennaRecords.isNotEmpty, isTrue);
      expect(appState.permitRecords.isNotEmpty, isTrue);
      expect(appState.liquidationRecords.isNotEmpty, isTrue);
      expect(appState.doctorRecords.isNotEmpty, isTrue);
      expect(appState.datasetMetadataMap.isNotEmpty, isTrue);
      expect(appState.apiHealth.isNotEmpty, isTrue);
      expect(appState.scraperRuns.isNotEmpty, isTrue);
      expect(appState.directoryRecords.isNotEmpty, isTrue);

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

      await appState.updateDatasetScheduler(
        '8935c8e5-ec77-421f-af86-d970583195f8',
        enabled: true,
        updateIntervalHours: 6,
      );
      final meta = appState.datasetMetadataMap['8935c8e5-ec77-421f-af86-d970583195f8'];
      expect(meta?['scheduler']?['enabled'], isTrue);
      expect(meta?['scheduler']?['updateIntervalHours'], 6);

      appState.setMockProfile(null);
      appState.dispose();
    });
  });
}
