import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/antennas_notifier.dart';
import 'package:plainsight/features/datasets/cellular_antennas/presentation/notifiers/permits_notifier.dart';
import 'package:plainsight/features/datasets/companies_liquidation/presentation/notifiers/liquidation_notifier.dart';
import 'package:plainsight/features/datasets/doctors_licenses/presentation/notifiers/doctors_notifier.dart';
import 'package:plainsight/features/admin/presentation/notifiers/telemetry_notifier.dart';
import 'package:plainsight/core/widgets/app_shell.dart';

void main() {
  testWidgets('AppShell renders correctly', (WidgetTester tester) async {
    AppStateNotifier.isTesting = true;
    final appState = AppStateNotifier();
    appState.initDirectoryListener();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateNotifier>.value(value: appState),
          ChangeNotifierProvider<AuthNotifier>.value(
            value: appState.authNotifier,
          ),
          ChangeNotifierProvider<AntennasNotifier>.value(
            value: appState.antennasNotifier,
          ),
          ChangeNotifierProvider<PermitsNotifier>.value(
            value: appState.permitsNotifier,
          ),
          ChangeNotifierProvider<LiquidationNotifier>.value(
            value: appState.liquidationNotifier,
          ),
          ChangeNotifierProvider<DoctorsNotifier>.value(
            value: appState.doctorsNotifier,
          ),
          ChangeNotifierProvider<TelemetryNotifier>.value(
            value: appState.telemetryNotifier,
          ),
        ],
        child: MaterialApp(home: AppShell(appState: appState)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });
}
