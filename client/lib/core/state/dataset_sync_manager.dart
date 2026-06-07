import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Callback type signature for creating a model from a map.
typedef ModelFromMap<T> = T Function(Map<String, dynamic> map);

/// Callback type signature for converting a model to a map.
typedef ModelToMap<T> = Map<String, dynamic> Function(T record);

/// Callback type signature to retrieve a model's unique identifier.
typedef ModelGetId<T> = String Function(T record);

/// Callback type signature to retrieve a model's lastUpdated timestamp string.
typedef ModelGetLastUpdated<T> = String Function(T record);

/// A robust, reusable repository orchestrator that handles dataset loading,
/// local storage caching, and incremental real-time syncing from Cloud Firestore.
///
/// Designed to load cached data instantly first, then query only the documents
/// modified since the last sync to minimize read/write costs and eliminate UI thread blocking.
class DatasetSyncManager<T> {
  /// Public override for testing web serialization bypasses on native VM.
  @visibleForTesting
  static bool isWebOverride = kIsWeb;

  /// Unique dataset identifier GUID matching [DatasetIds]
  final String datasetId;

  /// Map parser function to instantiate model T from raw key-values
  final ModelFromMap<T> fromMap;

  /// Map serializer function to convert model T into raw key-values
  final ModelToMap<T> toMap;

  /// Function to extract the unique record ID for map upserts
  final ModelGetId<T> getRecordId;

  /// Function to extract the ISO-8601 lastUpdated timestamp for delta queries
  final ModelGetLastUpdated<T> getRecordLastUpdated;

  /// Callback to notify the listening ChangeNotifier when the dataset changes
  final VoidCallback onStateChanged;

  /// Callback to notify when a sync error occurs
  final void Function(Object error)? onError;

  /// Optional custom comparator to sort records. Defaults to sorting by [lastUpdated] descending.
  final Comparator<T>? sortComparator;

  List<T> _records = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Currently loaded and merged dataset records.
  List<T> get records => _records;

  /// Returns true if the manager is loading cached or initial data.
  bool get isLoading => _isLoading;

  /// Returns true if the manager is actively fetching updates from the server.
  bool get isSyncing => _isSyncing;

  /// Construct a new [DatasetSyncManager] instance.
  DatasetSyncManager({
    required this.datasetId,
    required this.fromMap,
    required this.toMap,
    required this.getRecordId,
    required this.getRecordLastUpdated,
    required this.onStateChanged,
    this.sortComparator,
    this.onError,
  });

  /// Check if Firebase is initialized.
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

  /// Initialize the synchronizer. Loads from local storage cache immediately (fast render),
  /// then connects to Cloud Firestore to sync only new updates.
  ///
  /// For unit/widget testing, pass [mockData] or [isTesting] to bypass live Firestore streams.
  /// Initialize the synchronizer. Loads from local storage cache immediately (fast render),
  /// then connects to Cloud Firestore to sync only new updates.
  ///
  /// For unit/widget testing, pass [mockData] or [isTesting] to bypass live Firestore streams.
  Future<void> initialize({
    List<T>? mockData,
    bool isTesting = false,
    FirebaseFirestore? testFirestore,
    Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream,
    bool forceProductionAsync = false,
    String? collectionPath,
  }) async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    _isLoading = true;
    _isSyncing = false;
    _records = [];

    // 1. Offline/Testing mock mode
    if (isTesting) {
      if (mockData != null) {
        _records = List<T>.from(mockData);
      }
      _isLoading = false;
      _isSyncing = false;
      onStateChanged();
      return;
    }

    // 2. Check isFirebaseInitialized synchronously first to satisfy instant test errors/fallbacks
    if (!isFirebaseInitialized && testFirestoreStream == null) {
      _isLoading = false;
      _isSyncing = false;
      onStateChanged();
      return;
    }

