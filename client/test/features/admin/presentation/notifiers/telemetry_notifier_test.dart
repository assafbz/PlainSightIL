import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) sendHandler;
  MockHttpClient(this.sendHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await sendHandler(request);
    final stream = Stream.value(response.bodyBytes);
    return http.StreamedResponse(
      stream,
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('TelemetryNotifier Unit Tests', () {
    test('Initialization status in testing mode', () {
      final notifier = TelemetryNotifier(isTesting: true);
      expect(notifier.isLoadingAdminMetadata, isTrue);
      expect(notifier.isLoadingTelemetry, isTrue);
      expect(notifier.isLoadingDirectory, isTrue);
    });

    test(
      'initAdminMetadataListener loads static values in testing mode',
      () async {
        final notifier = TelemetryNotifier(isTesting: true);
        notifier.initAdminMetadataListener();
        await Future<void>.delayed(Duration.zero);

        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.datasetMetadataMap, isNotEmpty);
        expect(
          notifier.datasetMetadataMap.containsKey(
            '21fde05f-62e3-401b-81cf-5c385862026d',
          ),
          isTrue,
        );
      },
    );

    test(
      'initTelemetryListeners loads static values in testing mode',
      () async {
        final notifier = TelemetryNotifier(isTesting: true);
        notifier.initTelemetryListeners();
        await Future<void>.delayed(Duration.zero);

        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.apiHealth['url'], equals('https://data.gov.il'));
        expect(notifier.scraperRuns, isNotEmpty);
      },
    );

    test('initDirectoryListener loads static values in testing mode', () async {
      final notifier = TelemetryNotifier(isTesting: true);
      notifier.initDirectoryListener();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.isLoadingDirectory, isFalse);
      expect(notifier.directoryRecords, isNotEmpty);
      expect(
        notifier.getRequestCount('government-budget-dataset-id'),
        equals(18),
      );
    });

    test('requestDatasetActivation casts vote in testing mode', () async {
      final notifier = TelemetryNotifier(isTesting: true);
      notifier.initDirectoryListener();
      await Future<void>.delayed(Duration.zero);

      final success = await notifier.requestDatasetActivation(
        'government-budget-dataset-id',
        'Budget',
      );
      expect(success, isTrue);
      expect(
        notifier.getRequestCount('government-budget-dataset-id'),
        equals(19),
      );
    });

    test(
      'triggerManualSync sends POST and returns parsed data in mock httpClient mode',
      () async {
        AppStateNotifier.isTesting = false;
        final mockClient = MockHttpClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, endsWith('/manualSyncBankAtms'));
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Manual sync successful',
              'count': 3019,
            }),
            200,
          );
        });

        final notifier = TelemetryNotifier(
          isTesting: false,
          httpClient: mockClient,
        );

        final result = await notifier.triggerManualSync(
          '21fde05f-62e3-401b-81cf-5c385862026d',
        );
        expect(result['success'], isTrue);
        expect(result['count'], equals(3019));
        expect(result['message'], equals('Manual sync successful'));
      },
    );

    test('triggerManualSync handles non-200 HTTP responses', () async {
      AppStateNotifier.isTesting = false;
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Failed to sync ATMs dataset',
          }),
          500,
        );
      });

      final notifier = TelemetryNotifier(
        isTesting: false,
        httpClient: mockClient,
      );

      final result = await notifier.triggerManualSync(
        '21fde05f-62e3-401b-81cf-5c385862026d',
      );
      expect(result['success'], isFalse);
      expect(result['message'], equals('Failed to sync ATMs dataset'));
    });

    test(
      'triggerApiHealthCheck sends GET request via mock httpClient',
      () async {
        AppStateNotifier.isTesting = false;
        var getCalled = false;
        final mockClient = MockHttpClient((request) async {
          expect(request.method, equals('GET'));
          expect(request.url.path, endsWith('/manualApiHealthCheck'));
          getCalled = true;
          return http.Response('', 200);
        });

        final notifier = TelemetryNotifier(
          isTesting: false,
          httpClient: mockClient,
        );

        await notifier.triggerApiHealthCheck();
        expect(getCalled, isTrue);
      },
    );
    group('functionsBaseUrl evaluation', () {
      test('resolves standard http local target', () {
        final notifier = TelemetryNotifier(functionsPort: 9099);
        expect(notifier.functionsBaseUrl, contains(':9099/'));
      });
    });
  });
}
