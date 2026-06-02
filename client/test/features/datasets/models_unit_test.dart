import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';
import 'package:plainsight/features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';
import 'package:plainsight/features/datasets/doctors_licenses/data/models/doctor_license_model.dart';

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
        lastUpdated: tDate,
        tags: ['אנטנות'],
        isSupported: true,
      );

      final map = model.toMap();
      expect(map['id'], '8935c8e5-ec77-421f-af86-d970583195f8');
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
      final map = {
        'liquidationCaseId': 12345,
        'caseStatus': 'invalid-type',
      };

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
}
