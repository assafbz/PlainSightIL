import 'dart:ui';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/directory/data/models/dataset_metadata_model.dart';
import '../../features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';
import '../../features/datasets/doctors_licenses/data/models/doctor_license_model.dart';
import '../../features/datasets/bank_atms/data/models/bank_atm_record_model.dart';
import '../../features/datasets/patent_classifications/data/models/patent_classification_model.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';
import '../../features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';
import '../../features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';
import '../../features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';
import '../../features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';
import '../../features/datasets/patent_classifications/presentation/notifiers/patent_classifications_notifier.dart';
import '../../features/datasets/travel_warnings/data/models/travel_warning_model.dart';
import '../../features/datasets/travel_warnings/presentation/notifiers/travel_warnings_notifier.dart';
import '../../features/admin/presentation/notifiers/telemetry_notifier.dart';
import '../theme/design_system.dart';
import '../utils/app_logger.dart';
import 'local_storage.dart';

/// Central state coordinator that acts as a Facade for the underlying scoped
/// feature notifiers to maintain full backward compatibility across the app UI.
class AppStateNotifier extends ChangeNotifier {
  /// Global indicator if we are running in testing/mock offline mode.
  static bool isTesting = false;

  /// Global override for Firebase initialization state in tests.
  static bool? testIsFirebaseInitialized;

  /// Global custom functions emulator port value.
  static int functionsPort = 5002;

  /// Global indicator if we are using the Firebase local emulators.
  static bool useEmulator = true;

  /// Global indicator of the active environment name.
  static String environment = 'local';

  // Global layout configuration variables
  String _locale = 'en';
  int _activeTab = 0;
  bool _isDarkMode = true;

  // Composed Scoped Notifiers
  late final AuthNotifier authNotifier;
  late final AntennasNotifier antennasNotifier;
  late final PermitsNotifier permitsNotifier;
  late final LiquidationNotifier liquidationNotifier;
  late final DoctorsNotifier doctorsNotifier;
  late final BankAtmsNotifier bankAtmsNotifier;
  late final PatentClassificationsNotifier patentClassificationsNotifier;
  late final TravelWarningsNotifier travelWarningsNotifier;
  late final TelemetryNotifier telemetryNotifier;

  // Configuration Getters
  String get locale => _locale;
  int get activeTab => _activeTab;
  bool get isDarkMode => _isDarkMode;

  // App version loaded dynamically from pubspec.yaml via package_info_plus
  String _appVersion = '';
  String get appVersion => _appVersion;

  // Delegated Getters for AuthNotifier
  User? get currentUser => authNotifier.currentUser;
  bool get isAuthenticated => authNotifier.isAuthenticated;
  bool get isGuestMode => authNotifier.isGuestMode;
  bool get isAdmin => authNotifier.isAdmin;
  List<String> get favorites => authNotifier.favorites;
  List<String> get recents => authNotifier.recents;
  UserProfile? get userProfile => authNotifier.userProfile;
  Map<String, String>? get mockUser => authNotifier.mockUser;
  bool get isFirebaseInitialized => authNotifier.isFirebaseInitialized;

  // Delegated Getters for AntennasNotifier
  List<Map<String, dynamic>> get antennaRecords =>
      antennasNotifier.antennaRecords;
  bool get isLoadingAntennas => antennasNotifier.isLoadingAntennas;

  // Delegated Getters for PermitsNotifier
  List<Map<String, dynamic>> get permitRecords => permitsNotifier.permitRecords;
  bool get isLoadingPermits => permitsNotifier.isLoadingPermits;
  String get permitSyncStatus => permitsNotifier.permitSyncStatus;

  // Delegated Getters for LiquidationNotifier
  List<LiquidationRecordModel> get liquidationRecords =>
      liquidationNotifier.liquidationRecords;
  bool get isLoadingLiquidation => liquidationNotifier.isLoadingLiquidation;

  // Delegated Getters for DoctorsNotifier
  List<DoctorLicenseRecordModel> get doctorRecords =>
      doctorsNotifier.doctorRecords;
  bool get isLoadingDoctors => doctorsNotifier.isLoadingDoctors;

  // Delegated Getters for BankAtmsNotifier
  List<BankAtmRecordModel> get atmRecords => bankAtmsNotifier.atmRecords;
  bool get isLoadingAtms => bankAtmsNotifier.isLoadingAtms;

  // Delegated Getters for PatentClassificationsNotifier
  List<PatentClassificationRecordModel> get patentRecords =>
      patentClassificationsNotifier.patentRecords;
  bool get isLoadingPatents => patentClassificationsNotifier.isLoadingPatents;
  bool get isLoadingMorePatents =>
      patentClassificationsNotifier.isLoadingMorePatents;
  bool get hasMorePatents => patentClassificationsNotifier.hasMorePatents;

