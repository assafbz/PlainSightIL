import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';
import 'package:plainsight/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart';
import 'package:plainsight/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart';
import 'package:plainsight/features/datasets/bank_atms/pages/bank_atms_page.dart';
import 'package:plainsight/features/datasets/patent_classifications/pages/patent_classifications_page.dart';
import 'package:plainsight/features/datasets/car_importers/pages/car_importers_page.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';

class DashboardScreen extends StatelessWidget {
  final AppStateNotifier appState;

  const DashboardScreen({super.key, required this.appState});

  String _getDatasetTitle(DatasetMetadataModel item) {
    if (item.name == 'active_antennas' ||
        item.id == DatasetIds.cellularAntennas) {
      return appState.translate('towers_title');
    } else if (item.name == 'companies_liquidation' ||
        item.name == 'pr2018' ||
        item.id == DatasetIds.companiesLiquidation) {
      return appState.translate('water_title');
    } else if (item.name == 'government_budget') {
      return appState.translate('budget_title');
    } else if (item.id == DatasetIds.doctorsLicenses) {
      return appState.translate('doctors_title');
    } else if (item.id == '21fde05f-62e3-401b-81cf-5c385862026d') {
      return appState.translate('atm_title');
    } else if (item.id == DatasetIds.patentClassifications) {
      return appState.translate('patent_classifications_title');
    } else if (item.id == DatasetIds.carImporters) {
      return appState.translate('car_importers_title');
    }
    return item.title;
  }

  String _getDatasetDesc(DatasetMetadataModel item) {
    if (item.name == 'active_antennas' ||
        item.id == DatasetIds.cellularAntennas) {
      return appState.translate('towers_desc');
    } else if (item.name == 'companies_liquidation' ||
        item.name == 'pr2018' ||
        item.id == DatasetIds.companiesLiquidation) {
      return appState.translate('water_desc');
    } else if (item.name == 'government_budget') {
      return appState.translate('budget_desc');
    } else if (item.id == DatasetIds.doctorsLicenses) {
      return appState.translate('doctors_desc');
    } else if (item.id == '21fde05f-62e3-401b-81cf-5c385862026d') {
      return appState.translate('atm_desc');
    } else if (item.id == DatasetIds.patentClassifications) {
      return appState.translate('patent_classifications_desc');
    } else if (item.id == DatasetIds.carImporters) {
      return appState.translate('car_importers_desc');
    }
    return item.notes;
  }

  void _openDataset(BuildContext context, String id) {
    if (id == DatasetIds.cellularAntennas || id == DatasetIds.cellularPermits) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => CellularAntennasScreen(appState: appState),
        ),
      );
    } else if (id == DatasetIds.companiesLiquidation) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => CompaniesLiquidationScreen(appState: appState),
        ),
      );
    } else if (id == DatasetIds.doctorsLicenses) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => DoctorsLicensesScreen(appState: appState),
        ),
      );
    } else if (id == '21fde05f-62e3-401b-81cf-5c385862026d') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BankAtmsScreen(appState: appState),
        ),
      );
    } else if (id == DatasetIds.patentClassifications) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PatentClassificationsScreen(appState: appState),
        ),
      );
    } else if (id == DatasetIds.carImporters) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => CarImportersScreen(appState: appState),
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
        final isLiquidation = item.id == DatasetIds.companiesLiquidation;
        final isDoctors = item.id == DatasetIds.doctorsLicenses;
        final isAtm = item.id == '21fde05f-62e3-401b-81cf-5c385862026d';
        final isPatent = item.id == DatasetIds.patentClassifications;
        final isCar = item.id == DatasetIds.carImporters;
        final icon = isAtm
            ? Icons.atm
            : (isDoctors
                  ? Icons.badge_outlined
                  : (isLiquidation
                        ? Icons.gavel
                        : (isPatent
                              ? Icons.category
                              : (isCar
                                    ? Icons.directions_car
                                    : Icons.cell_tower))));
        final accentColor = isAtm
            ? const Color(0xFF2E7D32)
            : (isLiquidation
                  ? AppColors.danger
                  : (isPatent
                        ? const Color(0xFF673AB7)
                        : (isCar
                              ? const Color(0xFF00ACC1)
                              : AppColors.primary)));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDatasetCard(
            context,
            title: _getDatasetTitle(item),
            desc: _getDatasetDesc(item),
            badge: item.publisher,
            icon: icon,
            accentColor: accentColor,
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
          final isLiquidation = item.id == DatasetIds.companiesLiquidation;
          final isDoctors = item.id == DatasetIds.doctorsLicenses;
          final isAtm = item.id == '21fde05f-62e3-401b-81cf-5c385862026d';
          final isPatent = item.id == DatasetIds.patentClassifications;
          final isCar = item.id == DatasetIds.carImporters;
          final accentColor = isAtm
              ? const Color(0xFF2E7D32)
              : (isLiquidation
                    ? AppColors.danger
                    : (isPatent
                          ? const Color(0xFF673AB7)
                          : (isCar
                                ? const Color(0xFF00ACC1)
                                : AppColors.primary)));
          final icon = isAtm
              ? Icons.atm
              : (isDoctors
                    ? Icons.badge_outlined
                    : (isLiquidation
                          ? Icons.gavel
                          : (isPatent
                                ? Icons.category
                                : (isCar
                                      ? Icons.directions_car
                                      : Icons.cell_tower))));
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
                        Icon(icon, color: accentColor, size: 16),
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
        final isLiquidation = item.id == DatasetIds.companiesLiquidation;
        final isDoctors = item.id == DatasetIds.doctorsLicenses;
        final isAtm = item.id == '21fde05f-62e3-401b-81cf-5c385862026d';
        final isPatent = item.id == DatasetIds.patentClassifications;
        final isCar = item.id == DatasetIds.carImporters;
        final icon = isAtm
            ? Icons.atm
            : (isDoctors
                  ? Icons.badge_outlined
                  : (isLiquidation
                        ? Icons.gavel
                        : (isPatent
                              ? Icons.category
                              : (isCar
                                    ? Icons.directions_car
                                    : Icons.cell_tower))));
        final accentColor = isAtm
            ? const Color(0xFF2E7D32)
            : (isLiquidation
                  ? AppColors.danger
                  : (isPatent
                        ? const Color(0xFF673AB7)
                        : (isCar
                              ? const Color(0xFF00ACC1)
                              : AppColors.primary)));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDatasetCard(
            context,
            title: _getDatasetTitle(item),
            desc: _getDatasetDesc(item),
            badge: item.publisher,
            icon: icon,
            accentColor: accentColor,
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
