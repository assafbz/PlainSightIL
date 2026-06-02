import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'local_storage.dart';
import '../theme/design_system.dart';
import '../utils/app_logger.dart';
import '../constants/dataset_ids.dart';
import '../constants/mock_data.dart';
import '../../features/directory/data/models/dataset_metadata_model.dart';
import '../../features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';
import '../../features/datasets/doctors_licenses/data/models/doctor_license_model.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/profile/domain/repositories/user_profile_repository.dart';
import '../../features/profile/domain/usecases/get_user_profile.dart';
import '../../features/profile/domain/usecases/update_user_profile.dart';
import '../../features/profile/data/datasources/user_profile_remote_datasource.dart';
import '../../features/profile/data/repositories/user_profile_repository_impl.dart';

class AppStateNotifier extends ChangeNotifier {
  static bool isTesting = false;
  static int functionsPort = 5002;

  String _locale = 'en';
  int _activeTab = 0;
  bool _isDarkMode = true;
  bool _isCheckingApiHealth = false;

  bool get isCheckingApiHealth => _isCheckingApiHealth;

  // Authentication states
  User? _currentUser;
  bool _isGuestMode = false;
  bool _isMockAuthenticated = false;

  // Favorites and Recents
  List<String> _favorites = [];
  List<String> _recents = [];

  List<String> get favorites => _favorites;
  List<String> get recents => _recents;

  // Profile management state
  UserProfile? _userProfile;
  StreamSubscription<UserProfile?>? _profileSubscription;
  late final UserProfileRepository _profileRepository;
  late final GetUserProfile _getUserProfileUseCase;
  late final UpdateUserProfile _updateUserProfileUseCase;

  UserProfile? get userProfile => _userProfile;

  AppStateNotifier() {
    AppLogger.info('Initializing AppStateNotifier (isTesting: $isTesting)');
    _isMockAuthenticated = isTesting;
    _initProfileUsecases();
    _initAuthListener();
    _initSharedPreferences();
    if (_isMockAuthenticated) {
      _updateProfileListener('mock_uid');
    }
  }

  void _initProfileUsecases() {
    if (!isTesting && isFirebaseInitialized) {
      final datasource = UserProfileRemoteDataSourceImpl(
        FirebaseFirestore.instance,
      );
      _profileRepository = UserProfileRepositoryImpl(datasource);
    } else {
      _profileRepository = _MockUserProfileRepository();
    }
    _getUserProfileUseCase = GetUserProfile(_profileRepository);
    _updateUserProfileUseCase = UpdateUserProfile(_profileRepository);
  }

  /// Sets the mock user profile (available only in testing mode).
  void setMockProfile(UserProfile? profile) {
    if (!isTesting) return;
    if (_profileRepository is _MockUserProfileRepository) {
      final mockRepo = _profileRepository;
      mockRepo._currentProfile = profile;
      mockRepo._controller.add(profile);
      _userProfile = profile;
      notifyListeners();
    }
  }

