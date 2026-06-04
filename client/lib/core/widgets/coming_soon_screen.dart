import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final AppStateNotifier appState;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ValueKey(title),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassmorphicCard(
          startBorderColor: color,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: color),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Amber status badge reflecting "Phase 2 Roadmap"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.roadmapBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.roadmapText.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      appState.translate('badge_phase2'),
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.roadmapText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Back to home button
                  ElevatedButton.icon(
                    onPressed: () {
                      appState.setActiveTab(
                        0,
                      ); // Set active tab back to Home (0)
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: Text(appState.translate('back_button')),
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
        ),
      ),
    );
  }
}
