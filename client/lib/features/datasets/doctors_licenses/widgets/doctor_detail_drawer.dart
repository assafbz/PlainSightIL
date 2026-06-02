import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/doctor_license_model.dart';

/// Glassmorphic bottom drawer detail panel for a doctor's license record.
class DoctorDetailDrawer extends StatelessWidget {
  /// The doctor's license record model to display details for.
  final DoctorLicenseRecordModel record;

  /// The active app state notifier for translations and styling properties.
  final AppStateNotifier appState;

  /// Constructor
  const DoctorDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  /// Helper to format date strings to a readable YYYY-MM-DD or DD/MM/YYYY format.
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
    final hasSpecialty =
        record.specialtyName != null && record.specialtyName!.isNotEmpty;

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
                              '${isRtl ? "ד\"ר" : "Dr."} ${record.firstName} ${record.lastName}',
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Active Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                appState.translate('doctor_licensed'),
                                style: AppTypography.labelXs(
                                  context,
                                  color: AppColors.success,
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
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 20),

                  // License Info Card
                  Text(
                    isRtl ? 'פרטי רישיון רופא' : 'Medical License Details',
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.assignment_ind_outlined,
                    label: appState.translate('license_num_label'),
                    value: record.licenseNumber.toString(),
                  ),
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: appState.translate('license_date_label'),
                    value: _formatDate(record.licenseRegistrationDate),
                  ),
                  const SizedBox(height: 24),

                  // Specialties Section
                  if (hasSpecialty) ...[
                    const Divider(color: Color(0x14FFFFFF), height: 1),
                    const SizedBox(height: 20),
                    Text(
                      isRtl ? 'התמחות רפואית' : 'Medical Specialty',
                      style: AppTypography.headlineMd(
                        context,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      icon: Icons.medical_services_outlined,
                      label: isRtl ? 'שם התמחות: ' : 'Specialty: ',
                      value: record.specialtyName!,
                      valueColor: AppColors.secondary,
                    ),
                    if (record.specialtyCertificateNumber != null)
                      _buildDetailRow(
                        context,
                        icon: Icons.workspace_premium_outlined,
                        label: appState.translate('specialty_cert_label'),
                        value: record.specialtyCertificateNumber.toString(),
                      ),
                    if (record.specialtyRegistrationDate != null &&
                        record.specialtyRegistrationDate!.isNotEmpty)
                      _buildDetailRow(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: appState.translate('specialty_date_label'),
                        value: _formatDate(record.specialtyRegistrationDate!),
                      ),
                    const SizedBox(height: 24),
                  ],

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
                                  appState.translate('doctors_publisher'),
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
                                ? 'מקור המידע: משרד הבריאות - מאגר מורשי תעסוקה במקצועות הרפואה, פורטל המידע הממשלתי.'
                                : 'Source: Ministry of Health - Licensed Healthcare Practitioners Registry, Gov Open Data.',
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
                              'Resource ID: ${DatasetIds.doctorsLicenses}',
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
