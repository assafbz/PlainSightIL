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

      // Verify all three supported datasets cards exist initially
      expect(find.text('Cellular Antennas'), findsOneWidget);
      expect(find.text('Cellular Permit Applications'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsOneWidget);

      // Type query "Permit" in Search Field
      await tester.enterText(find.byType(TextField), 'Permit');
      await tester.pumpAndSettle();

      // Verify list is filtered
      expect(find.text('Cellular Antennas'), findsNothing);
      expect(find.text('Cellular Permit Applications'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsNothing);

      // Clear search query
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify list goes back to showing all datasets
      expect(find.text('Cellular Antennas'), findsOneWidget);
      expect(find.text('Companies in Liquidation'), findsOneWidget);

      // Filter by Error status (by default mock datasets are status 'idle')
      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      // Verify no datasets match the "Error" status filter
      expect(find.text('Cellular Antennas'), findsNothing);
      expect(find.text('Companies in Liquidation'), findsNothing);
      expect(find.text('No records found'), findsOneWidget);
    },
  );

  testWidgets('AdminPage renders Access Denied when user is not admin', (
    WidgetTester tester,
  ) async {
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
}
