import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:plainsight/features/towers/presentation/pages/towers_page.dart';
import 'package:plainsight/features/directory/presentation/pages/directory_page.dart';
import 'package:plainsight/features/auth/presentation/pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: 'demo-app-id',
        messagingSenderId: 'demo-sender-id',
        projectId: 'demo-plainsightil',
      ),
    );
    // Connect to local Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
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
  void initState() {
    super.initState();
    _appState.initPermitMetadataListener();
  }

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
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: AppColors.surface,
              error: AppColors.danger,
            ),
            useMaterial3: true,
          ),
          home: Directionality(
            textDirection: _appState.textDirection,
            child: (!_appState.isAuthenticated && !_appState.isGuestMode)
                ? LoginPage(appState: _appState)
                : AppShell(appState: _appState),
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
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: Icon(Icons.menu, color: AppColors.primary),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
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
        return TowersScreen(
          key: const ValueKey('towers_screen'),
          appState: appState,
        );
      case 2:
        return ComingSoonScreen(
          key: const ValueKey('water_coming_soon'),
          title: appState.translate('water_roadmap_title'),
          icon: Icons.water_drop,
          color: AppColors.info,
          description: appState.translate('water_roadmap_desc'),
          appState: appState,
        );
      case 3:
        return ComingSoonScreen(
          key: const ValueKey('budget_coming_soon'),
          title: appState.translate('budget_roadmap_title'),
          icon: Icons.payments,
          color: AppColors.secondary,
          description: appState.translate('budget_roadmap_desc'),
          appState: appState,
        );
      case 4:
        return ComingSoonScreen(
          key: const ValueKey('alerts_coming_soon'),
          title: appState.translate('alerts_roadmap_title'),
          icon: Icons.notifications,
          color: AppColors.danger,
          description: appState.translate('alerts_roadmap_desc'),
          appState: appState,
        );
      case 5:
        return DatasetDirectoryScreen(
          key: const ValueKey('directory_screen'),
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
              icon: Icons.cell_tower,
              label: appState.translate('nav_towers'),
            ),
            _buildNavItem(
              context,
              index: 2,
              icon: Icons.water_drop,
              label: appState.translate('nav_water'),
            ),
            _buildNavItem(
              context,
              index: 3,
              icon: Icons.payments,
              label: appState.translate('nav_budget'),
            ),
            _buildNavItem(
              context,
              index: 4,
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

class NavigationDrawerWidget extends StatelessWidget {
  final AppStateNotifier appState;

  const NavigationDrawerWidget({super.key, required this.appState});

  Future<void> _launchDataGovUrl(BuildContext context) async {
    const urlString = 'https://data.gov.il';
    final uri = Uri.parse(urlString);

    // Security check: must use HTTPS and have data.gov.il host
    if (uri.scheme == 'https' && uri.host == 'data.gov.il') {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            _showErrorSnackBar(context, 'Could not launch data.gov.il');
          }
        }
      } catch (e) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Error launching URL: $e');
        }
      }
    } else {
      _showErrorSnackBar(
        context,
        'Security check failed: Invalid URL scheme or host.',
      );
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 600
        ? (screenWidth * 0.85).clamp(0.0, 304.0)
        : 304.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          border: Border.all(color: AppColors.glassBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.35),
              blurRadius: 32.0,
              spreadRadius: 0.0,
              offset: Offset(isRtl ? -8.0 : 8.0, 0.0),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: SafeArea(
              left: false,
              right: false,
              child: Column(
                children: [
                  // 1. Header Zone
                  _buildHeader(context),

                  // User Profile info
                  _buildUserProfile(context),

                  // 2. Scrollable Body
                  Expanded(
                    child: RepaintBoundary(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildNavItem(
                            context,
                            index: 0,
                            icon: Icons.home,
                            titleKey: 'nav_home',
                            isActive: appState.activeTab == 0,
                            isRoadmap: false,
                          ),
                          _buildNavItem(
                            context,
                            index: 1,
                            icon: Icons.cell_tower,
                            titleKey: 'towers_title',
                            isActive: appState.activeTab == 1,
                            isRoadmap: false,
                          ),
                          _buildNavItem(
                            context,
                            index: 2,
                            icon: Icons.water_drop,
                            titleKey: 'water_title',
                            isActive: appState.activeTab == 2,
                            isRoadmap: true,
                          ),
                          _buildNavItem(
                            context,
                            index: 3,
                            icon: Icons.payments,
                            titleKey: 'budget_title',
                            isActive: appState.activeTab == 3,
                            isRoadmap: true,
                          ),
                          _buildNavItem(
                            context,
                            index: 4,
                            icon: Icons.notifications,
                            titleKey: 'alerts_title',
                            isActive: appState.activeTab == 4,
                            isRoadmap: true,
                          ),
                          _buildNavItem(
                            context,
                            index: 5,
                            icon: Icons.folder_open,
                            titleKey: 'nav_directory',
                            isActive: appState.activeTab == 5,
                            isRoadmap: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Footer Zone
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    if (!appState.isAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassGlow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Icon(Icons.person_outline, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appState.locale == 'he' ? 'משתמש אורח' : 'Guest User',
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      appState.setGuestMode(false); // redirects to Login
                    },
                    child: Text(
                      appState.translate('login_label'),
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.primary,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final displayName =
        appState.currentUser?.displayName ??
        appState.mockUser?['name'] ??
        'User';
    final email =
        appState.currentUser?.email ?? appState.mockUser?['email'] ?? '';
    final photoUrl = appState.currentUser?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassGlow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.bodySm(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTypography.labelXs(
                      context,
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo text
          Expanded(
            child: Text(
              appState.translate('app_title'),
              style: AppTypography.getTextStyle(
                context,
                fontSize: appState.locale == 'he' ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          // Language selector toggle
          GestureDetector(
            key: const ValueKey('drawer_language_toggle'),
            onTap: () {
              appState.toggleLocale();
            },
            child: Semantics(
              label: appState.locale == 'en'
                  ? 'החלף לעברית'
                  : 'Switch to English',
              button: true,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                  style: AppTypography.labelXs(
                    context,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String titleKey,
    required bool isActive,
    required bool isRoadmap,
  }) {
    final title = appState.translate(titleKey);
    final statusString = isRoadmap
        ? appState.translate('badge_roadmap')
        : (isActive ? appState.translate('badge_active') : '');

    final labelColor = isActive ? AppColors.primary : AppColors.textSecondary;
    final itemTextStyle = AppTypography.getTextStyle(
      context,
      fontSize: isActive
          ? (appState.locale == 'he' ? 17 : 16)
          : (appState.locale == 'he' ? 16 : 15),
      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      color: labelColor,
    );

    return Semantics(
      label:
          'Navigate to $title, Status: ${isRoadmap ? "Roadmap" : (isActive ? "Active" : "Inactive")}',
      button: true,
      selected: isActive,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            appState.setActiveTab(index);
            Navigator.of(context).pop(); // Close drawer
          },
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.glassGlow : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                if (isActive) ...[
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(icon, color: labelColor, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: itemTextStyle)),
                if (isRoadmap)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.roadmapBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.roadmapText.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusString,
                      style: AppTypography.getTextStyle(
                        context,
                        fontSize: appState.locale == 'he' ? 12 : 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.roadmapText,
                      ),
                    ),
                  )
                else if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.activeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.activeText.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusString,
                      style: AppTypography.getTextStyle(
                        context,
                        fontSize: appState.locale == 'he' ? 12 : 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.activeText,
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

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (appState.isAuthenticated) ...[
            Semantics(
              label: 'Log out from the application',
              button: true,
              child: GestureDetector(
                key: const ValueKey('drawer_logout_button'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  appState.signOut();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          appState.translate('logout_label'),
                          style: AppTypography.bodySm(
                            context,
                            color: AppColors.danger,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Theme Toggle button
              Semantics(
                label: 'Toggle dark theme',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('drawer_theme_toggle'),
                  onTap: () {
                    appState.toggleTheme();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedRotation(
                        turns: appState.isDarkMode ? 0.0 : 0.5,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          appState.isDarkMode
                              ? Icons.nightlight_round
                              : Icons.wb_sunny,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // App Version
              Text(
                'v1.0.0',
                style: AppTypography.getTextStyle(
                  context,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Data Source attribution link
          GestureDetector(
            onTap: () => _launchDataGovUrl(context),
            child: Semantics(
              label: 'Navigate to data.gov.il website',
              button: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      appState.translate('attribution_prefix'),
                      style: AppTypography.getTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'data.gov.il',
                      style: AppTypography.getTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
