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
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';
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
        ChangeNotifierProvider<TelemetryNotifier>.value(
          value: _appState.telemetryNotifier,
        ),
      ],
      child: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
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
                textDirection: _appState.textDirection,
                child: child!,
              );
            },
            home: (!_appState.isAuthenticated && !_appState.isGuestMode)
                ? LoginPage(appState: _appState)
                : AppShell(appState: _appState),
          );
        },
      ),
    );
  }
}
