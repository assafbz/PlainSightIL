import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/directory/presentation/widgets/dataset_card.dart';
import 'package:plainsight/app.dart';
import 'package:plainsight/core/widgets/navigation_drawer.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';

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
    expect(find.text('Companies in Liquidation'), findsOneWidget);
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
      expect(find.text('חברות בפירוק'), findsOneWidget);

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

    // Ensure the card is visible before tapping
    await tester.ensureVisible(find.text('Cellular Antennas'));
    await tester.pumpAndSettle();

    // Tap on the Cellular Antennas card on the Dashboard
    await tester.tap(find.text('Cellular Antennas'));
    await tester.pumpAndSettle();

    // Verify Cellular Antennas screen is shown with segmented controls
    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.text('Active Towers'), findsOneWidget);
    expect(find.text('Construction Permits'), findsOneWidget);

    // Tap the AppBar Back button to go back to Dashboard
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Ensure Travel Warnings card is visible and tap it
    await tester.ensureVisible(find.text('Travel Warnings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel Warnings'));
    await tester.pumpAndSettle();

    // Verify Travel Warnings screen is shown
    expect(find.text('Search by country or continent...'), findsOneWidget);

    // Tap the AppBar Back button to go back to Dashboard
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Verify we are back on the Dashboard by checking for the mission subtitle
    expect(find.text('Democratizing Civic Data'), findsOneWidget);

    // Tap the Directory navigation tab directly from bottom nav bar
    await tester.tap(find.text('Directory'));
    await tester.pumpAndSettle();

    // Scroll the directory list down to reveal the rest of the cards
    await tester.drag(find.byType(ListView), const Offset(0.0, -500.0));
    await tester.pumpAndSettle();

    final cardFinder = find.text('חברות בפירוק');
    final buttonFinder = find.descendant(
      of: find.ancestor(of: cardFinder, matching: find.byType(DatasetCard)),
      matching: find.text('Open Visualizer'),
    );
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // Verify Companies in Liquidation screen is shown
    expect(find.text('Companies in Liquidation'), findsWidgets);
    expect(find.byIcon(Icons.search), findsOneWidget);
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
        matching: find.text('מדריך מאגרים'),
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

  testWidgets('App redirects to LoginPage when unauthenticated', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = false;

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify it shows LoginPage components and not Dashboard
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Democratizing Civic Data'), findsNothing);

    // Scroll to the button to make sure it's visible in 800x600 test window
    await tester.ensureVisible(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // Tap Continue as Guest
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // Verify it transitions to Dashboard
    expect(find.text('Democratizing Civic Data'), findsOneWidget);
  });

  testWidgets(
    'Tapping permits card in directory navigates to CellularAntennasScreen with Construction Permits selected',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Tap the Directory navigation tab
      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();

      // Scroll the list down slightly to reveal the card
      await tester.drag(find.byType(ListView), const Offset(0.0, -200.0));
      await tester.pumpAndSettle();

      // Find the permits card (its title is 'בקשות להיתרי הקמה של אנטנות')
      final cardFinder = find.text('בקשות להיתרי הקמה של אנטנות');
      expect(cardFinder, findsOneWidget);

      final buttonFinder = find.descendant(
        of: find.ancestor(of: cardFinder, matching: find.byType(DatasetCard)),
        matching: find.text('Open Visualizer'),
      );
      expect(buttonFinder, findsOneWidget);
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify it navigates to CellularAntennasScreen
      expect(find.byType(CellularAntennasScreen), findsOneWidget);

      // Verify Permits tab is selected
      final activeTowersContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Active Towers'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(activeTowersContainer.decoration, isNull);

      final permitsContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Construction Permits'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(permitsContainer.decoration, isNotNull);
    },
  );
}
