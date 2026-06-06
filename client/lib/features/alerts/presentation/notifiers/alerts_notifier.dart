import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/alert_model.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/utils/app_logger.dart';

/// Scoped state notifier managing subscription statuses, real-time alert feeds,
/// and in-memory mock operations for offline testing.
class AlertsNotifier extends ChangeNotifier {
  final bool isTesting;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Checks if Firebase is initialized.
  bool get isFirebaseInitialized {
    if (AppStateNotifier.testIsFirebaseInitialized != null) {
      return AppStateNotifier.testIsFirebaseInitialized!;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  StreamSubscription<QuerySnapshot>? _alertsSubscription;
  StreamSubscription<QuerySnapshot>? _subsSubscription;

  List<AlertModel> _alerts = [];
  List<String> _subscribedDatasetIds = [];
  bool _isLoading = false;

  /// Gets the list of parsed alerts.
  List<AlertModel> get alerts => _alerts;

  /// Gets the list of active user subscriptions.
  List<String> get subscribedDatasetIds => _subscribedDatasetIds;

  /// Returns true if alerts or subscriptions are loading from the database.
  bool get isLoading => _isLoading;

  /// Returns the count of unread alerts.
  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  /// Constructs an [AlertsNotifier].
  AlertsNotifier({this.isTesting = false, FirebaseFirestore? firestore})
    : _firestoreOverride = firestore {
    AppLogger.info('Initializing AlertsNotifier (isTesting: $isTesting)');
    if (isTesting) {
      _loadMockData();
    }
  }

  /// Initializes Firestore stream listeners for alerts and subscriptions.
  void initAlertsListener(String? userId) {
    cancelListeners();
    if (isTesting) return;

    if (userId == null || userId.isEmpty) {
      _alerts = [];
      _subscribedDatasetIds = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    if (!isFirebaseInitialized) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Stream subscriptions
      _subsSubscription = _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen(
            (snapshot) {
              _subscribedDatasetIds = snapshot.docs
                  .map((doc) => doc.data()['datasetId'] as String? ?? '')
                  .where((id) => id.isNotEmpty)
                  .toList();
              notifyListeners();
            },
            onError: (Object error) {
              AppLogger.error('Subscriptions Stream Error', error);
            },
          );

      // Stream alerts
      _alertsSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              _alerts = snapshot.docs.map((doc) {
                final data = doc.data();
                return AlertModel.fromMap(data, doc.id);
              }).toList();
              _isLoading = false;
              notifyListeners();
            },
            onError: (Object error) {
              AppLogger.error('Alerts Stream Error', error);
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      AppLogger.error('Failed to bind AlertsNotifier listeners', e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels active stream subscriptions.
  void cancelListeners() {
    _alertsSubscription?.cancel();
    _alertsSubscription = null;
    _subsSubscription?.cancel();
    _subsSubscription = null;
  }

  /// Checks if the user is subscribed to a dataset.
  bool isSubscribed(String datasetId) {
    return _subscribedDatasetIds.contains(datasetId);
  }

  /// Toggles dataset subscription in Firestore or in-memory.
  Future<void> toggleSubscription(String datasetId, String userId) async {
    if (userId.isEmpty) return;

    final subId = '${userId}_$datasetId';

    if (isTesting) {
      if (_subscribedDatasetIds.contains(datasetId)) {
        _subscribedDatasetIds.remove(datasetId);
      } else {
        _subscribedDatasetIds.add(datasetId);
      }
      notifyListeners();
      return;
    }

    try {
      final docRef = _firestore.collection('subscriptions').doc(subId);
      final exists = _subscribedDatasetIds.contains(datasetId);

      if (exists) {
        await docRef.delete();
        AppLogger.info('Deleted subscription document for $datasetId');
      } else {
        await docRef.set({
          'id': subId,
          'userId': userId,
          'datasetId': datasetId,
          'createdAt': DateTime.now().toIso8601String(),
        });
        AppLogger.info('Created subscription document for $datasetId');
      }
    } catch (e) {
      AppLogger.error('Failed to toggle subscription in Firestore', e);
      rethrow;
    }
  }

  /// Marks a specific alert as read.
  Future<void> markAsRead(String alertId, String userId) async {
    if (isTesting) {
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx != -1) {
        final alert = _alerts[idx];
        _alerts[idx] = AlertModel(
          id: alert.id,
          userId: alert.userId,
          type: alert.type,
          title: alert.title,
          description: alert.description,
          datasetId: alert.datasetId,
          recordCount: alert.recordCount,
          isRead: true,
          createdAt: alert.createdAt,
        );
        notifyListeners();
      }
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(alertId)
          .update({'isRead': true});
    } catch (e) {
      AppLogger.error('Failed to mark alert $alertId as read', e);
      rethrow;
    }
  }

  /// Marks all unread alerts in the feed as read.
  Future<void> markAllAsRead(String userId) async {
    if (isTesting) {
      for (int i = 0; i < _alerts.length; i++) {
        final alert = _alerts[i];
        if (!alert.isRead) {
          _alerts[i] = AlertModel(
            id: alert.id,
            userId: alert.userId,
            type: alert.type,
            title: alert.title,
            description: alert.description,
            datasetId: alert.datasetId,
            recordCount: alert.recordCount,
            isRead: true,
            createdAt: alert.createdAt,
          );
        }
      }
      notifyListeners();
      return;
    }

    final unreadAlerts = _alerts.where((a) => !a.isRead).toList();
    if (unreadAlerts.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final alert in unreadAlerts) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('alerts')
            .doc(alert.id);
        batch.update(docRef, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      AppLogger.error('Failed to mark all alerts as read', e);
      rethrow;
    }
  }

  /// Deletes a specific alert.
  Future<void> deleteAlert(String alertId, String userId) async {
    if (isTesting) {
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      AppLogger.error('Failed to delete alert $alertId', e);
      rethrow;
    }
  }

  void _loadMockData() {
    _subscribedDatasetIds = ['cellular_antennas'];
    _alerts = [
      AlertModel(
        id: 'mock_alert_1',
        userId: 'mock_uid',
        type: 'new_records',
        title: {
          'he': 'נקלטו רשומות חדשות באנטנות סלולריות',
          'en': 'New Records Ingested in Cellular Antennas',
        },
        description: {
          'he': 'נקלטו 14 רשומות חדשות במאגר \'אנטנות סלולריות\'.',
          'en': 'Ingested 14 new records into \'Cellular Antennas\' dataset.',
        },
        datasetId: 'cellular_antennas',
        recordCount: 14,
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      AlertModel(
        id: 'mock_alert_2',
        userId: 'mock_uid',
        type: 'new_dataset',
        title: {
          'he': 'מאגר מידע חדש זמין לצפייה: אג"ח בשוק המקומי',
          'en': 'New Visualizer Supported: Local Market Bonds',
        },
        description: {
          'he':
              'מאגר \'אג"ח בשוק המקומי\' זמין כעת לצפייה והדמיות אינטראקטיביות באפליקציה!',
          'en':
              'The dataset \'Local Market Bonds\' is now available for interactive visualization in the app!',
        },
        datasetId: 'local_market_bonds',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  void dispose() {
    cancelListeners();
    super.dispose();
  }
}
