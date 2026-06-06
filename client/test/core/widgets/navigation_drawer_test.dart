import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/widgets/navigation_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationDrawerWidget Tests', () {
    late AppStateNotifier appState;

    setUp(() {
      AppStateNotifier.isTesting = true;
      appState = AppStateNotifier();
    });

    tearDown(() {
      appState.dispose();
      AppStateNotifier.isTesting = true;
    });

    testWidgets(
      'NavigationDrawerWidget renders and handles theme/locale/tabs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              drawer: NavigationDrawerWidget(appState: appState),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        // Open drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationDrawerWidget), findsOneWidget);

        // 1. Language Toggle
        final langToggle = find.byKey(const ValueKey('drawer_language_toggle'));
        expect(langToggle, findsOneWidget);
        await tester.tap(langToggle);
        await tester.pumpAndSettle();
        expect(appState.locale, 'he');

        // Toggle back
        await tester.tap(langToggle);
        await tester.pumpAndSettle();
        expect(appState.locale, 'en');

        // 2. Tab Navigation
        // Tap Directory Tab
        final dirTab = find.text('Directory');
        expect(dirTab, findsOneWidget);
        await tester.tap(dirTab);
        await tester.pumpAndSettle();
        expect(appState.activeTab, 1);

        // Reopen drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap Alerts Tab
        final alertsTab = find.text('Alerts');
        expect(alertsTab, findsOneWidget);
        await tester.tap(alertsTab);
        await tester.pumpAndSettle();
        expect(appState.activeTab, 2);

        // Reopen drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap Home Tab
        final homeTab = find.text('Home');
        expect(homeTab, findsOneWidget);
        await tester.tap(homeTab);
        await tester.pumpAndSettle();
        expect(appState.activeTab, 0);

        // Reopen drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 3. Theme Toggle
        final themeToggle = find.byKey(const ValueKey('drawer_theme_toggle'));
        expect(themeToggle, findsOneWidget);
        final initialThemeMode = appState.isDarkMode;
        await tester.tap(themeToggle);
        await tester.pumpAndSettle();
        expect(appState.isDarkMode, !initialThemeMode);

        // 4. Admin Navigation
        final adminBtn = find.byKey(const ValueKey('drawer_admin_button'));
        expect(adminBtn, findsOneWidget);
        await tester.tap(adminBtn);
        await tester.pumpAndSettle();
        // Verifies pop and push of AdminPage
        expect(find.byType(NavigationDrawerWidget), findsNothing);
      },
    );

    testWidgets('Guest Mode handles unauthenticated layout and login tap', (
      WidgetTester tester,
    ) async {
      // Set unauthenticated guest mode
      AppStateNotifier.isTesting = false;
      appState.setMockProfile(null);
      await appState.signOut();
      appState.setGuestMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: NavigationDrawerWidget(appState: appState),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Guest User'), findsOneWidget);

      // Tap login label
      final loginBtn = find.text('Log in');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(appState.isGuestMode, isFalse);
      expect(
        find.byType(NavigationDrawerWidget),
        findsNothing,
      ); // Drawer popped
    });

    testWidgets('Logout button handles sign out', (WidgetTester tester) async {
      AppStateNotifier.isTesting = true;
      await appState.signInWithGoogle();
      expect(appState.isAuthenticated, isTrue);

      AppStateNotifier.isTesting = false;
      expect(appState.isAuthenticated, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: NavigationDrawerWidget(appState: appState),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const ValueKey('drawer_logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(appState.isAuthenticated, isFalse);
    });

    testWidgets('Tapping user profile card navigates to ProfileSettingsPage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: NavigationDrawerWidget(appState: appState),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find user profile card and tap it
      final profileCard = find.byType(Card);
      expect(profileCard, findsOneWidget);
      await tester.tap(profileCard);
      await tester.pumpAndSettle();

      // Verifies pop and push of ProfileSettingsPage
      expect(find.byType(NavigationDrawerWidget), findsNothing);
    });

    testWidgets('Tapping data attribution links triggers url_launcher', (
      WidgetTester tester,
    ) async {
      const MethodChannel channel = MethodChannel(
        'plugins.flutter.io/url_launcher',
      );
      final List<MethodCall> log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        MethodCall methodCall,
      ) async {
        log.add(methodCall);
        if (methodCall.method == 'canLaunch') {
          return true;
        }
        if (methodCall.method == 'launch') {
          return true;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: NavigationDrawerWidget(appState: appState),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final attributionText = find.text('data.gov.il');
      expect(attributionText, findsOneWidget);
      await tester.tap(attributionText);
      await tester.pumpAndSettle();

      expect(log, isNotEmpty);
      expect(log.any((method) => method.method == 'launch'), isTrue);
    });
  });
}