  // Delegated Getters for TravelWarningsNotifier
  List<TravelWarningRecordModel> get warningRecords =>
      travelWarningsNotifier.warningRecords;
  bool get isLoadingWarnings => travelWarningsNotifier.isLoadingWarnings;

  // Delegated Getters for TelemetryNotifier
  Map<String, Map<String, dynamic>> get datasetMetadataMap =>
      telemetryNotifier.datasetMetadataMap;
  bool get isLoadingAdminMetadata => telemetryNotifier.isLoadingAdminMetadata;
  Map<String, dynamic> get apiHealth => telemetryNotifier.apiHealth;
  List<Map<String, dynamic>> get scraperRuns => telemetryNotifier.scraperRuns;
  bool get isLoadingTelemetry => telemetryNotifier.isLoadingTelemetry;
  List<DatasetMetadataModel> get directoryRecords =>
      telemetryNotifier.directoryRecords;
  bool get isLoadingDirectory => telemetryNotifier.isLoadingDirectory;
  bool get isCheckingApiHealth => telemetryNotifier.isCheckingApiHealth;

  bool _isDisposed = false;

  /// Construct and initialize the AppStateNotifier Facade.
  AppStateNotifier() {
    AppLogger.info('Initializing AppStateNotifier (isTesting: $isTesting)');
    authNotifier = AuthNotifier(isTesting: isTesting);
    antennasNotifier = AntennasNotifier(isTesting: isTesting);
    permitsNotifier = PermitsNotifier(isTesting: isTesting);
    liquidationNotifier = LiquidationNotifier(isTesting: isTesting);
    doctorsNotifier = DoctorsNotifier(isTesting: isTesting);
    bankAtmsNotifier = BankAtmsNotifier(isTesting: isTesting);
    patentClassificationsNotifier = PatentClassificationsNotifier(
      isTesting: isTesting,
    );
    travelWarningsNotifier = TravelWarningsNotifier(isTesting: isTesting);
    telemetryNotifier = TelemetryNotifier(
      isTesting: isTesting,
      functionsPort: functionsPort,
    );

    // Listen to changes in sub-notifiers and forward notifications safely
    authNotifier.addListener(_onSubNotifierChanged);
    antennasNotifier.addListener(_onSubNotifierChanged);
    permitsNotifier.addListener(_onSubNotifierChanged);
    liquidationNotifier.addListener(_onSubNotifierChanged);
    doctorsNotifier.addListener(_onSubNotifierChanged);
    bankAtmsNotifier.addListener(_onSubNotifierChanged);
    patentClassificationsNotifier.addListener(_onSubNotifierChanged);
    travelWarningsNotifier.addListener(_onSubNotifierChanged);
    telemetryNotifier.addListener(_onSubNotifierChanged);

    _initPackageInfo();
    _loadLocale();
  }

