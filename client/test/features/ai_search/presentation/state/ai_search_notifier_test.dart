import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/ai_search/presentation/state/ai_search_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
    SharedPreferences.setMockInitialValues({});
  });

  group('AiSearchNotifier Tests', () {
    late AppStateNotifier appState;

    setUp(() {
      appState = AppStateNotifier();
    });

    test('Loads and saves history correctly', () async {
      final notifier = AiSearchNotifier(appState: appState);
      await notifier.loadHistory();
      expect(notifier.history, isEmpty);

      // Perform test search (mock mode)
      await notifier.performSearch('Toyota recalls');
      expect(notifier.history.length, 1);
      expect(notifier.history.first, 'Toyota recalls');
      expect(notifier.searchResult, isNotNull);
      expect(notifier.searchResult!.citations.length, 1);

      // Verify clear history
      await notifier.clearHistory();
      expect(notifier.history, isEmpty);
    });

    test('Enforces maximum history limit of 5 items', () async {
      final notifier = AiSearchNotifier(appState: appState);
      await notifier.performSearch('q1');
      await notifier.performSearch('q2');
      await notifier.performSearch('q3');
      await notifier.performSearch('q4');
      await notifier.performSearch('q5');
      await notifier.performSearch('q6');

      expect(notifier.history.length, 5);
      expect(notifier.history.first, 'q6');
      expect(notifier.history.last, 'q2');
    });

    test('HTTP performSearch success paths', () async {
      AppStateNotifier.isTesting = false; // Test real calling logic
      final mockClient = http_testing.MockClient((request) async {
        final responseBody = {
          'answer': 'Found Toyota recall details [cit-01].',
          'citations': [
            {
              'id': 'cit-01',
              'datasetId': 'recalls-id',
              'docId': '11020',
              'title': 'Toyota Avensis',
            },
          ],
        };
        return http.Response(
          jsonEncode(responseBody),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final notifier = AiSearchNotifier(appState: appState, client: mockClient);
      await notifier.performSearch('toyota');

      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(
        notifier.searchResult!.answer,
        'Found Toyota recall details [cit-01].',
      );
      expect(notifier.searchResult!.citations.first.id, 'cit-01');
      AppStateNotifier.isTesting = true;
    });

    test('HTTP performSearch error paths', () async {
      AppStateNotifier.isTesting = false;
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Rate Limit Exceeded'}), 429);
      });

      final notifier = AiSearchNotifier(appState: appState, client: mockClient);
      await notifier.performSearch('toyota');

      expect(notifier.isLoading, isFalse);
      expect(notifier.searchResult, isNull);
      expect(notifier.errorMessage, 'Rate Limit Exceeded');
      AppStateNotifier.isTesting = true;
    });
  });
}
