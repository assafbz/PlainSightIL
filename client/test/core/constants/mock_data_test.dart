import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/constants/mock_data.dart';

void main() {
  test('MockData contains all required static definitions', () {
    expect(MockData.userProfile, isNotNull);
    expect(MockData.userMap, isNotEmpty);
    expect(MockData.permits, isNotEmpty);
    expect(MockData.antennas, isNotEmpty);
    expect(MockData.directory, isNotEmpty);
    expect(MockData.datasetRequestCounts, isNotEmpty);
    expect(MockData.liquidations, isNotEmpty);
    expect(MockData.doctors, isNotEmpty);
    expect(MockData.datasetMetadata, isNotEmpty);
    expect(MockData.apiHealth, isNotEmpty);
    expect(MockData.scraperRuns, isNotEmpty);
  });
}
