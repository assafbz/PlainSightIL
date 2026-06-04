import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/state/app_state.dart';
import '../data/models/bank_atm_record_model.dart';

/// Interactive map view for Bank ATMs featuring clustering and custom markers.
class BankAtmsMapView extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;

  /// The list of ATM records to map.
  final List<BankAtmRecordModel> records;

  /// The ID of the currently selected ATM document, if any.
  final String? selectedRecordId;

  /// Controller to manipulate map state programmatically.
  final MapController mapController;

  /// Callback fired when an ATM marker is tapped.
  final void Function(BankAtmRecordModel record) onMarkerTap;

  /// Constructor
  const BankAtmsMapView({
    super.key,
    required this.appState,
    required this.records,
    required this.selectedRecordId,
    required this.mapController,
    required this.onMarkerTap,
  });

  @override
  State<BankAtmsMapView> createState() => _BankAtmsMapViewState();
}

class _BankAtmsMapViewState extends State<BankAtmsMapView> {
  @override
  Widget build(BuildContext context) {
    const Color markerColor = Color(0xFF2E7D32);

    // 1. Coordinate bounds validation: discard any records with out-of-bounds coordinates
    final validRecords = widget.records.where((rec) {
      final lat = rec.latitude;
      final lng = rec.longitude;
      return lat >= -90.0 &&
          lat <= 90.0 &&
          lng >= -180.0 &&
          lng <= 180.0 &&
          (lat != 0.0 || lng != 0.0);
    }).toList();

    // 2. Select appropriate map tile URL based on Dark/Light mode
    final String tileUrl = widget.appState.isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    // 3. Define fallback coordinates on load if no records are available or selected
    LatLng initialCenter = const LatLng(32.0782, 34.7741); // Default Tel Aviv
    if (validRecords.isNotEmpty) {
      double sumLat = 0.0;
      double sumLng = 0.0;
      for (final rec in validRecords) {
        sumLat += rec.latitude;
        sumLng += rec.longitude;
      }
      initialCenter = LatLng(
        sumLat / validRecords.length,
        sumLng / validRecords.length,
      );
    }

    // 4. Map records to FlutterMap Markers
    final markers = validRecords.map((rec) {
      final latLng = LatLng(rec.latitude, rec.longitude);
      final isSelected =
          widget.selectedRecordId != null && widget.selectedRecordId == rec.id;

      return Marker(
        point: latLng,
        width: isSelected ? 48.0 : 36.0,
        height: isSelected ? 48.0 : 36.0,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onMarkerTap(rec),
          child: Center(
            child: Container(
              width: isSelected ? 28.0 : 16.0,
              height: isSelected ? 28.0 : 16.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 3.0 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: markerColor.withAlpha(isSelected ? 150 : 60),
                    blurRadius: isSelected ? 12.0 : 6.0,
                    spreadRadius: isSelected ? 4.0 : 1.0,
                  ),
                ],
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 6.0,
                        height: 6.0,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
    }).toList();

    return RepaintBoundary(
      child: FlutterMap(
        mapController: widget.mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 11.0,
          maxZoom: 18.0,
          minZoom: 7.0,
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.plainsight.app',
          ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 45,
              size: const Size(40, 40),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(50),
              maxZoom: 15,
              markers: markers,
              builder: (context, clusterMarkers) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: markerColor.withAlpha(40),
                  ),
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: markerColor.withAlpha(220),
                    ),
                    child: Center(
                      child: Text(
                        clusterMarkers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
