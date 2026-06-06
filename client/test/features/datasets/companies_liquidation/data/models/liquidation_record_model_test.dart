import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/companies_liquidation/data/models/liquidation_record_model.dart';

void main() {
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
}
