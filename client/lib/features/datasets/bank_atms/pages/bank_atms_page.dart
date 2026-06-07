import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';
import 'package:plainsight/features/datasets/bank_atms/presentation/notifiers/bank_atms_notifier.dart';
import '../data/models/bank_atm_record_model.dart';
import '../widgets/bank_atms_map_view.dart';
import '../../cellular_antennas/widgets/map_controls_overlay.dart';

/// Screen displaying the Bank ATMs list with searching, filtering, mapping, and detail drawers.
class BankAtmsScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;

  /// Constructor
  const BankAtmsScreen({super.key, required this.appState});

  @override
  State<BankAtmsScreen> createState() => _BankAtmsScreenState();
}

class _BankAtmsScreenState extends State<BankAtmsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBank = 'All'; // 'All' represents no bank filtering

  // Map and sync state
  bool _showMap = true;
  String? _selectedRecordId;
  final MapController _mapController = MapController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  AnimationController? _mapAnimationController;

  T _getNotifier<T>({bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (_) {
      if (T == BankAtmsNotifier) return widget.appState.bankAtmsNotifier as T;
      if (T == AuthNotifier) return widget.appState.authNotifier as T;
      if (T == AlertsNotifier) return widget.appState.alertsNotifier as T;
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
    widget.appState.addRecent(DatasetIds.bankAtms);
    _getNotifier<BankAtmsNotifier>().initBankAtmsListener();
  }

  @override
  void dispose() {
    _getNotifier<BankAtmsNotifier>().cancelBankAtmsListener();
    _searchController.dispose();
    _mapAnimationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Extracts unique bank names present in the records to build filter chips.
  List<String> _getUniqueBanks() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = _getNotifier<BankAtmsNotifier>().atmRecords;

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
    final allRecords = _getNotifier<BankAtmsNotifier>().atmRecords;
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

  /// Animates the map movement smoothly to a target location and zoom level.
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapAnimationController?.stop();
    _mapAnimationController?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _mapAnimationController = controller;

    final LatLng startLocation = _mapController.camera.center;
    final double startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: startLocation.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startLocation.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_mapAnimationController == controller) {
          _mapAnimationController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  /// Handles marker selection, zooming the map, and centering the list.
  void _onMarkerTap(BankAtmRecordModel record) {
    setState(() {
      _selectedRecordId = record.id;
    });

    _animatedMapMove(LatLng(record.latitude, record.longitude), 15.0);

    final filtered = _getFilteredRecords();
    final index = filtered.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Handles card clicks, highlighting the item, centering map, and opening details.
  void _onCardTap(BankAtmRecordModel record) {
    setState(() {
      _selectedRecordId = record.id;
    });

    if (record.latitude != 0.0 || record.longitude != 0.0) {
      if (_showMap) {
        _animatedMapMove(LatLng(record.latitude, record.longitude), 16.0);
      }
    }
    _showDetails(record);
  }

  /// Requests user geolocation access and centers the map on current coordinates.
  Future<void> _recenterOnUserLocation() async {
    final goAhead = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return AlertDialog(
          backgroundColor: AppColors.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isRtl ? 'גישה למיקום' : 'Location Access',
            style: AppTypography.headlineMd(context),
          ),
          content: Text(
            isRtl
                ? 'PlainSightIL זקוקה לגישה למיקום המכשיר שלך כדי להציג כספומטים סביבך על המפה.'
                : 'PlainSightIL needs access to your device location to display ATMs around you on the map.',
            style: AppTypography.bodySm(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                isRtl ? 'ביטול' : 'Cancel',
                style: AppTypography.bodySm(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isRtl ? 'אישור' : 'Allow',
                style: AppTypography.bodySm(context, color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );

    if (goAhead != true) {
      _fallbackToTelAviv();
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _animatedMapMove(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      _fallbackToTelAviv();
    }
  }

  /// Centering fallback logic on coordinate access failures.
  void _fallbackToTelAviv() {
    _animatedMapMove(const LatLng(32.0782, 34.7741), 15.0);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          isRtl
              ? 'לא ניתן לגשת למיקום הנוכחי. מוצג מרכז תל אביב.'
              : 'Could not access current location. Centering on Tel Aviv.',
          style: AppTypography.bodySm(context, color: Colors.white),
        ),
      ),
    );
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
      services.add(
        MapEntry(
          Icons.money_outlined,
          isRtl ? 'משיכת מזומנים' : 'Cash Withdrawal',
        ),
      );
    }
    if (record.hasCashDeposit) {
      services.add(
        MapEntry(
          Icons.savings_outlined,
          isRtl ? 'הפקדת מזומנים' : 'Cash Deposit',
        ),
      );
    }
    if (record.hasChequeDeposit) {
      services.add(
        MapEntry(
          Icons.receipt_long_outlined,
          isRtl ? 'הפקדת שיקים' : 'Cheque Deposit',
        ),
      );
    }
    if (record.hasEnvelopeDeposit) {
      services.add(
        MapEntry(
          Icons.mail_outlined,
          isRtl ? 'הפקדת מעטפות' : 'Envelope Deposit',
        ),
      );
    }
    if (record.hasForexTransaction) {
      services.add(
        MapEntry(Icons.currency_exchange_outlined, isRtl ? 'מט"ח' : 'Forex'),
      );
    }
    if (record.hasAdditionalTransactions) {
      services.add(
        MapEntry(Icons.more_horiz, isRtl ? 'פעולות נוספות' : 'Additional'),
      );
    }
    if (record.hasHandicapAccess) {
      services.add(
        MapEntry(Icons.accessible_outlined, isRtl ? 'נגישות' : 'Accessible'),
      );
    }
    if (record.hasCommission) {
      services.add(
        MapEntry(Icons.attach_money_outlined, isRtl ? 'עמלה' : 'Commission'),
      );
    }

    return services.map((entry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32).withAlpha(60)),
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
          border: Border.all(color: const Color(0xFF2E7D32).withAlpha(40)),
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
    return _buildConsumer<BankAtmsNotifier>(
      builder: (context, bankAtmsNotifier, _) {
        final isRtl = widget.appState.locale == 'he';
        final list = _getFilteredRecords();
        final banks = _getUniqueBanks();

        return Scaffold(
          backgroundColor: AppColors.baseBg,
          appBar: AppBar(
            backgroundColor: const Color(0x33000000),
            elevation: 0,
            centerTitle: true,
            title: Text(
              widget.appState.translate('atm_title'),
              style: AppTypography.headlineLg(
                context,
                color: const Color(0xFF2E7D32),
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showMap ? Icons.view_list : Icons.map,
                  color: Colors.white,
                ),
                tooltip: _showMap ? 'Show List Only' : 'Show Map',
                onPressed: () {
                  setState(() {
                    _showMap = !_showMap;
                  });
                },
              ),
              _buildConsumer2<AuthNotifier, AlertsNotifier>(
                builder: (context, authNotifier, alertsNotifier, _) {
                  final isFav = authNotifier.isFavorite(DatasetIds.bankAtms);
                  final isSubbed = alertsNotifier.isSubscribed(
                    DatasetIds.bankAtms,
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
                        onPressed: () => alertsNotifier.toggleSubscription(
                          DatasetIds.bankAtms,
                          authNotifier.currentUser?.uid ??
                              (AppStateNotifier.isTesting ? 'mock_uid' : ''),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            authNotifier.toggleFavorite(DatasetIds.bankAtms),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
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

              // 1. Map View Pane
              if (_showMap)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: RepaintBoundary(
                    child: BankAtmsMapView(
                      key: const ValueKey('map_view'),
                      appState: widget.appState,
                      records: list,
                      selectedRecordId: _selectedRecordId,
                      mapController: _mapController,
                      onMarkerTap: _onMarkerTap,
                    ),
                  ),
                ),

              // Map controls overlay (Zoom and Recenter buttons)
              if (_showMap)
                Positioned(
                  top: 12,
                  left: isRtl ? 16 : null,
                  right: isRtl ? null : 16,
                  child: MapControlsOverlay(
                    mapController: _mapController,
                    onRecenter: _recenterOnUserLocation,
                  ),
                ),

              // 2. Interactive Bottom Content Area
              Positioned.fill(
                key: const ValueKey('bottom_sheet_content'),
                top: _showMap ? MediaQuery.of(context).size.height * 0.32 : 0.0,
                child: Column(
                  children: [
                    if (_showMap)
                      // Bottom sheet drag handle indicator
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withAlpha(50),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                    // Glassmorphic Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Container(
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
                    ),

                    // Banks Horizontal Chips Row
                    if (banks.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: banks.length,
                            itemBuilder: (context, index) =>
                                _buildFilterChip(banks[index]),
                          ),
                        ),
                      ),

                    // Main Results list using ScrollablePositionedList
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (bankAtmsNotifier.isLoadingAtms) {
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

                          return ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final item = list[index];
                              final bankDisplay = isRtl
                                  ? (item.bankName['he'] ?? '')
                                  : (item.bankName['en'] ?? '');
                              final isSelected = _selectedRecordId == item.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          16.0,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF2E7D32),
                                          width: 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF2E7D32,
                                            ).withAlpha(80),
                                            blurRadius: 8.0,
                                            spreadRadius: 2.0,
                                          ),
                                        ],
                                      )
                                    : BoxDecoration(
                                        color: AppColors.surfaceLow.withAlpha(
                                          120,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.glassBorder,
                                          width: 1.0,
                                        ),
                                      ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () => _onCardTap(item),
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
                                                        color: AppColors
                                                            .textPrimary,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                  color: const Color(
                                                    0xFF2E7D32,
                                                  ).withAlpha(20),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF2E7D32,
                                                    ).withAlpha(80),
                                                  ),
                                                ),
                                                child: Text(
                                                  'ATM #${item.atmNum}',
                                                  style: AppTypography.labelXs(
                                                    context,
                                                    color: const Color(
                                                      0xFF2E7D32,
                                                    ),
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
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              Text(
                                                item.lastUpdated.length >= 10
                                                    ? item.lastUpdated
                                                          .substring(0, 10)
                                                    : item.lastUpdated,
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
            ],
          ),
        );
      },
    );
  }
}
