import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/app_state.dart';

void main() {
  group('AppStateNotifier Tests', () {
    late AppStateNotifier appState;

    setUp(() {
      appState = AppStateNotifier();
    });

    test('Initial values are set correctly', () {
      expect(appState.locale, 'en');
      expect(appState.activeTab, 0);
      expect(appState.textDirection, TextDirection.ltr);
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

      // Change locale to Hebrew and check translation
      appState.setLocale('he');
      expect(appState.translate('app_title'), 'PlainSight IL');
      expect(appState.translate('welcome_back'), 'ברוכים הבאים');
      expect(appState.translate('nav_home'), 'בית');
    });

    test('translate returns the key itself if no translation is found', () {
      expect(appState.translate('non_existent_key'), 'non_existent_key');
    });
  });
}
