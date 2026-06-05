import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/pages/vehicle_recalls_page.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/widgets/vehicle_recall_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('VehicleRecallsScreen Widget Tests', () {
    testWidgets(
      'Renders page title, search bar, chips, and initial list items',
      (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.initRecallsListener();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: VehicleRecallsScreen(appState: appState)),
          ),
        );
        await tester.pumpAndSettle();

        // Check title rendering (English locale default is "Vehicle Recalls")
        expect(find.text('Vehicle Recalls'), findsOneWidget);

        // Check search field
        expect(find.byType(TextField), findsOneWidget);

        // Verify that mock cards are rendered
        expect(find.text('TOYOTA - AVENSIS'), findsOneWidget);
        expect(find.text('SUZUKI MOTORCYCLES - EXEL  SUZUK'), findsOneWidget);
      },
    );

    testWidgets('Filtering items via search query works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initRecallsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VehicleRecallsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find text field and type "TOYOTA"
      await tester.enterText(find.byType(TextField), 'TOYOTA');
      await tester.pumpAndSettle();

      // Verify lists are filtered
      expect(find.text('TOYOTA - AVENSIS'), findsOneWidget);
      expect(find.text('SUZUKI MOTORCYCLES - EXEL  SUZUK'), findsNothing);
    });

    testWidgets('Filtering items via manufacturer chip works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initRecallsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VehicleRecallsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find chip for "SUZUKI MOTORCYCLES"
      final chipFinder = find.text('SUZUKI MOTORCYCLES').first;
      expect(chipFinder, findsOneWidget);

      // Tap the manufacturer chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Should filter to only show Suzuki
      expect(find.text('SUZUKI MOTORCYCLES - EXEL  SUZUK'), findsOneWidget);
      expect(find.text('TOYOTA - AVENSIS'), findsNothing);
    });

    testWidgets(
      'Tapping on a recall card opens VehicleRecallDetailDrawer sheet',
      (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.initRecallsListener();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: VehicleRecallsScreen(appState: appState)),
          ),
        );
        await tester.pumpAndSettle();

        // Find Toyota card and tap it
        final cardFinder = find.text('TOYOTA - AVENSIS');
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // Check if details drawer is loaded
        expect(find.byType(VehicleRecallDetailDrawer), findsOneWidget);
        expect(find.text('Recall Details'), findsOneWidget);
        expect(find.text('11020'), findsOneWidget); // Recall ID
      },
    );
  });
}
