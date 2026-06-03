import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';

import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles active cellular antenna stream queries,
/// loader flags, and test mode data fallbacks.
class AntennasNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<Map<String, dynamic>> _antennaRecords = [];
  bool _isLoadingAntennas = true;
  StreamSubscription<QuerySnapshot>? _antennaSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns cellular antenna documents list.
  List<Map<String, dynamic>> get antennaRecords => _antennaRecords;

  /// Checks if active antennas query is executing.
  bool get isLoadingAntennas => _isLoadingAntennas;

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
  });

  /// Initialize real-time streams to cellular antennas collection.
  void initAntennaListener() {
    _antennaSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingAntennas = true;
      _antennaSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _antennaRecords = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoadingAntennas = false;
          scheduleMicrotask(() => notifyListeners());
        },
        onError: (Object err) {
          _isLoadingAntennas = false;
          scheduleMicrotask(() => notifyListeners());
          AppLogger.error('Firestore antenna collection listener error', err);
        },
      );
      return;
    }
    if (_isTesting) {
      _antennaRecords = [
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
      ];
      _isLoadingAntennas = false;
      scheduleMicrotask(() => notifyListeners());
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingAntennas = false;
      scheduleMicrotask(() => notifyListeners());
      return;
    }

    AppLogger.info(
      'Initializing cellular antennas listener in AntennasNotifier',
    );
    _isLoadingAntennas = true;
    scheduleMicrotask(() => notifyListeners());

    try {
      _antennaSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('8935c8e5-ec77-421f-af86-d970583195f8')
          .snapshots()
          .listen(
            (snapshot) {
              _antennaRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingAntennas = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingAntennas = false;
              notifyListeners();
              AppLogger.error(
                'Firestore antenna collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingAntennas = false;
      notifyListeners();
      AppLogger.error('Failed to initialize antennas listener', e);
    }
  }

  /// Cancels any active stream subscription and resets state flags.
  void cancelAntennaListener() {
    _antennaSubscription?.cancel();
    _antennaSubscription = null;
    _isLoadingAntennas = true;
    _antennaRecords = [];
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
    _antennaSubscription?.cancel();
    super.dispose();
  }
}
