import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import '../data/models/bank_atm_record_model.dart';

/// Screen displaying the Bank ATMs list with searching, filtering, and detail drawers.
class BankAtmsScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;

  /// Constructor
  const BankAtmsScreen({super.key, required this.appState});

  @override
  State<BankAtmsScreen> createState() => _BankAtmsScreenState();
}

class _BankAtmsScreenState extends State<BankAtmsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBank = 'All'; // 'All' represents no bank filtering

  @override
  void initState() {
    super.initState();
    // Register the dataset in recent history
    widget.appState.addRecent('21fde05f-62e3-401b-81cf-5c385862026d');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Extracts unique bank names present in the records to build filter chips.
  List<String> _getUniqueBanks() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = widget.appState.atmRecords;

    final Set<String> banks = {};
    for (final r in allRecords) {
      final name = isRtl ? r.bankName['he'] : r.bankName['en'];
      if (name != null && name.isNotEmpty) {
        banks.add(name);
      }
    }

    final sortedBanks = banks.toList()..sort();
    return [isRtl ? 'הכל' : 'All', ...sortedBanks];
  }

  /// Filters loaded ATM records based on search keywords and selected bank chip.
  List<BankAtmRecordModel> _getFilteredRecords() {
    final allRecords = widget.appState.atmRecords;
    final isRtl = widget.appState.locale == 'he';
    final defaultFilter = isRtl ? 'הכל' : 'All';

    // 1. Bank Filter
    List<BankAtmRecordModel> filtered = allRecords;
    if (_selectedBank != defaultFilter && _selectedBank != 'All') {
      filtered = allRecords.where((r) {
        final name = isRtl ? r.bankName['he'] : r.bankName['en'];
        return name == _selectedBank;
      }).toList();
    }

    // 2. Search Text Filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final bankHe = (r.bankName['he'] ?? '').toLowerCase();
      final bankEn = (r.bankName['en'] ?? '').toLowerCase();
      final address = r.address.toLowerCase();
      final addressExtra = r.addressExtra.toLowerCase();
      final city = r.city.toLowerCase();

      return bankHe.contains(query) ||
          bankEn.contains(query) ||
          address.contains(query) ||
          addressExtra.contains(query) ||
          city.contains(query);
    }).toList();
  }

  /// Opens the glassmorphic detail bottom sheet for the selected record.
  void _showDetails(BankAtmRecordModel record) {
    final isRtl = widget.appState.locale == 'he';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Bank Name Header
                Text(
                  isRtl
                      ? (record.bankName['he'] ?? '')
                      : (record.bankName['en'] ?? ''),
                  style: AppTypography.headlineLg(
                    context,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // ATM Number
                Text(
                  'ATM #${record.atmNum}',
                  style: AppTypography.bodySm(
                    context,
                    color: AppColors.textSecondary,
                  ).copyWith(fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 16),

                // Address
                _buildDetailItem(
                  context,
                  Icons.location_on_outlined,
                  isRtl ? 'כתובת' : 'Address',
                  record.address,
                ),
                if (record.addressExtra.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailItem(
                    context,
                    Icons.add_location_outlined,
                    isRtl ? 'כתובת נוספת' : 'Additional Address',
                    record.addressExtra,
                  ),
                ],
                const SizedBox(height: 8),
                _buildDetailItem(
                  context,
                  Icons.location_city_outlined,
                  isRtl ? 'עיר' : 'City',
                  record.city,
                ),
                const SizedBox(height: 8),
                _buildDetailItem(
                  context,
                  Icons.place_outlined,
                  isRtl ? 'מיקום' : 'Location Type',
                  isRtl
                      ? (record.atmLocation['he'] ?? '')
                      : (record.atmLocation['en'] ?? ''),
                ),
                const SizedBox(height: 8),
                _buildDetailItem(
                  context,
                  Icons.business_outlined,
                  isRtl ? 'קוד בנק' : 'Bank Code',
                  '${record.bankCode}',
                ),
                const SizedBox(height: 8),
                _buildDetailItem(
                  context,
                  Icons.account_tree_outlined,
                  isRtl ? 'קוד סניף' : 'Branch Code',
                  '${record.branchCode}',
                ),

                const Divider(color: Color(0x14FFFFFF), height: 32),

                // Services Section
                Text(
                  isRtl ? 'שירותים' : 'Services',
                  style: AppTypography.bodyLg(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildServiceChips(record, isRtl),
                ),

                const Divider(color: Color(0x14FFFFFF), height: 32),

                // Coordinates
                if (record.latitude != 0.0 || record.longitude != 0.0) ...[
                  _buildDetailItem(
                    context,
                    Icons.map_outlined,
                    isRtl ? 'קואורדינטות' : 'Coordinates',
                    '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 8),
                ],

                // Timestamps
                if (record.lastUpdated.isNotEmpty)
                  _buildDetailItem(
                    context,
                    Icons.update_outlined,
                    isRtl ? 'עדכון אחרון' : 'Last Updated',
                    record.lastUpdated.length >= 10
                        ? record.lastUpdated.substring(0, 10)
                        : record.lastUpdated,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelXs(
                  context,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodySm(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildServiceChips(BankAtmRecordModel record, bool isRtl) {
    final services = <MapEntry<IconData, String>>[];

    if (record.hasCashWithdrawal) {
      services.add(MapEntry(
        Icons.money_outlined,
        isRtl ? 'משיכת מזומנים' : 'Cash Withdrawal',
      ));
    }
    if (record.hasCashDeposit) {
      services.add(MapEntry(
        Icons.savings_outlined,
        isRtl ? 'הפקדת מזומנים' : 'Cash Deposit',
      ));
    }
    if (record.hasChequeDeposit) {
      services.add(MapEntry(
        Icons.receipt_long_outlined,
        isRtl ? 'הפקדת שיקים' : 'Cheque Deposit',
      ));
    }
    if (record.hasEnvelopeDeposit) {
      services.add(MapEntry(
        Icons.mail_outlined,
        isRtl ? 'הפקדת מעטפות' : 'Envelope Deposit',
      ));
    }
    if (record.hasForexTransaction) {
      services.add(MapEntry(
        Icons.currency_exchange_outlined,
        isRtl ? 'מט"ח' : 'Forex',
      ));
    }
    if (record.hasAdditionalTransactions) {
      services.add(MapEntry(
        Icons.more_horiz,
        isRtl ? 'פעולות נוספות' : 'Additional',
      ));
    }
    if (record.hasHandicapAccess) {
      services.add(MapEntry(
        Icons.accessible_outlined,
        isRtl ? 'נגישות' : 'Accessible',
      ));
    }
    if (record.hasCommission) {
      services.add(MapEntry(
        Icons.attach_money_outlined,
        isRtl ? 'עמלה' : 'Commission',
      ));
    }

    return services.map((entry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32).withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.key, color: const Color(0xFF2E7D32), size: 14),
            const SizedBox(width: 4),
            Text(
              entry.value,
              style: AppTypography.labelXs(
                context,
                color: const Color(0xFF2E7D32),
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Build a service icon chip for the list card (compact version)
  Widget _buildServiceIcon(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withAlpha(15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF2E7D32).withAlpha(40),
          ),
        ),
        child: Icon(icon, color: const Color(0xFF2E7D32), size: 14),
      ),
    );
  }

  Widget _buildFilterChip(String bankName) {
    final isRtl = widget.appState.locale == 'he';
    final isSelected = _selectedBank == bankName;
    final defaultText = isRtl ? 'הכל' : 'All';

    // Display 'All' correctly localized
    final displayLabel = (bankName == 'All' || bankName == 'הכל')
        ? defaultText
        : bankName;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBank = bankName;
        });
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2E7D32).withAlpha(40)
              : AppColors.surfaceLow.withAlpha(120),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2E7D32).withAlpha(120)
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
    final list = _getFilteredRecords();
    final banks = _getUniqueBanks();

    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Stack(
        children: [
          // Background Atmospheric Gradients (Green for financial theme)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(
                      0x1F2E7D32,
                    ), // subtle green glow for financial accent
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
                          widget.appState.translate('atm_title'),
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
                            '21fde05f-62e3-401b-81cf-5c385862026d',
                          );
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                            onPressed: () => widget.appState.toggleFavorite(
                              '21fde05f-62e3-401b-81cf-5c385862026d',
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
                                'atm_search_placeholder',
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

                  // 3. Banks Horizontal Chips Row
                  if (banks.length > 1)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: banks.length,
                        itemBuilder: (context, index) =>
                            _buildFilterChip(banks[index]),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 4. Main Results list
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.appState,
                      builder: (context, _) {
                        if (widget.appState.isLoadingAtms) {
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
                          physics: const BouncingScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final bankDisplay = isRtl
                                ? (item.bankName['he'] ?? '')
                                : (item.bankName['en'] ?? '');

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
                                    decoration: const BoxDecoration(
                                      border: BorderDirectional(
                                        start: BorderSide(
                                          color: Color(0xFF2E7D32),
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Bank Name & ATM Number
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                bankDisplay,
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
                                                color: const Color(0xFF2E7D32)
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFF2E7D32)
                                                      .withAlpha(80),
                                                ),
                                              ),
                                              child: Text(
                                                'ATM #${item.atmNum}',
                                                style: AppTypography.labelXs(
                                                  context,
                                                  color:
                                                      const Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Address & City
                                        Text(
                                          '${item.address}, ${item.city}',
                                          style: AppTypography.bodySm(
                                            context,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),

                                        // Service Icon Chips Row
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (item.hasCashWithdrawal)
                                              _buildServiceIcon(
                                                Icons.money_outlined,
                                                isRtl
                                                    ? 'משיכת מזומנים'
                                                    : 'Cash Withdrawal',
                                              ),
                                            if (item.hasCashDeposit)
                                              _buildServiceIcon(
                                                Icons.savings_outlined,
                                                isRtl
                                                    ? 'הפקדת מזומנים'
                                                    : 'Cash Deposit',
                                              ),
                                            if (item.hasForexTransaction)
                                              _buildServiceIcon(
                                                Icons
                                                    .currency_exchange_outlined,
                                                isRtl ? 'מט"ח' : 'Forex',
                                              ),
                                            if (item.hasHandicapAccess)
                                              _buildServiceIcon(
                                                Icons.accessible_outlined,
                                                isRtl
                                                    ? 'נגישות'
                                                    : 'Accessible',
                                              ),
                                            if (item.hasChequeDeposit)
                                              _buildServiceIcon(
                                                Icons.receipt_long_outlined,
                                                isRtl
                                                    ? 'הפקדת שיקים'
                                                    : 'Cheque Deposit',
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Footer Row: Publisher
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.appState.translate(
                                                  'atm_publisher',
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
                                              item.lastUpdated.length >= 10
                                                  ? item.lastUpdated
                                                        .substring(0, 10)
                                                  : item.lastUpdated,
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
