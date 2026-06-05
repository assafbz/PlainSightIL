import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';

void main() {
  group('DatasetIds Tests', () {
    test('should contain patent classifications', () {
      expect(
        DatasetIds.patentClassifications,
        'b2c59e21-c345-4b02-b071-2890a3d431d6',
      );
    });

    test('should contain local market bonds', () {
      expect(
        DatasetIds.localMarketBonds,
        'c92fdda2-0939-4110-8ebc-edfcf35e8723',
      );
    });
  });
}
