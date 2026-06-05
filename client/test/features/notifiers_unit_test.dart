// ignore_for_file: subtype_of_sealed_class, inference_failure_on_function_return_type, unused_import, depend_on_referenced_packages, prefer_initializing_formals, unnecessary_non_null_assertion, unused_local_variable, unawaited_futures, close_sinks
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/errors/exceptions.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';
import 'package:plainsight/features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';
import 'package:plainsight/features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';
import 'package:plainsight/features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';
import 'package:plainsight/features/datasets/patent_classifications/presentation/notifiers/patent_classifications_notifier.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/presentation/notifiers/vehicle_recalls_notifier.dart';
import 'package:plainsight/features/datasets/bank_atms/data/models/bank_atm_record_model.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/domain/repositories/user_profile_repository.dart';

// Fake implementations for Firestore classes
class FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final bool _exists;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._id, this._exists, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake User implementation
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

// Fake User Profile Repository
class FakeUserProfileRepository implements UserProfileRepository {
  final StreamController<UserProfile?> controller =
      StreamController<UserProfile?>.broadcast();
  UserProfile? mockProfile;
  UserProfile? lastUpdated;
  bool throwOnUpdate = false;

  FakeUserProfileRepository(this.mockProfile);

  @override
  Stream<UserProfile?> getUserProfile(String uid) async* {
    yield mockProfile;
    yield* controller.stream;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    if (throwOnUpdate) {
      throw Exception('Update profile database error');
    }
    lastUpdated = profile;
    mockProfile = profile;
    controller.add(profile);
  }
}

// Fake HTTP Client
class FakeHttpClient implements http.Client {
  final FutureOr<http.Response> Function(Uri, {Map<String, String>? headers})?
  onGet;
  final FutureOr<http.Response> Function(
    Uri, {
    Object? body,
    Map<String, String>? headers,
  })?
  onPost;

