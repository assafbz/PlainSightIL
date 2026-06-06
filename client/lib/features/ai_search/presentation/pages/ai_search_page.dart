import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import '../state/ai_search_notifier.dart';
import '../widgets/ai_search_bar.dart';
import '../widgets/citation_badge.dart';
import '../../data/models/ai_search_result_model.dart';

/// Inline parsed text renderer that turns **bold** markers and [cit-XX] brackets
/// into rich styled text spans and clickable inline widgets.
class ParsedAnswerText extends StatelessWidget {
  final String text;
  final List<CitationModel> citations;
  final void Function(CitationModel) onCitationTap;

  const ParsedAnswerText({
    super.key,
    required this.text,
    required this.citations,
    required this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final textStyle = AppTypography.bodySm(
      context,
      color: AppColors.textPrimary,
    ).copyWith(fontFamily: isRtl ? 'Assistant' : 'Outfit', height: 1.6);

    final List<InlineSpan> spans = [];
    final RegExp regex = RegExp(
      r'(\[cit-\d+\])|(\*\*.*?\*\*)',
      multiLine: true,
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: textStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('[cit-')) {
        final citId = matchedText.replaceAll('[', '').replaceAll(']', '');
        final citation = citations.firstWhere(
          (c) => c.id == citId,
          orElse: () =>
              CitationModel(id: citId, datasetId: '', docId: '', title: ''),
        );

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => onCitationTap(citation),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(90),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  citId,
                  style: AppTypography.labelXs(
                    context,
                    color: AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith('**')) {
        final content = matchedText.substring(2, matchedText.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: textStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: textStyle));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

/// Dynamic Shimmer thinking loader displaying a clean micro-animation while search runs.
class ShimmerLoader extends StatelessWidget {
  final AppStateNotifier appState;
  const ShimmerLoader({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              appState.translate('ai_search_thinking'),
              style: AppTypography.bodySm(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Placeholder skeleton lines
        Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 16,
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 16,
          width: MediaQuery.of(context).size.width * 0.6,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

/// Interactive Search View Page overlay.
class AiSearchPage extends StatefulWidget {
  final AppStateNotifier appState;
  final void Function(BuildContext context, String datasetId, String? docId)
  onNavigate;

  const AiSearchPage({
    super.key,
    required this.appState,
    required this.onNavigate,
  });

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  late final AiSearchNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = AiSearchNotifier(appState: widget.appState);
    _notifier.loadHistory();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _notifier.performSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.appState.locale == 'he';
    return Directionality(
      textDirection: widget.appState.textDirection,
      child: Scaffold(
        backgroundColor: AppColors.baseBg,
        body: Stack(
          children: [
            // Ambient radial background glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.4, -0.7),
                    radius: 1.2,
                    colors: [
                      const Color(0x1F7C4DFF), // subtle deep purple AI glow
                      AppColors.baseBg,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isRtl ? Icons.arrow_forward : Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.appState.translate('ai_search_title'),
                                style: AppTypography.headlineLg(
                                  context,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                widget.appState.translate('ai_search_desc'),
                                style: AppTypography.labelXs(
                                  context,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Active Search Input Bar
                    AiSearchBar(
                      appState: widget.appState,
                      readOnly: false,
                      controller: _queryController,
                      onTap: () {},
                      onSubmitted: _onSearchSubmitted,
                    ),
                    const SizedBox(height: 24),

                    // Scrollable content area representing state updates
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _notifier,
                        builder: (context, _) {
                          if (_notifier.isLoading) {
                            return ShimmerLoader(appState: widget.appState);
                          }

                          if (_notifier.errorMessage != null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.danger,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      isRtl ? 'שגיאה בחיפוש' : 'Search Error',
                                      style: AppTypography.bodyLg(
                                        context,
                                        color: AppColors.danger,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  _notifier.errorMessage!,
                                  style: AppTypography.bodySm(
                                    context,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            );
                          }

                          final result = _notifier.searchResult;
                          if (result != null) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Inline citation rich text response
                                  ParsedAnswerText(
                                    text: result.answer,
                                    citations: result.citations,
                                    onCitationTap: (cit) {
                                      if (cit.datasetId.isNotEmpty) {
                                        widget.onNavigate(
                                          context,
                                          cit.datasetId,
                                          cit.docId,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 30),

                                  // Citation Sources badge grid if citations are available
                                  if (result.citations.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.bookmark_outline_rounded,
                                          color: AppColors.primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.appState.translate(
                                            'ai_search_citations',
                                          ),
                                          style:
                                              AppTypography.labelXs(
                                                context,
                                                color: AppColors.textSecondary,
                                              ).copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: result.citations.map((cit) {
                                        return CitationBadge(
                                          citation: cit,
                                          onTap: () {
                                            if (cit.datasetId.isNotEmpty) {
                                              widget.onNavigate(
                                                context,
                                                cit.datasetId,
                                                cit.docId,
                                              );
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ],
                              ),
                            );
                          }

                          // Default query history view
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.appState.translate(
                                      'ai_search_history',
                                    ),
                                    style: AppTypography.bodySm(
                                      context,
                                      color: AppColors.textSecondary,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_notifier.history.isNotEmpty)
                                    TextButton(
                                      onPressed: () => _notifier.clearHistory(),
                                      child: Text(
                                        isRtl ? 'נקה הכל' : 'Clear All',
                                        style: AppTypography.bodySm(
                                          context,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_notifier.history.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 40.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          size: 40,
                                          color: AppColors.textTertiary
                                              .withValues(alpha: 0.4),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.appState.translate(
                                            'ai_search_no_history',
                                          ),
                                          style: AppTypography.bodySm(
                                            context,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        // Quick suggestions
                                        _buildSuggestionTile(
                                          isRtl
                                              ? 'קריאות לתיקון של טויוטה'
                                              : 'Toyota recalls',
                                        ),
                                        _buildSuggestionTile(
                                          isRtl
                                              ? 'אזהרת מסע לטורקיה'
                                              : 'Turkey travel warnings',
                                        ),
                                        _buildSuggestionTile(
                                          isRtl
                                              ? 'אנטנות סלולריות בתל אביב'
                                              : 'Cellular antennas in Tel Aviv',
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _notifier.history.length,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final q = _notifier.history[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.history_rounded,
                                          color: AppColors.textTertiary,
                                          size: 18,
                                        ),
                                        title: Text(
                                          q,
                                          style: AppTypography.bodySm(
                                            context,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        trailing: Icon(
                                          isRtl
                                              ? Icons.arrow_left
                                              : Icons.arrow_right,
                                          color: AppColors.textTertiary,
                                        ),
                                        onTap: () {
                                          _queryController.text = q;
                                          _onSearchSubmitted(q);
                                        },
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
      ),
    );
  }

  Widget _buildSuggestionTile(String suggestion) {
    return GestureDetector(
      onTap: () {
        _queryController.text = suggestion;
        _onSearchSubmitted(suggestion);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceLow.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion,
                style: AppTypography.bodySm(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
