import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/utils/app_logger.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles system telemetry stats, scraper execution logs,
/// dataset directories, manual sync invocation, and government API ping updates.
class TelemetryNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  final int functionsPort;

  Map<String, Map<String, dynamic>> _datasetMetadataMap = {};
  bool _isLoadingAdminMetadata = true;
  StreamSubscription<QuerySnapshot>? _adminMetadataSubscription;

  Map<String, dynamic> _apiHealth = {};
  List<Map<String, dynamic>> _scraperRuns = [];
  bool _isLoadingTelemetry = true;
  bool _isCheckingApiHealth = false;
  StreamSubscription<DocumentSnapshot>? _apiHealthSubscription;
  StreamSubscription<QuerySnapshot>? _scraperRunsSubscription;

  bool get isCheckingApiHealth => _isCheckingApiHealth;

  List<DatasetMetadataModel> _directoryRecords = [];
  bool _isLoadingDirectory = true;
  Map<String, int> _datasetRequestCounts = {};
  StreamSubscription<QuerySnapshot>? _directorySubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testMetadataStream;
  @visibleForTesting
  Stream<DocumentSnapshot<Map<String, dynamic>>>? testHealthStream;
  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testScraperRunsStream;
  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testDirectoryStream;
  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testRequestsStream;
  @visibleForTesting
  http.Client? httpClient;

  /// Returns admin datasets metadata mapped by ID.
  Map<String, Map<String, dynamic>> get datasetMetadataMap =>
      _datasetMetadataMap;

  /// Checks if admin metadata collection is loading.
  bool get isLoadingAdminMetadata => _isLoadingAdminMetadata;

  /// Returns government API health details.
  Map<String, dynamic> get apiHealth => _apiHealth;

  /// Returns recent scraper run records.
  List<Map<String, dynamic>> get scraperRuns => _scraperRuns;

  /// Checks if telemetry information is loading.
  bool get isLoadingTelemetry => _isLoadingTelemetry;

  /// Returns all dataset directory records.
  List<DatasetMetadataModel> get directoryRecords => _directoryRecords;

  /// Checks if directory records are loading.
  bool get isLoadingDirectory => _isLoadingDirectory;

  /// Returns registration votes count by dataset ID.
  int getRequestCount(String id) => _datasetRequestCounts[id] ?? 0;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  @visibleForTesting
  FirebaseAuth? testAuth;

  /// Checks if Firebase is initialized.
  bool get isFirebaseInitialized {
    if (AppStateNotifier.testIsFirebaseInitialized != null) {
      return AppStateNotifier.testIsFirebaseInitialized!;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Construct and initialize the TelemetryNotifier.
  TelemetryNotifier({
    bool isTesting = false,
    this.functionsPort = 5002,
    this.testMetadataStream,
    this.testHealthStream,
    this.testScraperRunsStream,
    this.testDirectoryStream,
    this.testRequestsStream,
    this.httpClient,
    this.testFirestore,
    this.testAuth,
  });

  /// Initialize real-time streams on dataset metadata.
  void initAdminMetadataListener() {
    _adminMetadataSubscription?.cancel();
    initTelemetryListeners();
    if (testMetadataStream != null) {
      _isLoadingAdminMetadata = true;
      _adminMetadataSubscription = testMetadataStream!.listen(
        (snapshot) {
          final Map<String, Map<String, dynamic>> newMap = {};
          for (final doc in snapshot.docs) {
            newMap[doc.id] = doc.data();
          }
          _datasetMetadataMap = newMap;
          _isLoadingAdminMetadata = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingAdminMetadata = false;
          notifyListeners();
          AppLogger.error('Firestore admin metadata listener error', err);
        },
      );
      return;
    }
    if (_isTesting) {
      _datasetMetadataMap = {
        '8935c8e5-ec77-421f-af86-d970583195f8': {
          'id': '8935c8e5-ec77-421f-af86-d970583195f8',
          'recordCount': 9840,
          'lastUpdated': '2026-05-30T12:00:00Z',
          'status': 'idle',
        },
        'ff398c7e-c522-4ee8-a53a-312b188a573d': {
          'id': 'ff398c7e-c522-4ee8-a53a-312b188a573d',
          'recordCount': 120,
          'lastUpdated': '2026-05-29T14:30:00Z',
          'status': 'idle',
        },
        'd8715392-287f-49b7-9ae3-f21ec5bf55f3': {
          'id': 'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
          'recordCount': 3,
          'lastUpdated': '2026-06-01T09:15:00Z',
          'status': 'idle',
        },
        '9c64c522-bbc2-48fe-96fb-3b2a8626f59e': {
          'id': '9c64c522-bbc2-48fe-96fb-3b2a8626f59e',
          'recordCount': 100,
          'lastUpdated': '2026-06-02T17:00:00Z',
          'status': 'idle',
        },
        '21fde05f-62e3-401b-81cf-5c385862026d': {
          'id': '21fde05f-62e3-401b-81cf-5c385862026d',
          'recordCount': 3019,
          'lastUpdated': '2026-06-02T09:00:00Z',
          'status': 'idle',
        },
        DatasetIds.patentClassifications: {
          'id': DatasetIds.patentClassifications,
          'recordCount': 10,
          'lastUpdated': '2026-06-03T10:00:00Z',
          'status': 'idle',
        },
        DatasetIds.carImporters: {
          'id': DatasetIds.carImporters,
          'recordCount': 99489,
          'lastUpdated': '2026-06-05T12:00:00Z',
          'status': 'idle',
        },
        'datasets_metadata': {
          'id': 'datasets_metadata',
          'recordCount': 1245,
          'lastUpdated': '2026-06-03T10:00:00Z',
          'status': 'idle',
          'scheduler': {
            'enabled': true,
            'updateIntervalHours': 168,
            'nextRun': '2026-06-10T10:00:00Z',
          },
        },
      };
      _isLoadingAdminMetadata = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingAdminMetadata = false;
      notifyListeners();
      return;
    }

    try {
      _adminMetadataSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('dataset_metadata')
          .snapshots()
          .listen(
            (snapshot) {
              final Map<String, Map<String, dynamic>> newMap = {};
              for (final doc in snapshot.docs) {
                newMap[doc.id] = doc.data();
              }
              _datasetMetadataMap = newMap;
              _isLoadingAdminMetadata = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingAdminMetadata = false;
              notifyListeners();
              AppLogger.error('Firestore admin metadata listener error', err);
            },
          );
    } catch (e) {
      _isLoadingAdminMetadata = false;
      notifyListeners();
      AppLogger.error('Failed to initialize admin metadata listener', e);
    }
  }

  /// Initialize real-time listeners for system health and scraper runs collections.
  void initTelemetryListeners() {
    _apiHealthSubscription?.cancel();
    _scraperRunsSubscription?.cancel();

    if (testHealthStream != null || testScraperRunsStream != null) {
      _isLoadingTelemetry = true;
      if (testHealthStream != null) {
        _apiHealthSubscription = testHealthStream!.listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              _apiHealth = snapshot.data()!;
            } else {
              _apiHealth = {};
            }
            _isLoadingTelemetry = false;
            notifyListeners();
          },
          onError: (Object err) {
            _isLoadingTelemetry = false;
            notifyListeners();
            AppLogger.error('Firestore system_health listener error', err);
          },
        );
      }
      if (testScraperRunsStream != null) {
        _scraperRunsSubscription = testScraperRunsStream!.listen(
          (snapshot) {
            _scraperRuns = snapshot.docs.map((doc) => doc.data()).toList();
            notifyListeners();
          },
          onError: (Object err) {
            AppLogger.error('Firestore scraper_runs listener error', err);
          },
        );
      }
      return;
    }
    if (_isTesting) {
      _apiHealth = {
        'url': 'https://data.gov.il',
        'isReachable': true,
        'statusCode': 200,
        'latencyMs': 142,
        'lastChecked': DateTime.now()
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
      };
      _scraperRuns = [
        {
          'datasetId': '8935c8e5-ec77-421f-af86-d970583195f8',
          'startTime': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'endTime': DateTime.now()
              .subtract(const Duration(hours: 1, seconds: 5))
              .toIso8601String(),
          'durationMs': 4800,
          'status': 'success',
          'recordsProcessed': 9840,
          'firestoreReadsEstimate': 9841,
          'firestoreWritesEstimate': 9841,
          'errorMessage': '',
          'errorStack': '',
        },
        {
          'datasetId': 'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
          'startTime': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'endTime': DateTime.now()
              .subtract(const Duration(hours: 2, seconds: 1))
              .toIso8601String(),
          'durationMs': 1200,
          'status': 'success',
          'recordsProcessed': 3,
          'firestoreReadsEstimate': 4,
          'firestoreWritesEstimate': 4,
          'errorMessage': '',
          'errorStack': '',
        },
        {
          'datasetId': '9c64c522-bbc2-48fe-96fb-3b2a8626f59e',
          'startTime': DateTime.now()
              .subtract(const Duration(hours: 1, minutes: 30))
              .toIso8601String(),
          'endTime': DateTime.now()
              .subtract(const Duration(hours: 1, minutes: 29))
              .toIso8601String(),
          'durationMs': 3200,
          'status': 'success',
          'recordsProcessed': 100,
          'firestoreReadsEstimate': 0,
          'firestoreWritesEstimate': 100,
          'errorMessage': '',
          'errorStack': '',
        },
      ];
      _isLoadingTelemetry = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingTelemetry = false;
      notifyListeners();
      return;
    }

    try {
      _apiHealthSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('system_health')
          .doc('data_gov_il')
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                _apiHealth = snapshot.data()!;
              } else {
                _apiHealth = {};
              }
              _isLoadingTelemetry = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingTelemetry = false;
              notifyListeners();
              AppLogger.error('Firestore system_health listener error', err);
            },
          );

      _scraperRunsSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('scraper_runs')
          .orderBy('startTime', descending: true)
          .limit(20)
          .snapshots()
          .listen(
            (snapshot) {
              _scraperRuns = snapshot.docs.map((doc) => doc.data()).toList();
              notifyListeners();
            },
            onError: (Object err) {
              AppLogger.error('Firestore scraper_runs listener error', err);
            },
          );
    } catch (e) {
      _isLoadingTelemetry = false;
      notifyListeners();
      AppLogger.error('Failed to initialize telemetry listeners', e);
    }
  }

  /// Initialize real-time streams on dataset metadata directory.
  void initDirectoryListener() {
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();

    if (testDirectoryStream != null || testRequestsStream != null) {
      _isLoadingDirectory = true;
      if (testDirectoryStream != null) {
        _directorySubscription = testDirectoryStream!.listen(
          (snapshot) {
            _directoryRecords = snapshot.docs
                .map((doc) => DatasetMetadataModel.fromMap(doc.data()))
                .toList();
            _isLoadingDirectory = false;
            notifyListeners();
          },
          onError: (Object err) {
            _isLoadingDirectory = false;
            notifyListeners();
            AppLogger.error('Firestore directory metadata error', err);
          },
        );
      }
      if (testRequestsStream != null) {
        _requestsSubscription = testRequestsStream!.listen(
          (snapshot) {
            final Map<String, int> counts = {};
            for (final doc in snapshot.docs) {
              counts[doc.id] = (doc.data()['requestCount'] as num? ?? 0)
                  .toInt();
            }
            _datasetRequestCounts = counts;
            notifyListeners();
          },
          onError: (Object err) {
            AppLogger.error('Firestore dataset requests count error', err);
          },
        );
      }
      return;
    }
    if (_isTesting) {
      _directoryRecords = [
        DatasetMetadataModel(
          id: '8935c8e5-ec77-421f-af86-d970583195f8',
          datasetId: '995eb826-c471-4572-8fd3-39d92a3a9603',
          name: 'active_antennas',
          title: 'אנטנות סלולריות פעילות',
          notes: 'רשימת מוקדי שידור סלולריים פעילים ובדיקות קרינה שנערכו להם.',
          publisher: 'המשרד להגנת הסביבה',
          resourceCount: 3,
          lastUpdated: DateTime(2026, 5, 30),
          tags: ['אנטנות', 'סלולר', 'קרינה'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: 'ff398c7e-c522-4ee8-a53a-312b188a573d',
          datasetId: '4e9111d8-e842-40ec-b587-629e684e85ac',
          name: 'cellular_permit_applications',
          title: 'בקשות להיתרי הקמה של אנטנות',
          notes:
              'היתרי הקמה והפעלה למוקדי שידור סלולריים הנמצאים בהליכי אישור.',
          publisher: 'המשרד להגנת הסביבה',
          resourceCount: 1,
          lastUpdated: DateTime(2026, 5, 29),
          tags: ['היתרים', 'הקמה', 'סלולר'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: 'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
          datasetId: '6d8bf87d-bd13-4df6-9846-d449f407b318',
          name: 'pr2018',
          title: 'חברות בפירוק',
          notes:
              'רשימת חברות הנמצאות בהליכי פירוק ופירוק שיתוף בבתי המשפט המחוזיים.',
          publisher: 'רשות התאגידים',
          resourceCount: 3,
          lastUpdated: DateTime(2026, 6, 1),
          tags: ['פירוק', 'חברות', 'רשות התאגידים', 'משפט'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: '9c64c522-bbc2-48fe-96fb-3b2a8626f59e',
          datasetId: '9c64c522-bbc2-48fe-96fb-3b2a8626f59e',
          name: 'doctors_licenses',
          title: 'רישיונות רופאים',
          notes: 'מאגר מורשי תעסוקה ברפואה בישראל כולל מספרי רישיון והתמחויות.',
          publisher: 'משרד הבריאות',
          resourceCount: 1,
          lastUpdated: DateTime(2026, 6, 2),
          tags: ['רופאים', 'רישיון', 'בריאות', 'התמחות'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: '21fde05f-62e3-401b-81cf-5c385862026d',
          datasetId: '67759a6a-4167-439b-af53-0eb792321264',
          name: 'automated-devices',
          title: 'מכשירים אוטומטיים – ATMs',
          notes: 'מיקומי כספומטים בנקאיים ברחבי ישראל.',
          publisher: 'בנק ישראל',
          resourceCount: 1,
          lastUpdated: DateTime(2026, 6, 2),
          tags: ['כספומטים', 'בנקים', 'ATM'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: DatasetIds.patentClassifications,
          datasetId: DatasetIds.patentClassifications,
          name: 'patent_classifications',
          title: 'סיווגי CPC לפטנטים',
          notes:
              'מאגר סיווגי CPC (סיווג פטנטים משותף) לבקשות פטנט של רשם הפטנטים.',
          publisher: 'רשות הפטנטים',
          resourceCount: 1,
          lastUpdated: DateTime(2026, 6, 3),
          tags: const ['פטנטים', 'סיווג', 'חדשנות', 'CPC'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: DatasetIds.carImporters,
          datasetId: DatasetIds.carImporters,
          name: 'car_importers',
          title: 'מחירוני רכב חדש',
          notes: 'מחירוני רכב חדש ויבואנים רשמיים של משרד התחבורה בישראל.',
          publisher: 'משרד התחבורה',
          resourceCount: 1,
          lastUpdated: DateTime(2026, 6, 5),
          tags: const ['רכב', 'מחירון', 'יבואנים', 'משרד התחבורה'],
          isSupported: true,
        ),
      ];
      _datasetRequestCounts = {'government-budget-dataset-id': 18};
      _isLoadingDirectory = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingDirectory = false;
      notifyListeners();
      return;
    }

    try {
      _directorySubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('datasets_metadata')
          .snapshots()
          .listen(
            (snapshot) {
              _directoryRecords = snapshot.docs
                  .map((doc) => DatasetMetadataModel.fromMap(doc.data()))
                  .toList();
              _isLoadingDirectory = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingDirectory = false;
              notifyListeners();
              AppLogger.error('Firestore directory metadata error', err);
            },
          );

      _requestsSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('dataset_requests')
          .snapshots()
          .listen(
            (snapshot) {
              final Map<String, int> counts = {};
              for (final doc in snapshot.docs) {
                counts[doc.id] = (doc.data()['requestCount'] as num? ?? 0)
                    .toInt();
              }
              _datasetRequestCounts = counts;
              notifyListeners();
            },
            onError: (Object err) {
              AppLogger.error('Firestore dataset requests count error', err);
            },
          );
    } catch (e) {
      _isLoadingDirectory = false;
      notifyListeners();
      AppLogger.error('Failed to initialize directory listener', e);
    }
  }

  Future<void> triggerApiHealthCheck() async {
    _isCheckingApiHealth = true;
    notifyListeners();

    if (_isTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _apiHealth = {
        'url': 'https://data.gov.il',
        'isReachable': true,
        'statusCode': 200,
        'latencyMs': 89,
        'lastChecked': DateTime.now().toIso8601String(),
      };
      _isCheckingApiHealth = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized && httpClient == null) {
      _isCheckingApiHealth = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('$functionsBaseUrl/manualApiHealthCheck');
      if (httpClient != null) {
        await httpClient!.get(url);
      } else {
        await http.get(url).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      AppLogger.error('Failed to trigger API health check', e);
    } finally {
      _isCheckingApiHealth = false;
      notifyListeners();
    }
  }

  /// Request registration activation vote for un-supported directories.
  Future<bool> requestDatasetActivation(
    String datasetId,
    String datasetTitle,
  ) async {
    if (_isTesting) {
      _datasetRequestCounts[datasetId] =
          (_datasetRequestCounts[datasetId] ?? 0) + 1;
      notifyListeners();
      return true;
    }

    if (!isFirebaseInitialized) return false;

    try {
      final user = (testAuth ?? FirebaseAuth.instance).currentUser;
      String? uid = user?.uid;
      if (uid == null) {
        final authResult = await (testAuth ?? FirebaseAuth.instance)
            .signInAnonymously();
        uid = authResult.user?.uid;
      }

      if (uid == null) return false;

      final voteRef = (testFirestore ?? FirebaseFirestore.instance)
          .collection('dataset_requests')
          .doc(datasetId)
          .collection('votes')
          .doc(uid);

      final voteSnap = await voteRef.get();
      if (voteSnap.exists) return false;

      await (testFirestore ?? FirebaseFirestore.instance).runTransaction((
        transaction,
      ) async {
        final requestRef = (testFirestore ?? FirebaseFirestore.instance)
            .collection('dataset_requests')
            .doc(datasetId);

        final requestSnap = await transaction.get(requestRef);

        transaction.set(voteRef, {'votedAt': FieldValue.serverTimestamp()});

        if (requestSnap.exists) {
          final currentCount =
              (requestSnap.data()?['requestCount'] as num? ?? 0).toInt();
          transaction.update(requestRef, {
            'requestCount': currentCount + 1,
            'lastRequestedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(requestRef, {
            'datasetId': datasetId,
            'datasetTitle': datasetTitle,
            'requestCount': 1,
            'lastRequestedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      return true;
    } catch (e) {
      AppLogger.error('Error casting vote for dataset: $datasetId', e);
      return false;
    }
  }

  /// Triggers a manual scraper execution sync via HTTP Cloud Function call.
  Future<Map<String, dynamic>> triggerManualSync(String datasetId) async {
    final Map<String, dynamic> localMeta = _datasetMetadataMap[datasetId] ?? {};
    _datasetMetadataMap[datasetId] = {...localMeta, 'status': 'syncing'};
    notifyListeners();

    if (_isTesting) {
      await Future<void>.delayed(const Duration(seconds: 1));
      _datasetMetadataMap[datasetId] = {
        ...localMeta,
        'status': 'idle',
        'recordCount': 10000,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
      };
      notifyListeners();
      return {
        'success': true,
        'message': 'Sync completed successfully',
        'count': 10000,
      };
    }

    try {
      String? token;
      if (isFirebaseInitialized) {
        try {
          final user = (testAuth ?? FirebaseAuth.instance).currentUser;
          if (user != null) {
            token = await user.getIdToken();
          }
        } catch (_) {}
      }

      String functionName;
      if (datasetId == '8935c8e5-ec77-421f-af86-d970583195f8') {
        functionName = 'manualSyncAntennas';
      } else if (datasetId == 'ff398c7e-c522-4ee8-a53a-312b188a573d') {
        functionName = 'manualSyncPermitApps';
      } else if (datasetId == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3') {
        functionName = 'manualSyncCompaniesLiquidation';
      } else if (datasetId == '9c64c522-bbc2-48fe-96fb-3b2a8626f59e') {
        functionName = 'manualSyncDoctorsLicenses';
      } else if (datasetId == '21fde05f-62e3-401b-81cf-5c385862026d') {
        functionName = 'manualSyncBankAtms';
      } else if (datasetId == 'datasets_metadata') {
        functionName = 'manualSyncMetadata';
      } else if (datasetId == DatasetIds.patentClassifications) {
        functionName = 'manualSyncPatentClassifications';
      } else if (datasetId == DatasetIds.carImporters) {
        functionName = 'manualSyncCarImporters';
      } else {
        throw Exception('Unknown dataset ID: $datasetId');
      }

      final url = Uri.parse('$functionsBaseUrl/$functionName');
      final response = httpClient != null
          ? await httpClient!.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            )
          : await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'] ?? 'Sync completed successfully',
          'count': data['count'] ?? 0,
        };
      } else {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String errorMessage =
            (data['error'] ?? data['message'] ?? 'Failed to trigger sync')
                .toString();
        _datasetMetadataMap[datasetId] = {...localMeta, 'status': 'error'};
        notifyListeners();
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      AppLogger.error('Error triggering manual sync', e);
      _datasetMetadataMap[datasetId] = {...localMeta, 'status': 'error'};
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update the scraper scheduler configuration for a dataset.
  Future<void> updateDatasetScheduler(
    String datasetId, {
    required bool enabled,
    required int updateIntervalHours,
  }) async {
    AppLogger.info(
      'Updating scheduler for dataset: $datasetId (enabled: $enabled, interval: $updateIntervalHours)',
    );

    if (_isTesting) {
      final Map<String, dynamic> localMeta =
          _datasetMetadataMap[datasetId] ?? {};
      final scheduler = Map<String, dynamic>.from(
        localMeta['scheduler'] as Map? ?? {},
      );
      scheduler['enabled'] = enabled;
      scheduler['updateIntervalHours'] = updateIntervalHours;

      // Compute a fake nextRun locally for testing
      final nextRunDate = DateTime.now().add(
        Duration(hours: updateIntervalHours),
      );
      scheduler['nextRun'] = nextRunDate.toUtc().toIso8601String();

      _datasetMetadataMap[datasetId] = {...localMeta, 'scheduler': scheduler};
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) return;

    try {
      final metadataRef = (testFirestore ?? FirebaseFirestore.instance)
          .collection('dataset_metadata')
          .doc(datasetId);

      // Read current nextRun, or calculate a new one if it's currently missing or the interval changes
      final doc = await metadataRef.get();
      String nextRun = '';
      if (doc.exists) {
        final data = doc.data();
        final existingScheduler = data?['scheduler'] as Map<String, dynamic>?;
        nextRun = existingScheduler?['nextRun'] as String? ?? '';
      }

      // If nextRun is empty or scheduler was disabled and now enabled, calculate nextRun starting from now
      if (nextRun.isEmpty || enabled) {
        nextRun = DateTime.now()
            .add(Duration(hours: updateIntervalHours))
            .toUtc()
            .toIso8601String();
      }

      await metadataRef.set({
        'scheduler': {
          'enabled': enabled,
          'updateIntervalHours': updateIntervalHours,
          'nextRun': nextRun,
        },
      }, SetOptions(merge: true));

      AppLogger.info('Successfully updated Firestore scheduler for $datasetId');
    } catch (e) {
      AppLogger.error('Failed to update dataset scheduler', e);
      rethrow;
    }
  }

  /// Resolves the functions HTTP base URL (emulator or cloud).
  String get functionsBaseUrl {
    final bool useEmulator = AppStateNotifier.useEmulator;
    const String region = 'us-central1';

    if (useEmulator) {
      const String projectId = 'demo-plainsightil';
      final bool isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final String host = isAndroid ? '10.0.2.2' : '127.0.0.1';
      return 'http://$host:$functionsPort/$projectId/$region';
    } else {
      const String projectId = 'plainsightil';
      return 'https://$region-$projectId.cloudfunctions.net';
    }
  }

  /// Cancels active telemetry and admin metadata subscriptions.
  void cancelAdminMetadataListener() {
    _adminMetadataSubscription?.cancel();
    _adminMetadataSubscription = null;
    _apiHealthSubscription?.cancel();
    _apiHealthSubscription = null;
    _scraperRunsSubscription?.cancel();
    _scraperRunsSubscription = null;
    _isLoadingAdminMetadata = true;
    _isLoadingTelemetry = true;
    _datasetMetadataMap = {};
    _apiHealth = {};
    _scraperRuns = [];
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      scheduleMicrotask(() {
        if (!_isDisposed) {
          super.notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _adminMetadataSubscription?.cancel();
    _apiHealthSubscription?.cancel();
    _scraperRunsSubscription?.cancel();
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
