import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import '../data/models/local_market_bond_model.dart';

/// Bottom sheet drawer displaying detailed specifications and auction results for a selected bond record.
class BondDetailDrawer extends StatelessWidget {
  /// The selected bond record model.
  final LocalMarketBondRecordModel record;

  /// The global app state coordinator.
  final AppStateNotifier appState;

  /// Constructor
  const BondDetailDrawer({
    super.key,
    required this.record,
    required this.appState,
  });

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: AppTypography.bodyLg(
          context,
          color: AppColors.primary,
        ).copyWith(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
      ),
    );
  }

  Widget _buildFieldRow(
    BuildContext context,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                  fontWeight: FontWeight.w600,
                  fontFamily: isMonospace ? 'Courier' : 'Outfit',
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final locale = appState.locale;
    final typeName = record.bondType[locale] ?? record.bondType['en'] ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
      ),
      child: Column(
        children: [
          // Drag indicator
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withAlpha(100),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appState.translate("bond_series_label")}${record.series}',
                        style:
                            AppTypography.headlineMd(
                              context,
                              color: AppColors.textPrimary,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeName,
                        style: AppTypography.bodySm(
                          context,
                          color: AppColors.secondary,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0x14FFFFFF)),

          // Scrollable body
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              children: [
                // Section 1: Specifications
                _buildSectionHeader(
                  context,
                  isRtl ? 'מפרט איגרת החוב' : 'Bond Specifications',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_series_label'),
                  record.series.toString(),
                  isMonospace: true,
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_type_label'),
                  typeName,
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_issuance_date'),
                  _formatDate(record.issuanceDate),
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_redemption_date'),
                  _formatDate(record.redemptionDate),
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_term_to_maturity'),
                  '${record.actualTermToMaturity.toStringAsFixed(1)}${appState.translate("bond_years")}',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_coupon'),
                  '${record.coupon.toStringAsFixed(2)}%',
                ),
                const Divider(color: Color(0x14FFFFFF), height: 24),

                // Section 2: Auction Volumes
                _buildSectionHeader(
                  context,
                  isRtl ? 'כמויות במכרז' : 'Auction Volumes',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_offered'),
                  '${record.offeredQuantity.toStringAsFixed(1)} ${appState.translate("bond_millions_ils")}',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_purchased'),
                  '${record.purchasedQuantity.toStringAsFixed(1)} ${appState.translate("bond_millions_ils")}',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_demand'),
                  '${record.demandedAmount.toStringAsFixed(1)} ${appState.translate("bond_millions_ils")}',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_cover_ratio'),
                  record.coverRatio.toStringAsFixed(2),
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_additional_purchased'),
                  '${record.additionalPurchased.toStringAsFixed(1)} ${appState.translate("bond_millions_ils")}',
                ),
                const Divider(color: Color(0x14FFFFFF), height: 24),

                // Section 3: Yields & Pricing
                _buildSectionHeader(
                  context,
                  isRtl ? 'תמחור ותשואות' : 'Pricing & Yields',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_avg_price'),
                  record.averagePrice.toStringAsFixed(2),
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_cutoff_price'),
                  record.cutoffPrice.toStringAsFixed(2),
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_avg_yield'),
                  '${record.grossAvgYield.toStringAsFixed(2)}%',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_cutoff_yield'),
                  '${record.grossCutoffYield.toStringAsFixed(2)}%',
                ),
                _buildFieldRow(
                  context,
                  appState.translate('bond_total_funding'),
                  '${record.totalFunding.toStringAsFixed(2)} ${appState.translate("bond_millions_ils")}',
                ),
                const SizedBox(height: 32),

                // Attribution footer
                Center(
                  child: Text(
                    '${appState.translate("attribution_prefix")}${appState.translate("local_market_bonds_publisher")}',
                    style: AppTypography.labelXs(
                      context,
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
