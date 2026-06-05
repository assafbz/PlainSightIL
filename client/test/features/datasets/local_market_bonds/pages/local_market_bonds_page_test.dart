import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/local_market_bonds/pages/local_market_bonds_page.dart';
import 'package:plainsight/features/datasets/local_market_bonds/widgets/bond_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('LocalMarketBondsScreen Widget Tests', () {
    testWidgets('Renders page title, search bar, chips, and initial list items', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initBondsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalMarketBondsScreen(appState: appState)),
        ),
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // wait for 50ms delayed fetch
      await tester.pumpAndSettle();

      // Check title rendering (English locale default is "Local Market Bonds")
      expect(find.text('Local Market Bonds'), findsOneWidget);

      // Check search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify that mock cards are rendered (Series 1227784 and 1220722 are in mock bonds list)
      expect(find.text('Series: 1227784'), findsOneWidget);
      expect(find.text('Series: 1220722'), findsOneWidget);
    });

    testWidgets('Filtering items via search query works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initBondsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalMarketBondsScreen(appState: appState)),
        ),
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // wait for 50ms delayed fetch
      await tester.pumpAndSettle();

      // Find text field and type "1227784"
      await tester.enterText(find.byType(TextField), '1227784');
      await tester.pump(const Duration(milliseconds: 600)); // wait for debounce
      await tester.pumpAndSettle();

      // Verify lists are filtered
      expect(find.text('Series: 1227784'), findsOneWidget);
      expect(find.text('Series: 1220722'), findsNothing);
    });

    testWidgets('Filtering items via type chip works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initBondsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalMarketBondsScreen(appState: appState)),
        ),
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // wait for 50ms delayed fetch
      await tester.pumpAndSettle();

      // Find chip for "Government"
      final chipFinder = find.text('Government').first;
      expect(chipFinder, findsOneWidget);

      // Tap the type chip
      await tester.tap(chipFinder);
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // wait for 50ms delayed fetch
      await tester.pumpAndSettle();

      // Should filter to only show that type (Series 1227784 is Government)
      expect(find.text('Series: 1227784'), findsOneWidget);
      expect(find.text('Series: 1220722'), findsNothing);
    });

    testWidgets('Tapping on a bond card opens BondDetailDrawer sheet', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initBondsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalMarketBondsScreen(appState: appState)),
        ),
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // wait for 50ms delayed fetch
      await tester.pumpAndSettle();

      // Find first card and tap it
      final firstCardFinder = find.text('Series: 1227784');
      await tester.tap(firstCardFinder);
      await tester.pumpAndSettle();

      // Check if details drawer is loaded
      expect(find.byType(BondDetailDrawer), findsOneWidget);
      expect(find.text('Bond Specifications'), findsOneWidget);
      expect(find.text('4.15%'), findsOneWidget); // Coupon
    });
  });
}
