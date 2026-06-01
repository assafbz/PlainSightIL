import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/directory/data/models/dataset_metadata_model.dart';

class DatasetCard extends StatefulWidget {
  final DatasetMetadataModel dataset;
  final int requestCount;
  final VoidCallback onTapAction;
  final bool isRequesting;
  final String currentLocale;
  final String Function(String) translate;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const DatasetCard({
    super.key,
    required this.dataset,
    required this.requestCount,
    required this.onTapAction,
    required this.currentLocale,
    required this.translate,
    this.isRequesting = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<DatasetCard> createState() => _DatasetCardState();
}

class _DatasetCardState extends State<DatasetCard> {
  double _scale = 1.0;
  bool _isExpanded = false;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.97;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = widget.dataset.isSupported;
    final accentColor = isSupported ? AppColors.success : AppColors.info;
    final totalRequests = widget.requestCount;

    // Safely extract date string (e.g. 2026-06-01)
    String dateStr = '';
    try {
      dateStr = widget.dataset.lastUpdated.toIso8601String().substring(0, 10);
    } catch (_) {
      dateStr = 'N/A';
    }

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: GlassmorphicCard(
          startBorderColor: accentColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Publisher Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.withAlpha(150),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.dataset.publisher,
                        style: AppTypography.labelXs(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (widget.onFavoriteToggle != null)
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            icon: Icon(
                              widget.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: widget.isFavorite
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: widget.onFavoriteToggle,
                          ),
                        if (isSupported)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.activeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.translate('badge_active'),
                              style: AppTypography.labelXs(
                                context,
                                color: AppColors.activeText,
                              ),
                            ),
                          )
                        else if (totalRequests > 0)
                          Row(
                            children: [
                              Icon(Icons.bolt, size: 14, color: AppColors.info),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.translate('requests_label')}$totalRequests',
                                style: AppTypography.labelXs(
                                  context,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Title (forced RTL since governmental CKAN is in Hebrew)
                Text(
                  widget.dataset.title,
                  style: AppTypography.headlineMd(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),

                // 3. Expandable Description (notes)
                if (widget.dataset.notes.isNotEmpty) ...[
                  Text(
                    widget.dataset.notes,
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: _isExpanded ? 100 : 2,
                    overflow: _isExpanded
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  // Read more toggle button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Text(
                      _isExpanded
                          ? (widget.currentLocale == 'he'
                                ? 'קרא פחות'
                                : 'Read less')
                          : (widget.currentLocale == 'he'
                                ? 'קרא עוד'
                                : 'Read more'),
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 4. Resource statistics and Last Updated Date
                Divider(color: AppColors.glassBorder, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.dataset.resourceCount}${widget.translate('resources_label')}',
                          style: AppTypography.bodySm(
                            context,
                            color: AppColors.textTertiary,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.translate('updated_label')}$dateStr',
                      style: AppTypography.bodySm(
                        context,
                        color: AppColors.textTertiary,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Action Area Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: widget.isRequesting
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: accentColor,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor.withAlpha(25),
                            foregroundColor: accentColor,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: accentColor.withAlpha(100),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onPressed: widget.onTapAction,
                          child: Text(
                            isSupported
                                ? widget.translate('open_visualizer')
                                : widget.translate('request_integration'),
                            style:
                                AppTypography.labelXs(
                                  context,
                                  color: accentColor,
                                ).copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
