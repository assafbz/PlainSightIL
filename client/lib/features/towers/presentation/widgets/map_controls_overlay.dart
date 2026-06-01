import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/theme/design_system.dart';

class MapControlsOverlay extends StatelessWidget {
  final MapController mapController;
  final VoidCallback onRecenter;

  const MapControlsOverlay({
    super.key,
    required this.mapController,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 144,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.glassGlow,
            blurRadius: 10.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Column(
            children: [
              // Zoom In
              Expanded(
                child: IconButton(
                  tooltip: 'Zoom In',
                  icon: Icon(Icons.add, color: AppColors.textPrimary),
                  onPressed: () {
                    final currentZoom = mapController.camera.zoom;
                    final nextZoom = (currentZoom + 1.0).clamp(7.0, 18.0);
                    mapController.move(mapController.camera.center, nextZoom);
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.glassBorder),
              // Zoom Out
              Expanded(
                child: IconButton(
                  tooltip: 'Zoom Out',
                  icon: Icon(Icons.remove, color: AppColors.textPrimary),
                  onPressed: () {
                    final currentZoom = mapController.camera.zoom;
                    final nextZoom = (currentZoom - 1.0).clamp(7.0, 18.0);
                    mapController.move(mapController.camera.center, nextZoom);
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.glassBorder),
              // Recenter
              Expanded(
                child: IconButton(
                  tooltip: 'Recenter on Location',
                  icon: Icon(Icons.my_location, color: AppColors.textPrimary),
                  onPressed: onRecenter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
