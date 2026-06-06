import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import '../../data/models/ai_search_result_model.dart';

/// Clickable glassmorphic badge representing a citation source.
/// Features a micro-animation scaling effect on tap and highlights primary link colors.
class CitationBadge extends StatefulWidget {
  final CitationModel citation;
  final VoidCallback onTap;

  const CitationBadge({super.key, required this.citation, required this.onTap});

  @override
  State<CitationBadge> createState() => _CitationBadgeState();
}

class _CitationBadgeState extends State<CitationBadge> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withAlpha(120),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.citation.title.isNotEmpty
                      ? widget.citation.title
                      : widget.citation.id,
                  style: AppTypography.labelXs(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
