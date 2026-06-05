import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/vehicle_recall_model.dart';

/// Glassmorphic bottom drawer detail panel for a vehicle recall record.
class VehicleRecallDetailDrawer extends StatelessWidget {
  /// The vehicle recall record model to display details for.
  final VehicleRecallRecordModel record;

  /// The active app state notifier for translations and styling properties.
  final AppStateNotifier appState;

  /// Constructor
  const VehicleRecallDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  /// Helper to format date strings to a readable DD/MM/YYYY format.
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final parsed = DateTime.parse(isoDate);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      if (isoDate.length >= 10) return isoDate.substring(0, 10);
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appState.locale == 'he';
    final recallTypeStr = record.recallType[isRtl ? 'he' : 'en'] ?? '';

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

                  // Header Profile Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${record.manufacturerName} ${record.modelName}',
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ).copyWith(fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 8),
                            // Recall Type Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.danger.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                recallTypeStr,
                                style: AppTypography.labelXs(
                                  context,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Large Icon representation
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_outlined,
                          color: AppColors.danger,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Recall Details
                  Text(
                    isRtl ? 'פרטי קריאת השירות' : 'Recall Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.qr_code_outlined,
                    label: appState.translate('recall_id_label'),
                    value: record.recallId.toString(),
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: appState.translate('recall_year_label'),
                    value: record.recallYear.toString(),
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.date_range_outlined,
                    label: isRtl ? 'טווח ייצור מתאריך: ' : 'Build Start Date: ',
                    value: _formatDate(record.buildStartDate),
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.date_range_outlined,
                    label: isRtl ? 'טווח ייצור עד תאריך: ' : 'Build End Date: ',
                    value: _formatDate(record.buildEndDate),
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Technical Details
                  Text(
                    isRtl ? 'פרטים טכניים ואופן תיקון' : 'Technical Info & Fix',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.category_outlined,
                    label: appState.translate('recall_defect_label'),
                    value: record.defectCategory,
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.build_outlined,
                    label: appState.translate('recall_fix_label'),
                    value: record.repairAction,
                  ),
                  if (record.euCategory.isNotEmpty)
                    _buildDetailRow(
                      context,
                      icon: Icons.rule_folder_outlined,
                      label: appState.translate('recall_eu_category_label'),
                      value: record.euCategory,
                    ),
                  if (record.defectDescription.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      isRtl ? 'תיאור התקלה:' : 'Defect Description:',
                      style: AppTypography.bodySm(
                        context,
                        color: AppColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.defectDescription,
                      style: AppTypography.bodySm(
                        context,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Importer Details
                  Text(
                    isRtl
                        ? 'פרטי היבואן וליצירת קשר'
                        : 'Importer & Contact Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.business_outlined,
                    label: appState.translate('recall_importer_label'),
                    value: record.importerName,
                  ),
                  if (record.importerPhone.isNotEmpty)
                    _buildDetailRow(
                      context,
                      icon: Icons.phone_outlined,
                      label: appState.translate('recall_phone_label'),
                      value: record.importerPhone,
                    ),
                  if (record.importerWebsite.isNotEmpty)
                    _buildDetailRow(
                      context,
                      icon: Icons.language_outlined,
                      label: appState.translate('recall_website_label'),
                      value: record.importerWebsite,
                    ),
                  const SizedBox(height: 24),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 24),

                  // Data Provenance / Source Card
                  GlassmorphicCard(
                    borderRadius: 16.0,
                    startBorderColor: AppColors.danger.withAlpha(120),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  appState.translate('recalls_publisher'),
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
                                ? 'מקור המידע: משרד התחבורה - הודעות יצרני הרכב Recall, פורטל המידע הממשלתי.'
                                : 'Source: Ministry of Transport - Vehicle Recalls Registry, Gov Open Data.',
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Source GUID pill
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
                              'Resource ID: ${DatasetIds.vehicleRecalls}',
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
