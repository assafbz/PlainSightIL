import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/widgets/navigation_drawer.dart';

void main() {
  testWidgets('NavigationDrawerWidget renders correctly', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = true;
    final appState = AppStateNotifier();

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

    await tester.pumpAndSettle();

    // Open drawer
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify NavigationDrawerWidget is shown
    expect(find.byType(NavigationDrawerWidget), findsOneWidget);
  });
}
