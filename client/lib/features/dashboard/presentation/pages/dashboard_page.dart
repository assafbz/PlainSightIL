import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';

class DashboardScreen extends StatelessWidget {
  final AppStateNotifier appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Welcome Header
            Text(
              appState.translate('welcome_back'),
              style: AppTypography.labelXs(context, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              appState.translate('app_title'),
              style: AppTypography.headlineLg(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Hero Mission Card
            GlassmorphicCard(
              startBorderColor: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          appState.translate('mission_title'),
                          style: AppTypography.headlineMd(
                            context,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appState.translate('mission_subtitle'),
                      style: AppTypography.bodyLg(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Section Header
            Text(
              appState.translate('explore_datasets'),
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appState.translate('explore_cta'),
              style: AppTypography.bodySm(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Dataset Cards Grid / List
            // Using a clean ListView or Column to ensure perfect rendering on all screen sizes
            _buildDatasetCard(
              context,
              title: appState.translate('towers_title'),
              desc: appState.translate('towers_desc'),
              badge: appState.translate('towers_count'),
              icon: Icons.cell_tower,
              accentColor: AppColors.primary,
              onTap: () => appState.setActiveTab(1), // Index 1 is Towers
            ),
            const SizedBox(height: 12),
            _buildDatasetCard(
              context,
              title: appState.translate('water_title'),
              desc: appState.translate('water_desc'),
              badge: appState.translate('water_count'),
              icon: Icons.water_drop,
              accentColor: AppColors.info,
              onTap: () => appState.setActiveTab(2), // Index 2 is Water
            ),
            const SizedBox(height: 12),
            _buildDatasetCard(
              context,
              title: appState.translate('budget_title'),
              desc: appState.translate('budget_desc'),
              badge: appState.translate('budget_count'),
              icon: Icons.payments,
              accentColor: AppColors.secondary,
              onTap: () => appState.setActiveTab(3), // Index 3 is Budget
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetCard(
    BuildContext context, {
    required String title,
    required String desc,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      startBorderColor: accentColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            // Lead Icon with accent tint
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.bodyLg(
                            context,
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: AppTypography.labelXs(
                            context,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chevron end indicator
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
