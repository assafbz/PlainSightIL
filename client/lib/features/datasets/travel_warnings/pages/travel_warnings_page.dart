import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/travel_warning_model.dart';
import '../widgets/travel_warning_detail_drawer.dart';

/// Screen displaying the global travel warnings list with searching, continent filtering, and detail drawers.
class TravelWarningsScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;
  final String? initialSelectedId;

  /// Constructor
  const TravelWarningsScreen({
    super.key,
    required this.appState,
    this.initialSelectedId,
  });

  @override
  State<TravelWarningsScreen> createState() => _TravelWarningsScreenState();
}

class _TravelWarningsScreenState extends State<TravelWarningsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedContinent = 'All'; // 'All' represents no continent filtering
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    // Register the dataset in recent history
    widget.appState.addRecent(DatasetIds.travelWarnings);
    widget.appState.initTravelWarningsListener();
    if (widget.initialSelectedId != null) {
      widget.appState.addListener(_handleDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleDeepLink);
    widget.appState.cancelTravelWarningsListener();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleDeepLink() {
    if (_deepLinkHandled || widget.initialSelectedId == null) return;
    if (widget.appState.isLoadingWarnings) return;

    final records = widget.appState.warningRecords;
    if (records.isEmpty) return;

    TravelWarningRecordModel? targetRecord;
    for (final r in records) {
      if (r.id == widget.initialSelectedId ||
          r.country == widget.initialSelectedId) {
        targetRecord = r;
        break;
      }
    }

    if (targetRecord != null) {
      _deepLinkHandled = true;
      widget.appState.removeListener(_handleDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDetails(targetRecord!);
      });
    }
  }

  /// Extracts unique continent names present in the records to build filter chips.
  List<String> _getUniqueContinents() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = widget.appState.warningRecords;

    final Set<String> continents = {};
    for (final r in allRecords) {
      if (r.continent.isNotEmpty) {
        continents.add(r.continent);
      }
    }

    final sortedContinents = continents.toList()..sort();
    return [isRtl ? 'הכל' : 'All', ...sortedContinents];
  }

  /// Filters loaded travel warning records based on search keywords and selected continent chip.
  List<TravelWarningRecordModel> _getFilteredRecords() {
    final allRecords = widget.appState.warningRecords;
    final isRtl = widget.appState.locale == 'he';
    final defaultFilter = isRtl ? 'הכל' : 'All';

    // 1. Continent Filter
    List<TravelWarningRecordModel> filtered = allRecords;
    if (_selectedContinent != defaultFilter && _selectedContinent != 'All') {
      filtered = allRecords
          .where((r) => r.continent == _selectedContinent)
          .toList();
    }

    // 2. Search Text Filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final country = r.country.toLowerCase();
      final continent = r.continent.toLowerCase();
      final recommendations = r.recommendations.toLowerCase();
      final office = r.office.toLowerCase();

      return country.contains(query) ||
          continent.contains(query) ||
          recommendations.contains(query) ||
          office.contains(query);
    }).toList();
  }

  /// Opens the glassmorphic detail drawer bottom sheet for the selected record.
  void _showDetails(TravelWarningRecordModel record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => TravelWarningDetailDrawer(
          record: record,
          appState: widget.appState,
        ),
      ),
    );
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
  String _getWarningLevelLabel(int level) {
    final isRtl = widget.appState.locale == 'he';
    switch (level) {
      case 4:
        return isRtl ? 'איום גבוה מאוד' : 'High Threat';
      case 3:
        return isRtl ? 'איום בינוני' : 'Moderate Threat';
      case 2:
        return isRtl ? 'איום מזדמן' : 'Occasional Threat';
      case 1:
      default:
        return isRtl ? 'איום בסיסי' : 'Low Threat';
    }
  }

  Widget _buildFilterChip(String continentName) {
    final isRtl = widget.appState.locale == 'he';
    final isSelected = _selectedContinent == continentName;
    final defaultText = isRtl ? 'הכל' : 'All';

    // Display 'All' correctly localized
    final displayLabel = (continentName == 'All' || continentName == 'הכל')
        ? defaultText
        : continentName;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedContinent = continentName;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8.0, left: 8.0),
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
          displayLabel,
          style: AppTypography.bodySm(context, color: labelColor).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Stack(
        children: [
          // Background Atmospheric Gradients
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(
                      0x1F2E7D32,
                    ), // subtle green/financial glow for travel warnings
                    AppColors.baseBg,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Navigation Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.appState.translate('travel_warnings_title'),
                          style: AppTypography.headlineLg(
                            context,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: widget.appState,
                        builder: (context, _) {
                          final isFav = widget.appState.isFavorite(
                            DatasetIds.travelWarnings,
                          );
                          final isSubbed = widget.appState.isSubscribed(
                            DatasetIds.travelWarnings,
                          );
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: widget.appState.translate(
                                  isSubbed
                                      ? 'unsubscribe_tooltip'
                                      : 'subscribe_tooltip',
                                ),
                                icon: Icon(
                                  isSubbed
                                      ? Icons.notifications_active
                                      : Icons.notifications_none,
                                  color: isSubbed
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                onPressed: () async {
                                  try {
                                    await widget.appState.toggleSubscription(
                                      DatasetIds.travelWarnings,
                                    );
                                  } catch (e) {
                                    if (context.mounted &&
                                        e.toString().contains('LimitReached')) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            widget.appState.translate(
                                              'limits_exceeded_desc',
                                            ),
                                          ),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav
                                      ? AppColors.danger
                                      : AppColors.textSecondary,
                                ),
                                onPressed: () => widget.appState.toggleFavorite(
                                  DatasetIds.travelWarnings,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Glassmorphic Search Bar
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow.withAlpha(100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1.2,
                      ),
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
                              hintText: widget.appState.translate(
                                'travel_warnings_search_placeholder',
                              ),
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

                  // 3 & 4. ListenableBuilder containing Filter Chips & Results List
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.appState,
                      builder: (context, _) {
                        final list = _getFilteredRecords();
                        final continents = _getUniqueContinents();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (continents.length > 1) ...[
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: continents.length,
                                  itemBuilder: (context, index) =>
                                      _buildFilterChip(continents[index]),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Expanded(
                              child: widget.appState.isLoadingWarnings
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : list.isEmpty
                                  ? Center(
                                      child: Text(
                                        widget.appState.translate('no_results'),
                                        style: AppTypography.bodyLg(
                                          context,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: list.length,
                                      itemBuilder: (context, index) {
                                        final item = list[index];
                                        final levelColor =
                                            _getWarningLevelColor(
                                              item.warningLevel,
                                            );
                                        final levelLabel =
                                            _getWarningLevelLabel(
                                              item.warningLevel,
                                            );

                                        final dateToShow =
                                            (item.sourceUpdatedAt != null &&
                                                item.sourceUpdatedAt!
                                                    .trim()
                                                    .isNotEmpty)
                                            ? item.sourceUpdatedAt!
                                            : (item.sourceCreatedAt != null &&
                                                  item.sourceCreatedAt!
                                                      .trim()
                                                      .isNotEmpty)
                                            ? item.sourceCreatedAt!
                                            : (item.date != null &&
                                                  item.date!.trim().isNotEmpty)
                                            ? item.date!
                                            : (item.lastUpdated != null &&
                                                  item.lastUpdated!
                                                      .trim()
                                                      .isNotEmpty)
                                            ? item.lastUpdated!
                                            : (item.createdAt != null &&
                                                  item.createdAt!
                                                      .trim()
                                                      .isNotEmpty)
                                            ? item.createdAt!
                                            : '';

                                        // Clean HTML from recommendation summary to display plain text
                                        final cleanRecSummary = item
                                            .recommendations
                                            .replaceAll(RegExp(r'<[^>]*>'), '')
                                            .replaceAll('&nbsp;', ' ')
                                            .trim();

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLow
                                                .withAlpha(120),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: AppColors.glassBorder,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: InkWell(
                                              onTap: () => _showDetails(item),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: BorderDirectional(
                                                    start: BorderSide(
                                                      color: levelColor,
                                                      width: 4,
                                                    ),
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(
                                                  16.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Header Row: Country & Warning Level Badge
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.country,
                                                            style:
                                                                AppTypography.bodyLg(
                                                                  context,
                                                                  color: AppColors
                                                                      .textPrimary,
                                                                ).copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: levelColor
                                                                .withAlpha(20),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color: levelColor
                                                                  .withAlpha(
                                                                    80,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            levelLabel,
                                                            style:
                                                                AppTypography.labelXs(
                                                                  context,
                                                                  color:
                                                                      levelColor,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // Recommendations summary text
                                                    Text(
                                                      cleanRecSummary,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          AppTypography.bodySm(
                                                            context,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Footer Row: Publisher / Date
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item
                                                                    .office
                                                                    .isNotEmpty
                                                                ? item.office
                                                                : widget
                                                                      .appState
                                                                      .translate(
                                                                        'travel_warnings_publisher',
                                                                      ),
                                                            style: AppTypography.labelXs(
                                                              context,
                                                              color: AppColors
                                                                  .textTertiary,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        if (dateToShow
                                                            .isNotEmpty)
                                                          Text(
                                                            dateToShow.length >=
                                                                    10
                                                                ? dateToShow
                                                                      .substring(
                                                                        0,
                                                                        10,
                                                                      )
                                                                : dateToShow,
                                                            style:
                                                                AppTypography.labelXs(
                                                                  context,
                                                                  color: AppColors
                                                                      .textTertiary,
                                                                ).copyWith(
                                                                  fontFamily:
                                                                      'Outfit',
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