  /// Load the user's saved locale preference from local storage asynchronously.
  Future<void> _loadLocale() async {
    try {
      await LocalStorage.init();
      final savedLocale = LocalStorage.getLocale();
      if (savedLocale == 'en' || savedLocale == 'he') {
        if (_locale != savedLocale) {
          _locale = savedLocale;
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.error('Error loading locale from LocalStorage', e);
    }
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      AppLogger.info('Package version loaded: $_appVersion');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading package info', e);
    }
  }

  void _onSubNotifierChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Legacy initialization method for backwards compatibility
  void initPermitMetadataListener() {
    antennasNotifier.initAntennaListener();
    permitsNotifier.initPermitMetadataListener();
    telemetryNotifier.initAdminMetadataListener();
    telemetryNotifier.initDirectoryListener();
    liquidationNotifier.initLiquidationListener();
    doctorsNotifier.initDoctorsListener();
    bankAtmsNotifier.initBankAtmsListener();
    patentClassificationsNotifier.initPatentClassificationsListener();
    travelWarningsNotifier.initTravelWarningsListener();
  }

  void initAdminMetadataListener() {
    telemetryNotifier.initAdminMetadataListener();
  }

  void initAntennaListener() => antennasNotifier.initAntennaListener();
  void cancelAntennaListener() => antennasNotifier.cancelAntennaListener();

  void initDirectoryListener() => telemetryNotifier.initDirectoryListener();

  void cancelPermitMetadataListener() =>
      permitsNotifier.cancelPermitMetadataListener();

  void initLiquidationListener() =>
      liquidationNotifier.initLiquidationListener();
  void cancelLiquidationListener() =>
      liquidationNotifier.cancelLiquidationListener();

  void initDoctorsListener() => doctorsNotifier.initDoctorsListener();
  void cancelDoctorsListener() => doctorsNotifier.cancelDoctorsListener();

  void initBankAtmsListener() => bankAtmsNotifier.initBankAtmsListener();
  void cancelBankAtmsListener() => bankAtmsNotifier.cancelBankAtmsListener();

  void initPatentClassificationsListener() =>
      patentClassificationsNotifier.initPatentClassificationsListener();
  void cancelPatentClassificationsListener() =>
      patentClassificationsNotifier.cancelPatentClassificationsListener();

  void initTravelWarningsListener() =>
      travelWarningsNotifier.initTravelWarningsListener();
  void cancelTravelWarningsListener() =>
      travelWarningsNotifier.cancelTravelWarningsListener();
  void setPatentSearchQuery(String query) =>
      patentClassificationsNotifier.setSearchQuery(query);
  void setPatentPrimaryFilter(String filter) =>
      patentClassificationsNotifier.setPrimaryFilter(filter);
  void resetPatentFilters() => patentClassificationsNotifier.resetFilters();
  Future<void> fetchNextPatentPage() =>
      patentClassificationsNotifier.fetchNextPage();

  void initTelemetryListeners() => telemetryNotifier.initTelemetryListeners();
  void cancelAdminMetadataListener() =>
      telemetryNotifier.cancelAdminMetadataListener();

  // Delegated Methods for AuthNotifier
  void setMockProfile(UserProfile? profile) =>
      authNotifier.setMockProfile(profile);
  bool isFavorite(String datasetId) => authNotifier.isFavorite(datasetId);
  Future<void> toggleFavorite(String datasetId) =>
      authNotifier.toggleFavorite(datasetId);
  Future<void> addRecent(String datasetId) => authNotifier.addRecent(datasetId);
  Future<void> updateUserProfile(UserProfile profile) =>
      authNotifier.updateUserProfile(profile);
  Future<void> signInWithGoogle() => authNotifier.signInWithGoogle();
  Future<void> signOut() => authNotifier.signOut();
  void setGuestMode(bool enabled) => authNotifier.setGuestMode(enabled);

  // Delegated Methods for TelemetryNotifier
  int getRequestCount(String id) => telemetryNotifier.getRequestCount(id);
  Future<void> triggerApiHealthCheck() =>
      telemetryNotifier.triggerApiHealthCheck();
  Future<bool> requestDatasetActivation(
    String datasetId,
    String datasetTitle,
  ) => telemetryNotifier.requestDatasetActivation(datasetId, datasetTitle);
  Future<Map<String, dynamic>> triggerManualSync(String datasetId) =>
      telemetryNotifier.triggerManualSync(datasetId);

  Future<void> updateDatasetScheduler(
    String datasetId, {
    required bool enabled,
    required int updateIntervalHours,
  }) => telemetryNotifier.updateDatasetScheduler(
    datasetId,
    enabled: enabled,
    updateIntervalHours: updateIntervalHours,
  );

  // Global layout and localization helper methods
  TextDirection get textDirection =>
      _locale == 'he' ? TextDirection.rtl : TextDirection.ltr;

  void setLocale(String newLocale) {
    if (newLocale == 'en' || newLocale == 'he') {
      _locale = newLocale;
      notifyListeners();
      LocalStorage.saveLocale(newLocale);
    }
  }

  void toggleLocale() {
    _locale = _locale == 'en' ? 'he' : 'en';
    notifyListeners();
    LocalStorage.saveLocale(_locale);
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
    _isDisposed = true;
    authNotifier.removeListener(_onSubNotifierChanged);
    antennasNotifier.removeListener(_onSubNotifierChanged);
    permitsNotifier.removeListener(_onSubNotifierChanged);
    liquidationNotifier.removeListener(_onSubNotifierChanged);
    doctorsNotifier.removeListener(_onSubNotifierChanged);
    bankAtmsNotifier.removeListener(_onSubNotifierChanged);
    patentClassificationsNotifier.removeListener(_onSubNotifierChanged);
    travelWarningsNotifier.removeListener(_onSubNotifierChanged);
    telemetryNotifier.removeListener(_onSubNotifierChanged);

    authNotifier.dispose();
    antennasNotifier.dispose();
    permitsNotifier.dispose();
    liquidationNotifier.dispose();
    doctorsNotifier.dispose();
    bankAtmsNotifier.dispose();
    patentClassificationsNotifier.dispose();
    travelWarningsNotifier.dispose();
    telemetryNotifier.dispose();
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
      'antenna_id_prefix': 'ID: ',
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
      'patent_classifications_title': 'Patent Classifications',
      'patent_classifications_desc':
          'CPC Classifications for Patent Applications in Israel.',
      'patent_classifications_count': '~741,000+ records',
      'patent_classifications_search_placeholder':
          'Search by Application Number or Classification',
      'patent_classifications_publisher': 'Israel Patent Office',
      'travel_warnings_title': 'Travel Warnings',
      'travel_warnings_desc': 'Global travel warnings and safety advisories.',
      'travel_warnings_count': 'records',
      'nav_travel_warnings': 'Travel Warnings',
      'travel_warnings_search_placeholder': 'Search by country or continent...',
      'continent_label': 'Continent: ',
      'office_label': 'Office: ',
      'date_label': 'Date: ',
      'travel_warnings_publisher':
          'National Security Council & Ministry of Foreign Affairs',
      'patent_app_num_label': 'Application: #',
      'patent_class_label': 'CPC Classification: ',
      'patent_is_primary': 'Primary Classification',
      'patent_is_secondary': 'Secondary Classification',
      'patent_title_he': 'Title (Hebrew): ',
      'patent_title_en': 'Title (English): ',
      'patent_primary_chip_all': 'All',
      'patent_primary_chip_primary': 'Primary Only',
      'patent_primary_chip_secondary': 'Secondary Only',
      'atm_title': 'Bank ATMs',
      'atm_desc': 'ATM locations across Israel from the Bank of Israel.',
      'atm_search_placeholder': 'Search by city or bank...',
      'atm_publisher': 'Bank of Israel',
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
      'avg_latency': 'Avg Latency: ',
      'firestore_reads_writes': 'Firestore R/W: ',
      'error_logbook': 'Recent Outages & Errors',
      'no_telemetry': 'No telemetry logs found',
      'latency_sec': 's',
      'runs_title': 'Ingestion Pipelines',
      'scheduler_title': 'Scraper Automation Schedule',
      'scheduler_enabled': 'Enable Automated Sync',
      'scheduler_interval': 'Update Interval (Hours)',
      'scheduler_next_run': 'Next Scheduled Run: ',
      'scheduler_save_success': 'Schedule settings updated successfully',
      'scheduler_save_error': 'Failed to update schedule settings',
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
      'antenna_id_prefix': 'מזהה: ',
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
      'patent_classifications_title': 'סיווגי CPC לפטנטים',
      'patent_classifications_desc': 'סיווגי CPC לבקשות פטנט של רשם הפטנטים.',
      'patent_classifications_count': '~741,000+ רשומות',
      'patent_classifications_search_placeholder': 'חפש לפי מספר בקשה או סיווג',
      'patent_classifications_publisher': 'רשות הפטנטים',
      'travel_warnings_title': 'אזהרות מסע',
      'travel_warnings_desc': 'אזהרות מסע והנחיות בטיחות ברחבי העולם.',
      'travel_warnings_count': 'רשומות',
      'nav_travel_warnings': 'אזהרות מסע',
      'travel_warnings_search_placeholder': 'חפש לפי מדינה או יבשת...',
      'continent_label': 'יבשת: ',
      'office_label': 'גוף מפרסם: ',
      'date_label': 'תאריך: ',
      'travel_warnings_publisher': 'המטה לביטחון לאומי ומשרד החוץ',
      'patent_app_num_label': 'מספר בקשה: ',
      'patent_class_label': 'סיווג CPC: ',
      'patent_is_primary': 'סיווג ראשי',
      'patent_is_secondary': 'סיווג משני',
      'patent_title_he': 'שם האמצאה בעברית: ',
      'patent_title_en': 'שם האמצאה באנגלית: ',
      'patent_primary_chip_all': 'הכל',
      'patent_primary_chip_primary': 'ראשי בלבד',
      'patent_primary_chip_secondary': 'משני בלבד',
      'atm_title': 'כספומטים',
      'atm_desc': 'מיקומי כספומטים בנקאיים ברחבי ישראל.',
      'atm_search_placeholder': 'חיפוש לפי עיר או בנק...',
      'atm_publisher': 'בנק ישראל',
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
      'avg_latency': 'זמן ריצה ממוצע: ',
      'firestore_reads_writes': 'קריאות/כתיבות: ',
      'error_logbook': 'שגיאות ותקלות אחרונות',
      'no_telemetry': 'לא נמצאו נתוני טלמטריה',
      'latency_sec': ' שנ׳',
      'runs_title': 'תהליכי סנכרון',
      'scheduler_title': 'תזמון סנכרון אוטומטי',
      'scheduler_enabled': 'אפשר סנכרון אוטומטי',
      'scheduler_interval': 'תדירות עדכון (שעות)',
      'scheduler_next_run': 'ריצה הבאה מתוזמנת: ',
      'scheduler_save_success': 'הגדרות התזמון עודכנו בהצלחה',
      'scheduler_save_error': 'עדכון הגדרות התזמון נכשל',
    },
  };

  /// Translate a key using the current locale.
  String translate(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
