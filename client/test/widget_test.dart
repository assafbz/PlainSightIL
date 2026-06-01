import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/main.dart';

void main() {
  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  testWidgets('App loads on dashboard and shows initial English content', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify initial English content exists
    expect(find.text('PlainSight IL'), findsWidgets);
    expect(find.text('Democratizing Civic Data'), findsOneWidget);
    expect(find.text('HE'), findsOneWidget); // Language switcher toggle key

    // Verify dataset cards are present on the dashboard
    expect(find.text('Cellular Antennas'), findsOneWidget);
    expect(find.text('Kinneret Water Level'), findsOneWidget);
    expect(find.text('Government Budget'), findsOneWidget);
  });

  testWidgets(
    'Bilingual toggle updates locale, directionality, and translates text',
    (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify directionality is LTR initially
      Directionality dirLtr = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('Democratizing Civic Data'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dirLtr.textDirection, TextDirection.ltr);

      // Tap the bilingual language toggle to switch to Hebrew
      await tester.tap(find.text('HE'));
      await tester.pumpAndSettle();

      // Verify text is now translated to Hebrew
      expect(find.text('הנגשת מידע ממשלתי לציבור'), findsOneWidget);
      expect(find.text('אנטנות סלולריות'), findsOneWidget);
      expect(find.text('מפלס הכנרת'), findsOneWidget);
      expect(find.text('תקציב המדינה'), findsOneWidget);

      // Verify toggle button now displays 'EN'
      expect(find.text('EN'), findsOneWidget);

      // Verify directionality is now RTL
      Directionality dirRtl = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('הנגשת מידע ממשלתי לציבור'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dirRtl.textDirection, TextDirection.rtl);

      // Tap language toggle again to return to English
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      // Verify text goes back to English
      expect(find.text('Democratizing Civic Data'), findsOneWidget);
      expect(find.text('HE'), findsOneWidget);
    },
  );

  testWidgets('Tapping dataset cards or nav items navigates correctly', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Tap on the Cellular Antennas card on the Dashboard
    await tester.tap(find.text('Cellular Antennas'));
    await tester.pumpAndSettle();

    // Verify Cellular Antennas screen is shown with segmented controls
    expect(find.byIcon(Icons.cell_tower), findsOneWidget);
    expect(find.text('Active Towers'), findsOneWidget);
    expect(find.text('Construction Permits'), findsOneWidget);

    // Tap the Home navigation item to go back to Dashboard
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Verify we are back on the Dashboard by checking for the mission subtitle
    expect(find.text('Democratizing Civic Data'), findsOneWidget);

    // Tap the Water navigation tab directly from bottom nav bar
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    // Verify Kinneret Water Level placeholder screen is shown
    expect(
      find.byIcon(Icons.water_drop),
      findsNWidgets(2),
    ); // Nav bar icon + screen icon
  });

  testWidgets('Drawer opens and theme and language can be toggled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify drawer is not open
    expect(find.byType(NavigationDrawerWidget), findsNothing);

    // Tap on the Menu icon in the Header
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Verify drawer is now open
    expect(find.byType(NavigationDrawerWidget), findsOneWidget);

    // Verify language toggle button in drawer works and translates content
    final toggleFinder = find.byKey(const ValueKey('drawer_language_toggle'));
    expect(toggleFinder, findsOneWidget);
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    // The locale should change to Hebrew and translate text
    expect(
      find.descendant(
        of: find.byType(NavigationDrawerWidget),
        matching: find.text('בית'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationDrawerWidget),
        matching: find.text('אנטנות סלולריות'),
      ),
      findsOneWidget,
    );

    // Verify theme toggle button works
    expect(find.byKey(const ValueKey('drawer_theme_toggle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer_theme_toggle')));
    await tester.pumpAndSettle();

    // Dark mode should switch to light mode and display wb_sunny
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);

    // Tap attribution link
    await tester.tap(find.text('data.gov.il'));
    await tester.pumpAndSettle();
  });
}
