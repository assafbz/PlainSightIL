import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/auth/presentation/pages/login_page.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';
import 'package:plainsight/features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';
import 'package:plainsight/features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';
import 'package:plainsight/features/datasets/travel_warnings/presentation/notifiers/travel_warnings_notifier.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';
import 'package:plainsight/features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';
import 'package:plainsight/features/datasets/patent_classifications/presentation/notifiers/patent_classifications_notifier.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/presentation/notifiers/vehicle_recalls_notifier.dart';
import 'package:plainsight/features/datasets/car_importers/presentation/notifiers/car_importers_notifier.dart';
import 'package:plainsight/features/datasets/local_market_bonds/presentation/notifiers/local_market_bonds_notifier.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';
import 'package:plainsight/core/widgets/app_shell.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppStateNotifier _appState = AppStateNotifier();

  @override
  void initState() {
    super.initState();
    _appState.initDirectoryListener();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateNotifier>.value(value: _appState),
        ChangeNotifierProvider<AuthNotifier>.value(
          value: _appState.authNotifier,
        ),
        ChangeNotifierProvider<AntennasNotifier>.value(
          value: _appState.antennasNotifier,
        ),
        ChangeNotifierProvider<PermitsNotifier>.value(
          value: _appState.permitsNotifier,
        ),
        ChangeNotifierProvider<LiquidationNotifier>.value(
          value: _appState.liquidationNotifier,
        ),
        ChangeNotifierProvider<DoctorsNotifier>.value(
          value: _appState.doctorsNotifier,
        ),
        ChangeNotifierProvider<TravelWarningsNotifier>.value(
          value: _appState.travelWarningsNotifier,
        ),
        ChangeNotifierProvider<TelemetryNotifier>.value(
          value: _appState.telemetryNotifier,
        ),
        ChangeNotifierProvider<BankAtmsNotifier>.value(
          value: _appState.bankAtmsNotifier,
        ),
        ChangeNotifierProvider<PatentClassificationsNotifier>.value(
          value: _appState.patentClassificationsNotifier,
        ),
        ChangeNotifierProvider<VehicleRecallsNotifier>.value(
          value: _appState.vehicleRecallsNotifier,
        ),
        ChangeNotifierProvider<CarImportersNotifier>.value(
          value: _appState.carImportersNotifier,
        ),
        ChangeNotifierProvider<LocalMarketBondsNotifier>.value(
          value: _appState.bondsNotifier,
        ),
        ChangeNotifierProvider<AlertsNotifier>.value(
          value: _appState.alertsNotifier,
        ),
      ],
      child:
          Selector<
            AppStateNotifier,
            ({
              String locale,
              bool isDarkMode,
              bool isAuthenticated,
              bool isGuestMode,
            })
          >(
            selector: (context, appState) => (
              locale: appState.locale,
              isDarkMode: appState.isDarkMode,
              isAuthenticated: appState.isAuthenticated,
              isGuestMode: appState.isGuestMode,
            ),
            builder: (context, settings, _) {
              final appState = Provider.of<AppStateNotifier>(
                context,
                listen: false,
              );
              return MaterialApp(
                title: 'PlainSightIL',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  scaffoldBackgroundColor: AppColors.baseBg,
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.surface,
                    error: AppColors.danger,
                  ),
                  useMaterial3: true,
                ),
                builder: (context, child) {
                  return Directionality(
                    textDirection: settings.locale == 'he'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: child!,
                  );
                },
                home: (!settings.isAuthenticated && !settings.isGuestMode)
                    ? LoginPage(appState: appState)
                    : AppShell(appState: appState),
              );
            },
          ),
    );
  }
}
