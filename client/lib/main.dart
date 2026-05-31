import 'package:flutter/material.dart';
import 'app_state.dart';
import 'dashboard_screen.dart';
import 'design_system.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppStateNotifier _appState = AppStateNotifier();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'PlainSightIL',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.baseBg,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: AppColors.surface,
              error: AppColors.danger,
            ),
            useMaterial3: true,
          ),
          home: Directionality(
            textDirection: _appState.textDirection,
            child: AppShell(appState: _appState),
          ),
        );
      },
    );
  }
}

class AppShell extends StatelessWidget {
  final AppStateNotifier appState;

  const AppShell({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    // Scaffold without default AppBar and BottomNavigationBar to create
    // a completely custom, premium glassmorphic overlay layout.
    return Scaffold(
      backgroundColor: AppColors.baseBg,
      body: Stack(
        children: [
          // Background Atmospheric Gradients
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.6, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0x1F571BC1), // subtle secondary violet glow
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
      decoration: const BoxDecoration(
        color: Color(0x33000000),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Menu drawer not implemented yet'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                appState.translate('app_title'),
                style: AppTypography.headlineLg(context, color: AppColors.primary)
                    .copyWith(fontWeight: FontWeight.bold),
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
        return _buildPlaceholderScreen(
          context,
          title: appState.translate('towers_title'),
          icon: Icons.cell_tower,
          color: AppColors.primary,
        );
      case 2:
        return _buildPlaceholderScreen(
          context,
          title: appState.translate('water_title'),
          icon: Icons.water_drop,
          color: AppColors.info,
        );
      case 3:
        return _buildPlaceholderScreen(
          context,
          title: appState.translate('budget_title'),
          icon: Icons.payments,
          color: AppColors.secondary,
        );
      case 4:
        return _buildPlaceholderScreen(
          context,
          title: appState.translate('nav_alerts'),
          icon: Icons.notifications,
          color: AppColors.danger,
        );
      default:
        return DashboardScreen(appState: appState);
    }
  }

  Widget _buildPlaceholderScreen(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Center(
      key: ValueKey(title),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassmorphicCard(
          startBorderColor: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: color),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTypography.headlineMd(context, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'This dataset screen is under construction. Future integrations will include live data and interactive maps.',
                  style: AppTypography.bodySm(context, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            _buildNavItem(context, index: 0, icon: Icons.home, label: appState.translate('nav_home')),
            _buildNavItem(context, index: 1, icon: Icons.cell_tower, label: appState.translate('nav_towers')),
            _buildNavItem(context, index: 2, icon: Icons.water_drop, label: appState.translate('nav_water')),
            _buildNavItem(context, index: 3, icon: Icons.payments, label: appState.translate('nav_budget')),
            _buildNavItem(context, index: 4, icon: Icons.notifications, label: appState.translate('nav_alerts')),
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
    return locale == 'en' ? AppColors.secondary.withAlpha(102) : AppColors.primary.withAlpha(102);
  }
}
