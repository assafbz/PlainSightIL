import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/doctors_licenses/data/models/doctor_license_model.dart';

void main() {
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
