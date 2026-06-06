import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/car_importer_record_model.dart';
import '../widgets/car_importer_detail_drawer.dart';

/// Screen displaying the new car price lists with searching, filtering, and detail drawers.
class CarImportersScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;

  /// Constructor
  const CarImportersScreen({super.key, required this.appState});

  @override
  State<CarImportersScreen> createState() => _CarImportersScreenState();
}

class _CarImportersScreenState extends State<CarImportersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedMaker = 'All';

  @override
  void initState() {
    super.initState();
    // Register the dataset in recent history
    widget.appState.addRecent(DatasetIds.carImporters);
    widget.appState.initCarImportersListener();
  }

  @override
  void dispose() {
    widget.appState.cancelCarImportersListener();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Extracts unique maker names present in the records to build filter chips.
  List<String> _getUniqueMakers() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = widget.appState.carImporterRecords;

    final Set<String> makers = {};
    for (final r in allRecords) {
      if (r.makerName.isNotEmpty) {
        makers.add(r.makerName);
      }
    }

    final sortedMakers = makers.toList()..sort();
    return [isRtl ? 'הכל' : 'All', ...sortedMakers];
  }

  /// Filters loaded records based on search keywords and selected maker chip.
  List<CarImporterRecordModel> _getFilteredRecords() {
    final allRecords = widget.appState.carImporterRecords;
    final isRtl = widget.appState.locale == 'he';
    final defaultFilter = isRtl ? 'הכל' : 'All';

    // 1. Maker Filter
    List<CarImporterRecordModel> filtered = allRecords;
    if (_selectedMaker != defaultFilter && _selectedMaker != 'All') {
      filtered = allRecords
          .where((r) => r.makerName == _selectedMaker)
          .toList();
    }

    // 2. Search Text Filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final commercialName = r.commercialName.toLowerCase();
      final makerName = r.makerName.toLowerCase();
      final modelName = r.modelName.toLowerCase();
      final importerName = r.importerName.toLowerCase();

      return commercialName.contains(query) ||
          makerName.contains(query) ||
          modelName.contains(query) ||
          importerName.contains(query);
    }).toList();
  }

  /// Opens the detail drawer bottom sheet for the selected record.
  void _showDetails(CarImporterRecordModel record) {
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
            CarImporterDetailDrawer(record: record, appState: widget.appState),
      ),
    );
  }

  Widget _buildFilterChip(String makerName) {
    final isRtl = widget.appState.locale == 'he';
    final isSelected = _selectedMaker == makerName;
    final defaultText = isRtl ? 'הכל' : 'All';

    final displayLabel = (makerName == 'All' || makerName == 'הכל')
        ? defaultText
        : makerName;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMaker = makerName;
        });
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00ACC1).withAlpha(40)
              : AppColors.surfaceLow.withAlpha(120),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00ACC1).withAlpha(120)
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
                    const Color(0x1F00ACC1), // subtle cyan/teal glow
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
                          widget.appState.translate('car_importers_title'),
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
                            DatasetIds.carImporters,
                          );
                          final isSubbed = widget.appState.isSubscribed(
                            DatasetIds.carImporters,
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
                                      DatasetIds.carImporters,
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
                                  DatasetIds.carImporters,
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
                              hintText: isRtl
                                  ? 'חפש לפי דגם, יצרן או יבואן...'
                                  : 'Search by model, maker or importer...',
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
                        final makers = _getUniqueMakers();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (makers.length > 1) ...[
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: makers.length,
                                  itemBuilder: (context, index) =>
                                      _buildFilterChip(makers[index]),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Expanded(
                              child: widget.appState.isLoadingCarImporters
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
                                                decoration: const BoxDecoration(
                                                  border: BorderDirectional(
                                                    start: BorderSide(
                                                      color: Color(0xFF00ACC1),
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
                                                    // Header Row: Commercial name & Price
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
                                                            item
                                                                    .commercialName
                                                                    .isNotEmpty
                                                                ? item.commercialName
                                                                : item.modelName,
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
                                                        if (item.price != null)
                                                          Text(
                                                            isRtl
                                                                ? '${item.price} ₪'
                                                                : '₪${item.price}',
                                                            style:
                                                                AppTypography.bodyLg(
                                                                  context,
                                                                  color: AppColors
                                                                      .success,
                                                                ).copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontFamily:
                                                                      'Outfit',
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // Subtitle: Maker Name and Importer Name
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          item.makerName,
                                                          style: AppTypography.bodySm(
                                                            context,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        if (item.productionYear !=
                                                            null)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFF00ACC1,
                                                                  ).withAlpha(
                                                                    20,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFF00ACC1,
                                                                    ).withAlpha(
                                                                      50,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              item.productionYear
                                                                  .toString(),
                                                              style: AppTypography.labelXs(
                                                                context,
                                                                color:
                                                                    const Color(
                                                                      0xFF00ACC1,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // Footer: Importer Name
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.importerName,
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
