import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/travel_warning_model.dart';
import 'package:plainsight/core/constants/dataset_ids.dart';
import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles travel warnings collection streams,
/// loader flags, and test mode data fallbacks.
class TravelWarningsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<TravelWarningRecordModel> _warningRecords = [];
  bool _isLoadingWarnings = true;
  StreamSubscription<QuerySnapshot>? _warningsSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns travel warnings records list.
  List<TravelWarningRecordModel> get warningRecords => _warningRecords;

  /// Checks if travel warnings query is loading.
  bool get isLoadingWarnings => _isLoadingWarnings;

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

  /// Construct and initialize the TravelWarningsNotifier.
  TravelWarningsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  });

  /// Initialize real-time streams to travel warnings collection.
  void initTravelWarningsListener() {
    _warningsSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingWarnings = true;
      _warningsSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _warningRecords = snapshot.docs
              .map((doc) => TravelWarningRecordModel.fromMap(doc.data()))
              .toList();
          _isLoadingWarnings = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingWarnings = false;
          notifyListeners();
          AppLogger.error(
            'Firestore travel warnings collection listener error',
            err,
          );
        },
      );
      return;
    }
    if (_isTesting) {
      _warningRecords = [
        TravelWarningRecordModel(
          id: '1',
          idNum: 1,
          continent: 'אפריקה',
          country: 'אוגנדה',
          recommendations:
              'רמה 2/ איום מזדמן: המלצה לנקוט באמצעי זהירות מוגברים.',
          details: 'להמלצה באתר המטה לביטחון לאומי',
          logo: 'לוגו',
          date: '2026-06-03T00:00:00.000Z',
          office: 'מל"ל',
          warningLevel: 2,
        ),
        TravelWarningRecordModel(
          id: '2',
          idNum: 2,
          continent: 'אסיה',
          country: 'אוזבקיסטאן',
          recommendations:
              'רמת איום משולבת: רמה 4/ איום גבוה ולהימנע מהגעה לאיזור הגבול עם אפגניסטן.',
          details: 'להמלצה באתר המטה לביטחון לאומי',
          logo: 'לוגו',
          date: '2026-06-03T00:00:00.000Z',
          office: 'מל"ל',
          warningLevel: 4,
        ),
        TravelWarningRecordModel(
          id: '3',
          idNum: 3,
          continent: 'אירופה',
          country: 'אוסטריה',
          recommendations: 'שימרו על עירנות, הקשיבו לאמצעי התקשורת.',
          details: 'המלצות לקראת האירווויזיון',
          logo: 'לוגו',
          date: '2026-06-03T00:00:00.000Z',
          office: 'חוץ',
          warningLevel: 1,
        ),
      ];
      _isLoadingWarnings = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingWarnings = false;
      notifyListeners();
      return;
    }

    AppLogger.info(
      'Initializing travel warnings listener in TravelWarningsNotifier',
    );
    _isLoadingWarnings = true;
    notifyListeners();

    try {
      _warningsSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection(DatasetIds.travelWarnings)
          .snapshots()
          .listen(
            (snapshot) {
              _warningRecords = snapshot.docs
                  .map((doc) => TravelWarningRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingWarnings = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingWarnings = false;
              notifyListeners();
              AppLogger.error(
                'Firestore travel warnings collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingWarnings = false;
      notifyListeners();
      AppLogger.error('Failed to initialize travel warnings listener', e);
    }
  }

  /// Cancels active travel warnings subscriptions.
  void cancelTravelWarningsListener() {
    _warningsSubscription?.cancel();
    _warningsSubscription = null;
    _isLoadingWarnings = true;
    _warningRecords = [];
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
    _warningsSubscription?.cancel();
    super.dispose();
  }
}
