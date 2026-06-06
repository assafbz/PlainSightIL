import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/travel_warning_model.dart';

/// Glassmorphic bottom drawer detail panel for a travel warning record.
class TravelWarningDetailDrawer extends StatelessWidget {
  /// The travel warning record model to display details for.
  final TravelWarningRecordModel record;

  /// The active app state notifier for translations and styling properties.
  final AppStateNotifier appState;

  /// Constructor
  const TravelWarningDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  /// Extracts the URL target from the details HTML anchor tag.
  String? _parseUrl(String detailsHtml) {
    if (detailsHtml.isEmpty) return null;
    final reg = RegExp(r'href="([^"]+)"');
    final match = reg.firstMatch(detailsHtml);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    if (detailsHtml.startsWith('http')) {
      return detailsHtml;
    }
    return null;
  }

  /// Helper to get semantic color based on risk warning level.
  Color _getWarningLevelColor(int level) {
    switch (level) {
      case 4:
        return AppColors.danger; // Critical threat
      case 3:
        return AppColors.warning; // High threat
      case 2:
        return AppColors.primary; // Moderate threat
      case 1:
      default:
        return AppColors.success; // Low risk / health info
    }
  }

  /// Helper to get localized warning level string.
  String _getWarningLevelLabel(BuildContext context, int level) {
    final isRtl = appState.locale == 'he';
    switch (level) {
      case 4:
        return isRtl ? 'רמה 4 - איום גבוה מאוד' : 'Level 4 - High Threat';
      case 3:
        return isRtl ? 'רמה 3 - איום בינוני' : 'Level 3 - Moderate Threat';
      case 2:
        return isRtl ? 'רמה 2 - איום מזדמן' : 'Level 2 - Occasional Threat';
      case 1:
      default:
        return isRtl
            ? 'רמה 1 - איום בסיסי / בריאות'
            : 'Level 1 - Low Threat / Health';
    }
  }

  /// Returns the corresponding icon for the publishing office.
  IconData _getOfficeIcon(String office) {
    if (office.contains('מל"ל') ||
        office.contains('בטחון') ||
        office.contains('ביטחון')) {
      return Icons.security_outlined;
    } else if (office.contains('חוץ')) {
      return Icons.public_outlined;
    } else if (office.contains('בריאות')) {
      return Icons.health_and_safety_outlined;
    }
    return Icons.info_outline;
  }

  /// Safely launches the official government link via url_launcher.
  Future<void> _launchAdvisoryUrl(
    BuildContext context,
    String urlString,
  ) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not launch URL');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error launching URL: $e');
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          message,
          style: AppTypography.bodySm(context, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appState.locale == 'he';
    final levelColor = _getWarningLevelColor(record.warningLevel);
    final levelLabel = _getWarningLevelLabel(context, record.warningLevel);
    final targetUrl = _parseUrl(
      record.details.isNotEmpty ? record.details : record.recommendations,
    );

    // Strip HTML tags from recommendations to display clean plain text
    final cleanRecommendations = record.recommendations
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    final dateToShow =
        (record.sourceUpdatedAt != null &&
            record.sourceUpdatedAt!.trim().isNotEmpty)
        ? record.sourceUpdatedAt!
        : (record.sourceCreatedAt != null &&
              record.sourceCreatedAt!.trim().isNotEmpty)
        ? record.sourceCreatedAt!
        : (record.date != null && record.date!.trim().isNotEmpty)
        ? record.date!
        : (record.lastUpdated != null && record.lastUpdated!.trim().isNotEmpty)
        ? record.lastUpdated!
        : (record.createdAt != null && record.createdAt!.trim().isNotEmpty)
        ? record.createdAt!
        : '';

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

                  // Header Section: Country & Warning Level
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.country,
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Risk Level Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: levelColor.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                levelLabel,
                                style: AppTypography.labelXs(
                                  context,
                                  color: levelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Office Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: levelColor.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getOfficeIcon(record.office),
                          color: levelColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Details Section
                  Text(
                    isRtl ? 'פרטי אזהרת מסע' : 'Travel Warning Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildDetailRow(
                    context,
                    icon: Icons.public_outlined,
                    label: appState.translate('continent_label'),
                    value: record.continent,
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.account_balance_outlined,
                    label: appState.translate('office_label'),
                    value: record.office.isNotEmpty ? record.office : 'לא ידוע',
                  ),
                  if (dateToShow.isNotEmpty)
                    _buildDetailRow(
                      context,
                      icon: Icons.calendar_today_outlined,
                      label: appState.translate('date_label'),
                      value: dateToShow.length >= 10
                          ? dateToShow.substring(0, 10)
                          : dateToShow,
                    ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // Recommendations Text Block
                  Text(
                    isRtl
                        ? 'הנחיות והמלצות לפעולה:'
                        : 'Guidelines & Recommendations:',
                    style: AppTypography.bodyLg(
                      context,
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow.withAlpha(120),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      cleanRecommendations.isNotEmpty
                          ? cleanRecommendations
                          : (isRtl
                                ? 'אין הנחיות מפורטות.'
                                : 'No detailed guidelines provided.'),
                      style: AppTypography.bodySm(
                        context,
                        color: AppColors.textSecondary,
                      ).copyWith(height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Button to open Link if available
                  if (targetUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withAlpha(30),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.primary.withAlpha(120),
                              width: 1.5,
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _launchAdvisoryUrl(context, targetUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          isRtl ? 'פתח אזהרה רשמית' : 'View Official Advisory',
                          style: AppTypography.bodySm(
                            context,
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Attribution Panel
                  GlassmorphicCard(
                    borderRadius: 16.0,
                    startBorderColor: levelColor.withAlpha(120),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: levelColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRtl
                                      ? 'מקור המידע הממשלתי'
                                      : 'Government Data Source',
                                  style: AppTypography.bodySm(
                                    context,
                                    color: AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRtl
                                ? 'נתוני אזהרות מסע מאוחדים מפורסמים על ידי המטה לביטחון לאומי (מל"ל), משרד הבריאות ומשרד החוץ כחלק מיוזמת המידע הפתוח.'
                                : 'Combined travel warning datasets are published by the National Security Council (NSC), Ministry of Health, and Ministry of Foreign Affairs.',
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Resource ID: ${DatasetIds.travelWarnings}',
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.textTertiary,
                            ).copyWith(fontFamily: 'Outfit'),
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
              ).copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
