import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:plainsight/features/admin/presentation/pages/admin_page.dart';
import 'package:plainsight/core/widgets/app_shell.dart';

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

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
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
                                icon: Icons.folder_open,
                                titleKey: 'nav_directory',
                                isActive: appState.activeTab == 1,
                                isRoadmap: false,
                              ),
                              _buildNavItem(
                                context,
                                index: 2,
                                icon: Icons.notifications,
                                titleKey: 'alerts_title',
                                isActive: appState.activeTab == 2,
                                isRoadmap: true,
                              ),
                              if (appState.isAdmin) ...[
                                const Divider(
                                  color: Color(0x14FFFFFF),
                                  height: 16,
                                ),
                                _buildAdminNavItem(context),
                              ],
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
      },
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

    final profile = appState.userProfile;
    final displayName =
        (profile != null &&
            (profile.firstName.isNotEmpty || profile.lastName.isNotEmpty))
        ? '${profile.firstName} ${profile.lastName}'.trim()
        : (appState.currentUser?.displayName ??
              appState.mockUser?['name'] ??
              'User');
    final email = (profile != null && profile.email.isNotEmpty)
        ? profile.email
        : (appState.currentUser?.email ?? appState.mockUser?['email'] ?? '');
    final photoUrl = appState.currentUser?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ProfileSettingsPage(appState: appState),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    final slideTransition =
                        Tween<Offset>(
                          begin: const Offset(0.0, 0.1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.fastOutSlowIn,
                          ),
                        );
                    final fadeTransition = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(animation);
                    return SlideTransition(
                      position: slideTransition,
                      child: FadeTransition(
                        opacity: fadeTransition,
                        child: child,
                      ),
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassGlow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
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
        ),
      ),
    );
  }

  Widget _buildAdminNavItem(BuildContext context) {
    final title = appState.translate('nav_admin');
    final labelColor = AppColors.primary;
    final itemTextStyle = AppTypography.getTextStyle(
      context,
      fontSize: appState.locale == 'he' ? 16 : 15,
      fontWeight: FontWeight.w600,
      color: labelColor,
    );

    return Semantics(
      label: 'Navigate to $title',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey('drawer_admin_button'),
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    AdminPage(appState: appState),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          },
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: labelColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: itemTextStyle)),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
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
          // Logo image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/plainsight_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
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
                appState.appVersion.isNotEmpty ? 'v${appState.appVersion}' : '',
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
