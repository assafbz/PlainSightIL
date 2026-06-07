import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/utils/route_registry.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';
import 'package:plainsight/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart';
import 'package:plainsight/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart';
import 'package:plainsight/features/datasets/bank_atms/pages/bank_atms_page.dart';
import 'package:plainsight/features/datasets/patent_classifications/pages/patent_classifications_page.dart';
import 'package:plainsight/features/datasets/travel_warnings/pages/travel_warnings_page.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/pages/vehicle_recalls_page.dart';
import 'package:plainsight/features/datasets/car_importers/pages/car_importers_page.dart';
import 'package:plainsight/features/datasets/local_market_bonds/pages/local_market_bonds_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PlainSight IL',
      packageName: 'il.org.plainsight',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'signature',
    );
  });

  group('RouteRegistry Tests', () {
    test('getDatasetScreen maps IDs to correct widgets', () {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.cellularAntennas, appState),
        isA<CellularAntennasScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.cellularPermits, appState),
        isA<CellularAntennasScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(
          DatasetIds.companiesLiquidation,
          appState,
        ),
        isA<CompaniesLiquidationScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.doctorsLicenses, appState),
        isA<DoctorsLicensesScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.bankAtms, appState),
        isA<BankAtmsScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(
          DatasetIds.patentClassifications,
          appState,
        ),
        isA<PatentClassificationsScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.travelWarnings, appState),
        isA<TravelWarningsScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.vehicleRecalls, appState),
        isA<VehicleRecallsScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.carImporters, appState),
        isA<CarImportersScreen>(),
      );
      expect(
        RouteRegistry.getDatasetScreen(DatasetIds.localMarketBonds, appState),
        isA<LocalMarketBondsScreen>(),
      );
    });

    test('getDatasetScreen throws ArgumentError for unknown datasetId', () {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      expect(
        () => RouteRegistry.getDatasetScreen('invalid_id', appState),
        throwsArgumentError,
      );
    });

    test('getDatasetRoute returns MaterialPageRoute wrapping screen', () {
      AppStateNotifier.isTesting = true;
      final appState = AppStateNotifier();

      final route = RouteRegistry.getDatasetRoute(
        DatasetIds.cellularAntennas,
        appState,
      );
      expect(route, isA<MaterialPageRoute<void>>());
    });
  });
}
