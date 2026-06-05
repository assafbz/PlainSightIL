import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/data/models/vehicle_recall_model.dart';

void main() {
  group('VehicleRecallRecordModel Tests', () {
    test('fromMap parses safely with all fields', () {
      final map = {
        'id': '11020',
        '_id': 1,
        'recallId': 11020,
        'manufacturerCode': 1,
        'manufacturerName': 'TOYOTA',
        'modelName': 'AVENSIS',
        'recallYear': 2011,
        'buildStartDate': '2000-01-02T00:00:00Z',
        'buildEndDate': '2008-12-31T00:00:00Z',
        'recallType': {'he': 'תקלה סידרתית בטיחותית', 'en': 'Safety Recall'},
        'defectCategory': 'מנוע ומערכותיו',
        'defectDescription': 'שסתום צינור דלק',
        'repairAction': 'החלפה',
        'euCategory': 'M1',
        'importerName': 'יוניון מוטורס',
        'importerPhone': '1-800-22-1514',
        'importerWebsite': 'WWW.TOYOTA.CO.IL',
        'createdAt': '2026-06-05T12:00:00Z',
        'updatedAt': '2026-06-05T12:00:00Z',
        'lastUpdated': '2026-06-05T12:00:00Z',
      };

      final model = VehicleRecallRecordModel.fromMap(map);
      expect(model.id, '11020');
      expect(model.idNum, 1);
      expect(model.recallId, 11020);
      expect(model.manufacturerName, 'TOYOTA');
      expect(model.modelName, 'AVENSIS');
      expect(model.recallType['he'], 'תקלה סידרתית בטיחותית');
      expect(model.recallType['en'], 'Safety Recall');
    });

    test('fromMap parses safely with non-map recallType', () {
      final map = {'id': '11020', 'recallType': 'invalid-type'};

      final model = VehicleRecallRecordModel.fromMap(map);
      expect(model.recallType['he'], 'תקלה סידרתית בטיחותית');
      expect(model.recallType['en'], 'Safety Recall');
    });

    test('toMap serializes correctly', () {
      final model = VehicleRecallRecordModel(
        id: '11020',
        idNum: 1,
        recallId: 11020,
        manufacturerCode: 1,
        manufacturerName: 'TOYOTA',
        modelName: 'AVENSIS',
        recallYear: 2011,
        buildStartDate: '2000-01-02T00:00:00Z',
        buildEndDate: '2008-12-31T00:00:00Z',
        recallType: {'he': 'תקלה סידרתית בטיחותית', 'en': 'Safety Recall'},
        defectCategory: 'מנוע ומערכותיו',
        defectDescription: 'שסתום צינור דלק',
        repairAction: 'החלפה',
        euCategory: 'M1',
        importerName: 'יוניון מוטורס',
        importerPhone: '1-800-22-1514',
        importerWebsite: 'WWW.TOYOTA.CO.IL',
        createdAt: '2026-06-05T12:00:00Z',
        updatedAt: '2026-06-05T12:00:00Z',
        lastUpdated: '2026-06-05T12:00:00Z',
      );

      final map = model.toMap();
      expect(map['id'], '11020');
      expect(map['_id'], 1);
      expect(map['recallId'], 11020);
      expect(map['manufacturerName'], 'TOYOTA');
      expect(map['recallType']['en'], 'Safety Recall');
    });
  });
}
