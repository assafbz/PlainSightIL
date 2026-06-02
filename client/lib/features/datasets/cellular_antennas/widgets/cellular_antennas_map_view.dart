import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';

class CellularAntennasMapView extends StatefulWidget {
  final AppStateNotifier appState;
  final List<Map<String, dynamic>> records;
  final String? selectedRecordId;
  final MapController mapController;
  final void Function(Map<String, dynamic> record) onMarkerTap;
  final bool showAntennas;

  const CellularAntennasMapView({
    super.key,
    required this.appState,
    required this.records,
    required this.selectedRecordId,
    required this.mapController,
    required this.onMarkerTap,
    required this.showAntennas,
  });

  @override
  State<CellularAntennasMapView> createState() =>
      _CellularAntennasMapViewState();
}

class _CellularAntennasMapViewState extends State<CellularAntennasMapView> {
  @override
  Widget build(BuildContext context) {
    // 1. Coordinate bounds validation: discard any records with latitude outside [-90, 90] or longitude outside [-180, 180]
    final validRecords = widget.records.where((rec) {
      final coords = rec['coordinates'];
      if (coords is! GeoPoint) return false;
      final lat = coords.latitude;
      final lng = coords.longitude;
      return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
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
        final coords = rec['coordinates'] as GeoPoint;
        sumLat += coords.latitude;
        sumLng += coords.longitude;
      }
      initialCenter = LatLng(
        sumLat / validRecords.length,
        sumLng / validRecords.length,
      );
    }

    // 4. Map records to FlutterMap Markers
    final markers = validRecords.map((rec) {
      final coords = rec['coordinates'] as GeoPoint;
      final latLng = LatLng(coords.latitude, coords.longitude);

      // Determine record ID
      final id =
          rec['antennaId']?.toString() ??
          rec['referenceNumber']?.toString() ??
          rec['id']?.toString() ??
          '';
      final isSelected =
          widget.selectedRecordId != null && widget.selectedRecordId == id;

      // Select marker color based on type and status
      Color markerColor;
      if (widget.showAntennas) {
        markerColor = AppColors.primary;
      } else {
        final isApproved = (rec['permitType'] as String? ?? '').contains(
          'הקמה',
        );
        markerColor = isApproved ? AppColors.info : AppColors.warning;
      }

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
                    color: AppColors.primary.withAlpha(40),
                  ),
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withAlpha(220),
                    ),
                    child: Center(
                      child: Text(
                        clusterMarkers.length.toString(),
                        style: TextStyle(
                          color: AppColors.onPrimary,
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
