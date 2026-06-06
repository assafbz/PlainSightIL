import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/alerts/data/models/alert_model.dart';

void main() {
  group('AlertModel Serialization Tests', () {
    final mockCreatedAt = DateTime.now();

    final testMap = {
      'id': 'alert_1',
      'userId': 'user_1',
      'type': 'new_dataset',
      'title': {'he': 'כותרת', 'en': 'Title'},
      'description': {'he': 'תיאור', 'en': 'Description'},
      'datasetId': 'dataset_1',
      'recordCount': 100,
      'isRead': false,
      'createdAt': mockCreatedAt.toIso8601String(),
    };

    test('fromMap parses map structure correctly', () {
      final alert = AlertModel.fromMap(testMap, 'alert_1');

      expect(alert.id, 'alert_1');
      expect(alert.userId, 'user_1');
      expect(alert.type, 'new_dataset');
      expect(alert.title['he'], 'כותרת');
      expect(alert.title['en'], 'Title');
      expect(alert.description['he'], 'תיאור');
      expect(alert.description['en'], 'Description');
      expect(alert.datasetId, 'dataset_1');
      expect(alert.recordCount, 100);
      expect(alert.isRead, false);
      expect(
        alert.createdAt.isAtSameMomentAs(
          DateTime.parse(mockCreatedAt.toIso8601String()),
        ),
        true,
      );
    });

    test('toMap serializes AlertModel correctly', () {
      final alert = AlertModel(
        id: 'alert_1',
        userId: 'user_1',
        type: 'new_dataset',
        title: const {'he': 'כותרת', 'en': 'Title'},
        description: const {'he': 'תיאור', 'en': 'Description'},
        datasetId: 'dataset_1',
        recordCount: 100,
        isRead: false,
        createdAt: mockCreatedAt,
      );

      final map = alert.toMap();

      expect(map['id'], 'alert_1');
      expect(map['userId'], 'user_1');
      expect(map['type'], 'new_dataset');
      expect(map['title']['he'], 'כותרת');
      expect(map['title']['en'], 'Title');
      expect(map['description']['he'], 'תיאור');
      expect(map['description']['en'], 'Description');
      expect(map['datasetId'], 'dataset_1');
      expect(map['recordCount'], 100);
      expect(map['isRead'], false);
      expect(map['createdAt'], mockCreatedAt.toIso8601String());
    });
  });
}
