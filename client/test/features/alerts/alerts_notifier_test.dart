import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/alerts/presentation/notifiers/alerts_notifier.dart';

void main() {
  group('AlertsNotifier Tests', () {
    late AlertsNotifier alertsNotifier;

    setUp(() {
      alertsNotifier = AlertsNotifier(isTesting: true);
    });

    test('Initial mock alerts and subscriptions load correctly', () {
      expect(alertsNotifier.alerts.length, 2);
      expect(alertsNotifier.unreadCount, 1);
      expect(alertsNotifier.isLoading, false);

      expect(alertsNotifier.isSubscribed('cellular_antennas'), true);
      expect(alertsNotifier.isSubscribed('local_market_bonds'), false);
    });

    test(
      'toggleSubscription adds or removes subscription and notifies listeners',
      () async {
        var listenerCalled = false;
        alertsNotifier.addListener(() {
          listenerCalled = true;
        });

        // Unsubscribe cellular_antennas
        await alertsNotifier.toggleSubscription(
          'cellular_antennas',
          'mock_uid',
        );
        expect(alertsNotifier.isSubscribed('cellular_antennas'), false);
        expect(listenerCalled, true);

        listenerCalled = false;

        // Subscribe new dataset
        await alertsNotifier.toggleSubscription(
          'local_market_bonds',
          'mock_uid',
        );
        expect(alertsNotifier.isSubscribed('local_market_bonds'), true);
        expect(listenerCalled, true);
      },
    );

    test('markAsRead updates alert status and unreadCount', () async {
      var listenerCalled = false;
      alertsNotifier.addListener(() {
        listenerCalled = true;
      });

      expect(alertsNotifier.unreadCount, 1);
      expect(
        alertsNotifier.alerts.firstWhere((a) => a.id == 'mock_alert_1').isRead,
        false,
      );

      await alertsNotifier.markAsRead('mock_alert_1', 'mock_uid');

      expect(alertsNotifier.unreadCount, 0);
      expect(
        alertsNotifier.alerts.firstWhere((a) => a.id == 'mock_alert_1').isRead,
        true,
      );
      expect(listenerCalled, true);
    });

    test('markAllAsRead updates all alerts to read status', () async {
      expect(alertsNotifier.unreadCount, 1);

      await alertsNotifier.markAllAsRead('mock_uid');

      expect(alertsNotifier.unreadCount, 0);
      expect(alertsNotifier.alerts.every((a) => a.isRead), true);
    });

    test(
      'deleteAlert removes the alert from feed and notifies listeners',
      () async {
        var listenerCalled = false;
        alertsNotifier.addListener(() {
          listenerCalled = true;
        });

        expect(alertsNotifier.alerts.length, 2);

        await alertsNotifier.deleteAlert('mock_alert_1', 'mock_uid');

        expect(alertsNotifier.alerts.length, 1);
        expect(alertsNotifier.alerts.any((a) => a.id == 'mock_alert_1'), false);
        expect(listenerCalled, true);
      },
    );
  });
}
