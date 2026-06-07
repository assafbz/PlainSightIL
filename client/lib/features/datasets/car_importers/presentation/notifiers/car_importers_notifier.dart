import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/car_importer_record_model.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles car importers collection streams,
/// loader flags, and test mode data fallbacks.
class CarImportersNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<CarImporterRecordModel> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns car importers records list.
  List<CarImporterRecordModel> get carImporterRecords => _syncManager.records;

  /// Checks if car importers query is loading.
  bool get isLoadingCarImporters => _syncManager.isLoading;

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

  /// Construct and initialize the CarImportersNotifier.
  CarImportersNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<CarImporterRecordModel>(
      datasetId: DatasetIds.carImporters,
      fromMap: CarImporterRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to car importers collection.
  void initCarImportersListener() {
    final mockList = _isTesting
        ? [
            CarImporterRecordModel(
              id: '1',
              idNum: 1,
              importerCode: 1,
              importerName: 'קרסו מוטורס בע"מ',
              modelType: 'P',
              makerCode: 928,
              makerName: 'רנו צרפת',
              modelCode: 1000,
              modelName: 'C0635P R TWINGO EP',
              productionYear: 1996,
              price: 54950,
              commercialName: 'טווינגו 2.1 YSAE',
            ),
            CarImporterRecordModel(
              id: '2',
              idNum: 2,
              importerCode: 1,
              importerName: 'קרסו מוטורס בע"מ',
              modelType: 'P',
              makerCode: 928,
              makerName: 'רנו צרפת',
              modelCode: 4060,
              modelName: 'L53A05 R19 RN 1.4I',
              productionYear: 1996,
              price: 61990,
              commercialName: '91 NR I4.1 4 דלתות',
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

  /// Cancels active car importers subscriptions and resets paging states.
  void cancelCarImportersListener() {
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
