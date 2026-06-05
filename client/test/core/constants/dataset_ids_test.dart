import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';

void main() {
  group('DatasetIds Tests', () {
    test('DatasetIds constants are correct and class can be instantiated', () {
      // Instantiate the class to cover the implicit constructor
      final instance = DatasetIds();
      expect(instance, isNotNull);

      // Verify the constant values
      expect(
        DatasetIds.cellularAntennas,
        '8935c8e5-ec77-421f-af86-d970583195f8',
      );
      expect(
        DatasetIds.cellularPermits,
        'ff398c7e-c522-4ee8-a53a-312b188a573d',
      );
      expect(
        DatasetIds.companiesLiquidation,
        'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
      );
      expect(
        DatasetIds.doctorsLicenses,
        '9c64c522-bbc2-48fe-96fb-3b2a8626f59e',
      );
      expect(
        DatasetIds.patentClassifications,
        'b2c59e21-c345-4b02-b071-2890a3d431d6',
      );
      expect(DatasetIds.carImporters, '39f455bf-6db0-4926-859d-017f34eacbcb');

      // Verify the all getter list
      final allIds = DatasetIds.all;
      expect(allIds.length, 7);
      expect(allIds.contains(DatasetIds.carImporters), isTrue);
      expect(allIds.contains(DatasetIds.cellularAntennas), isTrue);
      expect(allIds.contains(DatasetIds.localMarketBonds), isTrue);
    });

    test('should contain local market bonds', () {
      expect(
        DatasetIds.localMarketBonds,
        'c92fdda2-0939-4110-8ebc-edfcf35e8723',
      );
    });
  });
}
