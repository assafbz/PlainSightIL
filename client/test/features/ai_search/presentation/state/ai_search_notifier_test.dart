// ignore_for_file: depend_on_referenced_packages, close_sinks

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/ai_search/presentation/state/ai_search_notifier.dart';

class FakeUser implements User {
  final String _uid;
  final String _email;

  FakeUser(this._uid, this._email);

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async =>
      'mock-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  final User? mockCurrentUser;

  FakeFirebaseAuth({this.mockCurrentUser});

  @override
  User? get currentUser => mockCurrentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ThrowingSharedPreferencesStore extends SharedPreferencesStorePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<bool> clear() => throw Exception('Prefs write error');

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      throw Exception('Prefs write error');

  @override
  Future<Map<String, Object>> getAll() => throw Exception('Prefs read error');

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => throw Exception('Prefs read error');

  @override
  Future<bool> remove(String key) => throw Exception('Prefs write error');

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw Exception('Prefs write error');
}

class FakeHttpClientResponse implements HttpClientResponse {
  final List<int> _bodyBytes;
  @override
  final int statusCode;

  FakeHttpClientResponse(this._bodyBytes, this.statusCode);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bodyBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  int get contentLength => _bodyBytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  final HttpClientResponse response;
  @override
  final HttpHeaders headers = FakeHttpHeaders();

  FakeHttpClientRequest(this.response);

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = 0;

  @override
  void write(Object? object) {}

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClient implements HttpClient {
  final HttpClientRequest request;
  FakeHttpClient(this.request);

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => request;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => request;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MyHttpOverrides extends HttpOverrides {
  final HttpClient client;
  MyHttpOverrides(this.client);

  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

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

    test('HTTP performSearch success paths with auth token', () async {
      AppStateNotifier.isTesting = false; // Test real calling logic
      AppStateNotifier.testIsFirebaseInitialized = true;
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

      final fakeUser = FakeUser('uid-123', 'test@example.com');
      final fakeAuth = FakeFirebaseAuth(mockCurrentUser: fakeUser);

      final notifier = AiSearchNotifier(
        appState: appState,
        client: mockClient,
        auth: fakeAuth,
      );
      await notifier.performSearch('toyota');

      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(
        notifier.searchResult!.answer,
        'Found Toyota recall details [cit-01].',
      );
      expect(notifier.searchResult!.citations.first.id, 'cit-01');

      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
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

    test('HTTP performSearch error path with invalid JSON response', () async {
      AppStateNotifier.isTesting = false;
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Invalid Non-JSON response', 500);
      });

      final notifier = AiSearchNotifier(appState: appState, client: mockClient);
      await notifier.performSearch('toyota');

      expect(notifier.isLoading, isFalse);
      expect(notifier.searchResult, isNull);
      expect(notifier.errorMessage, 'Failed to execute AI search (code: 500)');
      AppStateNotifier.isTesting = true;
    });

    test('HTTP performSearch throws exception', () async {
      AppStateNotifier.isTesting = false;
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Network connection error');
      });

      final notifier = AiSearchNotifier(appState: appState, client: mockClient);
      await notifier.performSearch('toyota');

      expect(notifier.isLoading, isFalse);
      expect(notifier.searchResult, isNull);
      expect(notifier.errorMessage, contains('Network connection error'));
      AppStateNotifier.isTesting = true;
    });

    test(
      'Fallback http.post when client is null using HttpOverrides',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final responseJson = jsonEncode({
          'answer': 'Fallback success',
          'citations': <Map<String, dynamic>>[],
        });
        final fakeResponse = FakeHttpClientResponse(
          utf8.encode(responseJson),
          200,
        );
        final fakeRequest = FakeHttpClientRequest(fakeResponse);
        final fakeClient = FakeHttpClient(fakeRequest);

        final fakeUser = FakeUser('uid-123', 'test@example.com');
        final fakeAuth = FakeFirebaseAuth(mockCurrentUser: fakeUser);

        await HttpOverrides.runWithHttpOverrides(() async {
          final notifier = AiSearchNotifier(
            appState: appState,
            client: null,
            auth: fakeAuth,
          );
          await notifier.performSearch('fallback test');

          expect(notifier.searchResult, isNotNull);
          expect(notifier.searchResult!.answer, 'Fallback success');
        }, MyHttpOverrides(fakeClient));

        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'SharedPreferences failures in load, save and clear are caught',
      () async {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance =
            ThrowingSharedPreferencesStore();

        final notifier = AiSearchNotifier(appState: appState);

        // Should not throw exceptions since they are caught internally
        await notifier.loadHistory();
        await notifier.performSearch('query to save');
        await notifier.clearHistory();

        expect(notifier.history, isEmpty);
      },
    );
  });
}
