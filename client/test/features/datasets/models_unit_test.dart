import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';
import 'package:plainsight/features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';
import 'package:plainsight/features/datasets/doctors_licenses/data/models/doctor_license_model.dart';
import 'package:plainsight/features/datasets/bank_atms/data/models/bank_atm_record_model.dart';
import 'package:plainsight/features/datasets/car_importers/data/models/car_importer_record_model.dart';

// Stub class representing a Timestamp-like object to cover the contains('Timestamp') check in DatasetMetadataModel
class MockTimestamp {
  final DateTime _date;
  MockTimestamp(this._date);

  DateTime toDate() => _date;

  @override
  String toString() => 'Timestamp(seconds=1779840000, nanoseconds=0)';
}

void main() {
  group('DatasetMetadataModel Tests', () {
    final tDate = DateTime(2026, 5, 30);

    test('fromMap parses safely with String date', () {
      final map = {
        'id': '8935c8e5-ec77-421f-af86-d970583195f8',
        'datasetId': '995eb826-c471-4572-8fd3-39d92a3a9603',
        'name': 'active_antennas',
        'title': 'אנטנות סלולריות פעילות',
        'notes': 'רשימת מוקדי שידור סלולריים פעילים ובדיקות קרינה שנערכו להם.',
        'publisher': 'המשרד להגנת הסביבה',
        'resourceCount': 3,
        'lastUpdated': '2026-05-30T12:00:00.000Z',
        'tags': ['אנטנות', 'סלולר', 'קרינה'],
        'isSupported': true,
      };

      final model = DatasetMetadataModel.fromMap(map);
      expect(model.id, '8935c8e5-ec77-421f-af86-d970583195f8');
      expect(model.lastUpdated.year, 2026);
      expect(model.isSupported, isTrue);
      expect(model.tags.length, 3);
    });

    test('fromMap parses safely with Timestamp-like structure', () {
      final map = {
        'id': '8935c8e5-ec77-421f-af86-d970583195f8',
        'lastUpdated': MockTimestamp(tDate),
      };

      final model = DatasetMetadataModel.fromMap(map);
      expect(model.lastUpdated, tDate);
      expect(model.publisher, 'לא ידוע'); // Falls back to default
    });

    test('fromMap parses safely with null / empty fields', () {
      final map = {
        'id': '8935c8e5-ec77-421f-af86-d970583195f8',
        'lastUpdated': null,
        'tags': null,
      };

      final model = DatasetMetadataModel.fromMap(map);
      expect(model.lastUpdated, isNotNull);
      expect(model.tags, isEmpty);
    });

    test('toMap serializes correctly', () {
      final model = DatasetMetadataModel(
        id: '8935c8e5-ec77-421f-af86-d970583195f8',
        datasetId: '995eb826-c471-4572-8fd3-39d92a3a9603',
        name: 'active_antennas',
        title: 'אנטנות סלולריות פעילות',
        notes: 'רשימת מוקדי שידור סלולריים פעילים',
        publisher: 'המשרד להגנת הסביבה',
        resourceCount: 3,
        sourceCreatedAt: tDate,
        sourceUpdatedAt: tDate,
        createdAt: tDate,
        updatedAt: tDate,
        lastUpdated: tDate,
        tags: ['אנטנות'],
        isSupported: true,
      );

      final map = model.toMap();
      expect(map['id'], '8935c8e5-ec77-421f-af86-d970583195f8');
      expect(map['sourceCreatedAt'], tDate.toIso8601String());
      expect(map['sourceUpdatedAt'], tDate.toIso8601String());
      expect(map['createdAt'], tDate.toIso8601String());
      expect(map['updatedAt'], tDate.toIso8601String());
      expect(map['lastUpdated'], tDate.toIso8601String());
      expect(map['isSupported'], isTrue);
    });
  });

  group('LiquidationRecordModel Tests', () {
    test('fromMap parses safely with Map status', () {
      final map = {
        'liquidationCaseId': 12345,
        'cityOfActivity': 'תל אביב',
        'caseStatus': {'he': 'פירוק פעיל', 'en': 'Active Winding Up'},
        'submissionDate': '2024-05-12T00:00:00.000Z',
        'liquidationOrderDate': '2024-06-15T00:00:00.000Z',
        'districtCourt': 'מחוזי תל אביב',
        'companyName': 'אלברט לוי',
        'companyId': 512345678,
      };

      final model = LiquidationRecordModel.fromMap(map);
      expect(model.liquidationCaseId, 12345);
      expect(model.caseStatus['he'], 'פירוק פעיל');
      expect(model.companyName, 'אלברט לוי');
    });

    test('fromMap parses safely with non-Map status', () {
      final map = {'liquidationCaseId': 12345, 'caseStatus': 'invalid-type'};

      final model = LiquidationRecordModel.fromMap(map);
      expect(model.caseStatus['he'], 'פירוק פעיל'); // Default
    });

    test('toMap serializes correctly', () {
      final model = LiquidationRecordModel(
        liquidationCaseId: 12345,
        cityOfActivity: 'תל אביב',
        caseStatus: {'he': 'פירוק פעיל', 'en': 'Active Winding Up'},
        submissionDate: '2024-05-12T00:00:00.000Z',
        liquidationOrderDate: '2024-06-15T00:00:00.000Z',
        districtCourt: 'מחוזי תל אביב',
        companyName: 'אלברט לוי',
        companyId: 512345678,
        cancellationFreezeDate: '2024-04-20',
        closureDate: '2024-05-20',
        closureReason: 'settlement',
      );

      final map = model.toMap();
      expect(map['liquidationCaseId'], 12345);
      expect(map['cancellationFreezeDate'], '2024-04-20');
      expect(map['closureDate'], '2024-05-20');
      expect(map['closureReason'], 'settlement');
    });
  });

  group('DoctorLicenseRecordModel Tests', () {
    test('fromMap parses safely', () {
      final map = {
        'id': '1',
        '_id': 101,
        'firstName': 'מריו',
        'lastName': 'קורוב',
        'licenseNumber': 4267,
        'licenseRegistrationDate': '1969-07-28T00:00:00.000Z',
        'specialtyCertificateNumber': 7656,
        'specialtyRegistrationDate': '1983-06-21T00:00:00.000Z',
        'specialtyName': 'רפואת ילדים',
      };

      final model = DoctorLicenseRecordModel.fromMap(map);
      expect(model.id, '1');
      expect(model.idNum, 101);
      expect(model.specialtyCertificateNumber, 7656);
      expect(model.specialtyName, 'רפואת ילדים');
    });

    test('toMap serializes correctly', () {
      final model = DoctorLicenseRecordModel(
        id: '1',
        idNum: 101,
        firstName: 'מריו',
        lastName: 'קורוב',
        licenseNumber: 4267,
        licenseRegistrationDate: '1969-07-28T00:00:00.000Z',
        specialtyCertificateNumber: 7656,
        specialtyRegistrationDate: '1983-06-21T00:00:00.000Z',
        specialtyName: 'רפואת ילדים',
      );

      final map = model.toMap();
      expect(map['id'], '1');
      expect(map['_id'], 101);
      expect(map['specialtyCertificateNumber'], 7656);
    });
  });

  group('BankAtmRecordModel Tests', () {
    test('fromMap parses safely with nested map coordinates', () {
      final map = {
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

      final model = BankAtmRecordModel.fromMap(map);
      expect(model.id, '1');
      expect(model.atmNum, 3777);
      expect(model.bankCode, 12);
      expect(model.bankName['he'], 'בנק הפועלים');
      expect(model.bankName['en'], 'Bank Hapoalim');
      expect(model.latitude, 29.555);
      expect(model.longitude, 34.952);
      expect(model.hasCommission, isFalse);
      expect(model.hasCashWithdrawal, isTrue);
    });

    test('fromMap parses safely with GeoPoint object', () {
      final map = {'id': '2', 'coordinates': MockGeoPoint(32.075, 34.774)};

      final model = BankAtmRecordModel.fromMap(map);
      expect(model.id, '2');
      expect(model.latitude, 32.075);
      expect(model.longitude, 34.774);
    });

    test('fromMap parses safely with null / empty fields', () {
      final map = {
        'id': null,
        'coordinates': null,
        'bankName': null,
        'atmLocation': null,
      };

      final model = BankAtmRecordModel.fromMap(map);
      expect(model.id, '');
      expect(model.bankName['he'], '');
      expect(model.atmLocation['en'], '');
      expect(model.latitude, 0.0);
      expect(model.longitude, 0.0);
    });

    test('toMap serializes correctly', () {
      final model = BankAtmRecordModel(
        id: '3',
        atmNum: 9020,
        bankCode: 20,
        bankName: {'he': 'בנק מזרחי', 'en': 'Mizrahi'},
        branchCode: 450,
        address: 'הרצל 32',
        addressExtra: 'הרצל 32',
        city: 'ירושלים',
        atmLocation: {'he': 'במרחק', 'en': 'Within'},
        latitude: 31.778,
        longitude: 35.235,
        geohash: 'svk4p0rn5',
        hasCommission: false,
        hasCashWithdrawal: true,
        hasCashDeposit: true,
        hasChequeDeposit: false,
        hasEnvelopeDeposit: false,
        hasForexTransaction: true,
        hasAdditionalTransactions: false,
        hasHandicapAccess: false,
        sourceCreatedAt: '2026-06-02T09:00:00Z',
        sourceUpdatedAt: '2026-06-02T09:00:00Z',
        createdAt: '2026-06-02T09:00:00Z',
        updatedAt: '2026-06-02T09:00:00Z',
        lastUpdated: '2026-06-02T09:00:00Z',
      );

      final map = model.toMap();
      expect(map['id'], '3');
      expect(map['atmNum'], 9020);
      expect(map['coordinates']['latitude'], 31.778);
      expect(map['coordinates']['longitude'], 35.235);
      expect(map['hasHandicapAccess'], isFalse);
      expect(map['sourceCreatedAt'], '2026-06-02T09:00:00Z');
      expect(map['sourceUpdatedAt'], '2026-06-02T09:00:00Z');
      expect(map['createdAt'], '2026-06-02T09:00:00Z');
      expect(map['updatedAt'], '2026-06-02T09:00:00Z');
      expect(map['lastUpdated'], '2026-06-02T09:00:00Z');
    });
  });

  group('CarImporterRecordModel Tests', () {
    test('fromMap parses safely', () {
      final map = {
        'id': '1',
        '_id': 1,
        'importerCode': 10,
        'importerName': 'קרסו מוטורס בע"מ',
        'modelType': 'P',
        'makerCode': 928,
        'makerName': 'רנו צרפת',
        'modelCode': 1000,
        'modelName': 'C0635P R TWINGO EP',
        'productionYear': 1996,
        'price': 54950,
        'commercialName': 'טווינגו 2.1 YSAE',
      };

      final model = CarImporterRecordModel.fromMap(map);
      expect(model.id, '1');
      expect(model.idNum, 1);
      expect(model.importerName, 'קרסו מוטורס בע"מ');
      expect(model.price, 54950);
    });

    test('toMap serializes correctly', () {
      final model = CarImporterRecordModel(
        id: '2',
        idNum: 2,
        importerCode: 20,
        importerName: 'קרסו',
        modelType: 'P',
        makerCode: 928,
        makerName: 'רנו',
        modelCode: 4060,
        modelName: 'R19',
        productionYear: 1996,
        price: 61990,
        commercialName: '91 NR',
      );

      final map = model.toMap();
      expect(map['id'], '2');
      expect(map['_id'], 2);
      expect(map['importerCode'], 20);
      expect(map['price'], 61990);
    });
  });
}

class MockGeoPoint {
  final double latitude;
  final double longitude;
  MockGeoPoint(this.latitude, this.longitude);
}
