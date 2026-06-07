import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/liquidation_record_model.dart';
import '../widgets/liquidation_detail_drawer.dart';

class CompaniesLiquidationScreen extends StatefulWidget {
  final AppStateNotifier appState;

  const CompaniesLiquidationScreen({super.key, required this.appState});

  @override
  State<CompaniesLiquidationScreen> createState() =>
      _CompaniesLiquidationScreenState();
}

class _CompaniesLiquidationScreenState
    extends State<CompaniesLiquidationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Closed

  @override
  void initState() {
    super.initState();
    widget.appState.addRecent(DatasetIds.companiesLiquidation);
    widget.appState.initLiquidationListener();
  }

  @override
  void dispose() {
    widget.appState.cancelLiquidationListener();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  List<LiquidationRecordModel> _getFilteredRecords() {
    final allRecords = widget.appState.liquidationRecords;

    // 1. Status Filter
    List<LiquidationRecordModel> filtered = [];
    if (_selectedFilterIndex == 0) {
      filtered = List.from(allRecords);
    } else if (_selectedFilterIndex == 1) {
      filtered = allRecords.where((r) {
        final status = r.caseStatus['he']!;
        return status == 'פירוק פעיל' ||
            status == 'הקפאה' ||
            status == 'הקפאת הליכים';
      }).toList();
    } else {
      filtered = allRecords.where((r) {
        final status = r.caseStatus['he']!;
        return status == 'סגור' || status == 'תיק סגור';
      }).toList();
    }

    // 2. Search query filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final name = r.companyName.toLowerCase();
      final companyId = r.companyId.toString();
      final city = r.cityOfActivity.toLowerCase();
      final court = r.districtCourt.toLowerCase();

      return name.contains(query) ||
          companyId.contains(query) ||
          city.contains(query) ||
          court.contains(query);
    }).toList();
  }

  void _showDetails(LiquidationRecordModel record) {
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
            LiquidationDetailDrawer(record: record, appState: widget.appState),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.appState.locale == 'he';

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
                    const Color(0x1A571BC1), // subtle secondary violet glow
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
                  // 1. Top Back navigation & title row
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
                          widget.appState.translate('liquidation_title'),
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
                            DatasetIds.companiesLiquidation,
                          );
                          final isSubbed = widget.appState.isSubscribed(
                            DatasetIds.companiesLiquidation,
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
                                onPressed: () =>
                                    widget.appState.toggleSubscription(
                                      DatasetIds.companiesLiquidation,
                                    ),
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
                                  DatasetIds.companiesLiquidation,
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
                                'liquidation_search_placeholder',
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

                  // 3. Horizontal Status Filters Row
                  Row(
                    children: [
                      _buildFilterChip(
                        0,
                        widget.appState.translate('filter_all'),
                      ),
                      _buildFilterChip(
                        1,
                        widget.appState.translate('filter_active'),
                      ),
                      _buildFilterChip(2, isRtl ? 'סגורים' : 'Closed'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. List View Area
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.appState,
                      builder: (context, _) {
                        final list = _getFilteredRecords();
                        if (widget.appState.isLoadingLiquidation) {
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

                        return ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final statusString = isRtl
                                ? item.caseStatus['he']!
                                : item.caseStatus['en']!;
                            final statusColor = _getStatusColor(
                              item.caseStatus['he']!,
                            );

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
                                          color: statusColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.companyName,
                                                style:
                                                    AppTypography.bodyLg(
                                                      context,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                color: statusColor.withAlpha(
                                                  20,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: statusColor.withAlpha(
                                                    80,
                                                  ),
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
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${isRtl ? 'ח.פ. ' : 'H.P. '}${item.companyId}',
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ).copyWith(fontFamily: 'Outfit'),
                                            ),
                                            Text(
                                              item.cityOfActivity,
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${widget.appState.translate('court_label')}${item.districtCourt}',
                                              style: AppTypography.labelXs(
                                                context,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                            Text(
                                              item
                                                          .liquidationOrderDate
                                                          .length >=
                                                      10
                                                  ? item.liquidationOrderDate
                                                        .substring(0, 10)
                                                  : item.liquidationOrderDate,
                                              style: AppTypography.labelXs(
                                                context,
                                                color: AppColors.textTertiary,
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