  Future<void> _initSharedPreferences() async {
    try {
      await LocalStorage.init();

      // Check if branch swapped and reset cache to prevent state pollution
      const String activeBranch = String.fromEnvironment(
        'GIT_BRANCH',
        defaultValue: 'unknown',
      );
      final String? lastSavedBranch = LocalStorage.getLastSavedBranch();

      if (activeBranch != 'unknown' && lastSavedBranch != activeBranch) {
        AppLogger.warning(
          '🔄 Git Branch Switch Detected! (Prev: $lastSavedBranch, Curr: $activeBranch). Flushing local cache...',
        );
        await LocalStorage.clearAll();
        await LocalStorage.saveLastSavedBranch(activeBranch);
      }

      _favorites = LocalStorage.getFavorites();
      _recents = LocalStorage.getRecents();
      _isGuestMode = LocalStorage.getGuestMode();
      AppLogger.info(
        'SharedPreferences loaded: ${_favorites.length} favorites, ${_recents.length} recents, guestMode: $_isGuestMode',
      );
      if (_isGuestMode) {
        initPermitMetadataListener();
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error initializing SharedPreferences', e);
    }
  }

  bool isFavorite(String datasetId) {
    return _favorites.contains(datasetId);
  }

  Future<void> toggleFavorite(String datasetId) async {
    final isFav = _favorites.contains(datasetId);
    AppLogger.info(
      'Toggling favorite for dataset $datasetId (Currently favorite: $isFav)',
    );
    if (isFav) {
      _favorites.remove(datasetId);
    } else {
      _favorites.add(datasetId);
    }
    notifyListeners();
    try {
      await LocalStorage.saveFavorites(_favorites);
    } catch (e) {
      AppLogger.error('Error saving favorites for dataset $datasetId', e);
    }
  }

  Future<void> addRecent(String datasetId) async {
    AppLogger.info('Adding dataset $datasetId to recents');
    _recents.remove(datasetId);
    _recents.insert(0, datasetId);
    if (_recents.length > 5) {
      _recents = _recents.sublist(0, 5);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    try {
      await LocalStorage.saveRecents(_recents);
    } catch (e) {
      AppLogger.error('Error saving recents for dataset $datasetId', e);
    }
  }

  void _initAuthListener() {
    if (isTesting || !isFirebaseInitialized) return;
    try {
      AppLogger.info('Initializing FirebaseAuth listener');
      FirebaseAuth.instance.authStateChanges().listen((user) {
        final bool userChanged = _currentUser?.uid != user?.uid;
        _currentUser = user;
        AppLogger.info(
          'Auth state updated. User UID: ${user?.uid}, changed: $userChanged',
        );
        if (userChanged) {
          // Clear profile and telemetry state to prevent race conditions or incorrect permissions checks
          _userProfile = null;
          _apiHealthSubscription?.cancel();
          _scraperRunsSubscription?.cancel();
          _apiHealth = {};
          _scraperRuns = [];

          // Re-bind Firestore listeners when the authentication state changes
          // to ensure data is fetched under the updated auth credentials.
          initPermitMetadataListener();
          _updateProfileListener(user?.uid);
        }
        notifyListeners();
      });
    } catch (e) {
      AppLogger.error('Auth listener init error', e);
    }
  }

  void _updateProfileListener(String? uid) {
    AppLogger.info('Updating profile stream listener for UID: $uid');
    _profileSubscription?.cancel();
    _profileSubscription = null;

    if (uid == null) {
      _userProfile = null;
      _apiHealthSubscription?.cancel();
      _scraperRunsSubscription?.cancel();
      _apiHealth = {};
      _scraperRuns = [];
      notifyListeners();
      return;
    }

    _profileSubscription = _getUserProfileUseCase
        .call(uid)
        .listen(
          (profile) {
            AppLogger.info(
              'Profile stream emitted value for UID $uid: $profile',
            );
            if (_userProfile != profile) {
              final bool wasAdmin = isAdmin;
              _userProfile = profile;
              if (isAdmin && !wasAdmin) {
                initTelemetryListeners();
              } else if (!isAdmin && wasAdmin) {
                _apiHealthSubscription?.cancel();
                _scraperRunsSubscription?.cancel();
                _apiHealth = {};
                _scraperRuns = [];
              }
              notifyListeners();
            }
          },
          onError: (Object error) {
            AppLogger.error('Profile stream error for UID: $uid', error);
          },
        );
  }

  /// Updates the user's profile and handles success/error states.
  Future<void> updateUserProfile(UserProfile profile) async {
    AppLogger.info('Updating user profile for UID: ${profile.uid}');
    try {
      await _updateUserProfileUseCase.call(profile);
      AppLogger.info(
        'Successfully updated user profile for UID: ${profile.uid}',
      );
    } catch (e) {
      AppLogger.error('Error updating user profile for UID: ${profile.uid}', e);
      rethrow;
    }
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null || _isMockAuthenticated;
  bool get isGuestMode => _isGuestMode;
  bool get isAdmin => _isMockAuthenticated || (_userProfile?.role == 'admin');

  Map<String, String>? get mockUser => _isMockAuthenticated
      ? MockData.userMap
      : null;

  Future<void> signInWithGoogle() async {
    AppLogger.info('Initiating Google Sign-In');
    if (isTesting || !isFirebaseInitialized) {
      AppLogger.info('Using mock authentication mode');
      _isMockAuthenticated = true;
      _isGuestMode = false;
      _updateProfileListener('mock_uid');
      notifyListeners();
      return;
    }

    try {
      final provider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(provider);
      _isGuestMode = false;
      AppLogger.info(
        'Successfully authenticated with Google. User UID: ${FirebaseAuth.instance.currentUser?.uid}',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Google Sign-In Error', e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    AppLogger.info('Signing out current user');
    _isMockAuthenticated = false;
    _isGuestMode = false;
    _updateProfileListener(null);
    try {
      await LocalStorage.saveGuestMode(false);
    } catch (_) {}
    _permitRecords = [];
    _antennaRecords = [];
    _directoryRecords = [];
    _isLoadingPermits = true;
    _isLoadingAntennas = true;
    _isLoadingDirectory = true;
    if (isFirebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
        AppLogger.info('Successfully signed out from FirebaseAuth');
      } catch (e) {
        AppLogger.error('Firebase Sign-Out Error', e);
      }
    }
    notifyListeners();
  }

  void setGuestMode(bool enabled) {
    AppLogger.info('Setting guest mode to: $enabled');
    _isGuestMode = enabled;
    if (enabled) {
      initPermitMetadataListener();
    }
    notifyListeners();
    try {
      LocalStorage.saveGuestMode(enabled);
    } catch (e) {
      AppLogger.error('Error saving guest mode', e);
    }
  }

  // Double-buffered Firestore subscriptions for permit applications
  String _activePermitCollection = '';
  List<Map<String, dynamic>> _permitRecords = [];
  bool _isLoadingPermits = true;
  String _permitSyncStatus = 'idle';
  StreamSubscription<QuerySnapshot>? _permitSubscription;
  StreamSubscription<DocumentSnapshot>? _permitMetadataSubscription;

  // Active Antennas Firestore subscription and state
  List<Map<String, dynamic>> _antennaRecords = [];
  bool _isLoadingAntennas = true;
  StreamSubscription<QuerySnapshot>? _antennaSubscription;

  // Dataset Directory state fields
  List<DatasetMetadataModel> _directoryRecords = [];
  bool _isLoadingDirectory = true;
  Map<String, int> _datasetRequestCounts = {};
  StreamSubscription<QuerySnapshot>? _directorySubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  // Companies in Liquidation state fields
  List<LiquidationRecordModel> _liquidationRecords = [];
  bool _isLoadingLiquidation = true;
  StreamSubscription<QuerySnapshot>? _liquidationSubscription;

  List<LiquidationRecordModel> get liquidationRecords => _liquidationRecords;
  bool get isLoadingLiquidation => _isLoadingLiquidation;

  // Doctors Licenses state fields
  List<DoctorLicenseRecordModel> _doctorRecords = [];
  bool _isLoadingDoctors = true;
  StreamSubscription<QuerySnapshot>? _doctorsSubscription;

  List<DoctorLicenseRecordModel> get doctorRecords => _doctorRecords;
  bool get isLoadingDoctors => _isLoadingDoctors;

  // Admin Metadata state fields
  Map<String, Map<String, dynamic>> _datasetMetadataMap = {};
  bool _isLoadingAdminMetadata = true;
  StreamSubscription<QuerySnapshot>? _adminMetadataSubscription;

  Map<String, Map<String, dynamic>> get datasetMetadataMap =>
      _datasetMetadataMap;
  bool get isLoadingAdminMetadata => _isLoadingAdminMetadata;

  // Telemetry state fields
  Map<String, dynamic> _apiHealth = {};
  List<Map<String, dynamic>> _scraperRuns = [];
  bool _isLoadingTelemetry = true;
  StreamSubscription<DocumentSnapshot>? _apiHealthSubscription;
  StreamSubscription<QuerySnapshot>? _scraperRunsSubscription;

  Map<String, dynamic> get apiHealth => _apiHealth;
  List<Map<String, dynamic>> get scraperRuns => _scraperRuns;
  bool get isLoadingTelemetry => _isLoadingTelemetry;

  List<DatasetMetadataModel> get directoryRecords => _directoryRecords;
  bool get isLoadingDirectory => _isLoadingDirectory;
  int getRequestCount(String id) => _datasetRequestCounts[id] ?? 0;

  String get locale => _locale;
  int get activeTab => _activeTab;
  bool get isDarkMode => _isDarkMode;

  List<Map<String, dynamic>> get permitRecords => _permitRecords;
  bool get isLoadingPermits => _isLoadingPermits;
  String get permitSyncStatus => _permitSyncStatus;

  List<Map<String, dynamic>> get antennaRecords => _antennaRecords;
  bool get isLoadingAntennas => _isLoadingAntennas;

  /// Check if Firebase is initialized
  bool get isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initialize metadata listener for cellular permits
  void initPermitMetadataListener() {
    initAntennaListener();
    initDirectoryListener();
    initLiquidationListener();
    initDoctorsListener();
    initAdminMetadataListener();

    if (isTesting) {
      _permitSyncStatus = 'idle';
      _permitRecords = MockData.permits;
      _isLoadingPermits = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _permitSyncStatus = 'error';
      _isLoadingPermits = false;
      notifyListeners();
      AppLogger.warning(
        'Firebase is not initialized. Skipping permit metadata listener.',
      );
      return;
    }

    AppLogger.info('Initializing permit metadata listener');
    _permitMetadataSubscription?.cancel();
    try {
      _permitMetadataSubscription = FirebaseFirestore.instance
          .collection('dataset_metadata')
          .doc(DatasetIds.cellularPermits)
          .snapshots()
          .listen(
            (metaSnapshot) {
              if (metaSnapshot.exists && metaSnapshot.data() != null) {
                final data = metaSnapshot.data()!;
                final newActive = data['activeCollection'] as String? ?? '';
                _permitSyncStatus = data['status'] as String? ?? 'idle';
                AppLogger.info(
                  'Permit metadata loaded. activeCollection: $newActive, status: $_permitSyncStatus',
                );

                if (newActive.isNotEmpty &&
                    newActive != _activePermitCollection) {
                  _bindActivePermitCollection(newActive);
                } else {
                  notifyListeners();
                }
              } else {
                AppLogger.warning('Permit metadata document does not exist');
                _isLoadingPermits = false;
                notifyListeners();
              }
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              AppLogger.error('Firestore permit metadata listener error', err);
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      AppLogger.error('Failed to bind Firestore metadata', e);
    }
  }

  void _bindActivePermitCollection(String newCollection) {
    AppLogger.info('Binding active permit collection to: $newCollection');
    _activePermitCollection = newCollection;
    _isLoadingPermits = true;
    notifyListeners();

    _permitSubscription?.cancel();
    if (!isFirebaseInitialized) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      return;
    }

    try {
      _permitSubscription = FirebaseFirestore.instance
          .collection(newCollection)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.info(
                'Permits fetched from Firestore ($newCollection): ${snapshot.docs.length} records',
              );
              // Swap only when data resolves to prevent flickering
              _permitRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingPermits = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              AppLogger.error(
                'Firestore permit collection listener error for $newCollection',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      AppLogger.error('Failed to bind Firestore collection $newCollection', e);
    }
  }

  void initAntennaListener() {
    _antennaSubscription?.cancel();
    if (isTesting) {
      _antennaRecords = MockData.antennas;
      _isLoadingAntennas = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingAntennas = false;
      notifyListeners();
      return;
    }

    AppLogger.info('Initializing cellular antennas listener');
    try {
      _antennaSubscription = FirebaseFirestore.instance
          .collection(DatasetIds.cellularAntennas)
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.info(
                'Antennas fetched from Firestore: ${snapshot.docs.length} records',
              );
              _antennaRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingAntennas = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingAntennas = false;
              notifyListeners();
              AppLogger.error(
                'Firestore antenna collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingAntennas = false;
      notifyListeners();
      AppLogger.error('Failed to bind Firestore antennas', e);
    }
  }

  void initDirectoryListener() {
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();

    if (isTesting) {
      _directoryRecords = MockData.directory;
      _datasetRequestCounts = MockData.datasetRequestCounts;
      _isLoadingDirectory = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingDirectory = false;
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Initializing dataset directory metadata and requests listeners',
    );
    try {
      _directorySubscription = FirebaseFirestore.instance
          .collection('datasets_metadata')
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.info(
                'Directory metadata fetched from Firestore: ${snapshot.docs.length} records',
              );
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

      _requestsSubscription = FirebaseFirestore.instance
          .collection('dataset_requests')
          .snapshots()
          .listen(
            (snapshot) {
              final Map<String, int> counts = {};
              for (final doc in snapshot.docs) {
                counts[doc.id] = (doc.data()['requestCount'] as num? ?? 0)
                    .toInt();
              }
              AppLogger.info(
                'Dataset requests counts fetched from Firestore: ${counts.length} records',
              );
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

  void initLiquidationListener() {
    _liquidationSubscription?.cancel();

    if (isTesting) {
      _liquidationRecords = MockData.liquidations;
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    AppLogger.info('Initializing companies liquidation listener');
    try {
      _liquidationSubscription = FirebaseFirestore.instance
          .collection(DatasetIds.companiesLiquidation)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.info(
                'Companies liquidation fetched from Firestore: ${snapshot.docs.length} records',
              );
              _liquidationRecords = snapshot.docs
                  .map((doc) => LiquidationRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingLiquidation = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingLiquidation = false;
              notifyListeners();
              AppLogger.error(
                'Firestore liquidation collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingLiquidation = false;
      notifyListeners();
      AppLogger.error('Failed to initialize liquidation listener', e);
    }
  }

  /// Initialize doctors licenses snapshots listener
  void initDoctorsListener() {
    _doctorsSubscription?.cancel();
    if (isTesting) {
      _doctorRecords = MockData.doctors;
      _isLoadingDoctors = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingDoctors = false;
      notifyListeners();
      return;
    }

    AppLogger.info('Initializing doctors licenses listener');
    try {
      _doctorsSubscription = FirebaseFirestore.instance
          .collection(DatasetIds.doctorsLicenses)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              AppLogger.info(
                'Doctors licenses fetched from Firestore: ${snapshot.docs.length} records',
              );
              _doctorRecords = snapshot.docs
                  .map((doc) => DoctorLicenseRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingDoctors = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingDoctors = false;
              notifyListeners();
              AppLogger.error(
                'Firestore doctors collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingDoctors = false;
      notifyListeners();
      AppLogger.error('Failed to initialize doctors listener', e);
    }
  }

  /// Initialize real-time snapshot listener on dataset_metadata collection
  void initAdminMetadataListener() {
    _adminMetadataSubscription?.cancel();
    initTelemetryListeners();
    if (isTesting) {
      _datasetMetadataMap = MockData.datasetMetadata;
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
      _adminMetadataSubscription = FirebaseFirestore.instance
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
              debugPrint('Firestore admin metadata listener error: $err');
            },
          );
    } catch (e) {
      _isLoadingAdminMetadata = false;
      notifyListeners();
      debugPrint('Failed to initialize admin metadata listener: $e');
    }
  }

  /// Initialize real-time listeners for system health and scraper runs
  void initTelemetryListeners() {
    _apiHealthSubscription?.cancel();
    _scraperRunsSubscription?.cancel();

    if (isTesting) {
      _apiHealth = MockData.apiHealth;
      _scraperRuns = MockData.scraperRuns;
      _isLoadingTelemetry = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingTelemetry = false;
      notifyListeners();
      return;
    }

    if (!isAdmin) {
      _isLoadingTelemetry = false;
      notifyListeners();
      return;
    }

    try {
      _apiHealthSubscription = FirebaseFirestore.instance
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

      _scraperRunsSubscription = FirebaseFirestore.instance
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

  /// Triggers a manual pings/health check of data.gov.il via Cloud Function.
  Future<void> triggerApiHealthCheck() async {
    AppLogger.info('Triggering manual API health check');
    _isCheckingApiHealth = true;
    notifyListeners();

    if (isTesting) {
      await Future.delayed(const Duration(milliseconds: 800));
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

    if (!isFirebaseInitialized) {
      _isCheckingApiHealth = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('$functionsBaseUrl/manualApiHealthCheck');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      AppLogger.info(
        'Manual API health check triggered. Status: ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.error('Failed to trigger API health check', e);
    } finally {
      _isCheckingApiHealth = false;
      notifyListeners();
    }
  }

  Future<bool> requestDatasetActivation(
    String datasetId,
    String datasetTitle,
  ) async {
    AppLogger.info(
      'Requesting dataset activation for datasetId: $datasetId ($datasetTitle)',
    );
    if (isTesting) {
      _datasetRequestCounts[datasetId] =
          (_datasetRequestCounts[datasetId] ?? 0) + 1;
      notifyListeners();
      return true;
    }

    if (!isFirebaseInitialized) {
      AppLogger.warning(
        'Firebase is not initialized. Skipping dataset activation request.',
      );
      return false;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? uid = user?.uid;
      if (uid == null) {
        AppLogger.info(
          'No authenticated user. Attempting anonymous sign-in for request registration',
        );
        final authResult = await FirebaseAuth.instance.signInAnonymously();
        uid = authResult.user?.uid;
      }

      if (uid == null) {
        AppLogger.warning(
          'Anonymous sign-in failed. Cannot record activation vote.',
        );
        return false;
      }

      final voteRef = FirebaseFirestore.instance
          .collection('dataset_requests')
          .doc(datasetId)
          .collection('votes')
          .doc(uid);

      final voteSnap = await voteRef.get();
      if (voteSnap.exists) {
        AppLogger.info(
          'User $uid has already registered a vote for dataset: $datasetId',
        );
        return false;
      }

      // Write transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final requestRef = FirebaseFirestore.instance
            .collection('dataset_requests')
            .doc(datasetId);

        final requestSnap = await transaction.get(requestRef);

        transaction.set(voteRef, {'votedAt': FieldValue.serverTimestamp()});

        if (requestSnap.exists) {
          final currentCount =
              (requestSnap.data()?['requestCount'] as num? ?? 0).toInt();
          AppLogger.info(
            'Incrementing requestCount for dataset $datasetId to ${currentCount + 1}',
          );
          transaction.update(requestRef, {
            'requestCount': currentCount + 1,
            'lastRequestedAt': FieldValue.serverTimestamp(),
          });
        } else {
          AppLogger.info('Initializing requestCount for dataset $datasetId');
          transaction.set(requestRef, {
            'datasetId': datasetId,
            'datasetTitle': datasetTitle,
            'requestCount': 1,
            'lastRequestedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      AppLogger.info(
        'Successfully registered activation request for dataset: $datasetId',
      );
      return true;
    } catch (e) {
      AppLogger.error('Error casting vote for dataset: $datasetId', e);
      return false;
    }
  }

  String get functionsBaseUrl {
    const String projectId = 'demo-plainsightil';
    const String region = 'us-central1';

    if (isTesting) {
      return 'http://127.0.0.1:$functionsPort/$projectId/$region';
    }

    final bool isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final String host = isAndroid ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:$functionsPort/$projectId/$region';
  }

  Future<Map<String, dynamic>> triggerManualSync(String datasetId) async {
    AppLogger.info('Triggering manual sync for dataset: $datasetId');

    // Immediately set local status to syncing to eliminate visual latency
    final Map<String, dynamic> localMeta = _datasetMetadataMap[datasetId] ?? {};
    _datasetMetadataMap[datasetId] = {...localMeta, 'status': 'syncing'};
    notifyListeners();

    if (isTesting) {
      await Future<void>.delayed(const Duration(seconds: 1));
      // Simulate success and update local state to idle with updated count
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
      final user = FirebaseAuth.instance.currentUser;
      String? token;
      if (user != null) {
        token = await user.getIdToken();
      }

      String functionName;
      if (datasetId == DatasetIds.cellularAntennas) {
        functionName = 'manualSyncAntennas';
      } else if (datasetId == DatasetIds.cellularPermits) {
        functionName = 'manualSyncPermitApps';
      } else if (datasetId == DatasetIds.companiesLiquidation) {
        functionName = 'manualSyncCompaniesLiquidation';
      } else if (datasetId == DatasetIds.doctorsLicenses) {
        functionName = 'manualSyncDoctorsLicenses';
      } else {
        throw Exception('Unknown dataset ID: $datasetId');
      }

      final url = Uri.parse('$functionsBaseUrl/$functionName');
      final response = await http.post(
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

        // Reset local status to error
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

  TextDirection get textDirection =>
      _locale == 'he' ? TextDirection.rtl : TextDirection.ltr;

  void setLocale(String newLocale) {
    if (newLocale == 'en' || newLocale == 'he') {
      _locale = newLocale;
      notifyListeners();
    }
  }

  void toggleLocale() {
    _locale = _locale == 'en' ? 'he' : 'en';
    notifyListeners();
  }

  void setActiveTab(int index) {
    _activeTab = index;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    AppColors.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  @override
  void dispose() {
    _permitSubscription?.cancel();
    _permitMetadataSubscription?.cancel();
    _antennaSubscription?.cancel();
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();
    _liquidationSubscription?.cancel();
    _doctorsSubscription?.cancel();
    _adminMetadataSubscription?.cancel();
    _profileSubscription?.cancel();
    _apiHealthSubscription?.cancel();
    _scraperRunsSubscription?.cancel();
    super.dispose();
  }

  // Bilingual string resource maps
  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'app_title': 'PlainSight IL',
      'mission_title': 'Democratizing Civic Data',
      'mission_subtitle':
          'Dry, obscure government records translated into clean, beautiful, and interactive mobile-first visualizations.',
      'explore_datasets': 'Explore Datasets',
      'towers_title': 'Cellular Antennas',
      'towers_desc': 'Active towers & radiation permits by location.',
      'towers_count': '9,840 records',
      'towers_roadmap_title': 'Cellular Antennas Coming Soon',
      'towers_roadmap_desc':
          'This dataset screen is under construction. Future integrations will include live data and interactive maps.',
      'towers_active_label': 'Active Towers',
      'towers_permit_label': 'Construction Permits',
      'towers_search_placeholder': 'Search by Locality or Site ID',
      'permit_ref_prefix': 'Ref: #',
      'permit_submitted': 'Submitted: ',
      'permit_locality': 'Locality: ',
      'permit_operator': 'Operator: ',
      'permit_type': 'Focal Type: ',
      'permit_badge_pending': 'Pending',
      'permit_badge_approved': 'In Construction',
      'no_results': 'No records found',
      'water_title': 'Companies in Liquidation',
      'water_desc': 'Businesses undergoing court winding up.',
      'water_count': '3 records',
      'budget_title': 'Government Budget',
      'budget_desc': 'Public budget tracking and market distribution.',
      'budget_count': 'Active issue #101',
      'alerts_title': 'Recent Alerts',
      'alerts_desc': 'Notifications and compliance warnings.',
      'alerts_count': '2 active alerts',
      'nav_home': 'Home',
      'nav_towers': 'Towers',
      'nav_water': 'Winding Up',
      'nav_budget': 'Budget',
      'nav_alerts': 'Alerts',
      'nav_directory': 'Directory',
      'directory_title': 'Dataset Directory',
      'search_hint': 'Search open datasets...',
      'open_visualizer': 'Open Visualizer',
      'request_integration': 'Request Activation',
      'request_success': 'Request registered successfully!',
      'requests_label': 'Requests: ',
      'publisher_label': 'Publisher: ',
      'resources_label': ' resources',
      'updated_label': 'Updated: ',
      'liquidation_title': 'Companies in Liquidation',
      'liquidation_desc': 'Businesses undergoing court winding up.',
      'liquidation_count': '3 records',
      'nav_liquidation': 'Winding Up',
      'case_id_label': 'Case ID: ',
      'court_label': 'Court: ',
      'city_label': 'City: ',
      'status_active': 'Active Winding Up',
      'status_frozen': 'Frozen',
      'status_closed': 'Closed',
      'closure_reason_prefix': 'Reason: ',
      'liquidation_search_placeholder': 'Search by Name or Company ID (H.P.)',
      'view_court_file': 'View Official Court File',
      'doctors_title': 'Doctors Licenses',
      'doctors_desc':
          'Israeli medical practitioner licenses and specialties registry.',
      'doctors_count': '3 records',
      'nav_doctors': 'Doctors Licenses',
      'doctors_search_placeholder': 'Search by Name or License Number',
      'license_num_label': 'License: #',
      'license_date_label': 'License Date: ',
      'specialty_cert_label': 'Specialty Cert: #',
      'specialty_date_label': 'Specialty Date: ',
      'doctor_licensed': 'Licensed / Active',
      'doctor_unlicensed': 'Muted / Inactive',
      'doctors_publisher': 'Ministry of Health - Medical Professions Registry',
      'trustee_publisher': 'Ministry of Justice - Corporations Authority',
      'filter_all': 'All',
      'filter_active': 'Supported',
      'filter_inactive': 'Requests',
      'toggle_lang': 'HE',
      'welcome_back': 'Welcome Back',
      'explore_cta': 'Select a dataset below to begin visualization',
      'badge_active': 'Active',
      'badge_roadmap': 'Roadmap',
      'badge_phase2': 'Phase 2 Roadmap',
      'back_button': 'Back to Home',
      'attribution_prefix': 'Data Source: ',
      'water_roadmap_title': 'Kinneret Telemetry Coming Soon',
      'water_roadmap_desc':
          'This dataset is part of the Phase 2 roadmap. We plan to integrate the official Water Authority API from data.gov.il to provide interactive water line charts, historical levels, and seasonal trend analysis.',
      'budget_roadmap_title': 'Budget Analysis Coming Soon',
      'budget_roadmap_desc':
          'This dataset is part of the Phase 2 roadmap. We plan to integrate the Ministry of Finance budget datasets from data.gov.il to provide interactive visualizations of public budget allocation, spending speed, and market distribution.',
      'alerts_roadmap_title': 'Alert Telemetry Coming Soon',
      'alerts_roadmap_desc':
          'This dataset is part of the Phase 2 roadmap. We plan to integrate real-time alert data from data.gov.il and environmental agencies to provide notifications, compliance warnings, and historical radiation/pollution alerts.',
      'secure_auth': 'Secure Authentication',
      'sign_in_google': 'Sign in with Google',
      'sign_up_google': 'Sign up with Google',
      'create_account_title': 'Create Account',
      'create_account_desc':
          'Create an account to save your favorite views, customize alerts, and track permits',
      'login_desc': 'Unlock the transparency of civic data',
      'already_have_account': 'Already have an account?',
      'dont_have_account': 'Don’t have an account?',
      'login_label': 'Log in',
      'signup_label': 'Sign up',
      'continue_guest': 'Continue as Guest',
      'ssl_protection': 'PROTECTED BY SSL',
      'login_info_text':
          'Access detailed visualizations of government spending and civic permits instantly.',
      'terms_disclaimer':
          'By continuing, you agree to PlainSight IL\'s Terms of Service and Privacy Policy.',
      'logout_label': 'Log out',
      'profile_settings_title': 'Profile Settings',
      'save': 'Save',
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'email': 'Email',
      'user_role': 'User Role',
      'save_profile': 'Save Profile',
      'cancel': 'Cancel',
      'role_user': 'User',
      'role_admin': 'Admin',
      'profile_credentials_info':
          'The following fields are bound to your identity provider and cannot be changed.',
      'profile_settings_label': 'Profile Settings',
      'profile_update_success': 'Profile updated successfully!',
      'profile_update_error': 'Failed to update profile.',
      'edit_profile': 'Edit Profile',
      'profile_loading': 'Loading profile...',
      'nav_admin': 'Admin Portal',
      'admin_title': 'Admin Dashboard',
      'admin_desc': 'Monitor and manage supported civic datasets.',
      'search_datasets': 'Search datasets...',
      'filter_status_all': 'All Statuses',
      'filter_status_idle': 'Idle',
      'filter_status_syncing': 'Syncing',
      'filter_status_error': 'Error',
      'dataset_records': 'Records: ',
      'last_sync': 'Last Sync: ',
      'resource_id': 'Resource ID: ',
      'source_agency': 'Source Agency: ',
      'status_label': 'Status: ',
      'telemetry_title': 'System Health & Telemetry',
      'telemetry_tab': 'Telemetry',
      'datasets_tab': 'Datasets',
      'api_reachability': 'API Reachability',
      'api_status_reachable': 'Reachable',
      'api_status_unreachable': 'Unreachable',
      'check_now': 'Check Now',
      'checking': 'Checking...',
      'avg_latency': 'Avg Latency: ',
      'firestore_reads_writes': 'Firestore R/W: ',
      'error_logbook': 'Recent Outages & Errors',
      'no_telemetry': 'No telemetry logs found',
      'latency_sec': 's',
      'runs_title': 'Ingestion Pipelines',
    },
    'he': {
      'app_title': 'בגובה העיניים',
      'mission_title': 'הנגשת מידע ממשלתי לציבור',
      'mission_subtitle':
          'נתונים ממשלתיים יבשים ומורכבים מתורגמים לממשקים נקיים, אינטראקטיביים ומותאמים לנייד.',
      'explore_datasets': 'חקור מאגרי מידע',
      'towers_title': 'אנטנות סלולריות',
      'towers_desc': 'אנטנות פעילות והיתרי קרינה לפי מיקום.',
      'towers_count': '9,840 רשומות',
      'towers_roadmap_title': 'אנטנות סלולריות - בקרוב',
      'towers_roadmap_desc':
          'מסך מאגר נתונים זה נמצא בבנייה. שילובים עתידיים יכללו נתונים חיים ומפות אינטראקטיביות.',
      'towers_active_label': 'אנטנות פעילות',
      'towers_permit_label': 'היתרי הקמה',
      'towers_search_placeholder': 'חפש לפי יישוב או מספר אתר',
      'permit_ref_prefix': 'סימוכין: ',
      'permit_submitted': 'תאריך הגשה: ',
      'permit_locality': 'יישוב: ',
      'permit_operator': 'מפעיל: ',
      'permit_type': 'סוג המוקד: ',
      'permit_badge_pending': 'בבדיקה',
      'permit_badge_approved': 'בהקמה',
      'no_results': 'לא נמצאו רשומות',
      'water_title': 'חברות בפירוק',
      'water_desc': 'חברות ועסקים בהליכי פירוק בבית משפט.',
      'water_count': '3 רשומות',
      'budget_title': 'תקציב המדינה',
      'budget_desc': 'מעקב אחר תקציב המדינה וחלוקת השוק.',
      'budget_count': 'נושא פעיל #101',
      'alerts_title': 'התראות אחרונות',
      'alerts_desc': 'התראות בנושא חריגות ותאימות תקנים.',
      'alerts_count': '2 התראות פעילות',
      'nav_home': 'בית',
      'nav_towers': 'אנטנות',
      'nav_water': 'פירוק חברות',
      'nav_budget': 'תקציב',
      'nav_alerts': 'התראות',
      'nav_directory': 'מדריך מאגרים',
      'directory_title': 'מדריך מאגרי מידע',
      'search_hint': 'חפש מאגרי מידע פתוחים...',
      'open_visualizer': 'פתח תצוגה',
      'request_integration': 'בקש הנגשה',
      'request_success': 'בקשתך נקלטה בהצלחה!',
      'requests_label': 'בקשות: ',
      'publisher_label': 'מפרסם: ',
      'resources_label': ' קבצים',
      'updated_label': 'עודכן: ',
      'liquidation_title': 'חברות בפירוק',
      'liquidation_desc': 'חברות ועסקים בהליכי פירוק בבית משפט.',
      'liquidation_count': '3 רשומות',
      'nav_liquidation': 'פירוק חברות',
      'case_id_label': 'מספר תיק: ',
      'court_label': 'בית משפט: ',
      'city_label': 'עיר פעילות: ',
      'status_active': 'פירוק פעיל',
      'status_frozen': 'הקפאת הליכים',
      'status_closed': 'סגור',
      'closure_reason_prefix': 'סיבת סגירה: ',
      'liquidation_search_placeholder': 'חפש לפי שם או מספר חברה (ח.פ.)',
      'view_court_file': 'צפה בתיק בית המשפט הרשמי',
      'doctors_title': 'רישיונות רופאים',
      'doctors_desc': 'מאגר רישיונות רופאים והתמחויות רפואיות בישראל.',
      'doctors_count': '3 רשומות',
      'nav_doctors': 'רישיונות רופאים',
      'doctors_search_placeholder': 'חפש לפי שם או מספר רישיון',
      'license_num_label': 'מספר רישיון: ',
      'license_date_label': 'תאריך רישום רישיון: ',
      'specialty_cert_label': 'מספר תעודת התמחות: ',
      'specialty_date_label': 'תאריך רישום התמחות: ',
      'doctor_licensed': 'מורשה / פעיל',
      'doctor_unlicensed': 'לא מורשה',
      'doctors_publisher': 'משרד הבריאות - האגף לרישוי מקצועות רפואיים',
      'trustee_publisher': 'משרד המשפטים - רשות התאגידים',
      'filter_all': 'הכל',
      'filter_active': 'נתמכים',
      'filter_inactive': 'בקשות',
      'toggle_lang': 'EN',
      'welcome_back': 'ברוכים הבאים',
      'explore_cta': 'בחר מאגר נתונים למטה כדי להתחיל בהדמיה',
      'badge_active': 'פעיל',
      'badge_roadmap': 'בקרוב',
      'badge_phase2': 'מפת דרכים שלב 2',
      'back_button': 'חזור לבית',
      'attribution_prefix': 'מקור מידע: ',
      'water_roadmap_title': 'מפלס הכנרת - בקרוב',
      'water_roadmap_desc':
          'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב את ה-API הרשמי של רשות המים מ-data.gov.il כדי לספק גרפים אינטראקטיביים של מפלס המים, רמות היסטוריות וניתוח מגמות עונתיות.',
      'budget_roadmap_title': 'תקציב המדינה - בקרוב',
      'budget_roadmap_desc':
          'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב את מאגרי התקציב של משרד האוצר מ-data.gov.il כדי לספק הדמיות אינטראקטיביות של הקצאת התקציב הציבורי, מהירות ההוצאה וחלוקת השוק.',
      'alerts_roadmap_title': 'התראות אחרונות - בקרוב',
      'alerts_roadmap_desc':
          'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב נתוני התראות בזמן אמת מ-data.gov.il ומסוכנויות לאיכות הסביבה כדי לספק התראות, אזהרות תאימות והתראות קרינה/זיהום היסטוריות.',
      'secure_auth': 'אימות מאובטח',
      'sign_in_google': 'התחברות באמצעות Google',
      'sign_up_google': 'הרשמה באמצעות Google',
      'create_account_title': 'הרשמה',
      'create_account_desc':
          'צור חשבון כדי לשמור תצוגות מועדפות, להתאים התראות ולעקוב אחר היתרים',
      'login_desc': 'חשפו את השקיפות של הנתונים האזרחיים',
      'already_have_account': 'כבר יש לך חשבון?',
      'dont_have_account': 'אין לך חשבון?',
      'login_label': 'התחברות',
      'signup_label': 'הרשמה',
      'continue_guest': 'המשך כאורח',
      'ssl_protection': 'מאובטח באמצעות SSL',
      'login_info_text':
          'קבלו גישה מיידית לפירוט הוצאות ממשלתיות והיתרים אזרחיים.',
      'terms_disclaimer':
          'בהמשך השימוש, הינך מסכים לתנאי השירות ומדיניות הפרטיות של בגובה העיניים.',
      'logout_label': 'התנתקות',
      'profile_settings_title': 'הגדרות פרופיל',
      'save': 'שמור',
      'first_name': 'שם פרטי',
      'last_name': 'שם משפחה',
      'email': 'אימייל',
      'user_role': 'תפקיד',
      'save_profile': 'שמור פרופיל',
      'cancel': 'ביטול',
      'role_user': 'משתמש',
      'role_admin': 'מנהל מערכת',
      'profile_credentials_info':
          'השדות הבאים קשורים לספק ההזדהות שלך ואינם ניתנים לשינוי.',
      'profile_settings_label': 'הגדרות פרופיל',
      'profile_update_success': 'הפרופיל עודכן בהצלחה!',
      'profile_update_error': 'עדכון הפרופיל נכשל.',
      'edit_profile': 'ערוך פרופיל',
      'profile_loading': 'טוען פרופיל...',
      'nav_admin': 'פורטל מנהל',
      'admin_title': 'לוח בקרה מנהל',
      'admin_desc': 'מעקב וניהול מאגרי מידע אזרחיים נתמכים.',
      'search_datasets': 'חפש מאגרי מידע...',
      'filter_status_all': 'כל הסטטוסים',
      'filter_status_idle': 'פעיל',
      'filter_status_syncing': 'מסנכרן',
      'filter_status_error': 'שגיאה',
      'dataset_records': 'רשומות: ',
      'last_sync': 'סנכרון אחרון: ',
      'resource_id': 'מזהה משאב: ',
      'source_agency': 'סוכנות מקור: ',
      'status_label': 'סטטוס: ',
      'telemetry_title': 'בריאות המערכת וטלמטריה',
      'telemetry_tab': 'טלמטריה',
      'datasets_tab': 'מאגרים',
      'api_reachability': 'זמינות ה-API',
      'api_status_reachable': 'זמין',
      'api_status_unreachable': 'לא זמין',
      'check_now': 'בדוק כעת',
      'checking': 'בודק...',
      'avg_latency': 'זמן ריצה ממוצע: ',
      'firestore_reads_writes': 'קריאות/כתיבות: ',
      'error_logbook': 'שגיאות ותקלות אחרונות',
      'no_telemetry': 'לא נמצאו נתוני טלמטריה',
      'latency_sec': ' שנ׳',
      'runs_title': 'תהליכי סנכרון',
    },
  };

  /// Translate a key using the current locale
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}

/// A Mock User Profile Repository used in testing and offline environments.
class _MockUserProfileRepository implements UserProfileRepository {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentProfile;

  _MockUserProfileRepository() {
    _currentProfile = UserProfile(
      uid: 'mock_uid',
      firstName: 'Assaf',
      lastName: 'Benzaken',
      email: 'assaf@plainsight.il',
      role: 'user',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
    _controller.add(_currentProfile);
  }

  @override
  Stream<UserProfile?> getUserProfile(String uid) async* {
    yield _currentProfile;
    yield* _controller.stream;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    _currentProfile = profile;
    _controller.add(profile);
  }
}
