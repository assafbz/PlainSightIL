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
  DocumentSnapshot? _lastLiquidationDoc;
  bool _hasMoreLiquidation = true;
  bool _isLoadingMoreLiquidation = false;

  bool get isLoadingMoreLiquidation => _isLoadingMoreLiquidation;

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
    reloadLiquidation();
  }

  /// Fetches the first page of liquidation records, resetting pagination state.
  Future<void> reloadLiquidation() async {
    _isLoadingLiquidation = true;
    _lastLiquidationDoc = null;
    _hasMoreLiquidation = true;
    _isLoadingMoreLiquidation = false;
    _liquidationRecords = [];
    notifyListeners();

    try {
      final query = (testFirestore ?? FirebaseFirestore.instance)
          .collection('d8715392-287f-49b7-9ae3-f21ec5bf55f3')
          .limit(50);
      final snapshot = await query.get();
      AppLogger.info(
        'Companies liquidation first page fetched: ${snapshot.docs.length} records',
      );
      if (snapshot.docs.isNotEmpty) {
        _lastLiquidationDoc = snapshot.docs.last;
        _liquidationRecords = snapshot.docs
            .map((doc) => LiquidationRecordModel.fromMap(doc.data()))
            .toList();
        if (snapshot.docs.length < 50) {
          _hasMoreLiquidation = false;
        }
      } else {
        _hasMoreLiquidation = false;
      }
    } catch (e) {
      AppLogger.error('Failed to reload liquidation records', e);
    } finally {
      _isLoadingLiquidation = false;
      notifyListeners();
    }
  }

  /// Fetches the next page of liquidation records using cursor pagination.
  Future<void> loadMoreLiquidation() async {
    if (_isLoadingMoreLiquidation ||
        !_hasMoreLiquidation ||
        _lastLiquidationDoc == null) {
      return;
    }

    _isLoadingMoreLiquidation = true;
    notifyListeners();

    try {
      final query = (testFirestore ?? FirebaseFirestore.instance)
          .collection('d8715392-287f-49b7-9ae3-f21ec5bf55f3')
          .startAfterDocument(_lastLiquidationDoc!)
          .limit(50);
      final snapshot = await query.get();
      AppLogger.info(
        'Companies liquidation loaded more: ${snapshot.docs.length} records',
      );

      if (snapshot.docs.isNotEmpty) {
        _lastLiquidationDoc = snapshot.docs.last;
        final newRecords = snapshot.docs
            .map((doc) => LiquidationRecordModel.fromMap(doc.data()))
            .toList();
        _liquidationRecords.addAll(newRecords);
        if (snapshot.docs.length < 50) {
          _hasMoreLiquidation = false;
        }
      } else {
        _hasMoreLiquidation = false;
      }
    } catch (e) {
      AppLogger.error('Failed to load more liquidation records', e);
    } finally {
      _isLoadingMoreLiquidation = false;
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _liquidationSubscription?.cancel();
    super.dispose();
  }
}
