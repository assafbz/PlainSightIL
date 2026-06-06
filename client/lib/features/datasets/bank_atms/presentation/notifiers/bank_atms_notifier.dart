import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/models/bank_atm_record_model.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles Bank ATMs collection streams,
/// loader flags, and test mode data fallbacks.
class BankAtmsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<BankAtmRecordModel> _syncManager;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns Bank ATM records list.
  List<BankAtmRecordModel> get atmRecords => _syncManager.records;

  /// Checks if Bank ATMs query is loading.
  bool get isLoadingAtms => _syncManager.isLoading;

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

  /// Construct and initialize the BankAtmsNotifier.
  BankAtmsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  }) {
    _syncManager = DatasetSyncManager<BankAtmRecordModel>(
      datasetId: DatasetIds.bankAtms,
      fromMap: BankAtmRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated,
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize real-time streams to Bank ATMs collection.
  void initBankAtmsListener() {
    final mockList = _isTesting
        ? [
            BankAtmRecordModel(
              id: '1',
              atmNum: 3777,
              bankCode: 12,
              bankName: {'he': 'בנק הפועלים בע"מ', 'en': 'Bank Hapoalim'},
              branchCode: 377,
              address: 'שד\' התמרים 11',
              addressExtra: 'שדרות התמרים 11',
              city: 'אילת',
              atmLocation: {'he': 'בתוך הסניף', 'en': 'Inside Branch'},
              latitude: 29.555192,
              longitude: 34.952591,
              geohash: 'sv0bh5bpb',
              hasCommission: false,
              hasCashWithdrawal: true,
              hasCashDeposit: true,
              hasChequeDeposit: true,
              hasEnvelopeDeposit: true,
              hasForexTransaction: true,
              hasAdditionalTransactions: true,
              hasHandicapAccess: true,
              sourceCreatedAt: '2026-06-02T09:00:00Z',
              sourceUpdatedAt: '2026-06-02T09:00:00Z',
              createdAt: '2026-06-02T09:00:00Z',
              updatedAt: '2026-06-02T09:00:00Z',
              lastUpdated: '2026-06-02T09:00:00Z',
            ),
            BankAtmRecordModel(
              id: '2',
              atmNum: 5001,
              bankCode: 10,
              bankName: {'he': 'בנק לאומי לישראל בע"מ', 'en': 'Bank Leumi'},
              branchCode: 800,
              address: 'דיזנגוף 50',
              addressExtra: 'דיזנגוף 50',
              city: 'תל אביב',
              atmLocation: {'he': 'על קיר הסניף', 'en': 'On Branch Wall'},
              latitude: 32.075,
              longitude: 34.774,
              geohash: 'sv8wrg6p7',
              hasCommission: true,
              hasCashWithdrawal: true,
              hasCashDeposit: false,
              hasChequeDeposit: false,
              hasEnvelopeDeposit: false,
              hasForexTransaction: false,
              hasAdditionalTransactions: false,
              hasHandicapAccess: true,
              sourceCreatedAt: '2026-06-02T09:00:00Z',
              sourceUpdatedAt: '2026-06-02T09:00:00Z',
              createdAt: '2026-06-02T09:00:00Z',
              updatedAt: '2026-06-02T09:00:00Z',
              lastUpdated: '2026-06-02T09:00:00Z',
            ),
            BankAtmRecordModel(
              id: '3',
              atmNum: 9020,
              bankCode: 20,
              bankName: {
                'he': 'בנק מזרחי טפחות בע"מ',
                'en': 'Mizrahi Tefahot Bank',
              },
              branchCode: 450,
              address: 'הרצל 32',
              addressExtra: 'הרצל 32',
              city: 'ירושלים',
              atmLocation: {
                'he': 'במרחק עד 500 מטר מהסניף',
                'en': 'Within 500m of Branch',
              },
              latitude: 31.778,
              longitude: 35.235,
              geohash: 'svk4p0rn5',
              hasCommission: false,
              hasCashWithdrawal: true,
              hasCashDeposit: true,
              hasChequeDeposit: false,
              hasEnvelopeDeposit: false,
              hasForexTransaction: true,
              hasAdditionalTransactions: false,
              hasHandicapAccess: false,
              sourceCreatedAt: '2026-06-02T09:00:00Z',
              sourceUpdatedAt: '2026-06-02T09:00:00Z',
              createdAt: '2026-06-02T09:00:00Z',
              updatedAt: '2026-06-02T09:00:00Z',
              lastUpdated: '2026-06-02T09:00:00Z',
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

  /// Cancels active Bank ATMs subscriptions and resets state flags.
  void cancelBankAtmsListener() {
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
