import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/liquidation_record_model.dart';

import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles companies in liquidation collection streams,
/// loader flags, and test mode data fallbacks.
class LiquidationNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<LiquidationRecordModel> _liquidationRecords = [];
  bool _isLoadingLiquidation = true;
  StreamSubscription<QuerySnapshot>? _liquidationSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns companies in liquidation list.
  List<LiquidationRecordModel> get liquidationRecords => _liquidationRecords;

  /// Checks if liquidation records query is loading.
  bool get isLoadingLiquidation => _isLoadingLiquidation;

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
  });

  /// Initialize real-time streams to companies liquidation collection.
  void initLiquidationListener() {
    _liquidationSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingLiquidation = true;
      _liquidationSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _liquidationRecords = snapshot.docs
              .map(
                (doc) => LiquidationRecordModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
          _isLoadingLiquidation = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingLiquidation = false;
          notifyListeners();
          AppLogger.error(
            'Firestore liquidation collection listener error',
            err,
          );
        },
      );
      return;
    }
    if (_isTesting) {
      _liquidationRecords = [
        LiquidationRecordModel(
          liquidationCaseId: 12345,
          cityOfActivity: 'תל אביב - יפו',
          caseStatus: const {'he': 'פירוק פעיל', 'en': 'Active Winding Up'},
          submissionDate: '2024-05-12T00:00:00.000Z',
          liquidationOrderDate: '2024-06-15T00:00:00.000Z',
          districtCourt: 'מחוזי תל אביב',
          companyName: 'אלברט לוי הנדסה בע"מ',
          companyId: 512345678,
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
        ),
      ];
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingLiquidation = false;
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Initializing companies liquidation listener in LiquidationNotifier',
    );
    try {
      _liquidationSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('d8715392-287f-49b7-9ae3-f21ec5bf55f3')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              _liquidationRecords = snapshot.docs
                  .map((doc) => LiquidationRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingLiquidation = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingLiquidation = false;
              notifyListeners();
              AppLogger.error(
                'Firestore liquidation collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingLiquidation = false;
      notifyListeners();
      AppLogger.error(
        'Failed to initialize liquidation listener in LiquidationNotifier',
        e,
      );
    }
  }

  @override
  void dispose() {
    _liquidationSubscription?.cancel();
    super.dispose();
  }
}
