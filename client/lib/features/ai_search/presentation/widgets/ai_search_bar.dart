import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Premium glassmorphic search input field.
/// Supports a read-only tapping trigger mode and an interactive typing search mode.
class AiSearchBar extends StatefulWidget {
  final AppStateNotifier appState;
  final VoidCallback onTap;
  final bool readOnly;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;

  const AiSearchBar({
    super.key,
    required this.appState,
    required this.onTap,
    this.readOnly = true,
    this.controller,
    this.onSubmitted,
  });

  @override
  State<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends State<AiSearchBar> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.appState.locale == 'he';
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed && widget.readOnly ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withAlpha(120),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 16.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.readOnly
                    ? Text(
                        widget.appState.translate('ai_search_hint'),
                        style: AppTypography.bodySm(
                          context,
                          color: AppColors.textTertiary,
                        ).copyWith(fontFamily: isRtl ? 'Assistant' : 'Outfit'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : TextField(
                        controller: widget.controller,
                        readOnly: false,
                        autofocus: true,
                        style: AppTypography.bodySm(
                          context,
                          color: AppColors.textPrimary,
                        ).copyWith(fontFamily: isRtl ? 'Assistant' : 'Outfit'),
                        textInputAction: TextInputAction.search,
                        onSubmitted: widget.onSubmitted,
                        decoration: InputDecoration(
                          hintText: widget.appState.translate('ai_search_hint'),
                          hintStyle:
                              AppTypography.bodySm(
                                context,
                                color: AppColors.textTertiary,
                              ).copyWith(
                                fontFamily: isRtl ? 'Assistant' : 'Outfit',
                              ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              if (!widget.readOnly && widget.controller != null)
                ListenableBuilder(
                  listenable: widget.controller!,
                  builder: (context, _) {
                    if (widget.controller!.text.isEmpty)
                      return const SizedBox.shrink();
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        widget.controller!.clear();
                        if (widget.onSubmitted != null) {
                          widget.onSubmitted!('');
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