    // 3. Test environment logic (connect synchronously to bypass SharedPreferences delays in tests)
    final isTestEnv =
        (testFirestore != null || testFirestoreStream != null) &&
        !forceProductionAsync;
    if (isTestEnv) {
      _isSyncing = true;
      try {
        final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
        if (testFirestoreStream != null) {
          stream = testFirestoreStream;
        } else {
          stream = testFirestore!
              .collection(collectionPath ?? datasetId)
              .snapshots();
        }

        _subscription = stream.listen(
          (snapshot) {
            _handleSnapshot(snapshot);
          },
          onError: (Object err) {
            _handleError(err);
          },
        );
      } catch (e) {
        _isLoading = false;
        _isSyncing = false;
        onError?.call(e);
        onStateChanged();
        AppLogger.error(
          'DatasetSyncManager ($datasetId): Exception connecting to test Firestore',
          e,
        );
      }

      // Check cache in test environment if present
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('dataset_cache_$datasetId');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final List<dynamic> decodedList =
              jsonDecode(cachedJson) as List<dynamic>;
          _records = decodedList
              .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          _isLoading = false;
        }
      } catch (e) {
        AppLogger.error(
          'DatasetSyncManager ($datasetId): Failed to parse cached JSON in test',
          e,
        );
      }

      onStateChanged();
      return;
    }

    // 4. Real Production App path
    _isSyncing = true;
    onStateChanged();
    unawaited(_initProductionAsync(testFirestore, collectionPath));
  }

  void _handleSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) {
      _isLoading = false;
      _isSyncing = false;
      onStateChanged();
      return;
    }

    final updatedRecords = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('id') && doc.id.isNotEmpty) {
        data['id'] = doc.id;
      }
      return fromMap(data);
    }).toList();

    final Map<String, T> recordMap = {
      for (final r in _records) getRecordId(r): r,
    };

    for (final record in updatedRecords) {
      recordMap[getRecordId(record)] = record;
    }

    _records = recordMap.values.toList();
    if (sortComparator != null) {
      _records.sort(sortComparator);
    } else {
      _records.sort(
        (a, b) => getRecordLastUpdated(b).compareTo(getRecordLastUpdated(a)),
      );
    }

    // Save cache asynchronously in background
    _saveToCacheAsync();

    _isLoading = false;
    _isSyncing = false;
    onStateChanged();
    AppLogger.info(
      'DatasetSyncManager ($datasetId): Synced ${updatedRecords.length} records. Total in memory: ${_records.length}',
    );
  }

  void _handleError(Object err) {
    _isLoading = false;
    _isSyncing = false;
    onError?.call(err);
    onStateChanged();
    AppLogger.error(
      'DatasetSyncManager ($datasetId): Firestore listener stream error',
      err,
    );
  }

  Future<void> _saveToCacheAsync() async {
    try {
      final List<Map<String, dynamic>> rawMaps = _records
          .map((r) => toMap(r))
          .toList();
      final String encodedJson = isWebOverride
          ? jsonEncode(rawMaps)
          : await compute(jsonEncode, rawMaps);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dataset_cache_$datasetId', encodedJson);
    } catch (e) {
      AppLogger.error(
        'DatasetSyncManager ($datasetId): Failed to write local storage cache',
        e,
      );
    }
  }

  Future<void> _initProductionAsync(
    FirebaseFirestore? testFirestore,
    String? collectionPath,
  ) async {
    // 1. Load cached records from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('dataset_cache_$datasetId');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decodedList = isWebOverride
            ? jsonDecode(cachedJson) as List<dynamic>
            : await compute(jsonDecode, cachedJson) as List<dynamic>;
        _records = decodedList
            .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _isLoading = false;
        onStateChanged();
        AppLogger.info(
          'DatasetSyncManager ($datasetId): Loaded ${_records.length} records from local cache',
        );
      }
    } catch (e) {
      AppLogger.error(
        'DatasetSyncManager ($datasetId): Failed to parse cached JSON',
        e,
      );
    }

    // Determine the lastSyncTime based on the maximum lastUpdated timestamp in existing records
    String lastSyncTime = '';
    if (_records.isNotEmpty) {
      for (final record in _records) {
        final updated = getRecordLastUpdated(record);
        if (updated.compareTo(lastSyncTime) > 0) {
          lastSyncTime = updated;
        }
      }
    }

    if (!isFirebaseInitialized) {
      _isLoading = false;
      _isSyncing = false;
      onStateChanged();
      AppLogger.warning(
        'DatasetSyncManager ($datasetId): Sync skipped (Firebase not initialized)',
      );
      return;
    }

    try {
      final collectionRef = (testFirestore ?? FirebaseFirestore.instance)
          .collection(collectionPath ?? datasetId);

      // Query only for records updated since the last sync time to minimize reads
      Query query = collectionRef;
      if (lastSyncTime.isNotEmpty) {
        query = query.where('lastUpdated', isGreaterThan: lastSyncTime);
      }

      _subscription = query.snapshots().listen(
        (snapshot) {
          _handleSnapshot(snapshot);
        },
        onError: (Object err) {
          _handleError(err);
        },
      );
    } catch (e) {
      _isLoading = false;
      _isSyncing = false;
      onError?.call(e);
      onStateChanged();
      AppLogger.error(
        'DatasetSyncManager ($datasetId): Failed to query Firestore snapshots',
        e,
      );
    }
  }

  /// Terminate the Firestore stream listener.
  Future<void> cancel() async {
    _isLoading = true;
    _isSyncing = false;
    _records = [];
    onStateChanged();

    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
  }

  /// Dispose the manager subscription resources.
  void dispose() {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }
  }
}
