import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/car_importer_record_model.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles car importers collection streams,
/// loader flags, and test mode data fallbacks.
class CarImportersNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<CarImporterRecordModel> _carImporterRecords = [];
  bool _isLoadingCarImporters = true;
  StreamSubscription<QuerySnapshot>? _carImportersSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns car importers records list.
  List<CarImporterRecordModel> get carImporterRecords => _carImporterRecords;

  /// Checks if car importers query is loading.
  bool get isLoadingCarImporters => _isLoadingCarImporters;

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
  });

  /// Initialize real-time streams to car importers collection.
  void initCarImportersListener() {
    _carImportersSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingCarImporters = true;
      _carImportersSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _carImporterRecords = snapshot.docs
              .map((doc) => CarImporterRecordModel.fromMap(doc.data()))
              .toList();
          _isLoadingCarImporters = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingCarImporters = false;
          notifyListeners();
          AppLogger.error(
            'Firestore car importers collection listener error',
            err,
          );
        },
      );
      return;
    }
    if (_isTesting) {
      _carImporterRecords = [
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
      ];
      _isLoadingCarImporters = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingCarImporters = false;
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Initializing car importers listener in CarImportersNotifier',
    );
    _isLoadingCarImporters = true;
    notifyListeners();

    try {
      _carImportersSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('39f455bf-6db0-4926-859d-017f34eacbcb')
          .snapshots()
          .listen(
            (snapshot) {
              _carImporterRecords = snapshot.docs
                  .map((doc) => CarImporterRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingCarImporters = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingCarImporters = false;
              notifyListeners();
              AppLogger.error(
                'Firestore car importers collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingCarImporters = false;
      notifyListeners();
      AppLogger.error('Failed to initialize car importers listener', e);
    }
  }

  /// Cancels active car importers subscriptions and resets paging states.
  void cancelCarImportersListener() {
    _carImportersSubscription?.cancel();
    _carImportersSubscription = null;
    _isLoadingCarImporters = true;
    _carImporterRecords = [];
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
    _carImportersSubscription?.cancel();
    super.dispose();
  }
}
