import 'package:cloud_firestore/cloud_firestore.dart';
import 'dataset_ids.dart';
import '../../features/directory/data/models/dataset_metadata_model.dart';
import '../../features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';
import '../../features/datasets/doctors_licenses/data/models/doctor_license_model.dart';
import '../../features/datasets/patent_classifications/data/models/patent_classification_model.dart';
import '../../features/profile/domain/entities/user_profile.dart';

/// Central repository of mock data loaded during offline or testing modes.
class MockData {
  /// Mock user profile configuration.
  static final UserProfile userProfile = UserProfile(
    uid: 'mock_uid',
    firstName: 'Assaf',
    lastName: 'Benzaken',
    email: 'assaf@plainsight.il',
    role: 'user',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  /// Mock user details map.
  static const Map<String, String> userMap = {
    'name': 'Assaf Benzaken',
    'email': 'assaf@plainsight.il',
  };

  /// Mock cellular permits dataset records.
  static final List<Map<String, dynamic>> permits = [
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

  /// Mock cellular antennas records.
  static final List<Map<String, dynamic>> antennas = [
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

  /// Mock catalog directory records.
  static final List<DatasetMetadataModel> directory = [
    DatasetMetadataModel(
      id: DatasetIds.cellularAntennas,
      datasetId: '995eb826-c471-4572-8fd3-39d92a3a9603',
      name: 'active_antennas',
      title: 'אנטנות סלולריות פעילות',
      notes: 'רשימת מוקדי שידור סלולריים פעילים ובדיקות קרינה שנערכו להם.',
      publisher: 'המשרד להגנת הסביבה',
      resourceCount: 3,
      lastUpdated: DateTime(2026, 5, 30),
      tags: const ['אנטנות', 'סלולר', 'קרינה'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: DatasetIds.cellularPermits,
      datasetId: '4e9111d8-e842-40ec-b587-629e684e85ac',
      name: 'cellular_permit_applications',
      title: 'בקשות להיתרי הקמה של אנטנות',
      notes: 'היתרי הקמה והפעלה למוקדי שידור סלולריים הנמצאים בהליכי אישור.',
      publisher: 'המשרד להגנת הסביבה',
      resourceCount: 1,
      lastUpdated: DateTime(2026, 5, 29),
      tags: const ['היתרים', 'הקמה', 'סלולר'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: DatasetIds.companiesLiquidation,
      datasetId: '6d8bf87d-bd13-4df6-9846-d449f407b318',
      name: 'pr2018',
      title: 'חברות בפירוק',
      notes:
          'רשימת חברות הנמצאות בהליכי פירוק ופירוק שיתוף בבתי המשפט המחוזיים.',
      publisher: 'רשות התאגידים',
      resourceCount: 3,
      lastUpdated: DateTime(2026, 6, 1),
      tags: const ['פירוק', 'חברות', 'רשות התאגידים', 'משפט'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: DatasetIds.doctorsLicenses,
      datasetId: DatasetIds.doctorsLicenses,
      name: 'doctors_licenses',
      title: 'רישיונות רופאים',
      notes: 'מאגר מורשי תעסוקה ברפואה בישראל כולל מספרי רישיון והתמחויות.',
      publisher: 'משרד הבריאות',
      resourceCount: 1,
      lastUpdated: DateTime(2026, 6, 2),
      tags: const ['רופאים', 'רישיון', 'בריאות', 'התמחות'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: DatasetIds.patentClassifications,
      datasetId: DatasetIds.patentClassifications,
      name: 'patent_classifications',
      title: 'סיווגי CPC לפטנטים',
      notes: 'מאגר סיווגי CPC (סיווג פטנטים משותף) לבקשות פטנט של רשם הפטנטים.',
      publisher: 'רשות הפטנטים',
      resourceCount: 1,
      lastUpdated: DateTime(2026, 6, 3),
      tags: const ['פטנטים', 'סיווג', 'חדשנות', 'CPC'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: DatasetIds.travelWarnings,
      datasetId: DatasetIds.travelWarnings,
      name: 'travel_warnings',
      title: 'אזהרות מסע',
      notes: 'אזהרות מסע והנחיות בטיחות מטעם המל"ל ומשרד החוץ.',
      publisher: 'המטה לביטחון לאומי',
      resourceCount: 1,
      lastUpdated: DateTime(2026, 6, 3),
      tags: const ['אזהרות', 'בטחון', 'נסיעות', 'חו"ל'],
      isSupported: true,
    ),
    DatasetMetadataModel(
      id: 'government-budget-dataset-id',
      datasetId: 'government-budget-dataset-id',
      name: 'government_budget',
      title: 'ספר התקציב ונתוני הוצאות',
      notes: 'ספר התקציב הפתוח ונתוני ביצוע תקציב הממשלה.',
      publisher: 'משרד האוצר',
      resourceCount: 12,
      lastUpdated: DateTime(2026, 5, 25),
      tags: const ['תקציב', 'אוצר', 'הוצאות'],
      isSupported: false,
    ),
  ];

  /// Mock request counts.
  static const Map<String, int> datasetRequestCounts = {
    'government-budget-dataset-id': 18,
  };

  /// Mock companies liquidation records.
  static final List<LiquidationRecordModel> liquidations = [
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

  /// Mock doctors licenses records.
  static final List<DoctorLicenseRecordModel> doctors = [
    DoctorLicenseRecordModel(
      id: '1',
      idNum: 1,
      firstName: 'מריו ה',
      lastName: 'קורוב',
      licenseNumber: 4267,
      licenseRegistrationDate: '1969-07-28T00:00:00.000Z',
    ),
    DoctorLicenseRecordModel(
      id: '2',
      idNum: 2,
      firstName: 'אברהם',
      lastName: 'שטיינברג',
      licenseNumber: 11116,
      licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
      specialtyCertificateNumber: 7656,
      specialtyRegistrationDate: '1983-06-21T00:00:00.000Z',
      specialtyName: 'רפואת ילדים',
    ),
    DoctorLicenseRecordModel(
      id: '3',
      idNum: 3,
      firstName: 'אברהם',
      lastName: 'שטיינברג',
      licenseNumber: 11116,
      licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
      specialtyCertificateNumber: 13230,
      specialtyRegistrationDate: '1993-12-02T00:00:00.000Z',
      specialtyName: 'נוירולוגיית ילדים',
    ),
  ];

  /// Mock dataset metadata map.
  static final Map<String, Map<String, dynamic>> datasetMetadata = {
    DatasetIds.cellularAntennas: {
      'id': DatasetIds.cellularAntennas,
      'recordCount': 9840,
      'lastUpdated': '2026-05-30T12:00:00Z',
      'status': 'idle',
    },
    DatasetIds.cellularPermits: {
      'id': DatasetIds.cellularPermits,
      'recordCount': 120,
      'lastUpdated': '2026-05-29T14:30:00Z',
      'status': 'idle',
    },
    DatasetIds.companiesLiquidation: {
      'id': DatasetIds.companiesLiquidation,
      'recordCount': 3,
      'lastUpdated': '2026-06-01T09:15:00Z',
      'status': 'idle',
    },
    DatasetIds.doctorsLicenses: {
      'id': DatasetIds.doctorsLicenses,
      'recordCount': 100,
      'lastUpdated': '2026-06-02T17:00:00Z',
      'status': 'idle',
    },
    DatasetIds.patentClassifications: {
      'id': DatasetIds.patentClassifications,
      'recordCount': 200,
      'lastUpdated': '2026-06-03T18:00:00Z',
      'status': 'idle',
    },
    DatasetIds.travelWarnings: {
      'id': DatasetIds.travelWarnings,
      'recordCount': 197,
      'lastUpdated': '2026-06-03T19:00:00Z',
      'status': 'idle',
    },
  };

  /// Mock API health telemetry.
  static final Map<String, dynamic> apiHealth = {
    'url': 'https://data.gov.il',
    'isReachable': true,
    'statusCode': 200,
    'latencyMs': 142,
    'lastChecked': DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toIso8601String(),
  };

  /// Mock scraper runs history.
  static final List<Map<String, dynamic>> scraperRuns = [
    {
      'datasetId': DatasetIds.cellularAntennas,
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
      'datasetId': DatasetIds.companiesLiquidation,
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
      'datasetId': DatasetIds.doctorsLicenses,
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
    {
      'datasetId': 'datasets_metadata',
      'startTime': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
      'endTime': DateTime.now()
          .subtract(const Duration(hours: 3, seconds: 12))
          .toIso8601String(),
      'durationMs': 12500,
      'status': 'success',
      'recordsProcessed': 1250,
      'firestoreReadsEstimate': 0,
      'firestoreWritesEstimate': 1250,
      'errorMessage': '',
      'errorStack': '',
    },
    {
      'datasetId': DatasetIds.cellularAntennas,
      'startTime': DateTime.now()
          .subtract(const Duration(hours: 4))
          .toIso8601String(),
      'endTime': DateTime.now()
          .subtract(const Duration(hours: 4, seconds: 4))
          .toIso8601String(),
      'durationMs': 3800,
      'status': 'error',
      'recordsProcessed': 0,
      'firestoreReadsEstimate': 0,
      'firestoreWritesEstimate': 0,
      'errorMessage': 'manualSyncAntennas: 502 Bad Gateway',
      'errorStack':
          'Error: 502 Bad Gateway\n    at scrapeAndSyncAntennas (/src/scrapers/antennas.ts:269:13)\n    at processTicksAndRejections (node:internal/process/task_queues:95:5)',
    },
  ];

  /// Mock patent classifications records.
  static final List<PatentClassificationRecordModel> patents = [
    PatentClassificationRecordModel(
      id: '741210',
      idNum: 741210,
      applicationNumber: 327015,
      titleHebrew: 'שילוב תרופות הכולל תצמיד נוגדן',
      titleEnglish: 'DRUG COMBINATION COMPRISING ANTIBODY',
      cpcClassification: 'A61P35/00',
      isPrimary: true,
      lastUpdated: '2026-06-03T18:00:00Z',
      createdAt: '2026-06-03T18:00:00Z',
    ),
    PatentClassificationRecordModel(
      id: '741209',
      idNum: 741209,
      applicationNumber: 326672,
      titleHebrew: 'תכשירים לטיפול בדלקת מפרקים',
      titleEnglish: 'COMPOSITIONS FOR THE TREATMENT OF ARTHRITIS',
      cpcClassification: 'C22C19/05',
      isPrimary: false,
      lastUpdated: '2026-06-03T18:00:00Z',
      createdAt: '2026-06-03T18:00:00Z',
    ),
    PatentClassificationRecordModel(
      id: '741208',
      idNum: 741208,
      applicationNumber: 325432,
      titleHebrew: 'מערכת חיישנים אופטיים',
      titleEnglish: 'OPTICAL SENSOR SYSTEM',
      cpcClassification: 'G01N21/00',
      isPrimary: true,
      lastUpdated: '2026-06-03T18:00:00Z',
      createdAt: '2026-06-03T18:00:00Z',
    ),
  ];
}
