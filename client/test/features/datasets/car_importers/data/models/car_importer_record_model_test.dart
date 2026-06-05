import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/car_importers/data/models/car_importer_record_model.dart';

void main() {
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
