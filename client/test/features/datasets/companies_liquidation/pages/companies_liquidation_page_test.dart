import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart';
import 'package:plainsight/features/datasets/companies_liquidation/widgets/liquidation_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('CompaniesLiquidationScreen Widget Tests', () {
    testWidgets('Renders title, search bar, chips, and initial list items', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initLiquidationListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CompaniesLiquidationScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Check title rendering
      expect(find.text('Companies in Liquidation'), findsOneWidget);

      // Check search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify that mock cards are rendered
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsOneWidget);
      expect(find.text('משה שירותי בנייה בע"מ'), findsOneWidget);
      expect(find.text('ישראל קומפני בע"מ'), findsOneWidget);
    });

    testWidgets('Filtering items via search query works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initLiquidationListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CompaniesLiquidationScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find text field and type "אלברט"
      await tester.enterText(find.byType(TextField), 'אלברט');
      await tester.pumpAndSettle();

      // Verify lists are filtered
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsOneWidget);
      expect(find.text('משה שירותי בנייה בע"מ'), findsNothing);
      expect(find.text('ישראל קומפני בע"מ'), findsNothing);

      // Type "512345680" (H.P. of Closed company)
      await tester.enterText(find.byType(TextField), '512345680');
      await tester.pumpAndSettle();

      // Verify lists are filtered to closed company
      expect(find.text('ישראל קומפני בע"מ'), findsOneWidget);
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsNothing);

      // Clear search query
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify all items restored
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsOneWidget);
      expect(find.text('משה שירותי בנייה בע"מ'), findsOneWidget);
      expect(find.text('ישראל קומפני בע"מ'), findsOneWidget);
    });

    testWidgets('Filtering items via status chip works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initLiquidationListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CompaniesLiquidationScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find chip for "Active" and tap it
      final activeChipFinder = find.text(appState.translate('filter_active'));
      expect(activeChipFinder, findsOneWidget);
      await tester.tap(activeChipFinder);
      await tester.pumpAndSettle();

      // Should filter to show only active / frozen companies
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsOneWidget);
      expect(find.text('משה שירותי בנייה בע"מ'), findsOneWidget);
      expect(find.text('ישראל קומפני בע"מ'), findsNothing);

      // Find chip for "Closed" and tap it
      final closedChipFinder = find.text('Closed');
      expect(closedChipFinder, findsOneWidget);
      await tester.tap(closedChipFinder);
      await tester.pumpAndSettle();

      // Should filter to show only closed company
      expect(find.text('ישראל קומפני בע"מ'), findsOneWidget);
      expect(find.text('אלברט לוי הנדסה בע"מ'), findsNothing);
      expect(find.text('משה שירותי בנייה בע"מ'), findsNothing);
    });

    testWidgets(
      'Tapping on a company card opens LiquidationDetailDrawer sheet',
      (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.initLiquidationListener();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompaniesLiquidationScreen(appState: appState),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find first card and tap it
        final cardFinder = find.text('אלברט לוי הנדסה בע"מ');
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // Check if details drawer is loaded
        expect(find.byType(LiquidationDetailDrawer), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(LiquidationDetailDrawer),
            matching: find.textContaining('512345678'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
