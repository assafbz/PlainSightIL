import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/doctor_license_model.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles doctors licenses collection streams,
/// loader flags, and test mode data fallbacks.
class DoctorsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<DoctorLicenseRecordModel> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns doctors licenses records list.
  List<DoctorLicenseRecordModel> get doctorRecords => _syncManager.records;

  /// Checks if doctors licenses query is loading.
  bool get isLoadingDoctors => _syncManager.isLoading;

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

  /// Construct and initialize the DoctorsNotifier.
  DoctorsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<DoctorLicenseRecordModel>(
      datasetId: DatasetIds.doctorsLicenses,
      fromMap: DoctorLicenseRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to doctors licenses collection.
  void initDoctorsListener() {
    final mockList = _isTesting
        ? [
            DoctorLicenseRecordModel(
              id: '1',
              idNum: 1,
              firstName: 'מריו ה',
              lastName: 'קורוב',
              licenseNumber: 4267,
              licenseRegistrationDate: '1969-07-28T00:00:00.000Z',
              lastUpdated: '1969-07-28T00:00:00Z',
            ),
            DoctorLicenseRecordModel(
              id: '2',
              idNum: 2,
              firstName: 'אברהם',
              lastName: 'שטיינברג',
              licenseNumber: 11116,
              licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
              specialtyCertificateNumber: 7656,
              specialtyRegistrationDate: '1983-06-21T00:00:00.000Z',
              specialtyName: 'רפואת ילדים',
              lastUpdated: '1983-06-21T00:00:00Z',
            ),
            DoctorLicenseRecordModel(
              id: '3',
              idNum: 3,
              firstName: 'אברהם',
              lastName: 'שטיינברג',
              licenseNumber: 11116,
              licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
              specialtyCertificateNumber: 13230,
              specialtyRegistrationDate: '1993-12-02T00:00:00.000Z',
              specialtyName: 'נוירולוגיית ילדים',
              lastUpdated: '1993-12-02T00:00:00Z',
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

  /// Cancels active doctors subscriptions and resets paging states.
  void cancelDoctorsListener() {
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
