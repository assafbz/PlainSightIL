import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/config/firebase_config.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AppStateNotifier Tests', () {
    late AppStateNotifier appState;

    setUp(() {
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
        expect(key, startsWith('AIzaSy'));
        expect(key.length, 39);

        final RegExp gcloudKeyPattern = RegExp(r'^AIzaSy[a-zA-Z0-9_-]{33}$');
        expect(gcloudKeyPattern.hasMatch(key), isTrue);
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
  });
}