  FakeHttpClient({this.onGet, this.onPost});

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    if (onGet != null) {
      return onGet!(url, headers: headers);
    }
    return http.Response('{}', 200);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    dynamic encoding,
  }) async {
    if (onPost != null) {
      return onPost!(url, headers: headers, body: body);
    }
    return http.Response('{}', 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final tDate = DateTime(2026, 6, 1);
  final tProfile = UserProfile(
    uid: 'user_123',
    firstName: 'Assaf',
    lastName: 'Benzaken',
    email: 'assaf@plainsight.il',
    role: 'user',
    createdAt: tDate,
    updatedAt: tDate,
  );

  group('AuthNotifier Tests', () {
    test(
      'Constructor initialization with custom repository and stream',
      () async {
        final mockRepo = FakeUserProfileRepository(tProfile);
        final authStreamController = StreamController<User?>();

        AppStateNotifier.isTesting = false;
        final notifier = AuthNotifier(
          isTesting: false,
          testProfileRepository: mockRepo,
          testAuthChangesStream: authStreamController.stream,
        );

        expect(notifier.isAuthenticated, isFalse);
        expect(notifier.userProfile, isNull);

        // Emit authenticated user
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        authStreamController.add(fakeUser);

        // Allow stream to process
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isAuthenticated, isTrue);
        expect(notifier.currentUser?.uid, 'user_123');
        expect(notifier.userProfile, tProfile);

        // Update User Profile
        final updatedProfile = tProfile.copyWith(firstName: 'Assaf New');
        await notifier.updateUserProfile(updatedProfile);
        expect(mockRepo.lastUpdated, updatedProfile);
        expect(notifier.userProfile?.firstName, 'Assaf New');

        // Guest Mode Toggle
        notifier.setGuestMode(true);
        expect(notifier.isGuestMode, isTrue);

        // Sign In with Google
        await notifier.signInWithGoogle();
        expect(notifier.isGuestMode, isFalse);

        // Sign Out
        AppStateNotifier.isTesting = false;
        await notifier.signOut();
        authStreamController.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.isAuthenticated, isFalse);
        expect(notifier.userProfile, isNull);

        AppStateNotifier.isTesting = true;

        await authStreamController.close();
        notifier.dispose();
      },
    );

    test('Favorites and Recents list toggling and saving', () async {
      final mockRepo = FakeUserProfileRepository(tProfile);
      final notifier = AuthNotifier(
        isTesting: true,
        testProfileRepository: mockRepo,
      );

      // Favorites
      expect(notifier.isFavorite('dataset-1'), isFalse);
      await notifier.toggleFavorite('dataset-1');
      expect(notifier.isFavorite('dataset-1'), isTrue);
      await notifier.toggleFavorite('dataset-1');
      expect(notifier.isFavorite('dataset-1'), isFalse);

      // Recents
      await notifier.addRecent('dataset-2');
      await notifier.addRecent('dataset-3');
      await notifier.addRecent('dataset-4');
      await notifier.addRecent('dataset-5');
      await notifier.addRecent('dataset-6');
      await notifier.addRecent('dataset-7');
      expect(notifier.recents.length, 5);
      expect(notifier.recents.first, 'dataset-7');

      notifier.dispose();
    });

    test(
      'AuthNotifier behaves correctly when isFirebaseInitialized is false',
      () async {
        AppStateNotifier.isTesting = false;
        final mockRepo = FakeUserProfileRepository(tProfile);
        final streamController = StreamController<User?>();
        final notifier = AuthNotifier(
          isTesting: false,
          testProfileRepository: mockRepo,
          testAuthChangesStream: streamController.stream,
        );
        expect(notifier.isAuthenticated, isFalse);

        // trigger auth stream exception path
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');

        streamController.addError('Connection failed');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await notifier.signInWithGoogle();
        expect(notifier.isAuthenticated, isTrue);

        await notifier.signOut();
        expect(notifier.isAuthenticated, isFalse);

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('AntennasNotifier Tests', () {
    test(
      'initAntennaListener updates records from testFirestoreStream',
      () async {
        final streamController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = AntennasNotifier(
          isTesting: false,
          testFirestoreStream: streamController.stream,
        );

        expect(notifier.isLoadingAntennas, isTrue);
        notifier.initAntennaListener();

        // Emit data snapshot
        final mapData = {
          'antennaId': 'CELL-100',
          'addressHebrew': 'Dizengoff 50',
        };
        final fakeDoc = FakeQueryDocumentSnapshot('1', mapData);
        final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

        streamController.add(fakeSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingAntennas, isFalse);
        expect(notifier.antennaRecords.length, 1);
        expect(notifier.antennaRecords.first['antennaId'], 'CELL-100');

        // Emit error
        streamController.addError('Connection Error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          notifier.isLoadingAntennas,
          isFalse,
        ); // Keeps loading state as false

        await streamController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initAntennaListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = AntennasNotifier(isTesting: false);
        notifier.initAntennaListener();
        expect(notifier.isLoadingAntennas, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('PermitsNotifier Tests', () {
    test(
      'initPermitMetadataListener double-buffers collections via streams',
      () async {
        final metadataController =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final permitsController =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();

        AppStateNotifier.isTesting = false;
        final notifier = PermitsNotifier(
          isTesting: false,
          testMetadataStream: metadataController.stream,
          testPermitsStream: permitsController.stream,
        );

        notifier.initPermitMetadataListener();
        expect(notifier.isLoadingPermits, isTrue);

        // Emit metadata snapshot with different collection name
        final metaData = {
          'activeCollection': 'permits_june_2026',
          'status': 'syncing',
        };
        final fakeMetaDoc = FakeDocumentSnapshot(
          'ff398c7e-c522-4ee8-a53a-312b188a573d',
          true,
          metaData,
        );
        metadataController.add(fakeMetaDoc);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.permitSyncStatus, 'syncing');

        // Send duplicate metadata snapshot to hit line 73 else branch
        metadataController.add(fakeMetaDoc);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Emit permits snapshots
        final permitData = {'siteNumber': 'PT1234B'};
        final fakePermitDoc = FakeQueryDocumentSnapshot('1', permitData);
        final fakePermitsSnapshot = FakeQuerySnapshot([fakePermitDoc]);

        permitsController.add(fakePermitsSnapshot);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.isLoadingPermits, isFalse);
        expect(notifier.permitRecords.length, 1);
        expect(notifier.permitRecords.first['siteNumber'], 'PT1234B');

        // Emit permits stream error to hit line 205-209
        permitsController.addError('Permits Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'error');

        // Emit metadata stream error
        metadataController.addError('Connection error');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.permitSyncStatus, 'error');

        // Emit metadata empty document
        final emptyMetaDoc = FakeDocumentSnapshot(
          'ff398c7e-c522-4ee8-a53a-312b188a573d',
          false,
          null,
        );
        metadataController.add(emptyMetaDoc);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await metadataController.close();
        await permitsController.close();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'initPermitMetadataListener fallback when streams are null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = PermitsNotifier(isTesting: false);
        notifier.initPermitMetadataListener();
        expect(notifier.permitSyncStatus, 'error');
        expect(notifier.isLoadingPermits, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('LiquidationNotifier Tests', () {
    test('initLiquidationListener updates liquidation records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = LiquidationNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initLiquidationListener();
      expect(notifier.isLoadingLiquidation, isTrue);

      final record = {
        'liquidationCaseId': 12345,
        'cityOfActivity': 'תל אביב',
        'districtCourt': 'מחוזי תל אביב',
        'companyName': 'אלברט לוי',
        'companyId': 512345678,
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingLiquidation, isFalse);
      expect(notifier.liquidationRecords.length, 1);
      expect(notifier.liquidationRecords.first.liquidationCaseId, 12345);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingLiquidation, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initLiquidationListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = LiquidationNotifier(isTesting: false);
        notifier.initLiquidationListener();
        expect(notifier.isLoadingLiquidation, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('DoctorsNotifier Tests', () {
    test('initDoctorsListener updates doctor records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = DoctorsNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initDoctorsListener();
      expect(notifier.isLoadingDoctors, isTrue);

      final record = {
        'id': '1',
        '_id': 101,
        'firstName': 'מריו',
        'lastName': 'קורוב',
        'licenseNumber': 4267,
        'licenseRegistrationDate': '1969-07-28T00:00:00.000Z',
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingDoctors, isFalse);
      expect(notifier.doctorRecords.length, 1);
      expect(notifier.doctorRecords.first.licenseNumber, 4267);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingDoctors, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initDoctorsListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = DoctorsNotifier(isTesting: false);
        notifier.initDoctorsListener();
        expect(notifier.isLoadingDoctors, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('BankAtmsNotifier Tests', () {
    test('initBankAtmsListener updates bank ATM records', () async {
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();

      AppStateNotifier.isTesting = false;
      final notifier = BankAtmsNotifier(
        isTesting: false,
        testFirestoreStream: streamController.stream,
      );

      notifier.initBankAtmsListener();
      expect(notifier.isLoadingAtms, isTrue);

      final record = {
        'id': '1',
        'atmNum': 3777,
        'bankCode': 12,
        'bankName': {'he': 'בנק הפועלים', 'en': 'Bank Hapoalim'},
        'branchCode': 377,
        'address': 'שד\' התמרים 11',
        'addressExtra': 'שדרות התמרים 11',
        'city': 'אילת',
        'atmLocation': {'he': 'בתוך הסניף', 'en': 'Inside Branch'},
        'coordinates': {'latitude': 29.555, 'longitude': 34.952},
        'geohash': 'sv0bh5bpb',
        'hasCommission': false,
        'hasCashWithdrawal': true,
        'hasCashDeposit': true,
        'hasChequeDeposit': true,
        'hasEnvelopeDeposit': true,
        'hasForexTransaction': true,
        'hasAdditionalTransactions': true,
        'hasHandicapAccess': true,
        'lastUpdated': '2026-06-02T09:00:00Z',
        'createdAt': '2026-06-02T09:00:00Z',
      };
      final fakeDoc = FakeQueryDocumentSnapshot('1', record);
      final fakeSnapshot = FakeQuerySnapshot([fakeDoc]);

      streamController.add(fakeSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.isLoadingAtms, isFalse);
      expect(notifier.atmRecords.length, 1);
      expect(notifier.atmRecords.first.atmNum, 3777);

      // Emit error
      streamController.addError('Error');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.isLoadingAtms, isFalse);

      await streamController.close();
      notifier.dispose();
      AppStateNotifier.isTesting = true;
    });

    test(
      'initBankAtmsListener fallback when stream is null and firebase is not initialized',
      () {
        AppStateNotifier.isTesting = false;
        final notifier = BankAtmsNotifier(isTesting: false);
        notifier.initBankAtmsListener();
        expect(notifier.isLoadingAtms, isFalse);
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );
  });

  group('TelemetryNotifier Tests', () {
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

        notifier.initAdminMetadataListener();
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
        notifier.initAdminMetadataListener();
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
  });

  group('Production path test cases for notifiers (Firebase/Firestore mock paths)', () {
    late FakeFirebaseFirestore mockFirestore;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    antennaController;
    late StreamController<DocumentSnapshot<Map<String, dynamic>>>
    permitMetadataController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    permitsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    liquidationController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    doctorsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    telemetryMetadataController;
    late StreamController<DocumentSnapshot<Map<String, dynamic>>>
    telemetryHealthController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    telemetryScraperRunsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    telemetryDirectoryController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    telemetryRequestsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    bankAtmsController;
    late StreamController<QuerySnapshot<Map<String, dynamic>>>
    vehicleRecallsController;

    setUp(() {
      AppStateNotifier.isTesting = false;
      AppStateNotifier.testIsFirebaseInitialized = true;

      antennaController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      permitMetadataController =
          StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      permitsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      liquidationController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      doctorsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      telemetryMetadataController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      telemetryHealthController =
          StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      telemetryScraperRunsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      telemetryDirectoryController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      telemetryRequestsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      bankAtmsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      vehicleRecallsController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      mockFirestore = FakeFirebaseFirestore((path) {
        if (path == '8935c8e5-ec77-421f-af86-d970583195f8') {
          return FakeCollectionReference(stream: antennaController.stream);
        } else if (path == 'dataset_metadata') {
          return FakeCollectionReference(
            stream: telemetryMetadataController.stream,
            docBuilder: (docId) {
              if (docId == 'ff398c7e-c522-4ee8-a53a-312b188a573d') {
                return FakeDocumentReference(
                  snapshotStream: permitMetadataController.stream,
                );
              }
              if (docId == 'existing-dataset-id') {
                return FakeDocumentReference(
                  exists: true,
                  data: {
                    'scheduler': {'nextRun': '2026-06-04T00:00:00Z'},
                  },
                );
              }
              return FakeDocumentReference();
            },
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
        } else if (path == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3') {
          return FakeCollectionReference(stream: liquidationController.stream);
        } else if (path == '9c64c522-bbc2-48fe-96fb-3b2a8626f59e') {
          return FakeCollectionReference(stream: doctorsController.stream);
        } else if (path == '21fde05f-62e3-401b-81cf-5c385862026d') {
          return FakeCollectionReference(stream: bankAtmsController.stream);
        } else if (path == '2c33523f-87aa-44ec-a736-edbb0a82975e') {
          return FakeCollectionReference(
            stream: vehicleRecallsController.stream,
          );
        }
        // Permit collection fallback
        return FakeCollectionReference(stream: permitsController.stream);
      });
    });

    tearDown(() {
      AppStateNotifier.isTesting = true;
      AppStateNotifier.testIsFirebaseInitialized = null;
      antennaController.close();
      permitMetadataController.close();
      permitsController.close();
      liquidationController.close();
      doctorsController.close();
      telemetryMetadataController.close();
      telemetryHealthController.close();
      telemetryScraperRunsController.close();
      telemetryDirectoryController.close();
      telemetryRequestsController.close();
      bankAtmsController.close();
      vehicleRecallsController.close();
    });

    test(
      'AntennasNotifier handles real Firestore streams and error path',
      () async {
        final notifier = AntennasNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        expect(notifier.isLoadingAntennas, isTrue);

        notifier.initAntennaListener();

        antennaController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'antennaId': 'CELL-200',
              'operatorName': 'Partner',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAntennas, isFalse);
        expect(notifier.antennaRecords.first['antennaId'], 'CELL-200');

        antennaController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAntennas, isFalse);

        notifier.dispose();
      },
    );

    test(
      'AntennasNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = AntennasNotifier(isTesting: false);
        notifier.initAntennaListener();
        expect(notifier.isLoadingAntennas, isFalse);
        notifier.dispose();
      },
    );

    test(
      'PermitsNotifier handles real Firestore streams and error paths',
      () async {
        final notifier = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'syncing');

        permitsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('perm1', {'referenceNumber': 12345}),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingPermits, isFalse);
        expect(notifier.permitRecords.first['referenceNumber'], 12345);

        permitsController.addError('Permits Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingPermits, isFalse);

        permitMetadataController.addError('Metadata Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.permitSyncStatus, 'error');

        notifier.dispose();
      },
    );

    test('PermitsNotifier handles empty permit metadata snapshot', () async {
      final notifier = PermitsNotifier(
        isTesting: false,
        testFirestore: mockFirestore,
      );
      notifier.initPermitMetadataListener();
      permitMetadataController.add(FakeDocumentSnapshot('meta', false, null));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isLoadingPermits, isFalse);
      notifier.dispose();
    });

    test(
      'PermitsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = PermitsNotifier(isTesting: false);
        notifier.initPermitMetadataListener();
        expect(notifier.isLoadingPermits, isFalse);
        notifier.dispose();
      },
    );

    test(
      'LiquidationNotifier handles real Firestore stream and error path',
      () async {
        final notifier = LiquidationNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initLiquidationListener();

        liquidationController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('liq1', {
              'liquidationCaseId': 999,
              'companyName': 'Liquidation Case 1',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingLiquidation, isFalse);
        expect(notifier.liquidationRecords.first.liquidationCaseId, 999);

        liquidationController.addError('Liquidation Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingLiquidation, isFalse);

        notifier.dispose();
      },
    );

    test(
      'LiquidationNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = LiquidationNotifier(isTesting: false);
        notifier.initLiquidationListener();
        expect(notifier.isLoadingLiquidation, isFalse);
        notifier.dispose();
      },
    );

    test(
      'VehicleRecallsNotifier handles real Firestore stream and error path',
      () async {
        final notifier = VehicleRecallsNotifier(testFirestore: mockFirestore);
        notifier.initRecallsListener();

        vehicleRecallsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('rec1', {
              'recallId': 54321,
              'recallYear': 2026,
              'manufacturerName': 'Honda',
              'modelName': 'Civic',
              'recallType': 'Safety',
              'defectDescription': 'Airbag issue',
              'defectCategory': 'Airbags',
              'buildStartDate': '2025-01-01',
              'buildEndDate': '2025-12-31',
              'lastUpdated': '2026-06-01T00:00:00Z',
              'createdAt': '2026-06-01T00:00:00Z',
              'scrapedAt': '2026-06-01T00:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingRecalls, isFalse);
        expect(notifier.recallRecords.first.recallId, 54321);

        vehicleRecallsController.addError('Vehicle Recalls Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingRecalls, isFalse);

        notifier.dispose();
      },
    );

    test(
      'VehicleRecallsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = VehicleRecallsNotifier();
        notifier.initRecallsListener();
        expect(notifier.isLoadingRecalls, isFalse);
        notifier.dispose();
      },
    );

    test(
      'VehicleRecallsNotifier handles Firestore snapshots exception',
      () async {
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Collection snapshots exception');
        });
        final notifier = VehicleRecallsNotifier(
          testFirestore: mockFirestoreThrow,
        );
        notifier.initRecallsListener();
        expect(notifier.isLoadingRecalls, isFalse);
        notifier.dispose();
      },
    );

    test(
      'DoctorsNotifier handles real Firestore stream and error path',
      () async {
        final notifier = DoctorsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initDoctorsListener();

        doctorsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'id': 'doc1',
              'licenseNumber': 8888,
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingDoctors, isFalse);
        expect(notifier.doctorRecords.first.licenseNumber, 8888);

        doctorsController.addError('Doctors Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingDoctors, isFalse);

        notifier.dispose();
      },
    );

    test(
      'DoctorsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = DoctorsNotifier(isTesting: false);
        notifier.initDoctorsListener();
        expect(notifier.isLoadingDoctors, isFalse);
        notifier.dispose();
      },
    );

    test(
      'TelemetryNotifier handles real Firestore streams and error paths',
      () async {
        final notifier = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initAdminMetadataListener();
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
      },
    );

    test(
      'TelemetryNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = TelemetryNotifier(isTesting: false);
        notifier.initAdminMetadataListener();
        notifier.initDirectoryListener();
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);
        notifier.dispose();
      },
    );

    test('AuthNotifier handles real Firebase and Firestore flows', () async {
      final authStreamController = StreamController<User?>.broadcast();
      final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
      final fakeAuth = FakeFirebaseAuth(
        mockCurrentUser: fakeUser,
        authChanges: authStreamController.stream,
      );
      final mockRepo = FakeUserProfileRepository(tProfile);

      final notifier = AuthNotifier(
        isTesting: false,
        testAuthChangesStream: authStreamController.stream,
        testProfileRepository: mockRepo,
        testAuth: fakeAuth,
      );

      authStreamController.add(fakeUser);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isAuthenticated, isTrue);

      await notifier.signInWithGoogle();
      await notifier.signOut();

      authStreamController.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.isAuthenticated, isFalse);

      authStreamController.addError('Auth Error');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.dispose();
      await authStreamController.close();
    });

    test(
      'AuthNotifier covers remote data source initialization, errors in local storage, and other operations',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;
        final authStreamController = StreamController<User?>.broadcast();
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        final fakeAuth = FakeFirebaseAuth(
          mockCurrentUser: fakeUser,
          authChanges: authStreamController.stream,
        );

        // Verify remote data source is instantiated
        final notifier = AuthNotifier(
          isTesting: false,
          testAuthChangesStream: authStreamController.stream,
          testFirestore: mockFirestore,
          testAuth: fakeAuth,
        );
        expect(notifier.isAuthenticated, isFalse);

        // Wait for LocalStorage.init() to complete successfully first
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 2. Set platform to throwing implementation for writes
        final originalPlatform = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance =
            ThrowingSharedPreferencesStore();

        await notifier.toggleFavorite('fav-dataset');
        await notifier.addRecent('recent-dataset');
        notifier.setGuestMode(true);

        // Restore platform
        SharedPreferencesStorePlatform.instance = originalPlatform;
        notifier.dispose();
        await authStreamController.close();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'AuthNotifier covers SharedPreferences initialization exceptions and listener errors',
      () async {
        AppStateNotifier.isTesting = false;
        AppStateNotifier.testIsFirebaseInitialized = true;

        // 1. SharedPreferences initialization throws exception (by setting mock initial values with wrong types)
        SharedPreferences.setMockInitialValues({
          'favorites':
              123, // getStringList on integer will throw a cast/type error
          'recents': 'not-a-list', // getStringList on string will throw
          'guest_mode': 'not-a-bool', // getBool on string will throw
        });

        final notifier = AuthNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 2. Auth changes stream listener onError callback
        final authStreamController = StreamController<User?>.broadcast();
        final fakeAuth = FakeFirebaseAuth(
          mockCurrentUser: null,
          authChanges: authStreamController.stream,
        );
        final notifier2 = AuthNotifier(
          isTesting: false,
          testAuth: fakeAuth,
          testProfileRepository: FakeUserProfileRepository(tProfile),
        );

        // Trigger success user login first to cover success listener path lines 216-223
        final fakeUser = FakeUser('user_123', 'assaf@plainsight.il');
        authStreamController.add(fakeUser);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        authStreamController.addError(Exception('Auth stream failure'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 3. User profile update exception path
        final mockRepo = FakeUserProfileRepository(tProfile);
        mockRepo.throwOnUpdate = true;
        final notifier3 = AuthNotifier(
          isTesting: false,
          testAuthChangesStream: authStreamController.stream,
          testProfileRepository: mockRepo,
        );

        // Add user to trigger profile listener setup so it listens to mockRepo.controller
        authStreamController.add(fakeUser);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(() => notifier3.updateUserProfile(tProfile), throwsException);

        // 4. Profile listen stream onError callback
        mockRepo.controller.addError(
          Exception('Profile stream listener error'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 5. Sign in and sign out errors
        final fakeAuthError = FakeFirebaseAuth(
          mockCurrentUser: null,
          authChanges: authStreamController.stream,
          onSignInWithPopup: () => throw Exception('Google sign in error'),
          onSignOut: () => throw Exception('Sign out error'),
        );
        final notifier4 = AuthNotifier(
          isTesting: false,
          testAuth: fakeAuthError,
          testProfileRepository: mockRepo,
        );

        expect(() => notifier4.signInWithGoogle(), throwsException);
        await notifier4.signOut();

        notifier.dispose();
        notifier2.dispose();
        notifier3.dispose();
        notifier4.dispose();
        await authStreamController.close();

        // Clean up mock values
        SharedPreferences.setMockInitialValues({});
        AppStateNotifier.isTesting = true;
      },
    );

    test('AntennasNotifier handles Firestore snapshots exception', () async {
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Collection snapshots exception');
      });
      final notifier = AntennasNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifier.initAntennaListener();
      expect(notifier.isLoadingAntennas, isFalse);
      notifier.dispose();
    });

    test(
      'PermitsNotifier handles duplicate active collection metadata, subscription errors, and binding exceptions',
      () async {
        // 1. PermitsNotifier metadata listener handles same active collection
        final notifier = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Send same metadata, should not bind again, hits the else branch
        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 2. Permits collection snapshots throws exception on bind
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          if (path == 'dataset_metadata') {
            return FakeCollectionReference(
              docBuilder: (docId) => FakeDocumentReference(
                snapshotStream: permitMetadataController.stream,
              ),
            );
          }
          throw Exception('Collection snapshots exception on permits list');
        });

        final notifier2 = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifier2.initPermitMetadataListener();

        permitMetadataController.add(
          FakeDocumentSnapshot('meta', true, {
            'activeCollection': 'permits_active_collection',
            'status': 'syncing',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier2.permitSyncStatus, 'error');

        // 3. Permits metadata snapshots throws exception on bind
        final mockFirestoreThrowMeta = FakeFirebaseFirestore((path) {
          throw Exception('Collection metadata snapshots exception');
        });
        final notifier3 = PermitsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrowMeta,
        );
        notifier3.initPermitMetadataListener();
        expect(notifier3.permitSyncStatus, 'error');

        notifier.dispose();
        notifier2.dispose();
        notifier3.dispose();
      },
    );

    test(
      'LiquidationNotifier and DoctorsNotifier handle snapshots exception',
      () async {
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Firestore exception');
        });

        final notifierLiq = LiquidationNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifierLiq.initLiquidationListener();
        expect(notifierLiq.isLoadingLiquidation, isFalse);

        final notifierDoc = DoctorsNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifierDoc.initDoctorsListener();
        expect(notifierDoc.isLoadingDoctors, isFalse);

        notifierLiq.dispose();
        notifierDoc.dispose();
      },
    );

    test(
      'PatentClassificationsNotifier handles testing mode and Firestore queries',
      () async {
        // Test in testing mode
        AppStateNotifier.isTesting = true;
        final notifier = PatentClassificationsNotifier();
        notifier.initPatentClassificationsListener();
        expect(notifier.isLoadingPatents, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(notifier.isLoadingPatents, isFalse);
        expect(notifier.patentRecords.isNotEmpty, isTrue);
        expect(notifier.patentRecords.length, MockData.patents.length);

        notifier.setPrimaryFilter('Primary');
        notifier.setSearchQuery('327015');
        notifier.resetFilters();
        notifier.cancelPatentClassificationsListener();
        expect(notifier.patentRecords.isEmpty, isTrue);

        // Test in non-testing mode with Firestore
        AppStateNotifier.isTesting = false;
        final mockFirestore = FakeFirebaseFirestore((path) {
          return FakeCollectionReference();
        });
        final notifierFirestore = PatentClassificationsNotifier(
          testFirestore: mockFirestore,
        );
        notifierFirestore.initPatentClassificationsListener();
        expect(notifierFirestore.isLoadingPatents, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        notifierFirestore.dispose();
        notifier.dispose();
        AppStateNotifier.isTesting = true;
      },
    );

    test(
      'TelemetryNotifier handles exception in listeners and triggers manual sync / activation',
      () async {
        // 1. TelemetryNotifier handles exceptions in all metadata/health/runs/dir/requests subscriptions
        final mockFirestoreThrow = FakeFirebaseFirestore((path) {
          throw Exception('Telemetry Firestore exception');
        });

        final notifier = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestoreThrow,
        );
        notifier.initAdminMetadataListener();
        notifier.initDirectoryListener();
        expect(notifier.isLoadingAdminMetadata, isFalse);
        expect(notifier.isLoadingTelemetry, isFalse);
        expect(notifier.isLoadingDirectory, isFalse);

        // 2. Health snapshot is empty (exists: false)
        final notifier2 = TelemetryNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier2.initAdminMetadataListener();
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
      },
    );

    test(
      'BankAtmsNotifier handles real Firestore streams and error path',
      () async {
        final notifier = BankAtmsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        expect(notifier.isLoadingAtms, isTrue);

        notifier.initBankAtmsListener();

        bankAtmsController.add(
          FakeQuerySnapshot([
            FakeQueryDocumentSnapshot('doc1', {
              'id': '1',
              'atmNum': 3777,
              'bankCode': 12,
              'bankName': {'he': 'בנק הפועלים', 'en': 'Bank Hapoalim'},
              'branchCode': 377,
              'address': 'שד\' התמרים 11',
              'addressExtra': 'שדרות התמרים 11',
              'city': 'אילת',
              'atmLocation': {'he': 'בתוך הסניף', 'en': 'Inside Branch'},
              'coordinates': {'latitude': 29.555, 'longitude': 34.952},
              'geohash': 'sv0bh5bpb',
              'hasCommission': false,
              'hasCashWithdrawal': true,
              'hasCashDeposit': true,
              'hasChequeDeposit': true,
              'hasEnvelopeDeposit': true,
              'hasForexTransaction': true,
              'hasAdditionalTransactions': true,
              'hasHandicapAccess': true,
              'lastUpdated': '2026-06-02T09:00:00Z',
              'createdAt': '2026-06-02T09:00:00Z',
            }),
          ]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAtms, isFalse);
        expect(notifier.atmRecords.first.id, '1');
        expect(notifier.atmRecords.first.atmNum, 3777);

        bankAtmsController.addError('Stream Error');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.isLoadingAtms, isFalse);

        notifier.dispose();
      },
    );

    test(
      'BankAtmsNotifier handles init failure / isFirebaseInitialized false path',
      () async {
        AppStateNotifier.testIsFirebaseInitialized = false;
        final notifier = BankAtmsNotifier(isTesting: false);
        notifier.initBankAtmsListener();
        expect(notifier.isLoadingAtms, isFalse);
        notifier.dispose();
      },
    );

    test('BankAtmsNotifier handles Firestore snapshots exception', () async {
      final mockFirestoreThrow = FakeFirebaseFirestore((path) {
        throw Exception('Collection snapshots exception');
      });
      final notifier = BankAtmsNotifier(
        isTesting: false,
        testFirestore: mockFirestoreThrow,
      );
      notifier.initBankAtmsListener();
      expect(notifier.isLoadingAtms, isFalse);
      notifier.dispose();
    });

    test(
      'BankAtmsNotifier cancel listener resets records and loading flags',
      () {
        final notifier = BankAtmsNotifier(
          isTesting: false,
          testFirestore: mockFirestore,
        );
        notifier.initBankAtmsListener();
        notifier.cancelBankAtmsListener();
        expect(notifier.atmRecords, isEmpty);
        expect(notifier.isLoadingAtms, isTrue);
        notifier.dispose();
      },
    );

    test(
      'AppStateNotifier.updateDatasetScheduler handles existing doc and throws exception path',
      () async {
        AppStateNotifier.isTesting = true;
        final appState = AppStateNotifier();
        appState.telemetryNotifier.testFirestore = mockFirestore;
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
      },
    );
  });
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  final CollectionReference Function(String) collectionBuilder;
  bool transactionExists = true;
  bool throwOnTransaction = false;

  FakeFirebaseFirestore(this.collectionBuilder);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return collectionBuilder(path) as CollectionReference<Map<String, dynamic>>;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (throwOnTransaction) {
      throw Exception('Transaction failed');
    }
    final transaction = FakeTransaction(exists: transactionExists);
    return await transactionHandler(transaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransaction implements Transaction {
  final bool exists;
  FakeTransaction({this.exists = true});

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    return FakeDocumentSnapshot(documentReference.id, exists, {
          'requestCount': 5,
        })
        as DocumentSnapshot<T>;
  }

  @override
  Transaction delete(DocumentReference documentReference) => this;

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) => this;

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Query Function(int)? limitBuilder;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final DocumentReference<Map<String, dynamic>> Function(String)? docBuilder;

  FakeCollectionReference({this.limitBuilder, this.stream, this.docBuilder});

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (docBuilder != null && path != null) {
      return docBuilder!(path);
    }
    return FakeDocumentReference(id: path ?? 'mock-id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return stream ?? const Stream.empty();
    }
    if (invocation.memberName == #orderBy) {
      return this;
    }
    if (invocation.memberName == #limit) {
      final limitVal = invocation.positionalArguments[0] as int;
      if (limitBuilder != null) {
        return limitBuilder!(limitVal);
      }
      return this;
    }
    if (invocation.memberName == #startAfterDocument) {
      return this;
    }
    if (invocation.memberName == #get) {
      if (stream != null) {
        return stream!.first;
      }
      return Future.value(FakeQuerySnapshot([]));
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? snapshotStream;
  final bool exists;
  final Map<String, dynamic>? data;
  FakeDocumentReference({
    String id = 'mock-id',
    this.snapshotStream,
    this.exists = false,
    this.data,
  }) : _id = id;

  @override
  String get id => _id;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return snapshotStream ?? const Stream.empty();
    }
    if (invocation.memberName == #get) {
      final exists = _id == 'existing-doc' || _id == 'existing-dataset-id';
      final data = exists
          ? {
              'scheduler': {'nextRun': '2026-06-04T12:00:00Z'},
            }
          : {'requestCount': 5};
      return Future.value(FakeDocumentSnapshot(_id, exists, data));
    }
    if (invocation.memberName == #set) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeFirebaseAuth implements FirebaseAuth {
  final User? mockCurrentUser;
  final Stream<User?> authChanges;
  final Future<UserCredential> Function()? onSignInAnonymously;
  final Future<UserCredential> Function()? onSignInWithPopup;
  final Future<void> Function()? onSignOut;

  FakeFirebaseAuth({
    this.mockCurrentUser,
    required this.authChanges,
    this.onSignInAnonymously,
    this.onSignInWithPopup,
    this.onSignOut,
  });

  @override
  User? get currentUser => mockCurrentUser;

  @override
  Stream<User?> authStateChanges() => authChanges;

  @override
  Future<UserCredential> signInWithPopup(dynamic provider) async {
    if (onSignInWithPopup != null) {
      return onSignInWithPopup!();
    }
    return FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    if (onSignOut != null) {
      await onSignOut!();
    }
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    if (onSignInAnonymously != null) {
      return onSignInAnonymously!();
    }
    return FakeUserCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  User get user => FakeUser('mock_anonymous_uid', 'anonymous@plainsight.il');

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
