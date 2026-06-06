import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/bank_atms/data/models/bank_atm_record_model.dart';

void main() {
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
        lastUpdated: '2026-06-02T09:00:00Z',
        createdAt: '2026-06-02T09:00:00Z',
      );

      final map = model.toMap();
      expect(map['id'], '3');
      expect(map['atmNum'], 9020);
      expect(map['coordinates']['latitude'], 31.778);
      expect(map['coordinates']['longitude'], 35.235);
      expect(map['hasHandicapAccess'], isFalse);
      expect(map['lastUpdated'], '2026-06-02T09:00:00Z');
      expect(map['createdAt'], '2026-06-02T09:00:00Z');
    });
  });
}

class MockGeoPoint {
  final double latitude;
  final double longitude;
  MockGeoPoint(this.latitude, this.longitude);
}
