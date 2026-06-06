import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/vehicle_recall_model.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles vehicle recalls collection streams,
/// loader flags, and test mode data fallbacks.
class VehicleRecallsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<VehicleRecallRecordModel> _recallRecords = [];
  bool _isLoadingRecalls = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recallsSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns vehicle recalls records list.
  List<VehicleRecallRecordModel> get recallRecords => _recallRecords;

  /// Checks if vehicle recalls query is loading.
  bool get isLoadingRecalls => _isLoadingRecalls;

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
  });

  /// Initialize real-time streams to vehicle recalls collection.
  void initRecallsListener() {
    _recallsSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingRecalls = true;
      _recallsSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _recallRecords = snapshot.docs
              .map((doc) => VehicleRecallRecordModel.fromMap(doc.data()))
              .toList();
          _isLoadingRecalls = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingRecalls = false;
          notifyListeners();
          AppLogger.error(
            'Firestore vehicle recalls collection listener error',
            err,
          );
        },
      );
      return;
    }
    if (_isTesting) {
      _recallRecords = MockData.recalls;
      _isLoadingRecalls = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingRecalls = false;
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Initializing vehicle recalls listener in VehicleRecallsNotifier',
    );
    _isLoadingRecalls = true;
    notifyListeners();

    try {
      _recallsSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection(DatasetIds.vehicleRecalls)
          .snapshots()
          .listen(
            (snapshot) {
              _recallRecords = snapshot.docs
                  .map((doc) => VehicleRecallRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingRecalls = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingRecalls = false;
              notifyListeners();
              AppLogger.error(
                'Firestore vehicle recalls collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingRecalls = false;
      notifyListeners();
      AppLogger.error('Failed to initialize vehicle recalls listener', e);
    }
  }

  /// Cancels active vehicle recalls subscriptions and resets paging states.
  void cancelRecallsListener() {
    _recallsSubscription?.cancel();
    _recallsSubscription = null;
    _isLoadingRecalls = true;
    _recallRecords = [];
    notifyListeners();
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
    _recallsSubscription?.cancel();
    super.dispose();
  }
}
