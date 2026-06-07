import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/patent_classification_model.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles Patent Classifications Firestore query pagination,
/// searching, filtering, and test mode data fallbacks.
class PatentClassificationsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<PatentClassificationRecordModel> _syncManager;
  List<PatentClassificationRecordModel> _testRecords = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMorePatents = true;
  bool _isLoadingPatents = false;
  bool _isLoadingMorePatents = false;
  int _currentPage = 1;
  static const int _pageSize = 20;

  String _searchQuery = '';
  String _primaryFilter = 'All'; // 'All', 'Primary', 'Secondary'

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  @visibleForTesting
  DatasetSyncManager<PatentClassificationRecordModel>
  get syncManagerForTesting => _syncManager;

  /// Returns patent classifications records list.
  List<PatentClassificationRecordModel> get patentRecords {
    if (testFirestore != null) {
      return _testRecords;
    }
    var list = _syncManager.records;

    // Apply primary/secondary filter
    if (_primaryFilter == 'Primary') {
      list = list.where((r) => r.isPrimary).toList();
    } else if (_primaryFilter == 'Secondary') {
      list = list.where((r) => !r.isPrimary).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final appNum = r.applicationNumber.toString();
        final cpc = r.cpcClassification.toLowerCase();
        final titleHe = r.titleHebrew.toLowerCase();
        final titleEn = r.titleEnglish.toLowerCase();
        return appNum.contains(query) ||
            cpc.contains(query) ||
            titleHe.contains(query) ||
            titleEn.contains(query);
      }).toList();
    }

    // Return paginated chunk
    final limit = _currentPage * _pageSize;
    return list.take(limit).toList();
  }

  /// Checks if patent classifications query is loading initial page.
  bool get isLoadingPatents {
    if (testFirestore != null) {
      return _isLoadingPatents;
    }
    return _isTesting ? _isLoadingPatents : _syncManager.isLoading;
  }

  /// Checks if patent classifications is loading subsequent pages.
  bool get isLoadingMorePatents => _isLoadingMorePatents;

  /// Checks if there are more pages to load.
  bool get hasMorePatents {
    if (testFirestore != null) {
      return _hasMorePatents;
    }
    if (_isTesting) {
      return _hasMorePatents;
    }
    var list = _syncManager.records;
    if (list.isEmpty) {
      return true;
    }

    // Apply primary/secondary filter
    if (_primaryFilter == 'Primary') {
      list = list.where((r) => r.isPrimary).toList();
    } else if (_primaryFilter == 'Secondary') {
      list = list.where((r) => !r.isPrimary).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final appNum = r.applicationNumber.toString();
        final cpc = r.cpcClassification.toLowerCase();
        final titleHe = r.titleHebrew.toLowerCase();
        final titleEn = r.titleEnglish.toLowerCase();
        return appNum.contains(query) ||
            cpc.contains(query) ||
            titleHe.contains(query) ||
            titleEn.contains(query);
      }).toList();
    }

    return list.length > _currentPage * _pageSize;
  }

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

  /// Construct and initialize the PatentClassificationsNotifier.
  PatentClassificationsNotifier({bool isTesting = false, this.testFirestore}) {
    _syncManager = DatasetSyncManager<PatentClassificationRecordModel>(
      datasetId: DatasetIds.patentClassifications,
      fromMap: PatentClassificationRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize and load the initial page of patent classifications.
  void initPatentClassificationsListener() {
    _currentPage = 1;
    if (testFirestore != null) {
      fetchNextPage(isRefresh: true);
      return;
    }
    if (_isTesting) {
      _isLoadingPatents = true;
      _syncManager.initialize(mockData: MockData.patents, isTesting: true);
      _hasMorePatents = false;
      Future.delayed(const Duration(milliseconds: 50), () {
        _isLoadingPatents = false;
        notifyListeners();
      });
    } else {
      _syncManager.initialize(testFirestore: testFirestore);
    }
  }

  /// Cancels and resets state.
  void cancelPatentClassificationsListener() {
    _currentPage = 1;
    _searchQuery = '';
    _primaryFilter = 'All';
    _hasMorePatents = true;
    _isLoadingPatents = false;
    _isLoadingMorePatents = false;
    if (testFirestore != null) {
      _testRecords = [];
      _lastDocument = null;
      notifyListeners();
    } else {
      _syncManager.cancel();
    }
  }

  /// Sets the search query and refreshes list.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    fetchNextPage(isRefresh: true);
  }

  /// Sets the primary/secondary classification filter and refreshes list.
  void setPrimaryFilter(String filter) {
    if (_primaryFilter == filter) return;
    _primaryFilter = filter;
    fetchNextPage(isRefresh: true);
  }

  /// Resets all search and filter values.
  void resetFilters() {
    _searchQuery = '';
    _primaryFilter = 'All';
    fetchNextPage(isRefresh: true);
  }

  /// Fetches a paginated page of records from Firestore.
  Future<void> fetchNextPage({bool isRefresh = false}) async {
    if (testFirestore != null) {
      if (isRefresh) {
        _testRecords = [];
        _lastDocument = null;
        _hasMorePatents = true;
        _isLoadingPatents = true;
      } else {
        if (!_hasMorePatents || _isLoadingMorePatents || _isLoadingPatents) {
          return;
        }
        _isLoadingMorePatents = true;
      }
      notifyListeners();

      try {
        final collectionRef = testFirestore!.collection(
          DatasetIds.patentClassifications,
        );

        Query query = collectionRef;

        // Apply primary/secondary filter
        if (_primaryFilter == 'Primary') {
          query = query.where('isPrimary', isEqualTo: true);
        } else if (_primaryFilter == 'Secondary') {
          query = query.where('isPrimary', isEqualTo: false);
        }

        // Apply search query
        bool queryIsOrderedByCpc = false;
        if (_searchQuery.isNotEmpty) {
          final searchString = _searchQuery.trim();
          final parsedAppNum = int.tryParse(searchString);

          if (parsedAppNum != null) {
            query = query.where('applicationNumber', isEqualTo: parsedAppNum);
          } else {
            final cleanSearch = searchString.toUpperCase();
            query = query
                .where('cpcClassification', isGreaterThanOrEqualTo: cleanSearch)
                .where(
                  'cpcClassification',
                  isLessThanOrEqualTo: '$cleanSearch\uf8ff',
                );
            queryIsOrderedByCpc = true;
          }
        }

        // Ordering
        if (queryIsOrderedByCpc) {
          query = query.orderBy('cpcClassification');
        } else {
          query = query.orderBy('_id', descending: true);
        }

        // Pagination
        const int pageSize = 20;
        query = query.limit(pageSize);
        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }

        final querySnapshot = await query.get();
        final fetchedDocs = querySnapshot.docs;

        final newRecords = fetchedDocs
            .map(
              (doc) => PatentClassificationRecordModel.fromMap(
                doc.data() as Map<String, dynamic>,
              ),
            )
            .toList();

        if (isRefresh) {
          _testRecords = newRecords;
        } else {
          _testRecords.addAll(newRecords);
        }

        _lastDocument = fetchedDocs.isNotEmpty ? fetchedDocs.last : null;
        _hasMorePatents = fetchedDocs.length == pageSize;
        _isLoadingPatents = false;
        _isLoadingMorePatents = false;
        notifyListeners();
      } catch (e) {
        AppLogger.error('Failed to fetch patent classifications page', e);
        _isLoadingPatents = false;
        _isLoadingMorePatents = false;
        notifyListeners();
      }
      return;
    }

    if (!_isTesting && !isFirebaseInitialized) {
      _isLoadingPatents = false;
      _isLoadingMorePatents = false;
      await _syncManager.initialize(mockData: [], isTesting: true);
      notifyListeners();
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
      if (_isTesting) {
        _isLoadingPatents = true;
        _hasMorePatents = true;
        notifyListeners();
        unawaited(
          _syncManager.initialize(mockData: MockData.patents, isTesting: true),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _hasMorePatents = false;
        _isLoadingPatents = false;
      }
    } else {
      if (!hasMorePatents || _isLoadingMorePatents || isLoadingPatents) {
        return;
      }
      _isLoadingMorePatents = true;
      notifyListeners();
      if (_isTesting) {
        unawaited(
          _syncManager.initialize(mockData: MockData.patents, isTesting: true),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _hasMorePatents = false;
      }
      _currentPage++;
      _isLoadingMorePatents = false;
    }
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
    _syncManager.dispose();
    super.dispose();
  }
}
