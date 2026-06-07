import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/local_market_bond_model.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';
import 'package:plainsight/core/state/dataset_sync_manager.dart';

/// Scoped state notifier that handles Local Market Bonds Firestore query pagination,
/// searching, filtering, and test mode data fallbacks.
class LocalMarketBondsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  late final DatasetSyncManager<LocalMarketBondRecordModel> _syncManager;
  List<LocalMarketBondRecordModel> _testRecords = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreBonds = true;
  bool _isLoadingBonds = false;
  bool _isLoadingMoreBonds = false;
  int _currentPage = 1;
  static const int _pageSize = 20;

  String _searchQuery = '';
  String _filter = 'All'; // 'All', 'Government', 'CPI-Linked', 'Floating Rate'

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns local market bonds records list.
  List<LocalMarketBondRecordModel> get bondRecords {
    if (testFirestore != null) {
      return _testRecords;
    }
    var list = _syncManager.records;

    // Apply bondType filter
    if (_filter == 'Government') {
      list = list.where((r) => r.bondType['en'] == 'Government').toList();
    } else if (_filter == 'CPI-Linked') {
      list = list
          .where((r) => r.bondType['en'] == 'CPI-Linked Government')
          .toList();
    } else if (_filter == 'Floating Rate') {
      list = list
          .where((r) => r.bondType['en'] == 'Floating Rate Government')
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final seriesStr = r.series.toString();
        final typeHe = r.bondType['he']?.toLowerCase() ?? '';
        final typeEn = r.bondType['en']?.toLowerCase() ?? '';
        return seriesStr.contains(query) ||
            typeHe.contains(query) ||
            typeEn.contains(query);
      }).toList();
    }

    final limit = _currentPage * _pageSize;
    return list.take(limit).toList();
  }

  /// Checks if bonds query is loading initial page.
  bool get isLoadingBonds {
    if (testFirestore != null) {
      return _isLoadingBonds;
    }
    return _isTesting ? _isLoadingBonds : _syncManager.isLoading;
  }

  /// Checks if bonds is loading subsequent pages.
  bool get isLoadingMoreBonds => _isLoadingMoreBonds;

  /// Checks if there are more pages to load.
  bool get hasMoreBonds {
    if (testFirestore != null) {
      return _hasMoreBonds;
    }
    if (_isTesting) {
      return _hasMoreBonds;
    }
    var list = _syncManager.records;
    if (list.isEmpty) {
      return true;
    }

    // Apply bondType filter
    if (_filter == 'Government') {
      list = list.where((r) => r.bondType['en'] == 'Government').toList();
    } else if (_filter == 'CPI-Linked') {
      list = list
          .where((r) => r.bondType['en'] == 'CPI-Linked Government')
          .toList();
    } else if (_filter == 'Floating Rate') {
      list = list
          .where((r) => r.bondType['en'] == 'Floating Rate Government')
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final seriesStr = r.series.toString();
        final typeHe = r.bondType['he']?.toLowerCase() ?? '';
        final typeEn = r.bondType['en']?.toLowerCase() ?? '';
        return seriesStr.contains(query) ||
            typeHe.contains(query) ||
            typeEn.contains(query);
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

  /// Construct and initialize the LocalMarketBondsNotifier.
  LocalMarketBondsNotifier({bool isTesting = false, this.testFirestore}) {
    _syncManager = DatasetSyncManager<LocalMarketBondRecordModel>(
      datasetId: DatasetIds.localMarketBonds,
      fromMap: LocalMarketBondRecordModel.fromMap,
      toMap: (r) => r.toMap(),
      getRecordId: (r) => r.id,
      getRecordLastUpdated: (r) => r.lastUpdated ?? '',
      onStateChanged: notifyListeners,
    );
  }

  /// Initialize and load the initial page of local market bonds.
  void initBondsListener() {
    _currentPage = 1;
    if (testFirestore != null) {
      fetchNextPage(isRefresh: true);
      return;
    }
    if (_isTesting) {
      _isLoadingBonds = true;
      _syncManager.initialize(mockData: MockData.bonds, isTesting: true);
      _hasMoreBonds = false;
      Future.delayed(const Duration(milliseconds: 50), () {
        _isLoadingBonds = false;
        notifyListeners();
      });
    } else {
      _syncManager.initialize(testFirestore: testFirestore);
    }
  }

  /// Cancels and resets state.
  void cancelBondsListener() {
    _currentPage = 1;
    _searchQuery = '';
    _filter = 'All';
    _hasMoreBonds = true;
    _isLoadingBonds = false;
    _isLoadingMoreBonds = false;
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

  /// Sets the bond type filter and refreshes list.
  void setFilter(String filter) {
    if (_filter == filter) return;
    _filter = filter;
    fetchNextPage(isRefresh: true);
  }

  /// Resets all search and filter values.
  void resetFilters() {
    _searchQuery = '';
    _filter = 'All';
    fetchNextPage(isRefresh: true);
  }

  /// Fetches a paginated page of records from Firestore.
  Future<void> fetchNextPage({bool isRefresh = false}) async {
    if (testFirestore != null) {
      if (isRefresh) {
        _testRecords = [];
        _lastDocument = null;
        _hasMoreBonds = true;
        _isLoadingBonds = true;
      } else {
        if (!_hasMoreBonds || _isLoadingMoreBonds || _isLoadingBonds) {
          return;
        }
        _isLoadingMoreBonds = true;
      }
      notifyListeners();

      try {
        final collectionRef = testFirestore!.collection(
          DatasetIds.localMarketBonds,
        );

        Query query = collectionRef;

        // Apply bondType filter
        if (_filter == 'Government') {
          query = query.where('bondType.en', isEqualTo: 'Government');
        } else if (_filter == 'CPI-Linked') {
          query = query.where(
            'bondType.en',
            isEqualTo: 'CPI-Linked Government',
          );
        } else if (_filter == 'Floating Rate') {
          query = query.where(
            'bondType.en',
            isEqualTo: 'Floating Rate Government',
          );
        }

        // Apply search query
        bool queryIsOrderedByString = false;
        if (_searchQuery.isNotEmpty) {
          final searchString = _searchQuery.trim();
          final parsedSeries = int.tryParse(searchString);

          if (parsedSeries != null) {
            query = query.where('series', isEqualTo: parsedSeries);
          } else {
            final cleanSearch = searchString;
            query = query
                .where('bondType.en', isGreaterThanOrEqualTo: cleanSearch)
                .where(
                  'bondType.en',
                  isLessThanOrEqualTo: '$cleanSearch\uf8ff',
                );
            queryIsOrderedByString = true;
          }
        }

        // Ordering
        if (queryIsOrderedByString) {
          query = query.orderBy('bondType.en').orderBy('_id', descending: true);
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
              (doc) => LocalMarketBondRecordModel.fromMap(
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
        _hasMoreBonds = fetchedDocs.length == pageSize;
        _isLoadingBonds = false;
        _isLoadingMoreBonds = false;
        notifyListeners();
      } catch (e) {
        AppLogger.error('Failed to fetch local market bonds page', e);
        _isLoadingBonds = false;
        _isLoadingMoreBonds = false;
        notifyListeners();
      }
      return;
    }

    if (!_isTesting && !isFirebaseInitialized) {
      _isLoadingBonds = false;
      _isLoadingMoreBonds = false;
      await _syncManager.initialize(mockData: [], isTesting: true);
      notifyListeners();
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
      if (_isTesting) {
        _isLoadingBonds = true;
        _hasMoreBonds = true;
        notifyListeners();
        unawaited(
          _syncManager.initialize(mockData: MockData.bonds, isTesting: true),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _hasMoreBonds = false;
        _isLoadingBonds = false;
      }
    } else {
      if (!hasMoreBonds || _isLoadingMoreBonds || isLoadingBonds) {
        return;
      }
      _isLoadingMoreBonds = true;
      notifyListeners();
      if (_isTesting) {
        unawaited(
          _syncManager.initialize(mockData: MockData.bonds, isTesting: true),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        _hasMoreBonds = false;
      }
      _currentPage++;
      _isLoadingMoreBonds = false;
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
