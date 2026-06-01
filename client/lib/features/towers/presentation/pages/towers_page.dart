import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';

class TowersScreen extends StatefulWidget {
  final AppStateNotifier appState;

  const TowersScreen({super.key, required this.appState});

  @override
  State<TowersScreen> createState() => _TowersScreenState();
}

class _TowersScreenState extends State<TowersScreen> with SingleTickerProviderStateMixin {
  int _selectedFilterIndex = 0; // 0: Construction Permits (Default), 1: Active Towers
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!AppStateNotifier.isTesting) {
      _radarController.repeat();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRecords(List<Map<String, dynamic>> records) {
    if (_searchQuery.isEmpty) return records;
    final query = _searchQuery.toLowerCase();
    return records.where((rec) {
      final locality = (rec['locality'] as String? ?? '').toLowerCase();
      final id = (rec['id'] as String? ?? rec['siteNumber'] as String? ?? '').toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return Stack(
      children: [
        // 1. Map/Radar Visualizer Pane
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.35,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, _) {
                // Dynamically pull coordinate dots from active collection
                final records = _selectedFilterIndex == 0
                    ? appState.permitRecords
                    : <Map<String, dynamic>>[];
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

        // 2. Interactive Bottom Sheet Content Area
        Positioned.fill(
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
                        label: appState.translate('towers_permit_label'),
                      ),
                      _buildSegmentItem(
                        context,
                        index: 1,
                        label: appState.translate('towers_active_label'),
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
                        child: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: AppTypography.bodySm(context, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: appState.translate('towers_search_placeholder'),
                            hintStyle: AppTypography.bodySm(context, color: AppColors.textTertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close, color: AppColors.textSecondary, size: 18),
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
              Expanded(
                child: _buildRecordsList(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentItem(BuildContext context, {required int index, required String label}) {
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
            });
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

    if (_selectedFilterIndex == 1) {
      if (AppStateNotifier.isTesting) {
        final filtered = _filterRecords([
          {
            'antennaId': 'CELL-100',
            'addressHebrew': 'דיזנגוף 50, תל אביב',
            'addressEnglish': 'Dizengoff 50, Tel Aviv',
            'operatorName': 'Pelephone',
            'radiationFrequency': 1800,
          }
        ]);
        if (filtered.isEmpty) return _buildEmptyState(context);
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _buildActiveAntennaCard(context, item);
          },
        );
      }
      // Active Antennas Stream Builder query
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cellular_antennas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GlassmorphicCardSkeletonList();
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final records = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          final filtered = _filterRecords(records);

          if (filtered.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _buildActiveAntennaCard(context, item);
            },
          );
        },
      );
    } else {
      // Construction Permits double-buffered data
      if (appState.isLoadingPermits && appState.permitRecords.isEmpty) {
        return const GlassmorphicCardSkeletonList();
      }

      final filtered = _filterRecords(appState.permitRecords);

      if (filtered.isEmpty) {
        return _buildEmptyState(context);
      }

      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildPermitCard(context, item);
        },
      );
    }
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
            style: AppTypography.bodyLg(context, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAntennaCard(BuildContext context, Map<String, dynamic> item) {
    final appState = widget.appState;
    final address = appState.locale == 'he' 
        ? (item['addressHebrew'] as String? ?? 'לא ידוע') 
        : (item['addressEnglish'] as String? ?? 'Unknown');
    final operatorName = item['operatorName'] as String? ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Semantics(
        label: 'Active antenna at $address',
        child: GlassmorphicCard(
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
                      "ID: ${item['antennaId']}",
                      style: AppTypography.headlineMd(context, color: AppColors.textPrimary)
                          .copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withAlpha(80)),
                      ),
                      child: Text(
                        appState.translate('badge_active'),
                        style: AppTypography.labelXs(context, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  address,
                  style: AppTypography.bodySm(context, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${appState.translate('permit_operator')}$operatorName",
                      style: AppTypography.labelXs(context, color: AppColors.textSecondary),
                    ),
                    Text(
                      "${item['radiationFrequency']} MHz",
                      style: AppTypography.labelXs(context, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
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
    final addressText = description.isNotEmpty ? '$locality - $description' : locality;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Semantics(
        label: 'Permit application at $addressText',
        child: GlassmorphicCard(
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
                      style: AppTypography.headlineMd(context, color: AppColors.textPrimary)
                          .copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withAlpha(80)),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTypography.labelXs(context, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  addressText,
                  style: AppTypography.bodySm(context, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${appState.translate('permit_operator')}$operator",
                      style: AppTypography.labelXs(context, color: AppColors.textSecondary),
                    ),
                    Text(
                      "${appState.translate('permit_type')}${item['focalPointType']}",
                      style: AppTypography.labelXs(context, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
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

  RadarGridPainter({required this.angle, required this.records, required this.isDark});

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
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), paintGrid);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), paintGrid);

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

    // Draw Coordinate Pins Mock locations (projected into circle bounds)
    final pinPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final pinOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rand = math.Random(42); // Seed to guarantee static mockup positions

    for (int i = 0; i < math.min(records.length, 12); i++) {
      // Mock relative coordinates layout centered inside radar circle
      final double r = maxRadius * (0.2 + 0.7 * rand.nextDouble());
      final double a = rand.nextDouble() * 2 * math.pi;

      final offset = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );

      // Pulse fade effect relative to sweep sweep angle
      double diff = (a - angle) % (2 * math.pi);
      if (diff < 0) diff += 2 * math.pi;
      double intensity = math.max(0.15, 1.0 - (diff / (2 * math.pi)));

      pinPaint.color = AppColors.primary.withAlpha((intensity * 255).round());
      canvas.drawCircle(offset, 6.0, pinPaint);
      canvas.drawCircle(offset, 6.0, pinOutline..color = Colors.white.withAlpha((intensity * 255).round()));
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
                      Container(width: 100, height: 16, color: AppColors.surfaceHigh),
                      Container(width: 80, height: 16, color: AppColors.surfaceHigh),
                    ],
                  ),
                  Container(width: double.infinity, height: 14, color: AppColors.surfaceHigh),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 120, height: 12, color: AppColors.surfaceHigh),
                      Container(width: 60, height: 12, color: AppColors.surfaceHigh),
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
