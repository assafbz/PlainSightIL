import 'package:flutter/material.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/constants/dataset_ids.dart';

/// A premium, responsive Admin Dashboard page to view and manage supported datasets.
/// Follows the Slate Dark mode style guide with glassmorphism overlays and logical mirroring.
class AdminPage extends StatefulWidget {
  final AppStateNotifier appState;

  const AdminPage({super.key, required this.appState});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'idle', 'syncing', 'error'
  int _activeSubTab = 0; // 0 for Datasets, 1 for Telemetry
  final Set<String> _expandedRuns = {}; // Tracks expanded log IDs

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
    // Initialize listener when entering the page
    widget.appState.initAdminMetadataListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Helper to format ISO timestamp strings to user friendly representation.
  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute:$second';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.appState.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.baseBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: AppColors.danger, size: 64),
                const SizedBox(height: 16),
                Text(
                  widget.appState.locale == 'he'
                      ? 'גישה נדחתה'
                      : 'Access Denied',
                  style: AppTypography.headlineLg(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.appState.locale == 'he'
                      ? 'אין לך הרשאות לגשת לדף זה.'
                      : 'You do not have permission to access this page.',
                  style: AppTypography.bodyLg(
                    context,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    widget.appState.locale == 'he' ? 'חזור' : 'Go Back',
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppColors.onPrimary,
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Central dataset metadata declarations that are active on the client
    final List<Map<String, String>> datasetsSpec = [
      {
        'id': DatasetIds.cellularAntennas,
        'titleEn': 'Cellular Antennas',
        'titleHe': 'אנטנות סלולריות פעילות',
        'resourceId': DatasetIds.cellularAntennas,
        'agencyEn': 'Ministry of Environmental Protection',
        'agencyHe': 'המשרד להגנת הסביבה',
      },
      {
        'id': DatasetIds.cellularPermits,
        'titleEn': 'Cellular Permit Applications',
        'titleHe': 'בקשות להיתרי הקמה של אנטנות',
        'resourceId': DatasetIds.cellularPermits,
        'agencyEn': 'Ministry of Environmental Protection',
        'agencyHe': 'המשרד להגנת הסביבה',
      },
      {
        'id': DatasetIds.companiesLiquidation,
        'titleEn': 'Companies in Liquidation',
        'titleHe': 'מאגר הכונס הרשמי',
        'resourceId': DatasetIds.companiesLiquidation,
        'agencyEn': 'Ministry of Justice - Corporations Authority',
        'agencyHe': 'משרד המשפטים - רשות התאגידים',
      },
      {
        'id': DatasetIds.doctorsLicenses,
        'titleEn': 'Doctors Licenses',
        'titleHe': 'רישיונות רופאים',
        'resourceId': DatasetIds.doctorsLicenses,
        'agencyEn': 'Ministry of Health',
        'agencyHe': 'משרד הבריאות',
      },
    ];

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final metadataMap = widget.appState.datasetMetadataMap;
        final isLoading = widget.appState.isLoadingAdminMetadata;

        // Map over data spec and merge live status from appState
        final List<Map<String, dynamic>> enrichedDatasets = datasetsSpec.map((
          spec,
        ) {
          final liveData = metadataMap[spec['id']] ?? {};
          final status = (liveData['status'] as String? ?? 'idle')
              .toLowerCase();
          final recordCount = liveData['recordCount'] as num? ?? 0;
          final lastUpdated = liveData['lastUpdated'] as String? ?? '';

          return {
            ...spec,
            'status': status,
            'recordCount': recordCount.toInt(),
            'lastUpdated': lastUpdated,
          };
        }).toList();

        // Apply Search and Filter matching functional requirements
        final List<Map<String, dynamic>> filteredDatasets = enrichedDatasets
            .where((dataset) {
              final title =
                  (widget.appState.locale == 'he'
                          ? dataset['titleHe']
                          : dataset['titleEn'])
                      .toString()
                      .toLowerCase();
              final resourceId = dataset['resourceId'].toString().toLowerCase();
              final query = _searchQuery.toLowerCase();

              final matchesSearch =
                  title.contains(query) || resourceId.contains(query);

              final matchesStatus =
                  _statusFilter == 'all' || dataset['status'] == _statusFilter;

              return matchesSearch && matchesStatus;
            })
            .toList();

        return Scaffold(
          backgroundColor: AppColors.baseBg,
          body: Stack(
            children: [
              // Ambient violet secondary gradient glow
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.7, -0.7),
                      radius: 1.3,
                      colors: [
                        const Color(0x1A8B5CF6), // Violet tint glow
                        AppColors.baseBg,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header Bar
                    _buildHeader(context),

                    // Sub Tab Bar (Datasets / Telemetry)
                    _buildSubTabBar(context),

                    // Conditional body
                    Expanded(
                      child: _activeSubTab == 0
                          ? Column(
                              children: [
                                // Filters Toolbar
                                _buildFiltersToolbar(context),

                                // Datasets List View
                                Expanded(
                                  child: isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : filteredDatasets.isEmpty
                                      ? Center(
                                          child: Text(
                                            widget.appState.translate(
                                              'no_results',
                                            ),
                                            style: AppTypography.bodyLg(
                                              context,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount: filteredDatasets.length,
                                          itemBuilder: (context, index) {
                                            final dataset =
                                                filteredDatasets[index];
                                            return _buildDatasetCard(
                                              context,
                                              dataset,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            )
                          : _buildTelemetryView(context),
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

  /// Build top header bar with back button and bilingual title
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Text(
            widget.appState.translate('admin_title'),
            style: AppTypography.headlineMd(
              context,
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build search textfield and status filter segment chips
  Widget _buildFiltersToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _searchController,
              style: AppTypography.bodyLg(
                context,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.appState.translate('search_datasets'),
                hintStyle: AppTypography.bodySm(
                  context,
                  color: AppColors.textTertiary,
                ),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Status Filter list
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(
                  'all',
                  widget.appState.translate('filter_status_all'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'idle',
                  widget.appState.translate('filter_status_idle'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'syncing',
                  widget.appState.translate('filter_status_syncing'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'error',
                  widget.appState.translate('filter_status_error'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build status filter chip
  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;

    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(40)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelXs(
            context,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Render individual glassmorphic dataset card widget
  Widget _buildDatasetCard(BuildContext context, Map<String, dynamic> dataset) {
    final String status = dataset['status'] as String;
    final int recordCount = dataset['recordCount'] as int;
    final String lastUpdated = dataset['lastUpdated'] as String;

    // Define colors and icons matching the status spec
    Color statusColor;
    IconData statusIcon;
    String statusLabelKey;

    switch (status) {
      case 'syncing':
        statusColor = AppColors.warning;
        statusIcon = Icons.sync;
        statusLabelKey = 'filter_status_syncing';
        break;
      case 'error':
        statusColor = AppColors.danger;
        statusIcon = Icons.error_outline;
        statusLabelKey = 'filter_status_error';
        break;
      case 'idle':
      default:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
        statusLabelKey = 'filter_status_idle';
        break;
    }

    final title =
        (widget.appState.locale == 'he'
                ? dataset['titleHe']
                : dataset['titleEn'])
            as String;
    final agency =
        (widget.appState.locale == 'he'
                ? dataset['agencyHe']
                : dataset['agencyEn'])
            as String;
    final resourceId = dataset['resourceId'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassmorphicCard(
        borderRadius: 20.0,
        startBorderColor: statusColor,
        startBorderWidth: 4.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'syncing')
                          _buildSyncingSpinner(statusColor)
                        else
                          Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.appState.translate(statusLabelKey),
                          style: AppTypography.labelXs(
                            context,
                            color: statusColor,
                          ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Metadata Details
              _buildDetailRow(
                context,
                Icons.storage_outlined,
                widget.appState.translate('dataset_records'),
                recordCount.toString(),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                Icons.access_time_outlined,
                widget.appState.translate('last_sync'),
                _formatTimestamp(lastUpdated),
              ),
              const Divider(color: Color(0x14FFFFFF), height: 20),

              // Raw IDs and Provenance details (FR-03)
              _buildDetailRow(
                context,
                Icons.business_outlined,
                widget.appState.translate('source_agency'),
                agency,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                Icons.fingerprint_outlined,
                widget.appState.translate('resource_id'),
                resourceId,
                isMonospace: true,
              ),
              const Divider(color: Color(0x14FFFFFF), height: 20),

              // Actions row (Trigger Manual Sync) (FR-01)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildSyncButton(context, dataset)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom animated rotating spinner widget for active syncing states
  Widget _buildSyncingSpinner(Color color) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  /// Render individual info row containing icon, label, and value
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodySm(
            context,
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.normal),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySm(context, color: AppColors.textPrimary)
                .copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: isMonospace ? 'Courier' : null,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  /// Render a glassmorphic manual sync trigger button (FR-01, FR-03)
  Widget _buildSyncButton(BuildContext context, Map<String, dynamic> dataset) {
    final String datasetId = dataset['id'] as String;
    final String status = dataset['status'] as String;
    final bool isSyncing = status == 'syncing';

    Color buttonColor;
    if (isSyncing) {
      buttonColor = AppColors.textTertiary;
    } else if (status == 'error') {
      buttonColor = AppColors.danger;
    } else {
      buttonColor = AppColors.primary;
    }

    final isHeb = widget.appState.locale == 'he';
    final buttonText = isSyncing
        ? (isHeb ? 'מסנכרן...' : 'Syncing...')
        : (isHeb ? 'סנכרן ידנית' : 'Trigger Sync');

    return Semantics(
      label: isHeb
          ? 'הפעל סנכרון ידני עבור $datasetId'
          : 'Trigger manual sync for $datasetId',
      button: true,
      enabled: !isSyncing,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
        child: ElevatedButton.icon(
          onPressed: isSyncing
              ? null
              : () => _handleManualSync(context, datasetId),
          icon: isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textTertiary,
                    ),
                  ),
                )
              : const Icon(Icons.sync, size: 18),
          label: Text(
            buttonText,
            style: AppTypography.labelXs(
              context,
              color: isSyncing ? AppColors.textTertiary : AppColors.onPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSyncing ? AppColors.surfaceHigh : buttonColor,
            foregroundColor: AppColors.onPrimary,
            elevation: isSyncing ? 0 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSyncing
                    ? AppColors.glassBorder
                    : buttonColor.withAlpha(50),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _activeSubTab = 0;
                  });
                },
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: _activeSubTab == 0
                      ? BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: Text(
                    widget.appState.translate('datasets_tab'),
                    style: AppTypography.bodySm(
                      context,
                      color: _activeSubTab == 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _activeSubTab = 1;
                  });
                },
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(15),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: _activeSubTab == 1
                      ? BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: Text(
                    widget.appState.translate('telemetry_tab'),
                    style: AppTypography.bodySm(
                      context,
                      color: _activeSubTab == 1
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryView(BuildContext context) {
    final scraperRuns = widget.appState.scraperRuns;
    final apiHealth = widget.appState.apiHealth;

    final List<Map<String, String>> specs = [
      {
        'id': DatasetIds.cellularAntennas,
        'titleEn': 'Cellular Antennas',
        'titleHe': 'אנטנות סלולריות פעילות',
      },
      {
        'id': DatasetIds.cellularPermits,
        'titleEn': 'Cellular Permits',
        'titleHe': 'בקשות להיתרי הקמה',
      },
      {
        'id': DatasetIds.companiesLiquidation,
        'titleEn': 'Companies Liquidation',
        'titleHe': 'מאגר הכונס הרשמי',
      },
      {
        'id': DatasetIds.doctorsLicenses,
        'titleEn': 'Doctors Licenses',
        'titleHe': 'רישיונות רופאים',
      },
      {
        'id': 'datasets_metadata',
        'titleEn': 'Dataset Metadata',
        'titleHe': 'מדריך מאגרי מידע',
      },
    ];

    final errorRuns = scraperRuns.where((r) => r['status'] == 'error').toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        _buildApiHealthCard(context, apiHealth),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            widget.appState.translate('runs_title'),
            style: AppTypography.headlineMd(
              context,
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...specs.map((spec) {
          final runs = scraperRuns
              .where((r) => r['datasetId'] == spec['id'])
              .toList();
          final latestRun = runs.isNotEmpty ? runs.first : null;
          double avgLatency = 0.0;
          if (runs.isNotEmpty) {
            avgLatency =
                runs
                    .map((r) => (r['durationMs'] as num).toDouble())
                    .reduce((a, b) => a + b) /
                runs.length /
                1000.0;
          }
          return _buildPipelineRowCard(context, spec, latestRun, avgLatency);
        }),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            widget.appState.translate('error_logbook'),
            style: AppTypography.headlineMd(
              context,
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (errorRuns.isEmpty)
          GlassmorphicCard(
            borderRadius: 16.0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  widget.appState.translate('no_telemetry'),
                  style: AppTypography.bodyLg(
                    context,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          )
        else
          ...errorRuns.map((run) {
            final runKey = '${run['datasetId']}_${run['startTime']}';
            final isExpanded = _expandedRuns.contains(runKey);
            return _buildErrorLogCard(context, run, runKey, isExpanded);
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildApiHealthCard(
    BuildContext context,
    Map<String, dynamic> apiHealth,
  ) {
    final isReachable = apiHealth['isReachable'] as bool? ?? false;
    final statusCode = apiHealth['statusCode'] as num? ?? 0;
    final latencyMs = apiHealth['latencyMs'] as num? ?? 0;
    final lastChecked = apiHealth['lastChecked'] as String? ?? '';

    final statusColor = isReachable ? AppColors.success : AppColors.danger;
    final statusText = isReachable
        ? widget.appState.translate('api_status_reachable')
        : widget.appState.translate('api_status_unreachable');

    return GlassmorphicCard(
      borderRadius: 20.0,
      startBorderColor: statusColor,
      startBorderWidth: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.appState.translate('api_reachability'),
                  style: AppTypography.bodyLg(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedGlowDot(color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: AppTypography.labelXs(
                          context,
                          color: statusColor,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Icons.link_outlined,
              'URL',
              apiHealth['url'] as String? ?? 'https://data.gov.il',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.speed_outlined,
              widget.appState.translate('status_label'),
              statusCode > 0 ? '$statusCode (${latencyMs}ms)' : '-',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.access_time_outlined,
              widget.appState.translate('last_sync'),
              _formatTimestamp(lastChecked),
            ),
            const Divider(color: Color(0x14FFFFFF), height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.appState.triggerApiHealthCheck();
                },
                icon: const Icon(Icons.refresh),
                label: Text(widget.appState.translate('check_now')),
                style: ElevatedButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: AppColors.primary.withAlpha(60),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineRowCard(
    BuildContext context,
    Map<String, String> spec,
    Map<String, dynamic>? latestRun,
    double avgLatency,
  ) {
    final title = widget.appState.locale == 'he'
        ? spec['titleHe']!
        : spec['titleEn']!;
    Color statusColor = AppColors.textTertiary;
    IconData statusIcon = Icons.help_outline;

    if (latestRun != null) {
      if (latestRun['status'] == 'success') {
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
      } else {
        statusColor = AppColors.danger;
        statusIcon = Icons.error_outline;
      }
    }

    final reads = latestRun != null
        ? latestRun['firestoreReadsEstimate'] as num? ?? 0
        : 0;
    final writes = latestRun != null
        ? latestRun['firestoreWritesEstimate'] as num? ?? 0
        : 0;
    final lastTime = latestRun != null
        ? latestRun['endTime'] as String? ?? ''
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassmorphicCard(
        borderRadius: 16.0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodySm(
                        context,
                        color: AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(statusIcon, color: statusColor, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniDetail(
                      context,
                      Icons.timer_outlined,
                      widget.appState.translate('avg_latency'),
                      '${avgLatency.toStringAsFixed(1)}${widget.appState.translate('latency_sec')}',
                    ),
                  ),
                  Expanded(
                    child: _buildMiniDetail(
                      context,
                      Icons.cloud_queue_outlined,
                      widget.appState.translate('firestore_reads_writes'),
                      '$reads / $writes',
                    ),
                  ),
                ],
              ),
              if (lastTime.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildMiniDetail(
                  context,
                  Icons.access_time_outlined,
                  widget.appState.translate('last_sync'),
                  _formatTimestamp(lastTime),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Handle trigger button actions and notify users via SnackBar on completion (FR-04)
  Future<void> _handleManualSync(BuildContext context, String datasetId) async {
    final isHeb = widget.appState.locale == 'he';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHeb ? 'מתחיל סנכרון ידני...' : 'Starting manual sync...',
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await widget.appState.triggerManualSync(datasetId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    if (result['success'] == true) {
      final int count = result['count'] as int;
      final String msg = isHeb
          ? 'הסנכרון הושלם בהצלחה! עודכנו $count רשומות.'
          : 'Sync completed successfully! Updated $count records.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      final String errorMsg = result['message'] as String;
      final String msg = isHeb
          ? 'הסנכרון נכשל: $errorMsg'
          : 'Sync failed: $errorMsg';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildMiniDetail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelXs(
            context,
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 10),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: AppTypography.labelXs(
            context,
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildErrorLogCard(
    BuildContext context,
    Map<String, dynamic> run,
    String runKey,
    bool isExpanded,
  ) {
    final datasetId = run['datasetId'] as String? ?? 'unknown';
    final startTime = run['startTime'] as String? ?? '';
    final errorMessage = run['errorMessage'] as String? ?? '';
    final errorStack = run['errorStack'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassmorphicCard(
        borderRadius: 16.0,
        startBorderColor: AppColors.danger,
        startBorderWidth: 4.0,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedRuns.remove(runKey);
              } else {
                _expandedRuns.add(runKey);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            datasetId,
                            style:
                                AppTypography.bodySm(
                                  context,
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimestamp(startTime),
                            style: AppTypography.labelXs(
                              context,
                              color: AppColors.textTertiary,
                            ).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: AppTypography.bodySm(
                    context,
                    color: AppColors.danger,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                if (isExpanded && errorStack.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0x14FFFFFF)),
                  Container(
                    height: 150,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText(
                        errorStack,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10,
                          color: Color(0xFFFDA4AF),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedGlowDot extends StatefulWidget {
  final Color color;
  const AnimatedGlowDot({super.key, required this.color});

  @override
  State<AnimatedGlowDot> createState() => _AnimatedGlowDotState();
}

class _AnimatedGlowDotState extends State<AnimatedGlowDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha((100 * _animation.value).toInt()),
                blurRadius: 10 * _animation.value,
                spreadRadius: 3 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
