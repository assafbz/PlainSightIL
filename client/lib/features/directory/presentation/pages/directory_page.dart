import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';
import 'package:plainsight/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart';
import 'package:plainsight/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart';
import 'package:plainsight/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart';
import 'package:plainsight/features/datasets/bank_atms/pages/bank_atms_page.dart';
import '../widgets/dataset_card.dart';

class DatasetDirectoryScreen extends StatefulWidget {
  final AppStateNotifier appState;

  const DatasetDirectoryScreen({super.key, required this.appState});

  @override
  State<DatasetDirectoryScreen> createState() => _DatasetDirectoryScreenState();
}

class _DatasetDirectoryScreenState extends State<DatasetDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Supported, 1: Requests
  final Set<String> _requestingIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DatasetMetadataModel> _getFilteredDatasets() {
    final allRecords = widget.appState.directoryRecords;

    // Apply tab filter first
    List<DatasetMetadataModel> filtered = [];
    if (_selectedFilterIndex == 0) {
      filtered = allRecords.where((d) => d.isSupported).toList();
    } else {
      filtered = allRecords.where((d) => !d.isSupported).toList();
    }

    // Apply text search
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase();

    return filtered.where((d) {
      final title = d.title.toLowerCase();
      final notes = d.notes.toLowerCase();
      final publisher = d.publisher.toLowerCase();
      final tags = d.tags.map((t) => t.toLowerCase()).join(' ');

      return title.contains(query) ||
          notes.contains(query) ||
          publisher.contains(query) ||
          tags.contains(query);
    }).toList();
  }

  Future<void> _handleVote(DatasetMetadataModel dataset) async {
    if (_requestingIds.contains(dataset.id)) return;

    setState(() {
      _requestingIds.add(dataset.id);
    });

    final success = await widget.appState.requestDatasetActivation(
      dataset.id,
      dataset.title,
    );

    setState(() {
      _requestingIds.remove(dataset.id);
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.appState.translate('request_success'),
                  style: AppTypography.bodySm(context, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      } else {
        // SnackBar for duplicate votes or general errors
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              isRtl
                  ? 'כבר הגשת בקשה עבור מאגר זה'
                  : 'You have already requested this dataset',
              style: AppTypography.bodySm(context, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _handleDeepLink(DatasetMetadataModel dataset) {
    if (dataset.id == DatasetIds.cellularAntennas ||
        dataset.id == DatasetIds.cellularPermits) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              CellularAntennasScreen(appState: widget.appState),
        ),
      );
    } else if (dataset.id == DatasetIds.companiesLiquidation) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              CompaniesLiquidationScreen(appState: widget.appState),
        ),
      );
    } else if (dataset.id == DatasetIds.doctorsLicenses) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              DoctorsLicensesScreen(appState: widget.appState),
        ),
      );
    } else if (dataset.id == '21fde05f-62e3-401b-81cf-5c385862026d') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BankAtmsScreen(appState: widget.appState),
        ),
      );
    }
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(40)
              : AppColors.surfaceLow.withAlpha(120),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withAlpha(120)
                : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm(context, color: color).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.find_in_page_outlined,
                size: 72,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                isRtl ? 'לא נמצאו מאגרי מידע' : 'No Datasets Found',
                style: AppTypography.headlineMd(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRtl
                    ? 'לא מצאת את מה שחיפשת? בקש הנגשה למאגר מידע חדש.'
                    : 'Can\'t find what you are looking for? Request activation for a new dataset.',
                style: AppTypography.bodySm(
                  context,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilterIndex = 1; // Jump to Requests tab
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  isRtl ? 'הצע מאגר מידע חדש' : 'Propose New Dataset',
                  style: AppTypography.labelXs(
                    context,
                    color: AppColors.onPrimary,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _getFilteredDatasets();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title / Header
          Text(
            widget.appState.translate('directory_title'),
            style: AppTypography.headlineLg(
              context,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // 2. Glassmorphic Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow.withAlpha(100),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.appState.translate('search_hint'),
                      hintStyle: AppTypography.bodySm(
                        context,
                        color: AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Horizontal Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(0, widget.appState.translate('filter_active')),
                _buildFilterChip(
                  1,
                  widget.appState.translate('filter_inactive'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Scrollable List of Cards
          Expanded(
            child: ListenableBuilder(
              listenable: widget.appState,
              builder: (context, _) {
                if (widget.appState.isLoadingDirectory) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (list.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80.0),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final reqCount = widget.appState.getRequestCount(item.id);
                    final isReq = _requestingIds.contains(item.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: DatasetCard(
                        dataset: item,
                        requestCount: reqCount,
                        isRequesting: isReq,
                        currentLocale: widget.appState.locale,
                        translate: widget.appState.translate,
                        isFavorite: widget.appState.isFavorite(item.id),
                        onFavoriteToggle: () {
                          widget.appState.toggleFavorite(item.id);
                        },
                        onTapAction: () {
                          if (item.isSupported) {
                            _handleDeepLink(item);
                          } else {
                            _handleVote(item);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
