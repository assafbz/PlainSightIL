import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/travel_warning_model.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles travel warnings collection streams,
/// loader flags, and test mode data fallbacks.
class TravelWarningsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<TravelWarningRecordModel> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns travel warnings records list.
  List<TravelWarningRecordModel> get warningRecords => _syncManager.records;

  /// Checks if travel warnings query is loading.
  bool get isLoadingWarnings => _syncManager.isLoading;

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

  /// Construct and initialize the TravelWarningsNotifier.
  TravelWarningsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<TravelWarningRecordModel>(
      datasetId: DatasetIds.travelWarnings,
      fromMap: TravelWarningRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to travel warnings collection.
  void initTravelWarningsListener() {
    final mockList = _isTesting
        ? [
            TravelWarningRecordModel(
              id: '1',
              idNum: 1,
              continent: 'אפריקה',
              country: 'אוגנדה',
              recommendations:
                  'רמה 2/ איום מזדמן: המלצה לנקוט באמצעי זהירות מוגברים.',
              details: 'להמלצה באתר המטה לביטחון לאומי',
              logo: 'לוגו',
              date: '2026-06-03T00:00:00.000Z',
              office: 'מל"ל',
              warningLevel: 2,
            ),
            TravelWarningRecordModel(
              id: '2',
              idNum: 2,
              continent: 'אסיה',
              country: 'אוזבקיסטאן',
              recommendations:
                  'רמת איום משולבת: רמה 4/ איום גבוה ולהימנע מהגעה לאיזור הגבול עם אפגניסטן.',
              details: 'להמלצה באתר המטה לביטחון לאומי',
              logo: 'לוגו',
              date: '2026-06-03T00:00:00.000Z',
              office: 'מל"ל',
              warningLevel: 4,
            ),
            TravelWarningRecordModel(
              id: '3',
              idNum: 3,
              continent: 'אירופה',
              country: 'אוסטריה',
              recommendations: 'שימרו על עירנות, הקשיבו לאמצעי התקשורת.',
              details: 'המלצות לקראת האירווויזיון',
              logo: 'לוגו',
              date: '2026-06-03T00:00:00.000Z',
              office: 'חוץ',
              warningLevel: 1,
            ),
          ]
        : null;

    _syncManager.initialize(
      mockData: mockList,
      isTesting: _isTesting,
      testFirestore: testFirestore,
      testFirestoreStream: testFirestoreStream,
    );
  }

  /// Cancels active travel warnings subscriptions.
  void cancelTravelWarningsListener() {
    _syncManager.cancel();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      scheduleMicrotask(() {
        if (!_isDisposed) {
          super.notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncManager.dispose();
    super.dispose();
  }
}
