import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../../features/directory/data/models/dataset_metadata_model.dart';

class AppStateNotifier extends ChangeNotifier {
  static bool isTesting = true;

  String _locale = 'en';
  int _activeTab = 0;
  bool _isDarkMode = true;

  // Double-buffered Firestore subscriptions for permit applications
  String _activePermitCollection = '';
  List<Map<String, dynamic>> _permitRecords = [];
  bool _isLoadingPermits = true;
  String _permitSyncStatus = 'idle';
  StreamSubscription<QuerySnapshot>? _permitSubscription;

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

    try {
      FirebaseFirestore.instance
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
          id: 'water-level-dataset-id',
          name: 'kinneret_water_level',
          title: 'מפלס הכנרת ונתוני הידרולוגיה',
          notes: 'מפלס הכנרת היומי ונתוני שפיעת מעיינות הידרולוגיים.',
          publisher: 'רשות המים',
          resourceCount: 2,
          lastUpdated: DateTime(2026, 5, 28),
          tags: ['כנרת', 'מים', 'מפלס'],
          isSupported: false,
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
      _datasetRequestCounts = {
        'water-level-dataset-id': 42,
        'government-budget-dataset-id': 18,
      };
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
    _antennaSubscription?.cancel();
    _directorySubscription?.cancel();
    _requestsSubscription?.cancel();
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
      'water_title': 'Kinneret Water Level',
      'water_desc': 'Real-time water levels and seasonal metrics.',
      'water_count': 'Daily updates',
      'budget_title': 'Government Budget',
      'budget_desc': 'Public budget tracking and market distribution.',
      'budget_count': 'Active issue #101',
      'alerts_title': 'Recent Alerts',
      'alerts_desc': 'Notifications and compliance warnings.',
      'alerts_count': '2 active alerts',
      'nav_home': 'Home',
      'nav_towers': 'Towers',
      'nav_water': 'Water',
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
      'water_title': 'מפלס הכנרת',
      'water_desc': 'מדדי מפלס מים בזמן אמת ומדדים עונתיים.',
      'water_count': 'עדכון יומי',
      'budget_title': 'תקציב המדינה',
      'budget_desc': 'מעקב אחר תקציב המדינה וחלוקת השוק.',
      'budget_count': 'נושא פעיל #101',
      'alerts_title': 'התראות אחרונות',
      'alerts_desc': 'התראות בנושא חריגות ותאימות תקנים.',
      'alerts_count': '2 התראות פעילות',
      'nav_home': 'בית',
      'nav_towers': 'אנטנות',
      'nav_water': 'כנרת',
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
    },
  };

  /// Translate a key using the current locale
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
