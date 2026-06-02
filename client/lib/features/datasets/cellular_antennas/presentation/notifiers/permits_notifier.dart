import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';

import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles cellular construction permits metadata streams,
/// double-buffering collection references, loader flags, and test mode data fallbacks.
class PermitsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  String _activePermitCollection = '';
  List<Map<String, dynamic>> _permitRecords = [];
  bool _isLoadingPermits = true;
  String _permitSyncStatus = 'idle';
  StreamSubscription<QuerySnapshot>? _permitSubscription;
  StreamSubscription<DocumentSnapshot>? _permitMetadataSubscription;

  @visibleForTesting
  @visibleForTesting
  Stream<DocumentSnapshot<Map<String, dynamic>>>? testMetadataStream;
  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testPermitsStream;
  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns cellular permit records list.
  List<Map<String, dynamic>> get permitRecords => _permitRecords;

  /// Checks if permits query is loading.
  bool get isLoadingPermits => _isLoadingPermits;

  /// Gets the synchronization status flag (idle, syncing, error).
  String get permitSyncStatus => _permitSyncStatus;

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

  /// Construct and initialize the PermitsNotifier.
  PermitsNotifier({
    bool isTesting = false,
    this.testMetadataStream,
    this.testPermitsStream,
    this.testFirestore,
  });

  /// Initialize real-time metadata streams to retrieve active collection mappings.
  void initPermitMetadataListener() {
    _permitMetadataSubscription?.cancel();
    if (testMetadataStream != null) {
      _permitMetadataSubscription = testMetadataStream!.listen(
        (metaSnapshot) {
          if (metaSnapshot.exists && metaSnapshot.data() != null) {
            final data = metaSnapshot.data()!;
            final newActive = data['activeCollection'] as String? ?? '';
            _permitSyncStatus = data['status'] as String? ?? 'idle';

            if (newActive.isNotEmpty && newActive != _activePermitCollection) {
              _bindActivePermitCollection(newActive);
            } else {
              notifyListeners();
            }
          } else {
            _isLoadingPermits = false;
            notifyListeners();
          }
        },
        onError: (Object err) {
          _isLoadingPermits = false;
          _permitSyncStatus = 'error';
          notifyListeners();
          AppLogger.error('Firestore permit metadata listener error', err);
        },
      );
      return;
    }
    if (_isTesting) {
      _permitSyncStatus = 'idle';
      _permitRecords = [
        {
          'id': '1',
          'referenceNumber': 2081659,
          'company': {'he': 'סלקום', 'en': 'Cellcom'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'NN1845A',
          'locality': 'אפיקים',
          'addressDescription': 'קיבוץ אפיקים',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'עמק הירדן',
          'coordinates': const GeoPoint(32.6789, 35.5788),
        },
        {
          'id': '2',
          'referenceNumber': 2081660,
          'company': {'he': 'פרטנר', 'en': 'Partner'},
          'permitType': 'היתר הפעלה',
          'siteNumber': 'PT1234B',
          'locality': 'תל אביב - יפו',
          'addressDescription': 'דיזנגוף 100',
          'focalPointType': 'גג',
          'jurisdiction': 'תל אביב',
          'coordinates': const GeoPoint(32.0795, 34.7738),
        },
        {
          'id': '3',
          'referenceNumber': 2081661,
          'company': {'he': 'הוט מובייל', 'en': 'Hot Mobile'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'HT9876C',
          'locality': 'חיפה',
          'addressDescription': 'הרצל 12',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'חיפה',
          'coordinates': const GeoPoint(32.8090, 34.9890),
        },
        {
          'id': '4',
          'referenceNumber': 2081662,
          'company': {'he': 'פלאפון', 'en': 'Pelephone'},
          'permitType': 'היתר הקמה',
          'siteNumber': 'PL4567D',
          'locality': 'ירושלים',
          'addressDescription': 'יפו 50',
          'focalPointType': 'קרקעי',
          'jurisdiction': 'ירושלים',
          'coordinates': const GeoPoint(31.7833, 35.2167),
        },
      ];
      _isLoadingPermits = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _permitSyncStatus = 'error';
      _isLoadingPermits = false;
      notifyListeners();
      return;
    }

    AppLogger.info('Initializing permit metadata listener in PermitsNotifier');
    _permitMetadataSubscription?.cancel();
    try {
      _permitMetadataSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('dataset_metadata')
          .doc('ff398c7e-c522-4ee8-a53a-312b188a573d')
          .snapshots()
          .listen(
            (metaSnapshot) {
              if (metaSnapshot.exists && metaSnapshot.data() != null) {
                final data = metaSnapshot.data()!;
                final newActive = data['activeCollection'] as String? ?? '';
                _permitSyncStatus = data['status'] as String? ?? 'idle';

                if (newActive.isNotEmpty && newActive != _activePermitCollection) {
                  _bindActivePermitCollection(newActive);
                } else {
                  notifyListeners();
                }
              } else {
                _isLoadingPermits = false;
                notifyListeners();
              }
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              AppLogger.error('Firestore permit metadata listener error', err);
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      AppLogger.error('Failed to bind Firestore metadata in PermitsNotifier', e);
    }
  }

  void _bindActivePermitCollection(String newCollection) {
    _activePermitCollection = newCollection;
    _isLoadingPermits = true;
    notifyListeners();

    _permitSubscription?.cancel();
    if (testPermitsStream != null) {
      _permitSubscription = testPermitsStream!.listen(
        (snapshot) {
          _permitRecords = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          _isLoadingPermits = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingPermits = false;
          _permitSyncStatus = 'error';
          notifyListeners();
          AppLogger.error('Firestore permit collection listener error for $newCollection', err);
        },
      );
      return;
    }
    try {
      _permitSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection(newCollection)
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              _permitRecords = snapshot.docs.map((doc) => doc.data()).toList();
              _isLoadingPermits = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingPermits = false;
              _permitSyncStatus = 'error';
              notifyListeners();
              AppLogger.error('Firestore permit collection listener error for $newCollection', err);
            },
          );
    } catch (e) {
      _isLoadingPermits = false;
      _permitSyncStatus = 'error';
      notifyListeners();
      AppLogger.error('Failed to bind Firestore collection $newCollection in PermitsNotifier', e);
    }
  }

  @override
  void dispose() {
    _permitSubscription?.cancel();
    _permitMetadataSubscription?.cancel();
    super.dispose();
  }
}
