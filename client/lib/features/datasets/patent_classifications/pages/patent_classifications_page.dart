import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/patent_classification_model.dart';
import '../widgets/patent_detail_drawer.dart';

/// Screen displaying the patent classifications list with infinite scroll pagination, search, and filters.
class PatentClassificationsScreen extends StatefulWidget {
  /// The global app state coordinator.
  final AppStateNotifier appState;

  /// Constructor
  const PatentClassificationsScreen({super.key, required this.appState});

  @override
  State<PatentClassificationsScreen> createState() =>
      _PatentClassificationsScreenState();
}

class _PatentClassificationsScreenState
    extends State<PatentClassificationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _activeFilter = 'All'; // 'All', 'Primary', 'Secondary'

  @override
  void initState() {
    super.initState();
    // Track in history and trigger initial fetch
    widget.appState.addRecent(DatasetIds.patentClassifications);
    widget.appState.initPatentClassificationsListener();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    widget.appState.cancelPatentClassificationsListener();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.appState.fetchNextPatentPage();
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.appState.setPatentSearchQuery(val);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _activeFilter = filter;
    });
    widget.appState.setPatentPrimaryFilter(filter);
  }

  /// Opens the detail drawer bottom sheet for the selected record.
  void _showDetails(PatentClassificationRecordModel record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            PatentDetailDrawer(record: record, appState: widget.appState),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String displayLabel) {
    final isSelected = _activeFilter == filterKey;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => _onFilterChanged(filterKey),
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
    final list = widget.appState.patentRecords;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Stack(
        children: [
          // Background Atmospheric Radial Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(
                      0x1F9C27B0,
                    ), // subtle purple glow for patent/legal accent
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
                          widget.appState.translate(
                            'patent_classifications_title',
                          ),
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
                            DatasetIds.patentClassifications,
                          );
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                            onPressed: () => widget.appState.toggleFavorite(
                              DatasetIds.patentClassifications,
                            ),
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
                            onChanged: _onSearchChanged,
                            style: AppTypography.bodySm(
                              context,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.appState.translate(
                                'patent_classifications_search_placeholder',
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
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Filters Chips Row
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildFilterChip(
                          'All',
                          widget.appState.translate('patent_primary_chip_all'),
                        ),
                        _buildFilterChip(
                          'Primary',
                          widget.appState.translate(
                            'patent_primary_chip_primary',
                          ),
                        ),
                        _buildFilterChip(
                          'Secondary',
                          widget.appState.translate(
                            'patent_primary_chip_secondary',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Main Results list
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.appState,
                      builder: (context, _) {
                        if (widget.appState.isLoadingPatents) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              widget.appState.translate('no_results'),
                              style: AppTypography.bodyLg(
                                context,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          );
                        }

                        final showLoadMore = widget.appState.hasMorePatents;

                        return ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: list.length + (showLoadMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == list.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final item = list[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLow.withAlpha(120),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                  width: 1.0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => _showDetails(item),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: BorderDirectional(
                                        start: BorderSide(
                                          color: item.isPrimary
                                              ? AppColors.primary
                                              : AppColors.secondary,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: CPC classification code & Badge
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.cpcClassification,
                                                style:
                                                    AppTypography.bodyLg(
                                                      context,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Outfit',
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (item.isPrimary
                                                            ? AppColors.primary
                                                            : AppColors
                                                                  .secondary)
                                                        .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      (item.isPrimary
                                                              ? AppColors
                                                                    .primary
                                                              : AppColors
                                                                    .secondary)
                                                          .withAlpha(80),
                                                ),
                                              ),
                                              child: Text(
                                                item.isPrimary
                                                    ? widget.appState.translate(
                                                        'patent_is_primary',
                                                      )
                                                    : widget.appState.translate(
                                                        'patent_is_secondary',
                                                      ),
                                                style: AppTypography.labelXs(
                                                  context,
                                                  color: item.isPrimary
                                                      ? AppColors.primary
                                                      : AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Title displays
                                        if (item.titleHebrew.isNotEmpty)
                                          Text(
                                            item.titleHebrew,
                                            style:
                                                AppTypography.bodySm(
                                                  context,
                                                  color: AppColors.textPrimary,
                                                ).copyWith(
                                                  fontFamily: 'Assistant',
                                                  height: 1.3,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (item.titleEnglish.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.titleEnglish,
                                            style:
                                                AppTypography.bodySm(
                                                  context,
                                                  color:
                                                      AppColors.textSecondary,
                                                ).copyWith(
                                                  fontFamily: 'Outfit',
                                                  height: 1.3,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 12),

                                        // Footer Row: Application number & publisher label
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.appState.translate(
                                                  'patent_classifications_publisher',
                                                ),
                                                style: AppTypography.labelXs(
                                                  context,
                                                  color: AppColors.textTertiary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            Text(
                                              '${widget.appState.translate("patent_app_num_label")}${item.applicationNumber}',
                                              style: AppTypography.labelXs(
                                                context,
                                                color: AppColors.textSecondary,
                                              ).copyWith(fontFamily: 'Outfit'),
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
