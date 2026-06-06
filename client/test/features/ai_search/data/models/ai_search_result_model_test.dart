import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/ai_search/data/models/ai_search_result_model.dart';

void main() {
  group('AiSearchResultModel Tests', () {
    test('fromJson and toJson match', () {
      final json = {
        'answer': 'This is a test answer with [cit-01].',
        'citations': [
          {
            'id': 'cit-01',
            'datasetId': 'test-dataset',
            'docId': 'doc-123',
            'title': 'Test Document',
          },
        ],
      };
      final model = AiSearchResultModel.fromJson(json);
      expect(model.answer, 'This is a test answer with [cit-01].');
      expect(model.citations.length, 1);
      expect(model.citations[0].id, 'cit-01');
      expect(model.citations[0].datasetId, 'test-dataset');
      expect(model.citations[0].docId, 'doc-123');
      expect(model.citations[0].title, 'Test Document');

      final back = model.toJson();
      expect(back['answer'], 'This is a test answer with [cit-01].');
      expect(back['citations'][0]['id'], 'cit-01');
    });
  });
}
