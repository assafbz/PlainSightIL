import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/alerts/presentation/pages/alerts_page.dart';

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

  testWidgets('AlertsPage renders unauthenticated prompt when not logged in', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = false;
    final appState = AppStateNotifier();

    await tester.pumpWidget(MaterialApp(home: AlertsPage(appState: appState)));

    await tester.pumpAndSettle();

    // Verify unauthenticated visual state shows sign in elements
    expect(
      find.text(appState.translate('alerts_sign_in_title')),
      findsOneWidget,
    );
    expect(find.text(appState.translate('sign_in_google')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('AlertsPage renders alerts list when authenticated', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = true;
    final appState = AppStateNotifier();
    appState.setGuestMode(false);

    await tester.pumpWidget(MaterialApp(home: AlertsPage(appState: appState)));

    await tester.pumpAndSettle();

    // Verify alerts page header
    expect(find.text(appState.translate('nav_alerts')), findsOneWidget);

    // Check titles for both mock alerts (English by default)
    expect(
      find.text('New Records Ingested in Cellular Antennas'),
      findsOneWidget,
    );
    expect(
      find.text('New Visualizer Supported: Local Market Bonds'),
      findsOneWidget,
    );

    // Verify mark all read button exists since we have unread alerts
    expect(
      find.text(appState.translate('alerts_mark_all_read')),
      findsOneWidget,
    );
  });

  testWidgets('AlertsPage updates dynamically when language is toggled', (
    WidgetTester tester,
  ) async {
    AppStateNotifier.isTesting = true;
    final appState = AppStateNotifier();
    appState.setGuestMode(false);

    await tester.pumpWidget(MaterialApp(home: AlertsPage(appState: appState)));

    await tester.pumpAndSettle();

    // Change locale to Hebrew
    appState.setLocale('he');
    await tester.pumpAndSettle();

    // Check Hebrew title and translation values
    expect(find.text('נקלטו רשומות חדשות באנטנות סלולריות'), findsOneWidget);
    expect(
      find.text('מאגר מידע חדש זמין לצפייה: אג"ח בשוק המקומי'),
      findsOneWidget,
    );
  });
}
