import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class AppStateNotifier extends ChangeNotifier {
  String _locale = 'en';
  int _activeTab = 0;
  bool _isDarkMode = true;

  // Double-buffered Firestore subscriptions for permit applications
  String _activePermitCollection = '';
  List<Map<String, dynamic>> _permitRecords = [];
  bool _isLoadingPermits = true;
  String _permitSyncStatus = 'idle';
  StreamSubscription<QuerySnapshot>? _permitSubscription;

  String get locale => _locale;
  int get activeTab => _activeTab;
  bool get isDarkMode => _isDarkMode;

  List<Map<String, dynamic>> get permitRecords => _permitRecords;
  bool get isLoadingPermits => _isLoadingPermits;
  String get permitSyncStatus => _permitSyncStatus;

  /// Initialize metadata listener for cellular permits
  void initPermitMetadataListener() {
    FirebaseFirestore.instance
        .collection('dataset_metadata')
        .doc('cellular_permit_applications')
        .snapshots()
        .listen((metaSnapshot) {
      if (metaSnapshot.exists && metaSnapshot.data() != null) {
        final data = metaSnapshot.data()!;
        final newActive = data['activeCollection'] as String? ?? '';
        _permitSyncStatus = data['status'] as String? ?? 'idle';

        if (newActive.isNotEmpty && newActive != _activePermitCollection) {
          _bindActivePermitCollection(newActive);
        } else {
          notifyListeners();
        }
      } else {
        _isLoadingPermits = false;
        notifyListeners();
      }
    }, onError: (err) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
    });
  }

  void _bindActivePermitCollection(String newCollection) {
    _activePermitCollection = newCollection;
    _isLoadingPermits = true;
    notifyListeners();

    _permitSubscription?.cancel();
    _permitSubscription = FirebaseFirestore.instance
        .collection(newCollection)
        .snapshots()
        .listen((snapshot) {
      // Swap only when data resolves to prevent flickering
      _permitRecords = snapshot.docs
          .map((doc) => doc.data())
          .toList();
      _isLoadingPermits = false;
      notifyListeners();
    }, onError: (err) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
    });
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
      'towers_roadmap_desc': 'This dataset screen is under construction. Future integrations will include live data and interactive maps.',
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
      'toggle_lang': 'HE',
      'welcome_back': 'Welcome Back',
      'explore_cta': 'Select a dataset below to begin visualization',
      'badge_active': 'Active',
      'badge_roadmap': 'Roadmap',
      'badge_phase2': 'Phase 2 Roadmap',
      'back_button': 'Back to Home',
      'attribution_prefix': 'Data Source: ',
      'water_roadmap_title': 'Kinneret Telemetry Coming Soon',
      'water_roadmap_desc': 'This dataset is part of the Phase 2 roadmap. We plan to integrate the official Water Authority API from data.gov.il to provide interactive water line charts, historical levels, and seasonal trend analysis.',
      'budget_roadmap_title': 'Budget Analysis Coming Soon',
      'budget_roadmap_desc': 'This dataset is part of the Phase 2 roadmap. We plan to integrate the Ministry of Finance budget datasets from data.gov.il to provide interactive visualizations of public budget allocation, spending speed, and market distribution.',
      'alerts_roadmap_title': 'Alert Telemetry Coming Soon',
      'alerts_roadmap_desc': 'This dataset is part of the Phase 2 roadmap. We plan to integrate real-time alert data from data.gov.il and environmental agencies to provide notifications, compliance warnings, and historical radiation/pollution alerts.',
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
      'towers_roadmap_desc': 'מסך מאגר נתונים זה נמצא בבנייה. שילובים עתידיים יכללו נתונים חיים ומפות אינטראקטיביות.',
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
      'toggle_lang': 'EN',
      'welcome_back': 'ברוכים הבאים',
      'explore_cta': 'בחר מאגר נתונים למטה כדי להתחיל בהדמיה',
      'badge_active': 'פעיל',
      'badge_roadmap': 'בקרוב',
      'badge_phase2': 'מפת דרכים שלב 2',
      'back_button': 'חזור לבית',
      'attribution_prefix': 'מקור מידע: ',
      'water_roadmap_title': 'מפלס הכנרת - בקרוב',
      'water_roadmap_desc': 'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב את ה-API הרשמי של רשות המים מ-data.gov.il כדי לספק גרפים אינטראקטיביים של מפלס המים, רמות היסטוריות וניתוח מגמות עונתיות.',
      'budget_roadmap_title': 'תקציב המדינה - בקרוב',
      'budget_roadmap_desc': 'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב את מאגרי התקציב של משרד האוצר מ-data.gov.il כדי לספק הדמיות אינטראקטיביות של הקצאת התקציב הציבורי, מהירות ההוצאה וחלוקת השוק.',
      'alerts_roadmap_title': 'התראות אחרונות - בקרוב',
      'alerts_roadmap_desc': 'מאגר נתונים זה הוא חלק ממפת הדרכים לשלב 2. אנו מתכננים לשלב נתוני התראות בזמן אמת מ-data.gov.il ומסוכנויות לאיכות הסביבה כדי לספק התראות, אזהרות תאימות והתראות קרינה/זיהום היסטוריות.',
    }
  };

  /// Translate a key using the current locale
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
