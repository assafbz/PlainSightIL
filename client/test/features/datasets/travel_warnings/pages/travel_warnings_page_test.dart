import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/travel_warnings/pages/travel_warnings_page.dart';
import 'package:plainsight/features/datasets/travel_warnings/widgets/travel_warning_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('TravelWarningsScreen Widget Tests', () {
    testWidgets('Renders title, search bar, chips, and initial list items', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initTravelWarningsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TravelWarningsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Check title rendering
      expect(find.text('Travel Warnings'), findsOneWidget);

      // Check search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify that mock cards are rendered
      expect(find.text('אוגנדה'), findsOneWidget);
      expect(find.text('אוזבקיסטאן'), findsOneWidget);
      expect(find.text('אוסטריה'), findsOneWidget);

      // Verify continent chips are rendered (All, אפריקה, אסיה, אירופה)
      expect(find.text('All'), findsOneWidget);
      expect(find.text('אפריקה'), findsOneWidget);
      expect(find.text('אסיה'), findsOneWidget);
      expect(find.text('אירופה'), findsOneWidget);
    });

    testWidgets('Filtering items via search query works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initTravelWarningsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TravelWarningsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find text field and type "אוגנדה"
      await tester.enterText(find.byType(TextField), 'אוגנדה');
      await tester.pumpAndSettle();

      // Verify lists are filtered (scope match to ListView to avoid TextField text)
      final listUgandaFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.text('אוגנדה'),
      );
      expect(listUgandaFinder, findsOneWidget);
      expect(find.text('אוזבקיסטאן'), findsNothing);
      expect(find.text('אוסטריה'), findsNothing);

      // Type "אסיה" (continent in Hebrew)
      await tester.enterText(find.byType(TextField), 'אסיה');
      await tester.pumpAndSettle();

      // Verify lists are filtered to Uzbekistan
      expect(find.text('אוזבקיסטאן'), findsOneWidget);
      expect(listUgandaFinder, findsNothing);

      // Clear search query
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify all items restored
      expect(find.text('אוגנדה'), findsOneWidget);
      expect(find.text('אוזבקיסטאן'), findsOneWidget);
      expect(find.text('אוסטריה'), findsOneWidget);
    });

    testWidgets('Filtering items via continent chip works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initTravelWarningsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TravelWarningsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "אירופה" chip
      final europeChipFinder = find.text('אירופה');
      expect(europeChipFinder, findsOneWidget);
      await tester.tap(europeChipFinder);
      await tester.pumpAndSettle();

      // Should filter to show only Austria
      expect(find.text('אוסטריה'), findsOneWidget);
      expect(find.text('אוגנדה'), findsNothing);
      expect(find.text('אוזבקיסטאן'), findsNothing);

      // Tap the "All" chip to restore
      final allChipFinder = find.text('All');
      expect(allChipFinder, findsOneWidget);
      await tester.tap(allChipFinder);
      await tester.pumpAndSettle();

      // All items restored
      expect(find.text('אוגנדה'), findsOneWidget);
      expect(find.text('אוזבקיסטאן'), findsOneWidget);
      expect(find.text('אוסטריה'), findsOneWidget);
    });

    testWidgets(
      'Tapping on a warning card opens TravelWarningDetailDrawer sheet',
      (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.initTravelWarningsListener();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TravelWarningsScreen(appState: appState)),
          ),
        );
        await tester.pumpAndSettle();

        // Find first card and tap it
        final cardFinder = find.text('אוגנדה');
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // Check if details drawer is loaded
        expect(find.byType(TravelWarningDetailDrawer), findsOneWidget);
        expect(find.text('Travel Warning Details'), findsOneWidget);
        expect(find.text('אוגנדה'), findsWidgets);
      },
    );
  });
}
