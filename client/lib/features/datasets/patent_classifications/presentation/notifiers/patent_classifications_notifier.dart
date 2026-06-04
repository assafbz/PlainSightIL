import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/patent_classification_model.dart';
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/constants/mock_data.dart';

/// Scoped state notifier that handles Patent Classifications Firestore query pagination,
/// searching, filtering, and test mode data fallbacks.
class PatentClassificationsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<PatentClassificationRecordModel> _patentRecords = [];
  bool _isLoadingPatents = false;
  bool _isLoadingMorePatents = false;
  bool _hasMorePatents = true;
  DocumentSnapshot? _lastDocument;

  String _searchQuery = '';
  String _primaryFilter = 'All'; // 'All', 'Primary', 'Secondary'

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns patent classifications records list.
  List<PatentClassificationRecordModel> get patentRecords => _patentRecords;

  /// Checks if patent classifications query is loading initial page.
  bool get isLoadingPatents => _isLoadingPatents;

  /// Checks if patent classifications is loading subsequent pages.
  bool get isLoadingMorePatents => _isLoadingMorePatents;

  /// Checks if there are more pages to load.
  bool get hasMorePatents => _hasMorePatents;

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
  PatentClassificationsNotifier({
    bool isTesting = false,
    this.testFirestore,
  });

  /// Initialize and load the initial page of patent classifications.
  void initPatentClassificationsListener() {
    fetchNextPage(isRefresh: true);
  }

  /// Cancels and resets state.
  void cancelPatentClassificationsListener() {
    _patentRecords = [];
    _lastDocument = null;
    _hasMorePatents = true;
    _isLoadingPatents = false;
    _isLoadingMorePatents = false;
    notifyListeners();
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
    if (isRefresh) {
      _patentRecords = [];
      _lastDocument = null;
      _hasMorePatents = true;
      _isLoadingPatents = true;
    } else {
      if (!_hasMorePatents || _isLoadingMorePatents || _isLoadingPatents) return;
      _isLoadingMorePatents = true;
    }
    notifyListeners();

    // 1. Mock fallback mode
    if (_isTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      List<PatentClassificationRecordModel> mockSource = MockData.patents;

      // Filter by primary/secondary
      if (_primaryFilter == 'Primary') {
        mockSource = mockSource.where((r) => r.isPrimary).toList();
      } else if (_primaryFilter == 'Secondary') {
        mockSource = mockSource.where((r) => !r.isPrimary).toList();
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        mockSource = mockSource.where((r) {
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

      _patentRecords = mockSource;
      _hasMorePatents = false; // Mock data is static and fits in one page
      _isLoadingPatents = false;
      _isLoadingMorePatents = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingPatents = false;
      _isLoadingMorePatents = false;
      notifyListeners();
      return;
    }

    try {
      final collectionRef = (testFirestore ?? FirebaseFirestore.instance)
          .collection('b2c59e21-c345-4b02-b071-2890a3d431d6');

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
          // Exact match on application number
          query = query.where('applicationNumber', isEqualTo: parsedAppNum);
        } else {
          // CPC classification prefix match
          final cleanSearch = searchString.toUpperCase();
          query = query
              .where('cpcClassification', isGreaterThanOrEqualTo: cleanSearch)
              .where('cpcClassification', isLessThanOrEqualTo: '$cleanSearch\uf8ff');
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
          .map((doc) => PatentClassificationRecordModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      if (isRefresh) {
        _patentRecords = newRecords;
      } else {
        _patentRecords.addAll(newRecords);
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
