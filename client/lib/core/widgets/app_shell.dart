import 'package:flutter/material.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:plainsight/features/directory/presentation/pages/directory_page.dart';
import 'package:plainsight/core/widgets/coming_soon_screen.dart';
import 'package:plainsight/core/widgets/navigation_drawer.dart';

class AppShell extends StatelessWidget {
  final AppStateNotifier appState;

  const AppShell({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    // Scaffold without default AppBar and BottomNavigationBar to create
    // a completely custom, premium glassmorphic overlay layout.
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      drawer: NavigationDrawerWidget(appState: appState),
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
                    const Color(0x1F571BC1), // subtle secondary violet glow
                    AppColors.baseBg,
                  ],
                ),
              ),
            ),
          ),

          // Main View Viewport
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildHeader(context),

                // Active View Body
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    child: _buildActiveView(context),
                  ),
                ),

                // Space for Floating Custom Bottom Navigation Bar
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Floating Bottom Navigation Bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildBottomNavigationBar(context),
          ),
        ],
      ),
    );
  }

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Open navigation menu',
                container: true,
                child: Builder(
                  builder: (context) {
                    return IconButton(
                      tooltip: 'Open navigation menu',
                      icon: Icon(Icons.menu, color: AppColors.primary),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                appState.translate('app_title'),
                style: AppTypography.headlineLg(
                  context,
                  color: AppColors.primary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          // Bilingual Language Toggle
          GestureDetector(
            onTap: () => appState.toggleLocale(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppStateColors.glowColor(appState.locale),
                  width: 1.5,
                ),
              ),
              child: Text(
                appState.translate('toggle_lang'),
                style: AppTypography.labelXs(context, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(BuildContext context) {
    switch (appState.activeTab) {
      case 0:
        return DashboardScreen(appState: appState);
      case 1:
        return DatasetDirectoryScreen(
          key: const ValueKey('directory_screen'),
          appState: appState,
        );
      case 2:
        return ComingSoonScreen(
          key: const ValueKey('alerts_coming_soon'),
          title: appState.translate('alerts_roadmap_title'),
          icon: Icons.notifications,
          color: AppColors.danger,
          description: appState.translate('alerts_roadmap_desc'),
          appState: appState,
        );
      default:
        return DashboardScreen(appState: appState);
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return GlassmorphicCard(
      borderRadius: 24.0,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context,
              index: 0,
              icon: Icons.home,
              label: appState.translate('nav_home'),
            ),
            _buildNavItem(
              context,
              index: 1,
              icon: Icons.folder_open,
              label: appState.translate('nav_directory'),
            ),
            _buildNavItem(
              context,
              index: 2,
              icon: Icons.notifications,
              label: appState.translate('nav_alerts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = appState.activeTab == index;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => appState.setActiveTab(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: isActive
              ? BoxDecoration(
                  color: AppColors.glassGlow,
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.labelXs(context, color: color).copyWith(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppStateColors {
  static Color glowColor(String locale) {
    return locale == 'en'
        ? AppColors.secondary.withAlpha(102)
        : AppColors.primary.withAlpha(102);
  }
}
