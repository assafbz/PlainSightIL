import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/car_importer_record_model.dart';

/// Glassmorphic bottom drawer detail panel for a car importer record.
class CarImporterDetailDrawer extends StatelessWidget {
  /// The record model to display details for.
  final CarImporterRecordModel record;

  /// The active app state notifier for translations and styling properties.
  final AppStateNotifier appState;

  /// Constructor
  const CarImporterDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  /// Helper to format pricing to a localized string (e.g. 54,950 ₪).
  String _formatPrice(int? price) {
    if (price == null) return '';
    final isRtl = appState.locale == 'he';
    // Simple comma formatting
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = price.toString().replaceAllMapped(
      reg,
      (Match m) => '${m[1]},',
    );
    return isRtl ? '$formatted ₪' : '₪$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appState.locale == 'he';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        border: Border.all(color: AppColors.glassBorder, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle Indicator
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24.0),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withAlpha(80),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.commercialName.isNotEmpty
                                  ? record.commercialName
                                  : record.modelName,
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              record.makerName,
                              style: AppTypography.bodyLg(
                                context,
                                color: AppColors.primary,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ACC1).withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Color(0xFF00ACC1),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Vehicle Details
                  Text(
                    isRtl ? 'פרטי הרכב והמחיר' : 'Vehicle & Price Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (record.price != null)
                    _buildDetailRow(
                      context,
                      icon: Icons.monetization_on_outlined,
                      label: isRtl ? 'מחיר לצרכן: ' : 'Consumer Price: ',
                      value: _formatPrice(record.price),
                      valueColor: AppColors.success,
                    ),
                  if (record.productionYear != null)
                    _buildDetailRow(
                      context,
                      icon: Icons.calendar_today_outlined,
                      label: isRtl ? 'שנת יצור: ' : 'Production Year: ',
                      value: record.productionYear.toString(),
                    ),
                  _buildDetailRow(
                    context,
                    icon: Icons.directions_car_outlined,
                    label: isRtl ? 'שם הדגם: ' : 'Model Name: ',
                    value: record.modelName,
                  ),
                  if (record.modelCode != null)
                    _buildDetailRow(
                      context,
                      icon: Icons.tag,
                      label: isRtl ? 'קוד דגם: ' : 'Model Code: ',
                      value: record.modelCode.toString(),
                    ),
                  if (record.modelType.isNotEmpty)
                    _buildDetailRow(
                      context,
                      icon: Icons.class_outlined,
                      label: isRtl ? 'סוג דגם: ' : 'Model Type: ',
                      value: record.modelType,
                    ),
                  const SizedBox(height: 24),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Importer Details
                  Text(
                    isRtl ? 'פרטי היבואן' : 'Importer Information',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.business_outlined,
                    label: isRtl ? 'שם היבואן: ' : 'Importer Name: ',
                    value: record.importerName,
                  ),
                  if (record.importerCode != null)
                    _buildDetailRow(
                      context,
                      icon: Icons.pin_outlined,
                      label: isRtl ? 'קוד יבואן: ' : 'Importer Code: ',
                      value: record.importerCode.toString(),
                    ),
                  if (record.makerCode != null)
                    _buildDetailRow(
                      context,
                      icon: Icons.factory_outlined,
                      label: isRtl ? 'קוד יצרן: ' : 'Maker Code: ',
                      value: record.makerCode.toString(),
                    ),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 24),

                  // Source Info Card
                  GlassmorphicCard(
                    borderRadius: 16.0,
                    startBorderColor: AppColors.primary.withAlpha(120),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRtl
                                      ? 'משרד התחבורה והבטיחות בדרכים'
                                      : 'Ministry of Transport and Road Safety',
                                  style: AppTypography.bodySm(
                                    context,
                                    color: AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isRtl
                                ? 'מקור המידע: מאגר יבואנים ומחירוני רכב חדש של משרד התחבורה, פורטל המידע הממשלתי.'
                                : 'Source: New vehicle price lists and importer registry by Ministry of Transport, Gov Open Data.',
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Text(
                              'Resource ID: ${DatasetIds.carImporters}',
                              style: AppTypography.labelXs(
                                context,
                                color: AppColors.textTertiary,
                              ).copyWith(fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodySm(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLg(
                context,
                color: valueColor ?? AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
