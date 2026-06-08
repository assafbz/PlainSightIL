import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/dataset_ids.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';
import '../widgets/cellular_antennas_map_view.dart';
import '../widgets/map_controls_overlay.dart';

class CellularAntennasScreen extends StatefulWidget {
  final AppStateNotifier appState;
  final int initialFilterIndex;
  final String? initialSelectedId;

  const CellularAntennasScreen({
    super.key,
    required this.appState,
    this.initialFilterIndex = 0,
    this.initialSelectedId,
  });

  @override
  State<CellularAntennasScreen> createState() => _CellularAntennasScreenState();
}

class _CellularAntennasScreenState extends State<CellularAntennasScreen>
    with TickerProviderStateMixin {
  late int
  _selectedFilterIndex; // 0: Active Towers (Default), 1: Construction Permits
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _radarController;

  // Map and sync state
  bool _showMap = true;
  String? _selectedRecordId;
  final MapController _mapController = MapController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  AnimationController? _mapAnimationController;
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = widget.initialFilterIndex;
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!AppStateNotifier.isTesting) {
      _radarController.repeat();
    }
    widget.appState.addRecent(
      widget.initialFilterIndex == 1
          ? DatasetIds.cellularPermits
          : DatasetIds.cellularAntennas,
    );
    widget.appState.initPermitMetadataListener();
    if (widget.initialSelectedId != null) {
      widget.appState.addListener(_handleDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleDeepLink);
    widget.appState.cancelPermitMetadataListener();
    _radarController.dispose();
    _searchController.dispose();
    _mapAnimationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleDeepLink() {
    if (_deepLinkHandled || widget.initialSelectedId == null) return;

    final antennasLoading =
        widget.appState.isLoadingAntennas &&
        widget.appState.antennaRecords.isEmpty;
    final permitsLoading =
        widget.appState.isLoadingPermits &&
        widget.appState.permitRecords.isEmpty;
    if (antennasLoading && permitsLoading) return;

    Map<String, dynamic>? targetAntenna;
    for (final rec in widget.appState.antennaRecords) {
      final id = rec['antennaId']?.toString() ?? rec['id']?.toString() ?? '';
      if (id == widget.initialSelectedId) {
        targetAntenna = rec;
        break;
      }
    }

    Map<String, dynamic>? targetPermit;
    for (final rec in widget.appState.permitRecords) {
      final id =
          rec['referenceNumber']?.toString() ?? rec['id']?.toString() ?? '';
      if (id == widget.initialSelectedId) {
        targetPermit = rec;
        break;
      }
    }

    if (targetAntenna != null) {
      _deepLinkHandled = true;
      widget.appState.removeListener(_handleDeepLink);
      setState(() {
        _selectedFilterIndex = 0;
        _selectedRecordId = widget.initialSelectedId;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAndMoveMap(targetAntenna!);
      });
    } else if (targetPermit != null) {
      _deepLinkHandled = true;
      widget.appState.removeListener(_handleDeepLink);
      setState(() {
        _selectedFilterIndex = 1;
        _selectedRecordId = widget.initialSelectedId;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAndMoveMap(targetPermit!);
      });
    }
  }

  void _scrollToAndMoveMap(Map<String, dynamic> record) {
    final coords = record['coordinates'];
    if (coords is GeoPoint) {
      _animatedMapMove(LatLng(coords.latitude, coords.longitude), 16.0);
    }

    final filtered = _getFilteredRecords();
    final index = filtered.indexWhere((rec) {
      final id =
          rec['antennaId']?.toString() ??
          rec['referenceNumber']?.toString() ??
          rec['id']?.toString() ??
          '';
      return id == widget.initialSelectedId;
    });

    if (index != -1) {
      try {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        // Safe fallback if controller is not attached yet
      }
    }
  }

  List<Map<String, dynamic>> _filterRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (_searchQuery.isEmpty) return records;
    final query = _searchQuery.toLowerCase();
    return records.where((rec) {
      final locality = (rec['locality'] as String? ?? '').toLowerCase();
      final id = (rec['id'] as String? ?? rec['siteNumber'] as String? ?? '')
          .toLowerCase();
      final ref = (rec['referenceNumber']?.toString() ?? '').toLowerCase();
      final operatorHe = (rec['company']?['he'] as String? ?? '').toLowerCase();
      final operatorEn = (rec['company']?['en'] as String? ?? '').toLowerCase();

      return locality.contains(query) ||
          id.contains(query) ||
          ref.contains(query) ||
          operatorHe.contains(query) ||
          operatorEn.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    final appState = widget.appState;
    if (_selectedFilterIndex == 0) {
      return _filterRecords(appState.antennaRecords);
    } else {
      return _filterRecords(appState.permitRecords);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapAnimationController?.stop();
    _mapAnimationController?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _mapAnimationController = controller;

    final LatLng startLocation = _mapController.camera.center;
    final double startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: startLocation.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startLocation.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_mapAnimationController == controller) {
          _mapAnimationController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _onMarkerTap(Map<String, dynamic> record) {
    final recordId =
        record['antennaId']?.toString() ??
        record['referenceNumber']?.toString() ??
        record['id']?.toString() ??
        '';
    setState(() {
      _selectedRecordId = recordId;
    });

    final coords = record['coordinates'] as GeoPoint;
    _animatedMapMove(LatLng(coords.latitude, coords.longitude), 15.0);

    final filtered = _getFilteredRecords();
    final index = filtered.indexWhere((rec) {
      final id =
          rec['antennaId']?.toString() ??
          rec['referenceNumber']?.toString() ??
          rec['id']?.toString() ??
          '';
      return id == recordId;
    });
    if (index != -1) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onCardTap(Map<String, dynamic> record) {
    final recordId =
        record['antennaId']?.toString() ??
        record['referenceNumber']?.toString() ??
        record['id']?.toString() ??
        '';
    setState(() {
      _selectedRecordId = recordId;
    });

    final coords = record['coordinates'];
    if (coords is GeoPoint) {
      if (_showMap) {
        _animatedMapMove(LatLng(coords.latitude, coords.longitude), 16.0);
      }
    }
  }

  Future<void> _recenterOnUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        // Show explanation dialog first
        final goAhead = await showDialog<bool>(
          context: context,
          builder: (context) {
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            return AlertDialog(
              backgroundColor: AppColors.surfaceLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isRtl ? 'גישה למיקום' : 'Location Access',
                style: AppTypography.headlineMd(context),
              ),
              content: Text(
                isRtl
                    ? 'PlainSightIL זקוקה לגישה למיקום המכשיר שלך כדי להציג אנטנות ואישורים סביבך על המפה.'
                    : 'PlainSightIL needs access to your device location to display cellular antennas and permits around you on the map.',
                style: AppTypography.bodySm(context),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    isRtl ? 'ביטול' : 'Cancel',
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    isRtl ? 'אישור' : 'Allow',
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (goAhead != true) {
          _fallbackToTelAviv();
          return;
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _animatedMapMove(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      _fallbackToTelAviv();
    }
  }

  void _fallbackToTelAviv() {
    _animatedMapMove(const LatLng(32.0782, 34.7741), 15.0);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          isRtl
              ? 'לא ניתן לגשת למיקום הנוכחי. מוצג מרכז תל אביב.'
              : 'Could not access current location. Centering on Tel Aviv.',
          style: AppTypography.bodySm(context, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary.withAlpha(100), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  AppTypography.bodySm(
                    context,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      appBar: AppBar(
        backgroundColor: const Color(0x33000000),
        elevation: 0,
        centerTitle: true,
        title: Text(
          appState.translate('towers_title'),
          style: AppTypography.headlineLg(
            context,
            color: AppColors.primary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              final currentDatasetId = _selectedFilterIndex == 1
                  ? DatasetIds.cellularPermits
                  : DatasetIds.cellularAntennas;
              final isFav = appState.isFavorite(currentDatasetId);
              final isSubbed = appState.isSubscribed(currentDatasetId);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: appState.translate(
                      isSubbed ? 'unsubscribe_tooltip' : 'subscribe_tooltip',
                    ),
                    icon: Icon(
                      isSubbed
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: isSubbed
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    onPressed: () async {
                      try {
                        await appState.toggleSubscription(currentDatasetId);
                      } catch (e) {
                        if (context.mounted &&
                            e.toString().contains('LimitReached')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                appState.translate('limits_exceeded_desc'),
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? AppColors.danger : AppColors.textSecondary,
                    ),
                    onPressed: () => appState.toggleFavorite(currentDatasetId),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Map/Radar Visualizer Pane
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showMap
                    ? CellularAntennasMapView(
                        key: const ValueKey('map_view'),
                        appState: widget.appState,
                        records: _getFilteredRecords(),
                        selectedRecordId: _selectedRecordId,
                        mapController: _mapController,
                        onMarkerTap: _onMarkerTap,
                        showAntennas: _selectedFilterIndex == 0,
                      )
                    : AnimatedBuilder(
                        key: const ValueKey('radar_view'),
                        animation: _radarController,
                        builder: (context, _) {
                          // Dynamically pull coordinate dots from active collection
                          final records = _selectedFilterIndex == 1
                              ? appState.permitRecords
                              : appState.antennaRecords;
                          return CustomPaint(
                            painter: RadarGridPainter(
                              angle: _radarController.value * 2 * math.pi,
                              records: records,
                              isDark: appState.isDarkMode,
                            ),
                            child: Container(),
                          );
                        },
                      ),
              ),
            ),
          ),

          // Map controls overlay (Zoom and Recenter buttons)
          if (_showMap)
            Positioned(
              top: 12,
              left: isRtl ? 16 : null,
              right: isRtl ? null : 16,
              child: MapControlsOverlay(
                mapController: _mapController,
                onRecenter: _recenterOnUserLocation,
              ),
            ),

          // Toggle Switch Overlay for Radar/Map selection
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glassGlow,
                      blurRadius: 10.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleOption(
                      icon: Icons.map,
                      label: widget.appState.locale == 'he' ? 'מפה' : 'Map',
                      isSelected: _showMap,
                      onTap: () {
                        setState(() {
                          _showMap = true;
                        });
                      },
                    ),
                    _buildToggleOption(
                      icon: Icons.radar,
                      label: widget.appState.locale == 'he' ? 'רדאר' : 'Radar',
                      isSelected: !_showMap,
                      onTap: () {
                        setState(() {
                          _showMap = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Interactive Bottom Sheet Content Area
          Positioned.fill(
            key: const ValueKey('bottom_sheet_content'),
            top: MediaQuery.of(context).size.height * 0.32,
            child: Column(
              children: [
                // Bottom sheet drag handle indicator
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withAlpha(50),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Segmented Control Filters (Active Towers vs Construction Permits)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow.withAlpha(150),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentItem(
                          context,
                          index: 0,
                          label: appState.translate('towers_active_label'),
                        ),
                        _buildSegmentItem(
                          context,
                          index: 1,
                          label: appState.translate('towers_permit_label'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Search Input Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow.withAlpha(100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: AppTypography.bodySm(
                              context,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: appState.translate(
                                'towers_search_placeholder',
                              ),
                              hintStyle: AppTypography.bodySm(
                                context,
                                color: AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Scrollable Records List View
                Expanded(child: _buildRecordsList(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(
    BuildContext context, {
    required int index,
    required String label,
  }) {
    final isSelected = _selectedFilterIndex == index;
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilterIndex = index;
              _selectedRecordId = null; // Clear selection when filter changes
            });
            widget.appState.addRecent(
              index == 1
                  ? DatasetIds.cellularPermits
                  : DatasetIds.cellularAntennas,
            );
          },
          borderRadius: BorderRadius.circular(15),
          child: Container(
            alignment: Alignment.center,
            decoration: isSelected
                ? BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(100),
                      width: 1.5,
                    ),
                  )
                : null,
            child: Text(
              label,
              style: AppTypography.bodySm(context, color: color).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context) {
    final appState = widget.appState;
    final filtered = _getFilteredRecords();

    if (_selectedFilterIndex == 0) {
      if (!AppStateNotifier.isTesting &&
          appState.isLoadingAntennas &&
          appState.antennaRecords.isEmpty) {
        return const GlassmorphicCardSkeletonList();
      }
    } else {
      if (appState.isLoadingPermits && appState.permitRecords.isEmpty) {
        return const GlassmorphicCardSkeletonList();
      }
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return ScrollablePositionedList.builder(
      key: const ValueKey('towers_scrollable_list'),
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _selectedFilterIndex == 0
            ? _buildActiveAntennaCard(context, item)
            : _buildPermitCard(context, item);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            widget.appState.translate('no_results'),
            style: AppTypography.bodyLg(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAntennaCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final appState = widget.appState;
    final address = appState.locale == 'he'
        ? (item['addressHebrew'] as String? ?? 'לא ידוע')
        : (item['addressEnglish'] as String? ?? 'Unknown');
    final operatorName = item['operatorName'] as String? ?? 'Unknown';

    final id = item['antennaId']?.toString() ?? item['id']?.toString() ?? '';
    final isSelected = _selectedRecordId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.primary, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 8.0,
                    spreadRadius: 2.0,
                  ),
                ],
              )
            : null,
        child: Semantics(
          label: 'Active antenna at $address',
          child: GlassmorphicCard(
            onTap: () => _onCardTap(item),
            startBorderColor: AppColors.success,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${appState.translate('antenna_id_prefix')}${item['antennaId']}",
                        style: AppTypography.headlineMd(
                          context,
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withAlpha(80),
                          ),
                        ),
                        child: Text(
                          appState.translate('badge_active'),
                          style: AppTypography.labelXs(
                            context,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address,
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${appState.translate('permit_operator')}$operatorName",
                        style: AppTypography.labelXs(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        "${item['radiationFrequency']} MHz",
                        style: AppTypography.labelXs(
                          context,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermitCard(BuildContext context, Map<String, dynamic> item) {
    final appState = widget.appState;
    final isApproved = (item['permitType'] as String? ?? '').contains('הקמה');
    final accentColor = isApproved ? AppColors.info : AppColors.warning;
    final badgeText = isApproved
        ? appState.translate('permit_badge_approved')
        : appState.translate('permit_badge_pending');

    final operator = appState.locale == 'he'
        ? (item['company']?['he'] as String? ?? 'לא ידוע')
        : (item['company']?['en'] as String? ?? 'Unknown');

    final description = item['addressDescription'] as String? ?? '';
    final locality = item['locality'] as String? ?? '';
    final addressText = description.isNotEmpty
        ? '$locality - $description'
        : locality;

    final id =
        item['referenceNumber']?.toString() ?? item['id']?.toString() ?? '';
    final isSelected = _selectedRecordId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.primary, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 8.0,
                    spreadRadius: 2.0,
                  ),
                ],
              )
            : null,
        child: Semantics(
          label: 'Permit application at $addressText',
          child: GlassmorphicCard(
            onTap: () => _onCardTap(item),
            startBorderColor: accentColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${appState.translate('permit_ref_prefix')}${item['referenceNumber']}",
                        style: AppTypography.headlineMd(
                          context,
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withAlpha(80)),
                        ),
                        child: Text(
                          badgeText,
                          style: AppTypography.labelXs(
                            context,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    addressText,
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${appState.translate('permit_operator')}$operator",
                        style: AppTypography.labelXs(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        "${appState.translate('permit_type')}${item['focalPointType']}",
                        style: AppTypography.labelXs(
                          context,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter drawing a premium glowing radar grid with coordinates pins
class RadarGridPainter extends CustomPainter {
  final double angle;
  final List<Map<String, dynamic>> records;
  final bool isDark;

  RadarGridPainter({
    required this.angle,
    required this.records,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.45;

    final paintGrid = Paint()
      ..color = isDark ? const Color(0x1A8ED5FF) : const Color(0x1F0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4), paintGrid);
    }

    // Draw crosshair axes
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      paintGrid,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      paintGrid,
    );

    // Draw radar sweep beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.primary.withAlpha(isSelectedDarkAlpha(isDark)),
        ],
        stops: const [0.85, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Filter records for elements containing a GeoPoint under 'coordinates'
    final validCoords = <GeoPoint>[];
    for (final rec in records) {
      final coordsObj = rec['coordinates'];
      if (coordsObj is GeoPoint) {
        validCoords.add(coordsObj);
      }
    }

    if (validCoords.isEmpty) {
      return;
    }

    // Calculate average latitude and average longitude of the coordinates
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (final coord in validCoords) {
      sumLat += coord.latitude;
      sumLng += coord.longitude;
    }
    final avgLat = sumLat / validCoords.length;
    final avgLng = sumLng / validCoords.length;

    // Compute relative dx (longitude delta) and dy (latitude delta) from the average
    // and find the maximum distance (delta) to scale offsets so they fit within maxRadius * 0.8.
    double maxDelta = 0.0;
    final deltas = <_CoordDelta>[];
    for (final coord in validCoords) {
      final dy = coord.latitude - avgLat;
      final dx = coord.longitude - avgLng;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > maxDelta) {
        maxDelta = dist;
      }
      deltas.add(_CoordDelta(dx, dy));
    }

    // Draw Coordinate Pins dynamically projected into circle bounds
    final pinPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final pinOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final delta in deltas) {
      // Scale offsets so they fit within maxRadius * 0.8
      final double scale = maxDelta > 0 ? (maxRadius * 0.8) / maxDelta : 0.0;
      final double px = delta.dx * scale;
      final double py =
          -delta.dy * scale; // Y direction is down in screen coords

      final offset = Offset(center.dx + px, center.dy + py);

      // Compute angle (in radians) of this offset from center to apply sweep fade intensity effect dynamically
      final double a = math.atan2(py, px);

      // Pulse fade effect relative to sweep angle
      double diff = (a - angle) % (2 * math.pi);
      if (diff < 0) diff += 2 * math.pi;
      double intensity = math.max(0.15, 1.0 - (diff / (2 * math.pi)));

      pinPaint.color = AppColors.primary.withAlpha((intensity * 255).round());
      canvas.drawCircle(offset, 6.0, pinPaint);
      canvas.drawCircle(
        offset,
        6.0,
        pinOutline..color = Colors.white.withAlpha((intensity * 255).round()),
      );
    }
  }

  int isSelectedDarkAlpha(bool dark) => dark ? 120 : 60;

  @override
  bool shouldRepaint(covariant RadarGridPainter oldDelegate) => true;
}

/// Styled skeletal loader list for premium appearance while fetching data
class GlassmorphicCardSkeletonList extends StatelessWidget {
  const GlassmorphicCardSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GlassmorphicCard(
            startBorderColor: AppColors.surfaceHigh,
            child: Container(
              height: 110,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 100,
                        height: 16,
                        color: AppColors.surfaceHigh,
                      ),
                      Container(
                        width: 80,
                        height: 16,
                        color: AppColors.surfaceHigh,
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: AppColors.surfaceHigh,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        color: AppColors.surfaceHigh,
                      ),
                      Container(
                        width: 60,
                        height: 12,
                        color: AppColors.surfaceHigh,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoordDelta {
  final double dx;
  final double dy;
  _CoordDelta(this.dx, this.dy);
}
