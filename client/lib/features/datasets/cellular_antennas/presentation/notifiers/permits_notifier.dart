import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';

import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles cellular construction permits metadata streams,
/// double-buffering collection references, loader flags, and test mode data fallbacks.
class PermitsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  String _activePermitCollection = '';
  String _permitSyncStatus = 'idle';
  StreamSubscription<DocumentSnapshot>? _permitMetadataSubscription;
  late final DatasetSyncManager<Map<String, dynamic>> _syncManager;

  @visibleForTesting
  Stream<DocumentSnapshot<Map<String, dynamic>>>? testMetadataStream;
  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testPermitsStream;
  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns cellular permit records list.
  List<Map<String, dynamic>> get permitRecords => _syncManager.records;

  /// Checks if permits query is loading.
  bool get isLoadingPermits => _syncManager.isLoading;

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
  }) {
    _syncManager = DatasetSyncManager<Map<String, dynamic>>(
      datasetId: DatasetIds.cellularPermits,
      fromMap: (map) => map,
      toMap: (map) => map,
      getRecordId: (map) =>
          map['id']?.toString() ?? map['referenceNumber']?.toString() ?? '',
      getRecordLastUpdated: (map) => map['lastUpdated']?.toString() ?? '',
      onStateChanged: notifyListeners,
      onError: (err) {
        _permitSyncStatus = 'error';
        notifyListeners();
      },
    );
  }

  /// Initialize real-time metadata streams to retrieve active collection mappings.
  void initPermitMetadataListener() {
    _permitMetadataSubscription?.cancel();
    if (testMetadataStream != null) {
      _permitMetadataSubscription = testMetadataStream!.listen(
        (metaSnapshot) {
          if (metaSnapshot.exists && metaSnapshot.data() != null) {
            final data = metaSnapshot.data()!;
            final newActive = data['activeCollection'] as String? ?? '';
            final newStatus = data['status'] as String? ?? 'idle';
            _permitSyncStatus = newStatus;

            if (newActive.isNotEmpty && newActive != _activePermitCollection) {
              _bindActivePermitCollection(newActive);
            } else {
              notifyListeners();
            }
          } else {
            // Emulate the syncManager loading state finished
            _syncManager.initialize(mockData: [], isTesting: true);
            notifyListeners();
          }
        },
        onError: (Object err) {
          _permitSyncStatus = 'error';
          notifyListeners();
          AppLogger.error('Firestore permit metadata listener error', err);
        },
      );
      return;
    }
    if (_isTesting) {
      _permitSyncStatus = 'idle';
      final mockList = [
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
      _syncManager.initialize(mockData: mockList, isTesting: true);
      return;
    }

    if (!isFirebaseInitialized) {
      _permitSyncStatus = 'error';
      // Initialize with empty list to stop loading state
      _syncManager.initialize(mockData: [], isTesting: true);
      return;
    }

    AppLogger.info('Initializing permit metadata listener in PermitsNotifier');
    _permitMetadataSubscription?.cancel();
    try {
      _permitMetadataSubscription =
          (testFirestore ?? FirebaseFirestore.instance)
              .collection('dataset_metadata')
              .doc(DatasetIds.cellularPermits)
              .snapshots()
              .listen(
                (metaSnapshot) {
                  if (metaSnapshot.exists && metaSnapshot.data() != null) {
                    final data = metaSnapshot.data()!;
                    final newActive = data['activeCollection'] as String? ?? '';
                    final newStatus = data['status'] as String? ?? 'idle';
                    _permitSyncStatus = newStatus;

                    if (newActive.isNotEmpty &&
                        newActive != _activePermitCollection) {
                      _bindActivePermitCollection(newActive);
                    } else {
                      notifyListeners();
                    }
                  } else {
                    _syncManager.initialize(mockData: [], isTesting: true);
                    notifyListeners();
                  }
                },
                onError: (Object err) {
                  _permitSyncStatus = 'error';
                  notifyListeners();
                  AppLogger.error(
                    'Firestore permit metadata listener error',
                    err,
                  );
                },
              );
    } catch (e) {
      _permitSyncStatus = 'error';
      notifyListeners();
      AppLogger.error(
        'Failed to bind Firestore metadata in PermitsNotifier',
        e,
      );
    }
  }

  void _bindActivePermitCollection(String newCollection) {
    _activePermitCollection = newCollection;
    notifyListeners();

    _syncManager.initialize(
      isTesting: _isTesting,
      testFirestore: testFirestore,
      testFirestoreStream: testPermitsStream,
      collectionPath: newCollection,
    );
  }

  /// Cancels active permit subscriptions and resets paging states.
  void cancelPermitMetadataListener() {
    _permitMetadataSubscription?.cancel();
    _permitMetadataSubscription = null;
    _activePermitCollection = '';
    _permitSyncStatus = 'idle';
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
    _permitMetadataSubscription?.cancel();
    _syncManager.dispose();
    super.dispose();
  }
}
