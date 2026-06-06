import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/ai_search/presentation/pages/ai_search_page.dart';
import 'package:plainsight/features/ai_search/presentation/widgets/ai_search_bar.dart';
import 'package:plainsight/features/ai_search/presentation/widgets/citation_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
    SharedPreferences.setMockInitialValues({});
  });

  group('AiSearchPage Widget Tests', () {
    late AppStateNotifier appState;

    setUp(() {
      appState = AppStateNotifier();
    });

    testWidgets('Renders layout elements (header, input, suggestions)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiSearchPage(
              appState: appState,
              onNavigate: (context, datasetId, docId) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Semantic Search'), findsOneWidget);
      expect(find.byType(AiSearchBar), findsOneWidget);
      expect(find.text('Toyota recalls'), findsOneWidget);
      expect(find.text('Turkey travel warnings'), findsOneWidget);
    });

    testWidgets('Tapping suggestions triggers search and renders answer', (
      WidgetTester tester,
    ) async {
      String? routedDatasetId;
      String? routedDocId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiSearchPage(
              appState: appState,
              onNavigate: (context, datasetId, docId) {
                routedDatasetId = datasetId;
                routedDocId = docId;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap suggestion chip "Toyota recalls"
      await tester.tap(find.text('Toyota recalls'));
      await tester.pump(); // Start loading, shimmer loader is active
      expect(find.byType(ShimmerLoader), findsOneWidget);

      await tester.pumpAndSettle(); // Resolve mock search response

      // Check answer rendering
      expect(find.byType(ParsedAnswerText), findsOneWidget);
      expect(
        find.textContaining('Active recalls found for Toyota'),
        findsOneWidget,
      );

      // Verify inline citation badge is clickable
      final badgeFinder = find.byType(CitationBadge);
      expect(badgeFinder, findsWidgets);
      await tester.tap(badgeFinder.first);
      await tester.pumpAndSettle();

      expect(routedDatasetId, isNotNull);
      expect(routedDocId, '11020');
    });
  });
}
