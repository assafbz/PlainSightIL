import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';

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
}
