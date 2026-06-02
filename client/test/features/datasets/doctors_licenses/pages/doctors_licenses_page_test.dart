import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart';
import 'package:plainsight/features/datasets/doctors_licenses/widgets/doctor_detail_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppStateNotifier.isTesting = true;
  });

  group('DoctorsLicensesScreen Widget Tests', () {
    testWidgets('Renders page title, search bar, chips, and initial list items', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initDoctorsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DoctorsLicensesScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Check title rendering (English locale default is "Doctors Licenses")
      expect(find.text('Doctors Licenses'), findsOneWidget);

      // Check search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify that mock cards are rendered (Steinberg is in the mock list twice)
      expect(find.text('Dr. אברהם שטיינברג'), findsNWidgets(2));
      expect(find.text('Dr. מריו ה קורוב'), findsOneWidget);
    });

    testWidgets('Filtering items via search query works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initDoctorsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DoctorsLicensesScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find text field and type "מריו"
      await tester.enterText(find.byType(TextField), 'מריו');
      await tester.pumpAndSettle();

      // Verify lists are filtered
      expect(find.text('Dr. מריו ה קורוב'), findsOneWidget);
      expect(find.text('Dr. אברהם שטיינברג'), findsNothing);
    });

    testWidgets('Filtering items via specialty chip works', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initDoctorsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DoctorsLicensesScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find chip for "נוירולוגיית ילדים" (Child Neurology)
      final chipFinder = find.text('נוירולוגיית ילדים').first;
      expect(chipFinder, findsOneWidget);

      // Tap the specialty chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Should filter to only show that specialty record (Steinberg child neurology)
      expect(find.text('Dr. אברהם שטיינברג'), findsOneWidget);
      expect(find.text('Dr. מריו ה קורוב'), findsNothing);
    });

    testWidgets('Tapping on a doctor card opens DoctorDetailDrawer sheet', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initDoctorsListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DoctorsLicensesScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Find first card and tap it
      final firstCardFinder = find.text('Dr. מריו ה קורוב');
      await tester.tap(firstCardFinder);
      await tester.pumpAndSettle();

      // Check if details drawer is loaded
      expect(find.byType(DoctorDetailDrawer), findsOneWidget);
      expect(find.text('Medical License Details'), findsOneWidget);
      expect(find.text('4267'), findsOneWidget); // License number
    });
  });
}
