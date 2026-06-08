import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/ai_search/presentation/pages/ai_search_page.dart';
import 'package:plainsight/features/ai_search/presentation/widgets/ai_search_bar.dart';
import 'package:plainsight/features/ai_search/presentation/widgets/citation_badge.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';

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
      appState.setMockProfile(
        UserProfile(
          uid: 'mock_uid',
          firstName: 'Assaf',
          lastName: 'Benzaken',
          email: 'assaf@plainsight.il',
          role: 'user',
          isSubscribed: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
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

    testWidgets('Shows premium paywall overlay when not subscribed', (
      WidgetTester tester,
    ) async {
      appState.setMockProfile(
        UserProfile(
          uid: 'mock_uid',
          firstName: 'Assaf',
          lastName: 'Benzaken',
          email: 'assaf@plainsight.il',
          role: 'user',
          isSubscribed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

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

      // Verify paywall overlay elements are visible
      expect(find.text('Premium Feature'), findsOneWidget);
      expect(find.text(appState.translate('subscribe_btn')), findsOneWidget);

      // Tap Subscribe, verify user becomes subscribed and paywall is dismissed
      await tester.tap(find.text(appState.translate('subscribe_btn')));
      await tester.pumpAndSettle();

      expect(appState.userProfile?.isSubscribed, isTrue);
      expect(find.text('Premium Feature'), findsNothing);
    });

    testWidgets('Tapping close button on premium paywall pops the page', (
      WidgetTester tester,
    ) async {
      appState.setMockProfile(
        UserProfile(
          uid: 'mock_uid',
          firstName: 'Assaf',
          lastName: 'Benzaken',
          email: 'assaf@plainsight.il',
          role: 'user',
          isSubscribed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => AiSearchPage(
                          appState: appState,
                          onNavigate: (context, datasetId, docId) {},
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Search'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open page
      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      // Verify paywall overlay is visible
      expect(find.text('Premium Feature'), findsOneWidget);

      // Find and tap close button
      final closeButtonFinder = find.byKey(const Key('paywall_close_button'));
      expect(closeButtonFinder, findsOneWidget);
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      // Verify the page is popped and we are back to the previous screen
      expect(find.text('Premium Feature'), findsNothing);
      expect(find.text('Open Search'), findsOneWidget);
    });
  });
}
