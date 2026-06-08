import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';
import 'package:plainsight/features/datasets/vehicle_recalls/presentation/notifiers/vehicle_recalls_notifier.dart';
import '../data/models/vehicle_recall_model.dart';
import '../widgets/vehicle_recall_detail_drawer.dart';

/// Screen displaying the vehicle recalls list with searching, filtering, and detail drawers.
class VehicleRecallsScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;
  final String? initialSelectedId;

  /// Constructor
  const VehicleRecallsScreen({
    super.key,
    required this.appState,
    this.initialSelectedId,
  });

  @override
  State<VehicleRecallsScreen> createState() => _VehicleRecallsScreenState();
}

class _VehicleRecallsScreenState extends State<VehicleRecallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedManufacturer =
      'All'; // 'All' represents no manufacturer filtering
  bool _deepLinkHandled = false;

  T _getNotifier<T>({bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (_) {
      if (T == VehicleRecallsNotifier) {
        return widget.appState.vehicleRecallsNotifier as T;
      }
      if (T == AuthNotifier) {
        return widget.appState.authNotifier as T;
      }
      if (T == AlertsNotifier) {
        return widget.appState.alertsNotifier as T;
      }
      throw Exception('Notifier not found in AppStateNotifier for type $T');
    }
  }

  Widget _buildConsumer<T>({
    required Widget Function(BuildContext context, T notifier, Widget? child)
    builder,
    Widget? child,
  }) {
    try {
      final notifier = Provider.of<T>(context);
      return builder(context, notifier, child);
    } catch (_) {
      final notifier = _getNotifier<T>();
      return ListenableBuilder(
        listenable: notifier as Listenable,
        builder: (context, _) => builder(context, notifier, child),
      );
    }
  }

  Widget _buildConsumer2<T1, T2>({
    required Widget Function(BuildContext context, T1 n1, T2 n2, Widget? child)
    builder,
    Widget? child,
  }) {
    try {
      final n1 = Provider.of<T1>(context);
      final n2 = Provider.of<T2>(context);
      return builder(context, n1, n2, child);
    } catch (_) {
      final n1 = _getNotifier<T1>();
      final n2 = _getNotifier<T2>();
      return ListenableBuilder(
        listenable: Listenable.merge([n1 as Listenable, n2 as Listenable]),
        builder: (context, _) => builder(context, n1, n2, child),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Register the dataset in recent history
    widget.appState.addRecent(DatasetIds.vehicleRecalls);
    final notifier = _getNotifier<VehicleRecallsNotifier>();
    notifier.initRecallsListener();
    if (widget.initialSelectedId != null) {
      notifier.addListener(_handleDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
    }
  }

  @override
  void dispose() {
    final notifier = _getNotifier<VehicleRecallsNotifier>();
    notifier.removeListener(_handleDeepLink);
    notifier.cancelRecallsListener();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleDeepLink() {
    if (_deepLinkHandled || widget.initialSelectedId == null) return;
    final notifier = _getNotifier<VehicleRecallsNotifier>();
    if (notifier.isLoadingRecalls) return;

    final records = notifier.recallRecords;
    if (records.isEmpty) return;

    VehicleRecallRecordModel? targetRecord;
    for (final r in records) {
      if (r.id == widget.initialSelectedId ||
          r.recallId.toString() == widget.initialSelectedId) {
        targetRecord = r;
        break;
      }
    }

    if (targetRecord != null) {
      _deepLinkHandled = true;
      notifier.removeListener(_handleDeepLink);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDetails(targetRecord!);
      });
    }
  }

  /// Extracts unique manufacturer names present in the records to build filter chips.
  List<String> _getUniqueManufacturers() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = _getNotifier<VehicleRecallsNotifier>().recallRecords;

    final Set<String> manufacturers = {};
    for (final r in allRecords) {
      if (r.manufacturerName.isNotEmpty) {
        manufacturers.add(r.manufacturerName);
      }
    }

    final sortedManufacturers = manufacturers.toList()..sort();
    return [isRtl ? 'הכל' : 'All', ...sortedManufacturers];
  }

  /// Filters loaded vehicle recall records based on search keywords and selected manufacturer chip.
  List<VehicleRecallRecordModel> _getFilteredRecords() {
    final allRecords = _getNotifier<VehicleRecallsNotifier>().recallRecords;
    final isRtl = widget.appState.locale == 'he';
    final defaultFilter = isRtl ? 'הכל' : 'All';

    // 1. Manufacturer Filter
    List<VehicleRecallRecordModel> filtered = allRecords;
    if (_selectedManufacturer != defaultFilter &&
        _selectedManufacturer != 'All') {
      filtered = allRecords
          .where((r) => r.manufacturerName == _selectedManufacturer)
          .toList();
    }

    // 2. Search Text Filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final manufacturer = r.manufacturerName.toLowerCase();
      final model = r.modelName.toLowerCase();
      final recallId = r.recallId.toString();
      final defect = r.defectDescription.toLowerCase();
      final category = r.defectCategory.toLowerCase();

      return manufacturer.contains(query) ||
          model.contains(query) ||
          recallId.contains(query) ||
          defect.contains(query) ||
          category.contains(query);
    }).toList();
  }

  /// Opens the glassmorphic detail drawer bottom sheet for the selected record.
  void _showDetails(VehicleRecallRecordModel record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => VehicleRecallDetailDrawer(
          record: record,
          appState: widget.appState,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String manufacturerName) {
    final isRtl = widget.appState.locale == 'he';
    final isSelected = _selectedManufacturer == manufacturerName;
    final defaultText = isRtl ? 'הכל' : 'All';

    // Display 'All' correctly localized
    final displayLabel =
        (manufacturerName == 'All' || manufacturerName == 'הכל')
        ? defaultText
        : manufacturerName;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedManufacturer = manufacturerName;
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
    return _buildConsumer<VehicleRecallsNotifier>(
      builder: (context, recallsNotifier, _) {
        final list = _getFilteredRecords();
        final manufacturers = _getUniqueManufacturers();

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
                          0x1FDD4B39,
                        ), // subtle red warning glow for recalls accent
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.appState.translate('recalls_title'),
                              style: AppTypography.headlineLg(
                                context,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildConsumer2<AuthNotifier, AlertsNotifier>(
                            builder:
                                (context, authNotifier, alertsNotifier, _) {
                                  final isFav = authNotifier.isFavorite(
                                    DatasetIds.vehicleRecalls,
                                  );
                                  final isSubbed = alertsNotifier.isSubscribed(
                                    DatasetIds.vehicleRecalls,
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
                                            await widget.appState
                                                .toggleSubscription(
                                                  DatasetIds.vehicleRecalls,
                                                );
                                          } catch (e) {
                                            if (context.mounted &&
                                                e.toString().contains(
                                                  'LimitReached',
                                                )) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    widget.appState.translate(
                                                      'limits_exceeded_desc',
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      AppColors.danger,
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
                                        onPressed: () =>
                                            authNotifier.toggleFavorite(
                                              DatasetIds.vehicleRecalls,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
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
                                    'recalls_search_placeholder',
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

                      // 3. Manufacturers Horizontal Chips Row
                      if (manufacturers.length > 1)
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: manufacturers.length,
                            itemBuilder: (context, index) =>
                                _buildFilterChip(manufacturers[index]),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 4. Main Results list
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (recallsNotifier.isLoadingRecalls) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                final hasCategory =
                                    item.defectCategory.isNotEmpty;

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
                                              color: AppColors.danger,
                                              width: 4,
                                            ),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header Row: Manufacturer/Model & Recall Code Badge
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${item.manufacturerName} - ${item.modelName}',
                                                    style:
                                                        AppTypography.bodyLg(
                                                          context,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ).copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily: 'Outfit',
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                    color: AppColors.danger
                                                        .withAlpha(20),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.danger
                                                          .withAlpha(80),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${widget.appState.translate("recall_id_label")}${item.recallId}',
                                                    style:
                                                        AppTypography.labelXs(
                                                          context,
                                                          color:
                                                              AppColors.danger,
                                                        ).copyWith(
                                                          fontFamily: 'Outfit',
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Defect Description
                                            Text(
                                              item.defectDescription,
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),

                                            // Mapped Details
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${widget.appState.translate("recall_year_label")}${item.recallYear}',
                                                  style:
                                                      AppTypography.bodySm(
                                                        context,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ).copyWith(
                                                        fontFamily: 'Outfit',
                                                      ),
                                                ),
                                                if (hasCategory)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.secondary
                                                          .withAlpha(20),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .secondary
                                                            .withAlpha(50),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      item.defectCategory,
                                                      style:
                                                          AppTypography.labelXs(
                                                            context,
                                                            color: AppColors
                                                                .secondary,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Footer Row: Metadata / Last Modified Date
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    widget.appState.translate(
                                                      'recalls_publisher',
                                                    ),
                                                    style:
                                                        AppTypography.labelXs(
                                                          context,
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                Text(
                                                  item.buildEndDate.length >= 10
                                                      ? item.buildEndDate
                                                            .substring(0, 10)
                                                      : item.buildEndDate,
                                                  style:
                                                      AppTypography.labelXs(
                                                        context,
                                                        color: AppColors
                                                            .textTertiary,
                                                      ).copyWith(
                                                        fontFamily: 'Outfit',
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
      },
    );
  }
}
