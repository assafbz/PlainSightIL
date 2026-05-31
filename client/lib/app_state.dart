import 'package:flutter/material.dart';

class AppStateNotifier extends ChangeNotifier {
  String _locale = 'en';
  int _activeTab = 0;

  String get locale => _locale;
  int get activeTab => _activeTab;

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
    },
    'he': {
      'app_title': 'PlainSight IL',
      'mission_title': 'הנגשת מידע ממשלתי לציבור',
      'mission_subtitle':
          'נתונים ממשלתיים יבשים ומורכבים מתורגמים לממשקים נקיים, אינטראקטיביים ומותאמים לנייד.',
      'explore_datasets': 'חקור מאגרי מידע',
      'towers_title': 'אנטנות סלולריות',
      'towers_desc': 'אנטנות פעילות והיתרי קרינה לפי מיקום.',
      'towers_count': '9,840 רשומות',
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
    }
  };

  /// Translate a key using the current locale
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
