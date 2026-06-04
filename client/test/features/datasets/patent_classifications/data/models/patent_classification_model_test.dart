import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/patent_classifications/data/models/patent_classification_model.dart';

void main() {
  group('PatentClassificationRecordModel Tests', () {
    test('fromMap parses safely', () {
      final map = {
        'id': '741210',
        '_id': 741210,
        'applicationNumber': 327015,
        'titleHebrew': 'שילוב תרופות',
        'titleEnglish': 'DRUG COMBINATION',
        'cpcClassification': 'A61P35/00',
        'isPrimary': true,
        'createdAt': '2026-06-03T18:00:00Z',
        'updatedAt': '2026-06-03T18:00:00Z',
        'lastUpdated': '2026-06-03T18:00:00Z',
      };

      final model = PatentClassificationRecordModel.fromMap(map);
      expect(model.id, '741210');
      expect(model.idNum, 741210);
      expect(model.applicationNumber, 327015);
      expect(model.titleHebrew, 'שילוב תרופות');
      expect(model.titleEnglish, 'DRUG COMBINATION');
      expect(model.cpcClassification, 'A61P35/00');
      expect(model.isPrimary, isTrue);
    });

    test('toMap serializes correctly', () {
      final model = PatentClassificationRecordModel(
        id: '741210',
        idNum: 741210,
        applicationNumber: 327015,
        titleHebrew: 'שילוב תרופות',
        titleEnglish: 'DRUG COMBINATION',
        cpcClassification: 'A61P35/00',
        isPrimary: true,
        createdAt: '2026-06-03T18:00:00Z',
        updatedAt: '2026-06-03T18:00:00Z',
        lastUpdated: '2026-06-03T18:00:00Z',
      );

      final map = model.toMap();
      expect(map['id'], '741210');
      expect(map['_id'], 741210);
      expect(map['applicationNumber'], 327015);
      expect(map['isPrimary'], isTrue);
    });
  });
}
