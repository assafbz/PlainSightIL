import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../../features/directory/data/models/dataset_metadata_model.dart';
import '../../features/directory/data/models/liquidation_record_model.dart';

class AppStateNotifier extends ChangeNotifier {
  static bool isTesting = false;

  String _locale = 'en';
  int _activeTab = 0;
  bool _isDarkMode = true;

  // Authentication states
  User? _currentUser;
  bool _isGuestMode = false;
  bool _isMockAuthenticated = false;

  AppStateNotifier() {
    _isMockAuthenticated = isTesting;
    _initAuthListener();
  }

  void _initAuthListener() {
    if (isTesting || !isFirebaseInitialized) return;
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        final bool userChanged = _currentUser?.uid != user?.uid;
        _currentUser = user;
        if (userChanged) {
          // Re-bind Firestore listeners when the authentication state changes
          // to ensure data is fetched under the updated auth credentials.
          initPermitMetadataListener();
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Auth listener init error: $e');
    }
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null || _isMockAuthenticated;
  bool get isGuestMode => _isGuestMode;

  Map<String, String>? get mockUser => _isMockAuthenticated
      ? {'name': 'Assaf Benzaken', 'email': 'assaf@plainsight.il'}
      : null;

  Future<void> signInWithGoogle() async {
    if (isTesting || !isFirebaseInitialized) {
      _isMockAuthenticated = true;
      _isGuestMode = false;
      notifyListeners();
      return;
    }

    try {
      final provider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(provider);
      _isGuestMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _isMockAuthenticated = false;
    _isGuestMode = false;
    _permitRecords = [];
    _antennaRecords = [];
    _directoryRecords = [];
    _isLoadingPermits = true;
    _isLoadingAntennas = true;
    _isLoadingDirectory = true;
    if (isFirebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Firebase Sign-Out Error: $e');
      }
    }
    notifyListeners();
  }

  void setGuestMode(bool enabled) {
    _isGuestMode = enabled;
    if (enabled) {
      initPermitMetadataListener();
    }
    notifyListeners();
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

    if (isTesting) {
      _permitSyncStatus = 'idle';
      _permitRecords = [
        {
          'id': '1',
          'referenceNumber': 2081659,
          'company': {'he': 'סלקום', 'en': 'Cellcom'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'NN1845A',
          'locality': 'אפיקים',
          'addressDescription': 'קיבוץ אפיקים',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'עמק הירדן',
          'coordinates': const GeoPoint(32.6789, 35.5788),
        },
        {
          'id': '2',
          'referenceNumber': 2081660,
          'company': {'he': 'פרטנר', 'en': 'Partner'},
          'permitType': 'היתר הפעלה',
          'siteNumber': 'PT1234B',
          'locality': 'תל אביב - יפו',
          'addressDescription': 'דיזנגוף 100',
          'focalPointType': 'גג',
          'jurisdiction': 'תל אביב',
          'coordinates': const GeoPoint(32.0795, 34.7738),
        },
        {
          'id': '3',
          'referenceNumber': 2081661,
          'company': {'he': 'הוט מובייל', 'en': 'Hot Mobile'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'HT9876C',
          'locality': 'חיפה',
          'addressDescription': 'הרצל 12',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'חיפה',
          'coordinates': const GeoPoint(32.8090, 34.9890),
        },
        {
          'id': '4',
          'referenceNumber': 2081662,
          'company': {'he': 'פלאפון', 'en': 'Pelephone'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'PL4567D',
          'locality': 'ירושלים',
          'addressDescription': 'יפו 50',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'ירושלים',
          'coordinates': const GeoPoint(31.7833, 35.2167),
        },
      ];
      _isLoadingPermits = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _permitSyncStatus = 'error';
      _isLoadingPermits = false;
      notifyListeners();
      debugPrint(
        'Firebase is not initialized. Skipping permit metadata listener.',
      );
      return;
    }

    _permitMetadataSubscription?.cancel();
    try {
      _permitMetadataSubscription = FirebaseFirestore.instance
          .collection('dataset_metadata')
          .doc('cellular_permit_applications')
          .snapshots()
          .listen(
            (metaSnapshot) {
              if (metaSnapshot.exists && metaSnapshot.data() != null) {
                final data = metaSnapshot.data()!;
                final newActive = data['activeCollection'] as String? ?? '';
                _permitSyncStatus = data['status'] as String? ?? 'idle';

                if (newActive.isNotEmpty &&
                    newActive != _activePermitCollection) {
                  _bindActivePermitCollection(newActive);
                } else {
                  notifyListeners();
                }
              } else {
                _isLoadingPermits = false;
                notifyListeners();
              }
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              debugPrint('Firestore permit metadata listener error: $err');
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      debugPrint('Failed to bind Firestore metadata: $e');
    }
  }

  void _bindActivePermitCollection(String newCollection) {
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
              // Swap only when data resolves to prevent flickering
              _permitRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingPermits = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              debugPrint('Firestore permit collection listener error: $err');
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      debugPrint('Failed to bind Firestore collection $newCollection: $e');
    }
  }

  void initAntennaListener() {
    _antennaSubscription?.cancel();
    if (isTesting) {
      _antennaRecords = [
        {
          'antennaId': 'CELL-100',
          'addressHebrew': 'דיזנגוף 50, תל אביב',
          'addressEnglish': 'Dizengoff 50, Tel Aviv',
          'operatorName': 'Pelephone',
          'radiationFrequency': 1800,
          'coordinates': const GeoPoint(32.0782, 34.7741),
        },
        {
          'antennaId': 'CELL-101',
          'addressHebrew': 'בן יהודה 80, תל אביב',
          'addressEnglish': 'Ben Yehuda 80, Tel Aviv',
          'operatorName': 'Partner',
          'radiationFrequency': 3500,
          'coordinates': const GeoPoint(32.0831, 34.7725),
        },
        {
          'antennaId': 'CELL-102',
          'addressHebrew': 'קיבוץ אפיקים, עמק הירדן',
          'addressEnglish': 'Kibbutz Afikim, Jordan Valley',
          'operatorName': 'Cellcom',
          'radiationFrequency': 2100,
          'coordinates': const GeoPoint(32.6795, 35.5792),
        },
        {
          'antennaId': 'CELL-103',
          'addressHebrew': 'שדרות רוטשילד 15, תל אביב',
          'addressEnglish': 'Rothschild Blvd 15, Tel Aviv',
          'operatorName': 'Hot Mobile',
          'radiationFrequency': 1800,
          'coordinates': const GeoPoint(32.0635, 34.7712),
        },
      ];
      _isLoadingAntennas = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingAntennas = false;
      notifyListeners();
      return;
    }

    try {
      _antennaSubscription = FirebaseFirestore.instance
          .collection('cellular_antennas')
          .snapshots()
          .listen(
            (snapshot) {
              _antennaRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingAntennas = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingAntennas = false;
              notifyListeners();
              debugPrint('Firestore antenna collection listener error: $err');
            },
          );
    } catch (e) {
      _isLoadingAntennas = false;
      notifyListeners();
      debugPrint('Failed to bind Firestore antennas: $e');
    }
  }

  void initDirectoryListener() {
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();

    if (isTesting) {
      _directoryRecords = [
        DatasetMetadataModel(
          id: '8935c8e5-ec77-421f-af86-d970583195f8',
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
          name: 'companies_liquidation',
          title: 'חברות בפירוק מרצון או בית משפט',
          notes:
              'רשימת חברות הנמצאות בהליכי פירוק ופירוק שיתוף בבתי המשפט המחוזיים.',
          publisher: 'רשות התאגידים',
          resourceCount: 3,
          lastUpdated: DateTime(2026, 6, 1),
          tags: ['פירוק', 'חברות', 'רשות התאגידים', 'משפט'],
          isSupported: true,
        ),
        DatasetMetadataModel(
          id: 'government-budget-dataset-id',
          name: 'government_budget',
          title: 'ספר התקציב ונתוני הוצאות',
          notes: 'ספר התקציב הפתוח ונתוני ביצוע תקציב הממשלה.',
          publisher: 'משרד האוצר',
          resourceCount: 12,
          lastUpdated: DateTime(2026, 5, 25),
          tags: ['תקציב', 'אוצר', 'הוצאות'],
          isSupported: false,
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
      _directorySubscription = FirebaseFirestore.instance
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
              debugPrint('Firestore directory metadata error: $err');
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
              _datasetRequestCounts = counts;
              notifyListeners();
            },
            onError: (Object err) {
              debugPrint('Firestore dataset requests count error: $err');
            },
          );
    } catch (e) {
      _isLoadingDirectory = false;
      notifyListeners();
      debugPrint('Failed to initialize directory listener: $e');
    }
  }

  void initLiquidationListener() {
    _liquidationSubscription?.cancel();

    if (isTesting) {
      _liquidationRecords = [
        LiquidationRecordModel(
          liquidationCaseId: 12345,
          cityOfActivity: 'תל אביב - יפו',
          caseStatus: const {'he': 'פירוק פעיל', 'en': 'Active Winding Up'},
          submissionDate: '2024-05-12T00:00:00.000Z',
          liquidationOrderDate: '2024-06-15T00:00:00.000Z',
          districtCourt: 'מחוזי תל אביב',
          companyName: 'אלברט לוי הנדסה בע"מ',
          companyId: 512345678,
        ),
        LiquidationRecordModel(
          liquidationCaseId: 12346,
          cityOfActivity: 'חיפה',
          caseStatus: const {'he': 'הקפאת הליכים', 'en': 'Frozen'},
          submissionDate: '2024-03-10T00:00:00.000Z',
          liquidationOrderDate: '2024-04-12T00:00:00.000Z',
          cancellationFreezeDate: '2024-04-20T00:00:00.000Z',
          districtCourt: 'מחוזי חיפה',
          companyName: 'משה שירותי בנייה בע"מ',
          companyId: 512345679,
        ),
        LiquidationRecordModel(
          liquidationCaseId: 12347,
          cityOfActivity: 'ירושלים',
          caseStatus: const {'he': 'סגור', 'en': 'Closed'},
          submissionDate: '2023-08-15T00:00:00.000Z',
          liquidationOrderDate: '2023-09-20T00:00:00.000Z',
          closureDate: '2024-01-10T00:00:00.000Z',
          closureReason: 'הסדר נושים',
          districtCourt: 'מחוזי ירושלים',
          companyName: 'ישראל קומפני בע"מ',
          companyId: 512345680,
        ),
      ];
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    try {
      _liquidationSubscription = FirebaseFirestore.instance
          .collection('companies_liquidation')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              _liquidationRecords = snapshot.docs
                  .map((doc) => LiquidationRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingLiquidation = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingLiquidation = false;
              notifyListeners();
              debugPrint(
                'Firestore liquidation collection listener error: $err',
              );
            },
          );
    } catch (e) {
      _isLoadingLiquidation = false;
      notifyListeners();
      debugPrint('Failed to initialize liquidation listener: $e');
    }
  }

  Future<bool> requestDatasetActivation(
    String datasetId,
    String datasetTitle,
  ) async {
    if (isTesting) {
      _datasetRequestCounts[datasetId] =
          (_datasetRequestCounts[datasetId] ?? 0) + 1;
      notifyListeners();
      return true;
    }

    if (!isFirebaseInitialized) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? uid = user?.uid;
      if (uid == null) {
        final authResult = await FirebaseAuth.instance.signInAnonymously();
        uid = authResult.user?.uid;
      }

      if (uid == null) return false;

      final voteRef = FirebaseFirestore.instance
          .collection('dataset_requests')
          .doc(datasetId)
          .collection('votes')
          .doc(uid);

      final voteSnap = await voteRef.get();
      if (voteSnap.exists) {
        // User already voted for this dataset
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
      debugPrint('Error casting vote for dataset: $e');
      return false;
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
    },
  };

  /// Translate a key using the current locale
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
