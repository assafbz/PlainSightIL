import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';
import 'package:plainsight/features/datasets/cellular_antennas/widgets/cellular_antennas_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel geolocatorChannel = MethodChannel(
    'flutter.baseflow.com/geolocator',
  );

  setUp(() {
    AppStateNotifier.isTesting = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'isLocationServiceEnabled') {
            return false;
          }
          if (methodCall.method == 'checkPermission') {
            return 0; // LocationPermission.denied.index
          }
          if (methodCall.method == 'requestPermission') {
            return 0; // LocationPermission.denied.index
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
  });

  group('CellularAntennasScreen & CellularAntennasMapView Widget Tests', () {
    testWidgets('Toggles between radar and map views', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initPermitMetadataListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CellularAntennasScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows CellularAntennasMapView and NOT RadarView (CustomPaint)
      expect(find.byType(CellularAntennasMapView), findsOneWidget);
      expect(find.byKey(const ValueKey('radar_view')), findsNothing);

      // Tap on the Radar toggle option
      final radarToggleFinder = find.text('Radar');
      expect(radarToggleFinder, findsOneWidget);
      await tester.tap(radarToggleFinder);
      await tester.pumpAndSettle();

      // Now it should show RadarView (uses CustomPaint) and NOT CellularAntennasMapView
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(CellularAntennasMapView), findsNothing);
    });

    testWidgets('CellularAntennasMapView discards invalid coordinates', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      final mapController = MapController();
      final records = [
        {
          'antennaId': 'VALID-1',
          'coordinates': const GeoPoint(32.0782, 34.7741),
        },
        {'antennaId': 'INVALID-TYPE', 'coordinates': 'not_a_geopoint'},
        {'antennaId': 'NULL-COORDS', 'coordinates': null},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CellularAntennasMapView(
              appState: appState,
              records: records,
              selectedRecordId: null,
              mapController: mapController,
              onMarkerTap: (_) {},
              showAntennas: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clusterFinder = find.byType(MarkerClusterLayerWidget);
      expect(clusterFinder, findsOneWidget);

      final MarkerClusterLayerWidget clusterWidget = tester.widget(
        clusterFinder,
      );
      // Only the VALID-1 record should be mapped as a marker
      expect(clusterWidget.options.markers.length, 1);
      expect(clusterWidget.options.markers.first.point.latitude, 32.0782);
      expect(clusterWidget.options.markers.first.point.longitude, 34.7741);
    });

    testWidgets('GPS Recenter handles cancellation gracefully', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initPermitMetadataListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CellularAntennasScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Recenter button
      final recenterButtonFinder = find.byTooltip('Recenter on Location');
      expect(recenterButtonFinder, findsOneWidget);
      await tester.tap(recenterButtonFinder);
      await tester.pumpAndSettle();

      // Location explanation dialog should appear
      expect(find.text('Location Access'), findsOneWidget);

      // Tap Cancel in the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // SnackBar fallback should appear
      expect(
        find.text('Could not access current location. Centering on Tel Aviv.'),
        findsOneWidget,
      );
    });

    testWidgets('GPS Recenter handles exception/denial gracefully', (
      WidgetTester tester,
    ) async {
      final appState = AppStateNotifier();
      appState.initPermitMetadataListener();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CellularAntennasScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Recenter button
      await tester.tap(find.byTooltip('Recenter on Location'));
      await tester.pumpAndSettle();

      // Tap Allow in the explanation dialog
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      // The platform exception in test is caught and triggers fallback SnackBar
      expect(
        find.text('Could not access current location. Centering on Tel Aviv.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Opens with Construction Permits when initialFilterIndex is 1',
      (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.initPermitMetadataListener();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CellularAntennasScreen(
                appState: appState,
                initialFilterIndex: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final activeTowersContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Active Towers'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(activeTowersContainer.decoration, isNull);

        final permitsContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Construction Permits'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(permitsContainer.decoration, isNotNull);

        expect(
          appState.recents.contains('ff398c7e-c522-4ee8-a53a-312b188a573d'),
          isTrue,
        );
      },
    );
  });
}
