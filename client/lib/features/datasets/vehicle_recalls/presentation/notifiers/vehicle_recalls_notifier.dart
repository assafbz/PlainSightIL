import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/vehicle_recall_model.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles vehicle recalls collection streams,
/// loader flags, and test mode data fallbacks.
class VehicleRecallsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<VehicleRecallRecordModel> _syncManager;

  @visibleForTesting
  DatasetSyncManager<VehicleRecallRecordModel> get syncManagerForTesting =>
      _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns vehicle recalls records list.
  List<VehicleRecallRecordModel> get recallRecords => _syncManager.records;

  /// Checks if vehicle recalls query is loading.
  bool get isLoadingRecalls => _syncManager.isLoading;

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

  /// Construct and initialize the VehicleRecallsNotifier.
  VehicleRecallsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<VehicleRecallRecordModel>(
      datasetId: DatasetIds.vehicleRecalls,
      fromMap: VehicleRecallRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to vehicle recalls collection.
  void initRecallsListener() {
    _syncManager.initialize(
      mockData: _isTesting ? MockData.recalls : null,
      isTesting: _isTesting,
      testFirestore: testFirestore,
      testFirestoreStream: testFirestoreStream,
    );
  }

  /// Cancels active vehicle recalls subscriptions and resets paging states.
  void cancelRecallsListener() {
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
