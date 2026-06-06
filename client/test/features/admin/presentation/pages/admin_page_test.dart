import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/admin/presentation/pages/admin_page.dart';

void main() {
  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  testWidgets(
    'AdminPage renders supported datasets list and filters correct records',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppStateNotifier();
      // Build the AdminPage within a MaterialApp framework
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: AdminPage(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title and Search Bar exist
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify section headers and primary directory card exist
      expect(find.text('Primary Dataset Directory'), findsOneWidget);
      expect(find.text('Dataset Directory'), findsOneWidget);
      expect(find.text('Supported Datasets'), findsOneWidget);

      // Verify all supported datasets cards exist initially
      expect(find.text('Cellular Antennas'), findsOneWidget);
      expect(find.text('Cellular Permit Applications'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsOneWidget);
      expect(find.text('Doctors Licenses'), findsOneWidget);
      expect(find.text('Bank ATMs'), findsOneWidget);

      // Scroll down to find Car Importers card
      final carImportersFinder = find.text(
        'Car Importers and New Car Price Lists',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600.0));
      await tester.pumpAndSettle();
      expect(carImportersFinder, findsOneWidget);

      // Scroll back up for remaining test actions
      await tester.drag(find.byType(ListView), const Offset(0, 1000.0));
      await tester.pumpAndSettle();

      // Type query "Permit" in Search Field
      await tester.enterText(find.byType(TextField), 'Permit');
      await tester.pumpAndSettle();

      // Verify list is filtered
      expect(find.text('Dataset Directory'), findsNothing);
      expect(find.text('Cellular Antennas'), findsNothing);
      expect(find.text('Cellular Permit Applications'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsNothing);

      // Clear search query
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify list goes back to showing all datasets
      expect(find.text('Dataset Directory'), findsOneWidget);
      expect(find.text('Cellular Antennas'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsOneWidget);

      // Type query "Travel" in Search Field
      await tester.enterText(find.byType(TextField), 'Travel');
      await tester.pumpAndSettle();

      // Verify list is filtered to Travel Warnings
      expect(find.text('Dataset Directory'), findsNothing);
      expect(find.text('Cellular Antennas'), findsNothing);
      expect(find.text('Travel Warnings'), findsOneWidget);

      // Clear search query again
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Filter by Error status (by default mock datasets are status 'idle')
      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      // Verify no datasets match the "Error" status filter
      expect(find.text('Dataset Directory'), findsNothing);
      expect(find.text('Cellular Antennas'), findsNothing);
      expect(find.text('Companies in Liquidation'), findsNothing);
      expect(find.text('No records found'), findsOneWidget);
    },
  );

  testWidgets('AdminPage renders Access Denied when user is not admin', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    AppStateNotifier.isTesting = false;
    final appState = AppStateNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: AdminPage(appState: appState),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Access Denied content exists
    expect(find.text('Access Denied'), findsOneWidget);
    expect(
      find.text('You do not have permission to access this page.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);

    // Verify datasets are not rendered
    expect(find.text('Cellular Antennas'), findsNothing);
  });

  testWidgets('AdminPage manual sync trigger works and changes state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppStateNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: AdminPage(appState: appState)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Verify manual sync buttons exist on the screen (6 supported + 1 directory = 7 buttons)
    final syncButtonsFinder = find.byType(ElevatedButton);
    expect(syncButtonsFinder, findsNWidgets(7));

    // By default, all buttons show 'Trigger Sync'
    expect(find.text('Trigger Sync'), findsNWidgets(7));

    // Tap the first button to trigger manual sync (which is the primary Dataset Directory card)
    await tester.tap(syncButtonsFinder.at(0));

    // Pump to initiate state change and verify immediate syncing visual feedback
    await tester.pump();
    expect(find.text('Syncing...'), findsOneWidget);

    // Wait for the mock Future delay in triggerManualSync (1 second) to complete
    await tester.pump(const Duration(seconds: 1));
    await tester
        .pump(); // Run microtasks scheduled by Future resolution (calls showSnackBar)
    // Pump frames to allow SnackBar slide-up animation to complete (without auto-dismissing)
    await tester.pump(const Duration(milliseconds: 500));

    // The mock sync should complete and return to idle with a success SnackBar
    expect(find.text('Syncing...'), findsNothing);
    expect(find.text('Trigger Sync'), findsNWidgets(7));
    expect(
      find.text('Sync completed successfully! Updated 10000 records.'),
      findsOneWidget,
    );
  });
}
