import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/towers/presentation/pages/towers_page.dart';
import 'package:plainsight/features/directory/presentation/pages/liquidation_page.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';

class DashboardScreen extends StatelessWidget {
  final AppStateNotifier appState;

  const DashboardScreen({super.key, required this.appState});

  String _getDatasetTitle(DatasetMetadataModel item) {
    if (item.name == 'active_antennas') {
      return appState.translate('towers_title');
    } else if (item.name == 'companies_liquidation') {
      return appState.translate('water_title');
    } else if (item.name == 'government_budget') {
      return appState.translate('budget_title');
    }
    return item.title;
  }

  String _getDatasetDesc(DatasetMetadataModel item) {
    if (item.name == 'active_antennas') {
      return appState.translate('towers_desc');
    } else if (item.name == 'companies_liquidation') {
      return appState.translate('water_desc');
    } else if (item.name == 'government_budget') {
      return appState.translate('budget_desc');
    }
    return item.notes;
  }

  void _openDataset(BuildContext context, String id) {
    if (id == '8935c8e5-ec77-421f-af86-d970583195f8' ||
        id == 'ff398c7e-c522-4ee8-a53a-312b188a573d') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => TowersScreen(appState: appState),
        ),
      );
    } else if (id == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => LiquidationScreen(appState: appState),
        ),
      );
    }
  }

  Widget _buildFavoritesSection(BuildContext context) {
    final isRtl = appState.locale == 'he';
    final favIds = appState.favorites;

    if (favIds.isEmpty) {
      return GlassmorphicCard(
        startBorderColor: AppColors.textTertiary.withAlpha(50),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: AppColors.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRtl
                      ? 'אין מועדפים עדיין. עבור למדריך המאגרים כדי להוסיף!'
                      : 'No favorites yet. Go to Directory to add some!',
                  style: AppTypography.bodySm(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => appState.setActiveTab(1), // Move to Directory
                child: Text(
                  isRtl ? 'למדריך' : 'Go',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allRecords = appState.directoryRecords;
    final favRecords = allRecords.where((d) => favIds.contains(d.id)).toList();

    if (favRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: favRecords.map((item) {
        final isLiquidation = item.id == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDatasetCard(
            context,
            title: _getDatasetTitle(item),
            desc: _getDatasetDesc(item),
            badge: item.publisher,
            icon: isLiquidation ? Icons.gavel : Icons.cell_tower,
            accentColor: isLiquidation ? AppColors.danger : AppColors.primary,
            onTap: () => _openDataset(context, item.id),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentsSection(BuildContext context) {
    final recentIds = appState.recents;
    final allRecords = appState.directoryRecords;

    final List<DatasetMetadataModel> recentRecords = [];
    for (final id in recentIds) {
      final matches = allRecords.where((d) => d.id == id);
      if (matches.isNotEmpty) {
        recentRecords.add(matches.first);
      }
    }

    if (recentRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: recentRecords.map((item) {
          final isLiquidation =
              item.id == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3';
          final accentColor = isLiquidation
              ? AppColors.danger
              : AppColors.primary;
          return Container(
            width: 200,
            margin: const EdgeInsetsDirectional.only(end: 12.0),
            child: GlassmorphicCard(
              startBorderColor: accentColor,
              onTap: () => _openDataset(context, item.id),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLiquidation ? Icons.gavel : Icons.cell_tower,
                          color: accentColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDatasetTitle(item),
                            style: AppTypography.bodySm(
                              context,
                              color: AppColors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.publisher,
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSupportedSection(BuildContext context) {
    final allRecords = appState.directoryRecords;
    final supported = allRecords.where((d) => d.isSupported).toList();

    if (supported.isEmpty) {
      if (appState.isLoadingDirectory) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: supported.map((item) {
        final isLiquidation = item.id == 'd8715392-287f-49b7-9ae3-f21ec5bf55f3';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDatasetCard(
            context,
            title: _getDatasetTitle(item),
            desc: _getDatasetDesc(item),
            badge: item.publisher,
            icon: isLiquidation ? Icons.gavel : Icons.cell_tower,
            accentColor: isLiquidation ? AppColors.danger : AppColors.primary,
            onTap: () => _openDataset(context, item.id),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appState.locale == 'he';

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

            // Section 1: Favorites
            Text(
              isRtl ? 'מועדפים' : 'Favorites',
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildFavoritesSection(context),
            const SizedBox(height: 24),

            // Section 2: Recently Viewed
            if (appState.recents.isNotEmpty) ...[
              Text(
                isRtl ? 'נצפו לאחרונה' : 'Recently Viewed',
                style: AppTypography.headlineMd(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentsSection(context),
              const SizedBox(height: 24),
            ],

            // Section 3: Supported Highlight
            Text(
              isRtl ? 'מאגרי מידע נתמכים' : 'Supported Datasets',
              style: AppTypography.headlineMd(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRtl
                  ? 'מאגרי מידע ממשלתיים מתורגמים להדמיות אינטראקטיביות'
                  : 'Civic datasets translated to interactive visualizations',
              style: AppTypography.bodySm(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSupportedSection(context),
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
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
