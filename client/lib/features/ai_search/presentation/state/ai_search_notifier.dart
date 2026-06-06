// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/state/app_state.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import '../../data/models/ai_search_result_model.dart';

/// State notifier that manages AI semantic search querying, loading states, errors,
/// and local query history storage.
class AiSearchNotifier extends ChangeNotifier {
  final AppStateNotifier appState;
  final http.Client? _client;
  final FirebaseAuth? _auth;

  bool _isLoading = false;
  String? _errorMessage;
  AiSearchResultModel? _searchResult;
  List<String> _history = [];

  AiSearchNotifier({
    required this.appState,
    http.Client? client,
    FirebaseAuth? auth,
  }) : _client = client,
       _auth = auth;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AiSearchResultModel? get searchResult => _searchResult;
  List<String> get history => _history;

  /// Loads search history from local SharedPreferences.
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _history = prefs.getStringList('ai_search_history') ?? [];
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to load search history', e);
    }
  }

  /// Adds a query string to the search history cache, maintaining a maximum of 5 items.
  Future<void> _addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _history.remove(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > 5) {
      _history = _history.sublist(0, 5);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ai_search_history', _history);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to save search history', e);
    }
  }

  /// Clears local search query history.
  Future<void> clearHistory() async {
    _history.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_search_history');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to clear search history', e);
    }
  }

  /// Performs AI semantic search across active collections by invoking the HTTPS Cloud Function.
  Future<void> performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _searchResult = null;
    notifyListeners();

    // Mock response mode for unit tests
    if (AppStateNotifier.isTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = trimmed.toLowerCase();
      if (q.contains('toyota') || q.contains('טויוטה')) {
        _searchResult = AiSearchResultModel(
          answer: appState.locale == 'he'
              ? 'נמצאו קריאות פעילות לתיקון עבור רכבי טויוטה [cit-01]. התקלה נובעת משסתום צינור דלק במנוע.'
              : 'Active recalls found for Toyota vehicles [cit-01]. The defect is in the engine fuel pipe valve.',
          citations: [
            CitationModel(
              id: 'cit-01',
              datasetId: DatasetIds.vehicleRecalls,
              docId: '11020',
              title: 'טויוטה אוונסיס 2011',
            ),
          ],
        );
      } else {
        _searchResult = AiSearchResultModel(
          answer: appState.locale == 'he'
              ? 'לא נמצאו רשומות רלוונטיות במאגרי המידע.'
              : 'No relevant records found in the database.',
          citations: [],
        );
      }
      _isLoading = false;
      await _addToHistory(trimmed);
      return;
    }

    try {
      await _addToHistory(trimmed);

      String? token;
      if (appState.isFirebaseInitialized) {
        try {
          final auth = _auth ?? FirebaseAuth.instance;
          final currentUser = auth.currentUser;
          if (currentUser != null) {
            token = await currentUser.getIdToken();
          }
        } catch (_) {}
      }

      final String functionUrl =
          '${appState.telemetryNotifier.functionsBaseUrl}/aiSemanticSearch';
      final response = _client != null
          ? await _client.post(
              Uri.parse(functionUrl),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'query': trimmed, 'lang': appState.locale}),
            )
          : await http
                .post(
                  Uri.parse(functionUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    if (token != null) 'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({'query': trimmed, 'lang': appState.locale}),
                )
                .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _searchResult = AiSearchResultModel.fromJson(decoded);
      } else {
        Map<String, dynamic>? decoded;
        try {
          decoded =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>?;
        } catch (_) {}
        _errorMessage =
            (decoded?['message'] as String?) ??
            (decoded?['error'] as String?) ??
            'Failed to execute AI search (code: ${response.statusCode})';
      }
    } catch (e) {
      AppLogger.error('AI search failed', e);
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
