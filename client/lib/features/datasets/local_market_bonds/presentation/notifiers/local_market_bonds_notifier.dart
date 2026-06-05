import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/local_market_bond_model.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';

/// Scoped state notifier that handles Local Market Bonds Firestore query pagination,
/// searching, filtering, and test mode data fallbacks.
class LocalMarketBondsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<LocalMarketBondRecordModel> _bondRecords = [];
  bool _isLoadingBonds = false;
  bool _isLoadingMoreBonds = false;
  bool _hasMoreBonds = true;
  DocumentSnapshot? _lastDocument;

  String _searchQuery = '';
  String _filter = 'All'; // 'All', 'Government', 'CPI-Linked', 'Floating Rate'

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns local market bonds records list.
  List<LocalMarketBondRecordModel> get bondRecords => _bondRecords;

  /// Checks if bonds query is loading initial page.
  bool get isLoadingBonds => _isLoadingBonds;

  /// Checks if bonds is loading subsequent pages.
  bool get isLoadingMoreBonds => _isLoadingMoreBonds;

  /// Checks if there are more pages to load.
  bool get hasMoreBonds => _hasMoreBonds;

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
  LocalMarketBondsNotifier({bool isTesting = false, this.testFirestore});

  /// Initialize and load the initial page of local market bonds.
  void initBondsListener() {
    fetchNextPage(isRefresh: true);
  }

  /// Cancels and resets state.
  void cancelBondsListener() {
    _bondRecords = [];
    _lastDocument = null;
    _hasMoreBonds = true;
    _isLoadingBonds = false;
    _isLoadingMoreBonds = false;
    notifyListeners();
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
    if (isRefresh) {
      _bondRecords = [];
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

    // 1. Mock fallback mode
    if (_isTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      List<LocalMarketBondRecordModel> mockSource = MockData.bonds;

      // Filter by type
      if (_filter == 'Government') {
        mockSource = mockSource
            .where((r) => r.bondType['en'] == 'Government')
            .toList();
      } else if (_filter == 'CPI-Linked') {
        mockSource = mockSource
            .where((r) => r.bondType['en'] == 'CPI-Linked Government')
            .toList();
      } else if (_filter == 'Floating Rate') {
        mockSource = mockSource
            .where((r) => r.bondType['en'] == 'Floating Rate Government')
            .toList();
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        mockSource = mockSource.where((r) {
          final seriesStr = r.series.toString();
          final typeHe = r.bondType['he']?.toLowerCase() ?? '';
          final typeEn = r.bondType['en']?.toLowerCase() ?? '';
          return seriesStr.contains(query) ||
              typeHe.contains(query) ||
              typeEn.contains(query);
        }).toList();
      }

      _bondRecords = mockSource;
      _hasMoreBonds = false; // Mock data is static and fits in one page
      _isLoadingBonds = false;
      _isLoadingMoreBonds = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingBonds = false;
      _isLoadingMoreBonds = false;
      notifyListeners();
      return;
    }

    try {
      final collectionRef = (testFirestore ?? FirebaseFirestore.instance)
          .collection('c92fdda2-0939-4110-8ebc-edfcf35e8723');

      Query query = collectionRef;

      // Apply bondType filter
      if (_filter == 'Government') {
        query = query.where('bondType.en', isEqualTo: 'Government');
      } else if (_filter == 'CPI-Linked') {
        query = query.where('bondType.en', isEqualTo: 'CPI-Linked Government');
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
              .where('bondType.en', isLessThanOrEqualTo: '$cleanSearch\uf8ff');
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
        _bondRecords = newRecords;
      } else {
        _bondRecords.addAll(newRecords);
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
    super.dispose();
  }
}
