import 'package:flutter/material.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/design_system.dart';

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
                  widget.appState.locale == 'he' ? 'גישה נדחתה' : 'Access Denied',
                  style: AppTypography.headlineLg(context, color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.appState.locale == 'he'
                      ? 'אין לך הרשאות לגשת לדף זה.'
                      : 'You do not have permission to access this page.',
                  style: AppTypography.bodyLg(context, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(widget.appState.locale == 'he' ? 'חזור' : 'Go Back'),
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

    // Hardcoded dataset metadata declarations that are active on the client
    final List<Map<String, String>> datasetsSpec = [
      {
        'id': 'cellular_antennas',
        'titleEn': 'Cellular Antennas',
        'titleHe': 'אנטנות סלולריות פעילות',
        'resourceId': '8935c8e5-ec77-421f-af86-d970583195f8',
        'agencyEn': 'Ministry of Environmental Protection',
        'agencyHe': 'המשרד להגנת הסביבה',
      },
      {
        'id': 'cellular_permit_applications',
        'titleEn': 'Cellular Permit Applications',
        'titleHe': 'בקשות להיתרי הקמה של אנטנות',
        'resourceId': 'ff398c7e-c522-4ee8-a53a-312b188a573d',
        'agencyEn': 'Ministry of Environmental Protection',
        'agencyHe': 'המשרד להגנת הסביבה',
      },
      {
        'id': 'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
        'titleEn': 'Companies in Liquidation',
        'titleHe': 'מאגר הכונס הרשמי',
        'resourceId': 'd8715392-287f-49b7-9ae3-f21ec5bf55f3',
        'agencyEn': 'Ministry of Justice - Corporations Authority',
        'agencyHe': 'משרד המשפטים - רשות התאגידים',
      },
    ];

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final metadataMap = widget.appState.datasetMetadataMap;
        final isLoading = widget.appState.isLoadingAdminMetadata;

        // Map over data spec and merge live status from appState
        final List<Map<String, dynamic>> enrichedDatasets = datasetsSpec.map((spec) {
          final liveData = metadataMap[spec['id']] ?? {};
          final status = (liveData['status'] as String? ?? 'idle').toLowerCase();
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
        final List<Map<String, dynamic>> filteredDatasets = enrichedDatasets.where((dataset) {
          final title = (widget.appState.locale == 'he' ? dataset['titleHe'] : dataset['titleEn']).toString().toLowerCase();
          final resourceId = dataset['resourceId'].toString().toLowerCase();
          final query = _searchQuery.toLowerCase();

          final matchesSearch = title.contains(query) || resourceId.contains(query);

          final matchesStatus = _statusFilter == 'all' || dataset['status'] == _statusFilter;

          return matchesSearch && matchesStatus;
        }).toList();

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
                                    widget.appState.translate('no_results'),
                                    style: AppTypography.bodyLg(context, color: AppColors.textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredDatasets.length,
                                  itemBuilder: (context, index) {
                                    final dataset = filteredDatasets[index];
                                    return _buildDatasetCard(context, dataset);
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
              style: AppTypography.bodyLg(context, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.appState.translate('search_datasets'),
                hintStyle: AppTypography.bodySm(context, color: AppColors.textTertiary),
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
                _buildFilterChip('all', widget.appState.translate('filter_status_all')),
                const SizedBox(width: 8),
                _buildFilterChip('idle', widget.appState.translate('filter_status_idle')),
                const SizedBox(width: 8),
                _buildFilterChip('syncing', widget.appState.translate('filter_status_syncing')),
                const SizedBox(width: 8),
                _buildFilterChip('error', widget.appState.translate('filter_status_error')),
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
          color: isSelected ? AppColors.primary.withAlpha(40) : Colors.transparent,
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

    final title = (widget.appState.locale == 'he' ? dataset['titleHe'] : dataset['titleEn']) as String;
    final agency = (widget.appState.locale == 'he' ? dataset['agencyHe'] : dataset['agencyEn']) as String;
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
                      style: AppTypography.bodyLg(context, color: AppColors.textPrimary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          style: AppTypography.labelXs(context, color: statusColor).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
          style: AppTypography.bodySm(context, color: AppColors.textSecondary).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySm(context, color: AppColors.textPrimary).copyWith(
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
}
