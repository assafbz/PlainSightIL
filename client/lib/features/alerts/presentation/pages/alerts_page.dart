import 'package:flutter/material.dart';
import 'package:plainsight/core/theme/design_system.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/features/alerts/data/models/alert_model.dart';

import 'package:plainsight/core/utils/route_registry.dart';

class AlertsPage extends StatelessWidget {
  final AppStateNotifier appState;

  const AlertsPage({super.key, required this.appState});

  void _handleDeepLink(BuildContext context, String datasetId) {
    try {
      Navigator.of(
        context,
      ).push(RouteRegistry.getDatasetRoute(datasetId, appState));
    } on ArgumentError catch (_) {
      // Ignore unknown dataset IDs
    }
  }

  void _onAlertTapped(BuildContext context, AlertModel alert) {
    if (!alert.isRead) {
      appState.markAlertAsRead(alert.id);
    }
    if (alert.datasetId != null && alert.datasetId!.isNotEmpty) {
      _handleDeepLink(context, alert.datasetId!);
    }
  }

  Widget _buildUnauthenticatedState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassmorphicCard(
            borderRadius: 24,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 72, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    appState.translate('alerts_sign_in_title'),
                    style: AppTypography.headlineMd(
                      context,
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.translate('alerts_sign_in_desc'),
                    style: AppTypography.bodySm(
                      context,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => appState.signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: Text(
                      appState.translate('sign_in_google'),
                      style: AppTypography.labelXs(
                        context,
                        color: AppColors.onPrimary,
                      ).copyWith(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 72,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                appState.translate('alerts_empty_title'),
                style: AppTypography.headlineMd(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appState.translate('alerts_empty_desc'),
                style: AppTypography.bodySm(
                  context,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsList(BuildContext context, List<AlertModel> list) {
    final hasUnread = list.any((a) => !a.isRead);

    return Column(
      children: [
        if (hasUnread)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () => appState.markAllAlertsAsRead(),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(
                  appState.translate('alerts_mark_all_read'),
                  style: AppTypography.labelXs(
                    context,
                    color: AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 96.0),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final alert = list[index];
              final title =
                  alert.title[appState.locale] ?? alert.title['en'] ?? '';
              final desc =
                  alert.description[appState.locale] ??
                  alert.description['en'] ??
                  '';
              final statusColor = alert.isRead
                  ? Colors.transparent
                  : AppColors.primary;

              // Swipe-to-dismiss background layout
              final deleteBackground = Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.danger.withAlpha(120),
                    width: 1.0,
                  ),
                ),
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 28,
                ),
              );

              return Dismissible(
                key: ValueKey(alert.id),
                direction: DismissDirection.endToStart,
                secondaryBackground: deleteBackground,
                background: deleteBackground, // fallback
                onDismissed: (_) {
                  appState.deleteAlert(alert.id);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassmorphicCard(
                    onTap: () => _onAlertTapped(context, alert),
                    startBorderColor: alert.isRead ? null : AppColors.primary,
                    startBorderWidth: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAlertIcon(alert.type),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style:
                                          AppTypography.bodyLg(
                                            context,
                                            color: alert.isRead
                                                ? AppColors.textSecondary
                                                : AppColors.textPrimary,
                                          ).copyWith(
                                            fontWeight: alert.isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      desc,
                                      style:
                                          AppTypography.bodySm(
                                            context,
                                            color: AppColors.textSecondary,
                                          ).copyWith(
                                            fontWeight: alert.isRead
                                                ? FontWeight.normal
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!alert.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsetsDirectional.only(
                                    top: 6,
                                    start: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withAlpha(150),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              _formatTime(alert.createdAt, appState.locale),
                              style: AppTypography.labelXs(
                                context,
                                color: AppColors.textTertiary,
                              ).copyWith(fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertIcon(String type) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'new_dataset':
        iconData = Icons.rocket_launch_outlined;
        color = AppColors.primary;
        break;
      case 'new_government_dataset':
        iconData = Icons.library_add_outlined;
        color = AppColors.secondary;
        break;
      case 'new_records':
      default:
        iconData = Icons.update_outlined;
        color = AppColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  String _formatTime(DateTime time, String locale) {
    final now = DateTime.now();
    final difference = now.difference(time);

    final isHebrew = locale == 'he';

    if (difference.inMinutes < 1) {
      return isHebrew ? 'עכשיו' : 'Just now';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return isHebrew ? 'לפני $m דקות' : '$m min ago';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return isHebrew ? 'לפני $h שעות' : '$h hours ago';
    } else {
      final d = difference.inDays;
      if (d == 1) {
        return isHebrew ? 'אתמול' : 'Yesterday';
      }
      return isHebrew ? 'לפני $d ימים' : '$d days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        Widget body;
        if (!appState.isAuthenticated) {
          body = _buildUnauthenticatedState(context);
        } else if (appState.isLoadingAlerts) {
          body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (appState.alerts.isEmpty) {
          body = _buildEmptyState(context);
        } else {
          body = _buildAlertsList(context, appState.alerts);
        }

        return Scaffold(
          backgroundColor: AppColors.baseBg,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, -0.6),
                      radius: 1.2,
                      colors: [const Color(0x1A571BC1), AppColors.baseBg],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Text(
                        appState.translate('nav_alerts'),
                        style: AppTypography.headlineLg(
                          context,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
