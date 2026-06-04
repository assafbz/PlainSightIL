import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/widgets/coming_soon_screen.dart';

void main() {
  testWidgets('ComingSoonScreen renders with title and description', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = true;
    final appState = AppStateNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComingSoonScreen(
            title: 'Test Title',
            icon: Icons.info,
            color: Colors.blue,
            description: 'Test Description',
            appState: appState,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test Description'), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });
}
