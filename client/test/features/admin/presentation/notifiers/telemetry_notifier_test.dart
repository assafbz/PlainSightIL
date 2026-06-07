import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../notifiers_mocks.dart';

class MockHttpClientLocal extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) sendHandler;
  MockHttpClientLocal(this.sendHandler);

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TelemetryNotifier Unit Tests', () {
    setUp(() {
      AppStateNotifier.isTesting = true;
    });

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
          notifier.datasetMetadataMap.containsKey(DatasetIds.bankAtms),
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
        final mockClient = MockHttpClientLocal((request) async {
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

        final result = await notifier.triggerManualSync(DatasetIds.bankAtms);
        expect(result['success'], isTrue);
        expect(result['count'], equals(3019));
        expect(result['message'], equals('Manual sync successful'));
      },
    );

    test('triggerManualSync handles non-200 HTTP responses', () async {
      AppStateNotifier.isTesting = false;
      final mockClient = MockHttpClientLocal((request) async {
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

      final result = await notifier.triggerManualSync(DatasetIds.bankAtms);
      expect(result['success'], isFalse);
      expect(result['message'], equals('Failed to sync ATMs dataset'));
    });

    test(
      'triggerApiHealthCheck sends GET request via mock httpClient',
      () async {
        AppStateNotifier.isTesting = false;
        var getCalled = false;
        final mockClient = MockHttpClientLocal((request) async {
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

  group('TelemetryNotifier Integrated Tests', () {
    test(
      'initTelemetryListeners and initDirectoryListener update stats',
      () async {
        final metaController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final healthController =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final runsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final directoryController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final requestsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = TelemetryNotifier(
          isTesting: false,
          testMetadataStream: metaController.stream,
          testHealthStream: healthController.stream,
          testScraperRunsStream: runsController.stream,
          testDirectoryStream: directoryController.stream,
          testRequestsStream: requestsController.stream,
        );

        notifier.initAdminMetadataListener(isAdmin: true);
        notifier.initDirectoryListener();

        expect(notifier.isLoadingAdminMetadata, isTrue);
        expect(notifier.isLoadingTelemetry, isTrue);
        expect(notifier.isLoadingDirectory, isTrue);

        // 1. Metadata snapshot
        final fakeMetaDoc = FakeQueryDocumentSnapshot('antennas-id', {
          'recordCount': 100,
        });
        metaController.add(FakeQuerySnapshot([fakeMetaDoc]));

        // 2. Health snapshot
        final fakeHealthDoc = FakeDocumentSnapshot('data_gov_il', true, {
          'isReachable': true,
        });
        healthController.add(fakeHealthDoc);

        // 3. Scraper runs snapshot
        final fakeRunDoc = FakeQueryDocumentSnapshot('run-1', {
          'datasetId': 'antennas-id',
          'status': 'success',
        });
        runsController.add(FakeQuerySnapshot([fakeRunDoc]));

        // 4. Directory records snapshot
        final fakeDirDoc = FakeQueryDocumentSnapshot('1', {
          'id': 'antennas-id',
          'datasetId': 'antennas-id',
          'name': 'antennas',
          'title': 'Antennas',
          'notes': 'notes',
          'publisher': 'agency',
          'resourceCount': 1,
          'lastUpdated': '2026-06-01T12:00:00.000Z',
          'tags': ['radiation'],
          'isSupported': true,
        });
        directoryController.add(FakeQuerySnapshot([fakeDirDoc]));

        // 5. Requests snapshot
        final fakeReqDoc = FakeQueryDocumentSnapshot('antennas-id', {
          'requestCount': 12,
        });
        requestsController.add(FakeQuerySnapshot([fakeReqDoc]));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);

        expect(notifier.datasetMetadataMap['antennas-id']?['recordCount'], 100);
        expect(notifier.apiHealth['isReachable'], isTrue);
        expect(notifier.scraperRuns.length, 1);
        expect(notifier.directoryRecords.first.title, 'Antennas');
        expect(notifier.getRequestCount('antennas-id'), 12);

        // Stream Errors
        metaController.addError('Error');
        healthController.addError('Error');
        runsController.addError('Error');
        directoryController.addError('Error');
        requestsController.addError('Error');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Stream Empty docs
        healthController.add(FakeDocumentSnapshot('data_gov_il', false, null));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Clean up
        await metaController.close();
        await healthController.close();
        await runsController.close();
        await directoryController.close();
        await requestsController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initTelemetryListeners and initDirectoryListener fallback when streams are null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = TelemetryNotifier(isTesting: false);
        notifier.initAdminMetadataListener(isAdmin: true);
        notifier.initDirectoryListener();
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test('HTTP calls triggerApiHealthCheck and triggerManualSync', () async {
      var pingCalled = false;
      var syncCalled = false;
      var metadataSyncCalled = false;

      final httpClient = FakeHttpClient(
        onGet: (url, {headers}) {
          if (url.path.contains('manualApiHealthCheck')) {
            pingCalled = true;
            return http.Response('{"status":"reachable"}', 200);
          }
          return http.Response('{}', 404);
        },
        onPost: (url, {body, headers}) {
          if (url.path.contains('manualSyncAntennas')) {
            syncCalled = true;
            return http.Response(
              '{"message":"Synced successfully", "count": 150}',
              200,
            );
          } else if (url.path.contains('manualSyncMetadata')) {
            metadataSyncCalled = true;
            return http.Response(
              '{"message":"Metadata synced successfully", "count": 1245}',
              200,
            );
          }
          return http.Response('{"error":"Not Found"}', 404);
        },
      );

      AppStateNotifier.isTesting = false;

      final notifier = TelemetryNotifier(
        isTesting: false,
        httpClient: httpClient,
      );

      expect(notifier.isCheckingApiHealth, isFalse);
      final checkFuture = notifier.triggerApiHealthCheck();
      expect(notifier.isCheckingApiHealth, isTrue);
      await checkFuture;
      expect(notifier.isCheckingApiHealth, isFalse);
      expect(pingCalled, isTrue);

      // Test triggerApiHealthCheck when isFirebaseInitialized is false and httpClient is null
      AppStateNotifier.testIsFirebaseInitialized = false;
      final notifierNoFirebase = TelemetryNotifier(isTesting: false);
      expect(notifierNoFirebase.isCheckingApiHealth, isFalse);
      await notifierNoFirebase.triggerApiHealthCheck();
      expect(notifierNoFirebase.isCheckingApiHealth, isFalse);
      notifierNoFirebase.dispose();
      AppStateNotifier.testIsFirebaseInitialized = null; // Reset

      final syncResult = await notifier.triggerManualSync(
        '8935c8e5-ec77-421f-af86-d970583195f8',
      );
      expect(syncCalled, isTrue);
      expect(syncResult['success'], isTrue);
      expect(syncResult['count'], 150);

      // Test manual sync for datasets_metadata
      final metadataSyncResult = await notifier.triggerManualSync(
        'datasets_metadata',
      );
      expect(metadataSyncCalled, isTrue);
      expect(metadataSyncResult['success'], isTrue);
      expect(metadataSyncResult['count'], 1245);

      // Test manual sync with unknown/failure cases
      final failSyncResult = await notifier.triggerManualSync(
        'unknown-dataset',
      );
      expect(failSyncResult['success'], isFalse);

      // Test manual sync with HTTP failure
      final notifierFailHttp = TelemetryNotifier(
        isTesting: false,
        httpClient: FakeHttpClient(
          onPost: (url, {body, headers}) =>
              http.Response('{"error":"Server error"}', 500),
        ),
      );
      final errorSyncResult = await notifierFailHttp.triggerManualSync(
        '8935c8e5-ec77-421f-af86-d970583195f8',
      );
      expect(errorSyncResult['success'], isFalse);

      notifier.dispose();
      notifierFailHttp.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'TelemetryNotifier handles real Firestore streams and error paths',
      () async {
        final telemetryMetadataController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final telemetryHealthController =
            StreamController<
              DocumentSnapshot<Map<String, dynamic>>
            >.broadcast();
        final telemetryScraperRunsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final telemetryDirectoryController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        final telemetryRequestsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == 'dataset_metadata') {
            return FakeCollectionReference(
              stream: telemetryMetadataController.stream,
            );
          } else if (path == 'system_health') {
            return FakeCollectionReference(
              docBuilder: (docId) {
                if (docId == 'data_gov_il') {
                  return FakeDocumentReference(
                    snapshotStream: telemetryHealthController.stream,
                  );
                }
                return FakeDocumentReference();
              },
            );
          } else if (path == 'scraper_runs') {
            return FakeCollectionReference(
              stream: telemetryScraperRunsController.stream,
            );
          } else if (path == 'datasets_metadata') {
            return FakeCollectionReference(
              stream: telemetryDirectoryController.stream,
            );
          } else if (path == 'dataset_requests') {
            return FakeCollectionReference(
              stream: telemetryRequestsController.stream,
            );
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        final notifier = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initAdminMetadataListener(isAdmin: true);
        notifier.initDirectoryListener();

        telemetryMetadataController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('meta1', {'activeCollection': 'coll1'}),
          ]),
        );
        telemetryHealthController.add(
          FakeDocumentSnapshot('data_gov_il', true, {'status': 'up'}),
        );
        telemetryScraperRunsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('run1', {
              'startTime': '2026-06-02T18:00:00Z',
            }),
          ]),
        );
        telemetryDirectoryController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('dir1', {
              'datasetId': 'government-budget-dataset-id',
              'datasetTitle': 'Budget',
              'resourceCount': 5,
            }),
          ]),
        );
        telemetryRequestsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('government-budget-dataset-id', {
              'requestCount': 25,
            }),
          ]),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);
        expect(
          notifier.datasetMetadataMap['meta1']?['activeCollection'],
          'coll1',
        );
        expect(notifier.apiHealth['status'], 'up');
        expect(notifier.scraperRuns.first['startTime'], '2026-06-02T18:00:00Z');
        expect(
          notifier.directoryRecords.first.datasetId,
          'government-budget-dataset-id',
        );
        expect(notifier.getRequestCount('government-budget-dataset-id'), 25);

        telemetryMetadataController.addError('Error');
        telemetryHealthController.addError('Error');
        telemetryScraperRunsController.addError('Error');
        telemetryDirectoryController.addError('Error');
        telemetryRequestsController.addError('Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        notifier.dispose();
        await telemetryMetadataController.close();
        await telemetryHealthController.close();
        await telemetryScraperRunsController.close();
        await telemetryDirectoryController.close();
        await telemetryRequestsController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'TelemetryNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = TelemetryNotifier(isTesting: false);
        notifier.initAdminMetadataListener(isAdmin: true);
        notifier.initDirectoryListener();
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);
        notifier.dispose();
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'TelemetryNotifier handles exception in listeners and triggers manual sync / activation',
      () async {
        final telemetryHealthController =
            StreamController<
              DocumentSnapshot<Map<String, dynamic>>
            >.broadcast();

        final mockFirestore = FakeFirebaseFirestore((path) {
          if (path == 'system_health') {
            return FakeCollectionReference(
              docBuilder: (docId) => FakeDocumentReference(
                snapshotStream: telemetryHealthController.stream,
              ),
            );
          }
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = false;

        // 1. TelemetryNotifier handles exceptions in all metadata/health/runs/dir/requests subscriptions
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Telemetry Firestore exception');
        });

        final notifier = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifier.initAdminMetadataListener(isAdmin: true);
        notifier.initDirectoryListener();
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);

        // 2. Health snapshot is empty (exists: false)
        final notifier2 = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier2.initAdminMetadataListener(isAdmin: true);
        telemetryHealthController.add(
          FakeDocumentSnapshot('data_gov_il', false, null),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier2.apiHealth.isEmpty, isTrue);

        // 3. triggerApiHealthCheck triggers catch block and http.get fallback
        await notifier2.triggerApiHealthCheck();

        final notifierFailPing = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
          httpClient: FakeHttpClient(
            onGet: (url, {headers}) => throw Exception('Ping failed'),
          ),
        );
        await notifierFailPing.triggerApiHealthCheck();
        notifierFailPing.dispose();

        // 4. requestDatasetActivation with different paths:
        // A. isFirebaseInitialized is false
        AppStateNotifier.testIsFirebaseInitialized = false;
        final success1 = await notifier2.requestDatasetActivation(
          'some-id',
          'some-title',
        );
        expect(success1, isFalse);

        // B. isFirebaseInitialized is true
        AppStateNotifier.testIsFirebaseInitialized = true;
        final authStreamController = StreamController<User?>.broadcast();
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        final fakeAuth = FakeFirebaseAuth(
          mockCurrentUser: fakeUser,
          authChanges: authStreamController.stream,
        );

        final mockFirestoreTrans = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });

        final notifier3 = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreTrans,
          testAuth: fakeAuth,
        );

        // B1. User is not null, transaction works and doc does not exist
        mockFirestoreTrans.transactionExists = false;
        final success2 = await notifier3.requestDatasetActivation(
          'dataset-1',
          'Title 1',
        );
        expect(success2, isTrue);

        // B2. User is null, signInAnonymously is called, transaction works and doc exists
        final fakeAuthNull = FakeFirebaseAuth(
          mockCurrentUser: null,
          authChanges: authStreamController.stream,
          onSignInAnonymously: () async => FakeUserCredential(),
        );
        final notifier4 = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreTrans,
          testAuth: fakeAuthNull,
        );
        mockFirestoreTrans.transactionExists = true;
        final success3 = await notifier4.requestDatasetActivation(
          'dataset-2',
          'Title 2',
        );
        expect(success3, isTrue);

        // B3. Transaction throws error
        mockFirestoreTrans.throwOnTransaction = true;
        final success4 = await notifier4.requestDatasetActivation(
          'dataset-3',
          'Title 3',
        );
        expect(success4, isFalse);

        // 5. triggerManualSync fetches auth token
        final fakeAuthUser = FakeFirebaseAuth(
          mockCurrentUser: fakeUser,
          authChanges: authStreamController.stream,
        );
        var checkedAuthHeader = false;
        final httpClient = FakeHttpClient(
          onPost: (url, {body, headers}) {
            if (headers != null &&
                headers['Authorization'] == 'Bearer mock-id-token') {
              checkedAuthHeader = true;
            }
            return http.Response(
              '{"message":"Sync started", "count": 22}',
              200,
            );
          },
        );
        final notifier5 = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
          testAuth: fakeAuthUser,
          httpClient: httpClient,
        );

        await notifier5.triggerManualSync(
          '8935c8e5-ec77-421f-af86-d970583195f8',
        );
        expect(checkedAuthHeader, isTrue);

        // 6. triggerManualSync without httpClient to cover the http.post fallback
        final notifierNoClient = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
          testAuth: fakeAuthUser,
        );
        await notifierNoClient.triggerManualSync(
          '8935c8e5-ec77-421f-af86-d970583195f8',
        );

        notifier.dispose();
        notifier2.dispose();
        notifier3.dispose();
        notifier4.dispose();
        notifier5.dispose();
        notifierNoClient.dispose();
        await authStreamController.close();
        await telemetryHealthController.close();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'TelemetryNotifier.updateDatasetScheduler in production mode works successfully',
      () async {
        final mockFirestoreOptions = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });

        final notifier = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreOptions,
        );

        AppStateNotifier.testIsFirebaseInitialized = true;
        AppStateNotifier.isTesting = false;

        // 1. Success case where document exists
        await notifier.updateDatasetScheduler(
          'existing-doc',
          enabled: true,
          updateIntervalHours: 6,
        );

        // 2. Success case where document does not exist
        await notifier.updateDatasetScheduler(
          'some-id',
          enabled: false,
          updateIntervalHours: 12,
        );

        // 3. Exception path
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Update scheduler exception');
        });
        final notifierFail = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );

        expect(
          () => notifierFail.updateDatasetScheduler(
            'some-id',
            enabled: true,
            updateIntervalHours: 6,
          ),
          throwsException,
        );

        notifier.dispose();
        notifierFail.dispose();
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
      },
    );

    test(
      'AppStateNotifier.updateDatasetScheduler handles existing doc and throws exception path',
      () async {
        final mockFirestoreOptions = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });

        AppStateNotifier.isTesting = true;
        final appState = AppStateNotifier();
        appState.telemetryNotifier.testFirestore = mockFirestoreOptions;
        AppStateNotifier.testIsFirebaseInitialized = true;
        AppStateNotifier.isTesting = false;

        // 1. Existing document path
        await appState.updateDatasetScheduler(
          'existing-dataset-id',
          enabled: true,
          updateIntervalHours: 4,
        );

        // 2. Non-existent document path
        await appState.updateDatasetScheduler(
          'non-existent-dataset-id',
          enabled: true,
          updateIntervalHours: 4,
        );

        // 3. Exception throw / catch path
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Firestore update error');
        });
        appState.telemetryNotifier.testFirestore = mockFirestoreThrow;
        expect(
          () => appState.updateDatasetScheduler(
            'any-id',
            enabled: true,
            updateIntervalHours: 4,
          ),
          throwsA(isA<Exception>()),
        );

        // Reset
        AppStateNotifier.isTesting = true;
        AppStateNotifier.testIsFirebaseInitialized = null;
        appState.dispose();
      },
    );
  });
}
