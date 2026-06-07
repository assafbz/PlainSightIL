import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles active cellular antenna stream queries,
/// loader flags, and test mode data fallbacks.
class AntennasNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<Map<String, dynamic>> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns cellular antenna documents list.
  List<Map<String, dynamic>> get antennaRecords => _syncManager.records;

  /// Checks if active antennas query is executing.
  bool get isLoadingAntennas => _syncManager.isLoading;

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

  /// Construct and initialize the AntennasNotifier.
  AntennasNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<Map<String, dynamic>>(
      datasetId: DatasetIds.cellularAntennas,
      fromMap: (map) => map,
      toMap: (map) => map,
      getRecordId: (map) =>
          map['antennaId']?.toString() ?? map['id']?.toString() ?? '',
      getRecordLastUpdated: (map) => map['lastUpdated']?.toString() ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to cellular antennas collection.
  void initAntennaListener() {
    final mockList = _isTesting
        ? [
            {
              'antennaId': 'CELL-100',
              'addressHebrew': 'דיזנגוף 50, תל אביב',
              'addressEnglish': 'Dizengoff 50, Tel Aviv',
              'operatorName': 'Pelephone',
              'radiationFrequency': 1800.0,
              'coordinates': const GeoPoint(32.0782, 34.7741),
            },
            {
              'antennaId': 'CELL-101',
              'addressHebrew': 'בן יהודה 80, תל אביב',
              'addressEnglish': 'Ben Yehuda 80, Tel Aviv',
              'operatorName': 'Partner',
              'radiationFrequency': 3500.0,
              'coordinates': const GeoPoint(32.0831, 34.7725),
            },
            {
              'antennaId': 'CELL-102',
              'addressHebrew': 'קיבוץ אפיקים, עמק הירדן',
              'addressEnglish': 'Kibbutz Afikim, Jordan Valley',
              'operatorName': 'Cellcom',
              'radiationFrequency': 2100.0,
              'coordinates': const GeoPoint(32.6795, 35.5792),
            },
            {
              'antennaId': 'CELL-103',
              'addressHebrew': 'שדרות רוטשילד 15, תל אביב',
              'addressEnglish': 'Rothschild Blvd 15, Tel Aviv',
              'operatorName': 'Hot Mobile',
              'radiationFrequency': 1800.0,
              'coordinates': const GeoPoint(32.0635, 34.7712),
            },
          ]
        : null;

    _syncManager.initialize(
      mockData: mockList,
      isTesting: _isTesting,
      testFirestore: testFirestore,
      testFirestoreStream: testFirestoreStream,
    );
  }

  /// Cancels any active stream subscription and resets state flags.
  void cancelAntennaListener() {
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
