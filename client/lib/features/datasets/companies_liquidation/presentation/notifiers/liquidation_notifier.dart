import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/liquidation_record_model.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles companies in liquidation collection streams,
/// loader flags, and test mode data fallbacks.
class LiquidationNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<LiquidationRecordModel> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns companies in liquidation list.
  List<LiquidationRecordModel> get liquidationRecords => _syncManager.records;

  /// Checks if liquidation records query is loading.
  bool get isLoadingLiquidation => _syncManager.isLoading;

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

  /// Construct and initialize the LiquidationNotifier.
  LiquidationNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<LiquidationRecordModel>(
      datasetId: DatasetIds.companiesLiquidation,
      fromMap: LiquidationRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.companyId.toString(),
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to companies liquidation collection.
  void initLiquidationListener() {
    final mockList = _isTesting
        ? [
            LiquidationRecordModel(
              liquidationCaseId: 12345,
              cityOfActivity: 'תל אביב - יפו',
              caseStatus: const {'he': 'פירוק פעיל', 'en': 'Active Winding Up'},
              submissionDate: '2024-05-12T00:00:00.000Z',
              liquidationOrderDate: '2024-06-15T00:00:00.000Z',
              districtCourt: 'מחוזי תל אביב',
              companyName: 'אלברט לוי הנדסה בע"מ',
              companyId: 512345678,
              lastUpdated: '2024-06-15T00:00:00Z',
            ),
            LiquidationRecordModel(
              liquidationCaseId: 12346,
              cityOfActivity: 'חיפה',
              caseStatus: const {'he': 'הקפאת הליכים', 'en': 'Frozen'},
              submissionDate: '2024-03-10T00:00:00.000Z',
              liquidationOrderDate: '2024-04-12T00:00:00.000Z',
              cancellationFreezeDate: '2024-04-20T00:00:00.000Z',
              districtCourt: 'מחוזי חיפה',
              companyName: 'משה שירותי בנייה בע"מ',
              companyId: 512345679,
              lastUpdated: '2024-04-20T00:00:00Z',
            ),
            LiquidationRecordModel(
              liquidationCaseId: 12347,
              cityOfActivity: 'ירושלים',
              caseStatus: const {'he': 'סגור', 'en': 'Closed'},
              submissionDate: '2023-08-15T00:00:00.000Z',
              liquidationOrderDate: '2023-09-20T00:00:00.000Z',
              closureDate: '2024-01-10T00:00:00.000Z',
              closureReason: 'הסדר נושים',
              districtCourt: 'מחוזי ירושלים',
              companyName: 'ישראל קומפני בע"מ',
              companyId: 512345680,
              lastUpdated: '2024-01-10T00:00:00Z',
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

  /// Cancels active liquidation subscriptions and resets paging states.
  void cancelLiquidationListener() {
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
