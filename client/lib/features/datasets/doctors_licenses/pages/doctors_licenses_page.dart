import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../data/models/doctor_license_model.dart';
import '../widgets/doctor_detail_drawer.dart';

/// Screen displaying the doctors licenses list with searching, filtering, and detail drawers.
class DoctorsLicensesScreen extends StatefulWidget {
  /// The global app state notifier.
  final AppStateNotifier appState;

  /// Constructor
  const DoctorsLicensesScreen({super.key, required this.appState});

  @override
  State<DoctorsLicensesScreen> createState() => _DoctorsLicensesScreenState();
}

class _DoctorsLicensesScreenState extends State<DoctorsLicensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSpecialty = 'All'; // 'All' represents no specialty filtering

  @override
  void initState() {
    super.initState();
    // Register the dataset in recent history
    widget.appState.addRecent(DatasetIds.doctorsLicenses);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Extracts unique specialty names present in the records to build filter chips.
  List<String> _getUniqueSpecialties() {
    final isRtl = widget.appState.locale == 'he';
    final allRecords = widget.appState.doctorRecords;

    final Set<String> specs = {};
    for (final r in allRecords) {
      if (r.specialtyName != null && r.specialtyName!.isNotEmpty) {
        specs.add(r.specialtyName!);
      }
    }

    final sortedSpecs = specs.toList()..sort();
    return [isRtl ? 'הכל' : 'All', ...sortedSpecs];
  }

  /// Filters loaded doctor records based on search keywords and selected specialty chip.
  List<DoctorLicenseRecordModel> _getFilteredRecords() {
    final allRecords = widget.appState.doctorRecords;
    final isRtl = widget.appState.locale == 'he';
    final defaultFilter = isRtl ? 'הכל' : 'All';

    // 1. Specialty Filter
    List<DoctorLicenseRecordModel> filtered = allRecords;
    if (_selectedSpecialty != defaultFilter && _selectedSpecialty != 'All') {
      filtered = allRecords
          .where((r) => r.specialtyName == _selectedSpecialty)
          .toList();
    }

    // 2. Search Text Filter
    if (_searchQuery.isEmpty) return filtered;
    final query = _searchQuery.toLowerCase().trim();

    return filtered.where((r) {
      final firstName = r.firstName.toLowerCase();
      final lastName = r.lastName.toLowerCase();
      final fullName = '$firstName $lastName';
      final licenseNum = r.licenseNumber.toString();
      final specialty = (r.specialtyName ?? '').toLowerCase();

      return firstName.contains(query) ||
          lastName.contains(query) ||
          fullName.contains(query) ||
          licenseNum.contains(query) ||
          specialty.contains(query);
    }).toList();
  }

  /// Opens the glassmorphic detail drawer bottom sheet for the selected record.
  void _showDetails(DoctorLicenseRecordModel record) {
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
            DoctorDetailDrawer(record: record, appState: widget.appState),
      ),
    );
  }

  Widget _buildFilterChip(String specialtyName) {
    final isRtl = widget.appState.locale == 'he';
    final isSelected = _selectedSpecialty == specialtyName;
    final defaultText = isRtl ? 'הכל' : 'All';

    // Display 'All' correctly localized
    final displayLabel = (specialtyName == 'All' || specialtyName == 'הכל')
        ? defaultText
        : specialtyName;
    final labelColor = isSelected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSpecialty = specialtyName;
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
    final isRtl = widget.appState.locale == 'he';
    final list = _getFilteredRecords();
    final specialties = _getUniqueSpecialties();

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
                      0x1F0088CC,
                    ), // subtle cyan glow for doctors accent
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
                          widget.appState.translate('doctors_title'),
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
                            DatasetIds.doctorsLicenses,
                          );
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                            onPressed: () => widget.appState.toggleFavorite(
                              DatasetIds.doctorsLicenses,
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
                                'doctors_search_placeholder',
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

                  // 3. Specialties Horizontal Chips Row
                  if (specialties.length > 1)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: specialties.length,
                        itemBuilder: (context, index) =>
                            _buildFilterChip(specialties[index]),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 4. Main Results list
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.appState,
                      builder: (context, _) {
                        if (widget.appState.isLoadingDoctors) {
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
                            final hasSpecialty =
                                item.specialtyName != null &&
                                item.specialtyName!.isNotEmpty;

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
                                          color: AppColors.primary,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Doctor Name & License Active Badge
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${isRtl ? "ד\"ר" : "Dr."} ${item.firstName} ${item.lastName}',
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
                                                color: AppColors.success
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppColors.success
                                                      .withAlpha(80),
                                                ),
                                              ),
                                              child: Text(
                                                widget.appState.translate(
                                                  'doctor_licensed',
                                                ),
                                                style: AppTypography.labelXs(
                                                  context,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Mapped Details
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${widget.appState.translate("license_num_label")}${item.licenseNumber}',
                                              style: AppTypography.bodySm(
                                                context,
                                                color: AppColors.textSecondary,
                                              ).copyWith(fontFamily: 'Outfit'),
                                            ),
                                            if (hasSpecialty)
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
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: AppColors.secondary
                                                        .withAlpha(50),
                                                  ),
                                                ),
                                                child: Text(
                                                  item.specialtyName!,
                                                  style: AppTypography.labelXs(
                                                    context,
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Footer Row: Metadata / License Reg Date
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.appState.translate(
                                                  'doctors_publisher',
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
                                              item
                                                          .licenseRegistrationDate
                                                          .length >=
                                                      10
                                                  ? item.licenseRegistrationDate
                                                        .substring(0, 10)
                                                  : item.licenseRegistrationDate,
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
