import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';
import 'package:plainsight/features/datasets/local_market_bonds/presentation/notifiers/local_market_bonds_notifier.dart';
import '../data/models/local_market_bond_model.dart';
import '../widgets/bond_detail_drawer.dart';

/// Screen displaying the local market bonds list with infinite scroll pagination, search, and type filters.
class LocalMarketBondsScreen extends StatefulWidget {
  /// The global app state coordinator.
  final AppStateNotifier appState;

  /// Constructor
  const LocalMarketBondsScreen({super.key, required this.appState});

  @override
  State<LocalMarketBondsScreen> createState() => _LocalMarketBondsScreenState();
}

class _LocalMarketBondsScreenState extends State<LocalMarketBondsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _activeFilter =
      'All'; // 'All', 'Government', 'CPI-Linked', 'Floating Rate'

  T _getNotifier<T>({bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (_) {
      if (T == LocalMarketBondsNotifier) {
        return widget.appState.bondsNotifier as T;
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
    widget.appState.addRecent(DatasetIds.localMarketBonds);
    _getNotifier<LocalMarketBondsNotifier>().initBondsListener();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _getNotifier<LocalMarketBondsNotifier>().cancelBondsListener();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _getNotifier<LocalMarketBondsNotifier>().fetchNextPage();
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _getNotifier<LocalMarketBondsNotifier>().setSearchQuery(val);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _activeFilter = filter;
    });
    _getNotifier<LocalMarketBondsNotifier>().setFilter(filter);
  }

  void _showDetails(LocalMarketBondRecordModel record) {
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
            BondDetailDrawer(record: record, appState: widget.appState),
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

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (_) {
      return isoString;
    }
  }

  Color _getBondColor(String bondTypeEn) {
    if (bondTypeEn == 'Government') {
      return AppColors.primary;
    } else if (bondTypeEn == 'CPI-Linked Government') {
      return AppColors.secondary;
    } else if (bondTypeEn == 'Floating Rate Government') {
      return Colors.teal;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Stack(
        children: [
          // Background Atmospheric Radial Gradient (Violet/Finance Accent Glow)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(0x1F8B5CF6), // Subtle violet glow
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
                          widget.appState.translate('local_market_bonds_title'),
                          style: AppTypography.headlineLg(
                            context,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildConsumer2<AuthNotifier, AlertsNotifier>(
                        builder: (context, authNotifier, alertsNotifier, _) {
                          final isFav = authNotifier.isFavorite(
                            DatasetIds.localMarketBonds,
                          );
                          final isSubbed = alertsNotifier.isSubscribed(
                            DatasetIds.localMarketBonds,
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
                                      DatasetIds.localMarketBonds,
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
                                onPressed: () => authNotifier.toggleFavorite(
                                  DatasetIds.localMarketBonds,
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
                            onChanged: _onSearchChanged,
                            style: AppTypography.bodySm(
                              context,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.appState.translate(
                                'local_market_bonds_search_placeholder',
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
                        _buildFilterChip('All', isRtl ? 'הכל' : 'All'),
                        _buildFilterChip(
                          'Government',
                          isRtl ? 'ממשלתית' : 'Government',
                        ),
                        _buildFilterChip(
                          'CPI-Linked',
                          isRtl ? 'צמודת מדד' : 'CPI-Linked',
                        ),
                        _buildFilterChip(
                          'Floating Rate',
                          isRtl ? 'ריבית משתנה' : 'Floating Rate',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Main Results List
                  Expanded(
                    child: _buildConsumer<LocalMarketBondsNotifier>(
                      builder: (context, bondsNotifier, _) {
                        if (bondsNotifier.isLoadingBonds) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final list = bondsNotifier.bondRecords;
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

                        final showLoadMore = bondsNotifier.hasMoreBonds;

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
                            final bondTypeEn = item.bondType['en'] ?? '';
                            final typeName =
                                item.bondType[widget.appState.locale] ??
                                bondTypeEn;
                            final accentColor = _getBondColor(bondTypeEn);

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
                                          color: accentColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Series & Type Badge
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${widget.appState.translate("bond_series_label")}${item.series}',
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
                                                color: accentColor.withAlpha(
                                                  20,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: accentColor.withAlpha(
                                                    80,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                typeName,
                                                style: AppTypography.labelXs(
                                                  context,
                                                  color: accentColor,
                                                ).copyWith(fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Pricing & Coupon details
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${widget.appState.translate("bond_coupon")}${item.coupon.toStringAsFixed(2)}%',
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              '${widget.appState.translate("bond_term_to_maturity")}${item.actualTermToMaturity.toStringAsFixed(1)}${widget.appState.translate("bond_years")}',
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Issuance and Redemption Dates
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${widget.appState.translate("bond_issuance_date")}${_formatDate(item.issuanceDate)}',
                                              style: AppTypography.labelXs(
                                                context,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                            Text(
                                              '${widget.appState.translate("bond_redemption_date")}${_formatDate(item.redemptionDate)}',
                                              style: AppTypography.labelXs(
                                                context,
                                                color: AppColors.textTertiary,
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
  }
}
