import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/travel_warnings/data/models/travel_warning_model.dart';

void main() {
  group('TravelWarningRecordModel Tests', () {
    test('fromMap parses raw firestore map successfully', () {
      final map = {
        'id': '123',
        '_id': 123,
        'continent': 'אפריקה',
        'country': 'אוגנדה',
        'recommendations': 'רמה 2/ איום מזדמן',
        'details': 'פרטים',
        'logo': 'לוגו',
        'date': '2026-06-03T00:00:00Z',
        'office': 'מל"ל',
        'warningLevel': 2,
        'createdAt': '2026-06-03T00:00:00Z',
        'updatedAt': '2026-06-03T00:00:00Z',
        'lastUpdated': '2026-06-03T00:00:00Z',
      };

      final model = TravelWarningRecordModel.fromMap(map);

      expect(model.id, '123');
      expect(model.idNum, 123);
      expect(model.continent, 'אפריקה');
      expect(model.country, 'אוגנדה');
      expect(model.recommendations, 'רמה 2/ איום מזדמן');
      expect(model.details, 'פרטים');
      expect(model.logo, 'לוגו');
      expect(model.date, '2026-06-03T00:00:00Z');
      expect(model.office, 'מל"ל');
      expect(model.warningLevel, 2);
      expect(model.createdAt, '2026-06-03T00:00:00Z');
      expect(model.updatedAt, '2026-06-03T00:00:00Z');
      expect(model.lastUpdated, '2026-06-03T00:00:00Z');
    });

    test('toMap converts model to map successfully', () {
      final model = TravelWarningRecordModel(
        id: '123',
        idNum: 123,
        continent: 'אפריקה',
        country: 'אוגנדה',
        recommendations: 'רמה 2/ איום מזדמן',
        details: 'פרטים',
        logo: 'לוגו',
        date: '2026-06-03T00:00:00Z',
        office: 'מל"ל',
        warningLevel: 2,
        createdAt: '2026-06-03T00:00:00Z',
        updatedAt: '2026-06-03T00:00:00Z',
        lastUpdated: '2026-06-03T00:00:00Z',
      );

      final map = model.toMap();

      expect(map['id'], '123');
      expect(map['_id'], 123);
      expect(map['continent'], 'אפריקה');
      expect(map['country'], 'אוגנדה');
      expect(map['recommendations'], 'רמה 2/ איום מזדמן');
      expect(map['details'], 'פרטים');
      expect(map['logo'], 'לוגו');
      expect(map['date'], '2026-06-03T00:00:00Z');
      expect(map['office'], 'מל"ל');
      expect(map['warningLevel'], 2);
      expect(map['createdAt'], '2026-06-03T00:00:00Z');
      expect(map['updatedAt'], '2026-06-03T00:00:00Z');
      expect(map['lastUpdated'], '2026-06-03T00:00:00Z');
    });
  });
}
