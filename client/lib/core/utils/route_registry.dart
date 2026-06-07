import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';
import 'package:plainsight/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart';
import 'package:plainsight/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart';
import 'package:plainsight/features/datasets/bank_atms/pages/bank_atms_page.dart';
import 'package:plainsight/features/datasets/patent_classifications/pages/patent_classifications_page.dart';
import 'package:plainsight/features/datasets/travel_warnings/pages/travel_warnings_page.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/pages/vehicle_recalls_page.dart';
import 'package:plainsight/features/datasets/car_importers/pages/car_importers_page.dart';
import 'package:plainsight/features/datasets/local_market_bonds/pages/local_market_bonds_page.dart';

/// Centralized route registry to map dataset IDs to concrete visualization screens
class RouteRegistry {
  /// Returns the concrete widget for the given dataset ID
  static Widget getDatasetScreen(
    String datasetId,
    AppStateNotifier appState, {
    int? initialFilterIndex,
    String? initialSelectedId,
  }) {
    if (datasetId == DatasetIds.cellularAntennas ||
        datasetId == DatasetIds.cellularPermits) {
      return CellularAntennasScreen(
        appState: appState,
        initialFilterIndex:
            initialFilterIndex ??
            (datasetId == DatasetIds.cellularPermits ? 1 : 0),
        initialSelectedId: initialSelectedId,
      );
    } else if (datasetId == DatasetIds.companiesLiquidation) {
      return CompaniesLiquidationScreen(appState: appState);
    } else if (datasetId == DatasetIds.doctorsLicenses) {
      return DoctorsLicensesScreen(appState: appState);
    } else if (datasetId == DatasetIds.bankAtms) {
      return BankAtmsScreen(appState: appState);
    } else if (datasetId == DatasetIds.patentClassifications) {
      return PatentClassificationsScreen(appState: appState);
    } else if (datasetId == DatasetIds.travelWarnings) {
      return TravelWarningsScreen(
        appState: appState,
        initialSelectedId: initialSelectedId,
      );
    } else if (datasetId == DatasetIds.vehicleRecalls) {
      return VehicleRecallsScreen(
        appState: appState,
        initialSelectedId: initialSelectedId,
      );
    } else if (datasetId == DatasetIds.carImporters) {
      return CarImportersScreen(appState: appState);
    } else if (datasetId == DatasetIds.localMarketBonds) {
      return LocalMarketBondsScreen(appState: appState);
    }
    throw ArgumentError('Unknown datasetId: $datasetId');
  }

  /// Returns a Route that wraps the screen for the given dataset ID
  static Route<void> getDatasetRoute(
    String datasetId,
    AppStateNotifier appState, {
    int? initialFilterIndex,
    String? initialSelectedId,
  }) {
    return MaterialPageRoute<void>(
      builder: (context) => getDatasetScreen(
        datasetId,
        appState,
        initialFilterIndex: initialFilterIndex,
        initialSelectedId: initialSelectedId,
      ),
    );
  }
}
