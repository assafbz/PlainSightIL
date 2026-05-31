import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/main.dart';

void main() {
  testWidgets('App loads on dashboard and shows initial English content',
      (WidgetTester tester) async {
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

  testWidgets('Bilingual toggle updates locale, directionality, and translates text',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify directionality is LTR initially
    Directionality dirLtr = tester.widget<Directionality>(
        find.ancestor(
          of: find.text('Democratizing Civic Data'),
          matching: find.byType(Directionality),
        ).first
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
        find.ancestor(
          of: find.text('הנגשת מידע ממשלתי לציבור'),
          matching: find.byType(Directionality),
        ).first
    );
    expect(dirRtl.textDirection, TextDirection.rtl);

    // Tap language toggle again to return to English
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    // Verify text goes back to English
    expect(find.text('Democratizing Civic Data'), findsOneWidget);
    expect(find.text('HE'), findsOneWidget);
  });

  testWidgets('Tapping dataset cards or nav items navigates correctly',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Tap on the Cellular Antennas card on the Dashboard
    await tester.tap(find.text('Cellular Antennas'));
    await tester.pumpAndSettle();

    // Verify Cellular Antennas placeholder screen is shown
    expect(find.byIcon(Icons.cell_tower), findsNWidgets(2)); // Nav bar icon + screen icon
    expect(
      find.text('This dataset screen is under construction. Future integrations will include live data and interactive maps.'),
      findsOneWidget,
    );

    // Tap the Home navigation item to go back to Dashboard
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Verify we are back on the Dashboard by checking for the mission subtitle
    expect(find.text('Democratizing Civic Data'), findsOneWidget);

    // Tap the Water navigation tab directly from bottom nav bar
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    // Verify Kinneret Water Level placeholder screen is shown
    expect(find.byIcon(Icons.water_drop), findsNWidgets(2)); // Nav bar icon + screen icon
  });
}
