import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:plainsight/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Profile settings and drawer integration tests', () {
    late AppStateNotifier appState;

    setUp(() {
      AppStateNotifier.isTesting = true;
      appState = AppStateNotifier();
    });

    testWidgets(
      'ProfileSettingsPage retrieves fallback details from identity provider if userProfile is null',
      (WidgetTester tester) async {
        // Force userProfile to be null to simulate no existing Firestore profile document
        appState.setMockProfile(null);

        // Render the ProfileSettingsPage wrapped in MaterialApp and ListenableBuilder
        await tester.pumpWidget(
          MaterialApp(home: ProfileSettingsPage(appState: appState)),
        );
        await tester.pumpAndSettle();

        // Find all TextFormField widgets
        final formFieldsFinder = find.byType(TextFormField);
        expect(formFieldsFinder, findsNWidgets(4));

        // Retrieve current controller text to verify fallback values are retrieved from mockUser
        final TextFormField firstNameField = tester.widget<TextFormField>(
          formFieldsFinder.at(0),
        );
        final TextFormField lastNameField = tester.widget<TextFormField>(
          formFieldsFinder.at(1),
        );
        final TextFormField emailField = tester.widget<TextFormField>(
          formFieldsFinder.at(2),
        );

        expect(firstNameField.controller?.text, 'Assaf');
        expect(lastNameField.controller?.text, 'Benzaken');
        expect(emailField.controller?.text, 'assaf@plainsight.il');
      },
    );

    testWidgets(
      'ProfileSettingsPage inherits correct Directionality from MaterialApp builder based on appState locale',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              return MaterialApp(
                builder: (context, child) {
                  return Directionality(
                    textDirection: appState.textDirection,
                    child: child!,
                  );
                },
                home: ProfileSettingsPage(appState: appState),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially it should be English (LTR)
        expect(appState.locale, 'en');
        final Directionality dirLtr = tester.widget<Directionality>(
          find
              .ancestor(
                of: find.byType(ProfileSettingsPage),
                matching: find.byType(Directionality),
              )
              .first,
        );
        expect(dirLtr.textDirection, TextDirection.ltr);

        // 2. Change locale to Hebrew (RTL)
        appState.setLocale('he');
        await tester.pumpAndSettle();

        // Verify Directionality is now RTL
        final Directionality dirRtl = tester.widget<Directionality>(
          find
              .ancestor(
                of: find.byType(ProfileSettingsPage),
                matching: find.byType(Directionality),
              )
              .first,
        );
        expect(dirRtl.textDirection, TextDirection.rtl);
      },
    );

    testWidgets(
      'NavigationDrawerWidget displays name from userProfile when populated and live-updates',
      (WidgetTester tester) async {
        // Initialize with default profile
        final originalProfile = UserProfile(
          uid: 'mock_uid',
          firstName: 'OriginalFirst',
          lastName: 'OriginalLast',
          email: 'original@email.com',
          role: 'user',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        appState.setMockProfile(originalProfile);

        // Build main app shell to test the drawer
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              drawer: NavigationDrawerWidget(appState: appState),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Verify the original profile name is displayed in the drawer
        expect(find.text('OriginalFirst OriginalLast'), findsOneWidget);
        expect(find.text('original@email.com'), findsOneWidget);

        // Close the drawer
        await tester.tapAt(const Offset(700, 300));
        await tester.pumpAndSettle();

        // Update the profile in the state notifier
        final updatedProfile = originalProfile.copyWith(
          firstName: 'UpdatedFirst',
          lastName: 'UpdatedLast',
        );
        appState.setMockProfile(updatedProfile);
        await tester.pumpAndSettle();

        // Re-open the drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Verify that the live profile updates immediately in the drawer
        expect(find.text('UpdatedFirst UpdatedLast'), findsOneWidget);
        expect(find.text('OriginalFirst OriginalLast'), findsNothing);
      },
    );
  });
}
