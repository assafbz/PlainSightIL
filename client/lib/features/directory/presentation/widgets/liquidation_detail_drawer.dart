import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import '../../data/models/liquidation_record_model.dart';

class LiquidationDetailDrawer extends StatelessWidget {
  final LiquidationRecordModel record;
  final AppStateNotifier appState;

  const LiquidationDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'פירוק פעיל':
      case 'Active Winding Up':
        return AppColors.danger;
      case 'הקפאה':
      case 'הקפאת הליכים':
      case 'Frozen':
        return AppColors.warning;
      case 'סגור':
      case 'תיק סגור':
      case 'Closed':
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySm(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySm(context, color: AppColors.textPrimary)
                .copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: appState.locale == 'en' ? 'Outfit' : 'Assistant',
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appState.locale == 'he';
    final statusString = isRtl
        ? record.caseStatus['he']!
        : record.caseStatus['en']!;
    final statusColor = _getStatusColor(record.caseStatus['he']!);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        border: Border.all(color: AppColors.glassBorder, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withAlpha(50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Company Name
                  Text(
                    record.companyName,
                    style: AppTypography.headlineLg(
                      context,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 8),

                  // 3. Company H.P. & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isRtl ? 'ח.פ. ' : 'H.P. '}${record.companyId}',
                        style:
                            AppTypography.bodyLg(
                              context,
                              color: AppColors.primary,
                            ).copyWith(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withAlpha(120),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          statusString,
                          style: AppTypography.labelXs(
                            context,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppColors.glassBorder),
                  const SizedBox(height: 12),

                  // 4. Details
                  _buildDetailRow(
                    context,
                    appState.translate('case_id_label'),
                    '${record.liquidationCaseId}',
                  ),
                  _buildDetailRow(
                    context,
                    appState.translate('court_label'),
                    record.districtCourt,
                  ),
                  _buildDetailRow(
                    context,
                    appState.translate('city_label'),
                    record.cityOfActivity,
                  ),
                  _buildDetailRow(
                    context,
                    isRtl ? 'תאריך הגשה: ' : 'Submission Date: ',
                    record.submissionDate.length >= 10
                        ? record.submissionDate.substring(0, 10)
                        : record.submissionDate,
                  ),
                  _buildDetailRow(
                    context,
                    isRtl ? 'תאריך צו פירוק: ' : 'Liquidation Order Date: ',
                    record.liquidationOrderDate.length >= 10
                        ? record.liquidationOrderDate.substring(0, 10)
                        : record.liquidationOrderDate,
                  ),

                  if (record.cancellationFreezeDate != null &&
                      record.cancellationFreezeDate!.isNotEmpty)
                    _buildDetailRow(
                      context,
                      isRtl
                          ? 'תאריך הקפאה/ביטול: '
                          : 'Freeze/Cancellation Date: ',
                      record.cancellationFreezeDate!.substring(0, 10),
                    ),

                  if (record.closureDate != null &&
                      record.closureDate!.isNotEmpty)
                    _buildDetailRow(
                      context,
                      isRtl ? 'תאריך סגירה: ' : 'Closure Date: ',
                      record.closureDate!.substring(0, 10),
                    ),

                  if (record.closureReason != null &&
                      record.closureReason!.isNotEmpty)
                    _buildDetailRow(
                      context,
                      appState.translate('closure_reason_prefix'),
                      record.closureReason!,
                    ),

                  const SizedBox(height: 24),
                  Divider(color: AppColors.glassBorder),
                  const SizedBox(height: 16),

                  // 5. Action Button (View Official Court File)
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
                      onPressed: () {
                        // Action placeholder
                      },
                      icon: const Icon(Icons.gavel),
                      label: Text(
                        appState.translate('view_court_file'),
                        style: AppTypography.bodySm(
                          context,
                          color: AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Data Source Attribution
                  Center(
                    child: Text(
                      '${appState.translate('attribution_prefix')}${appState.translate('trustee_publisher')}',
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.textTertiary,
                      ).copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
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
}
