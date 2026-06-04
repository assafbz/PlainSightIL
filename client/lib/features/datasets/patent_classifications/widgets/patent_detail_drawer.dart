import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/patent_classification_model.dart';

/// Glassmorphic bottom drawer detail panel for a patent classification record.
class PatentDetailDrawer extends StatelessWidget {
  /// The patent classification record model to display details for.
  final PatentClassificationRecordModel record;

  /// The active app state notifier for translations and styling properties.
  final AppStateNotifier appState;

  /// Constructor
  const PatentDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

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

                  // Header Title Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.cpcClassification,
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ).copyWith(fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 8),
                            // Primary / Secondary Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: record.isPrimary
                                    ? AppColors.primary.withAlpha(20)
                                    : AppColors.secondary.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: record.isPrimary
                                      ? AppColors.primary.withAlpha(80)
                                      : AppColors.secondary.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                record.isPrimary
                                    ? appState.translate('patent_is_primary')
                                    : appState.translate('patent_is_secondary'),
                                style: AppTypography.labelXs(
                                  context,
                                  color: record.isPrimary
                                      ? AppColors.primary
                                      : AppColors.secondary,
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
                          color: AppColors.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.gavel_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Application Info
                  Text(
                    isRtl ? 'פרטי בקשת פטנט' : 'Patent Application Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.assignment_outlined,
                    label: appState.translate('patent_app_num_label'),
                    value: record.applicationNumber.toString(),
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.qr_code_outlined,
                    label: appState.translate('patent_class_label'),
                    value: record.cpcClassification,
                  ),
                  const SizedBox(height: 20),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Invention Titles
                  Text(
                    isRtl ? 'שם האמצאה' : 'Invention Titles',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (record.titleHebrew.isNotEmpty)
                    _buildTitleBlock(
                      context,
                      label: appState.translate('patent_title_he'),
                      value: record.titleHebrew,
                      isHebrew: true,
                    ),
                  if (record.titleEnglish.isNotEmpty)
                    _buildTitleBlock(
                      context,
                      label: appState.translate('patent_title_en'),
                      value: record.titleEnglish,
                      isHebrew: false,
                    ),
                  const SizedBox(height: 24),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 24),

                  // Data Provenance / Source Card
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
                                  appState.translate(
                                    'patent_classifications_publisher',
                                  ),
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
                                ? 'מקור המידע: רשות הפטנטים - סיווגי CPC לבקשות פטנט, פורטל המידע הממשלתי.'
                                : 'Source: Israel Patent Office - CPC Classifications for Patent Applications, Gov Open Data.',
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
                              'Resource ID: ${DatasetIds.patentClassifications}',
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
                color: AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock(
    BuildContext context, {
    required String label,
    required String value,
    required bool isHebrew,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySm(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow.withAlpha(60),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              value,
              style: AppTypography.bodyLg(context, color: AppColors.textPrimary)
                  .copyWith(
                    fontWeight: FontWeight.w500,
                    fontFamily: isHebrew ? 'Assistant' : 'Outfit',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
