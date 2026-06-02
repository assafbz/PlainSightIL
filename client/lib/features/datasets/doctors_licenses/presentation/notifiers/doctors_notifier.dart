import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../data/models/doctor_license_model.dart';

import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles doctors licenses collection streams,
/// loader flags, and test mode data fallbacks.
class DoctorsNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  List<DoctorLicenseRecordModel> _doctorRecords = [];
  bool _isLoadingDoctors = true;
  StreamSubscription<QuerySnapshot>? _doctorsSubscription;

  @visibleForTesting
  Stream<QuerySnapshot<Map<String, dynamic>>>? testFirestoreStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  /// Returns doctors licenses records list.
  List<DoctorLicenseRecordModel> get doctorRecords => _doctorRecords;

  /// Checks if doctors licenses query is loading.
  bool get isLoadingDoctors => _isLoadingDoctors;

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

  /// Construct and initialize the DoctorsNotifier.
  DoctorsNotifier({
    bool isTesting = false,
    this.testFirestoreStream,
    this.testFirestore,
  });

  /// Initialize real-time streams to doctors licenses collection.
  void initDoctorsListener() {
    _doctorsSubscription?.cancel();
    if (testFirestoreStream != null) {
      _isLoadingDoctors = true;
      _doctorsSubscription = testFirestoreStream!.listen(
        (snapshot) {
          _doctorRecords = snapshot.docs
              .map(
                (doc) => DoctorLicenseRecordModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
          _isLoadingDoctors = false;
          notifyListeners();
        },
        onError: (Object err) {
          _isLoadingDoctors = false;
          notifyListeners();
          AppLogger.error('Firestore doctors collection listener error', err);
        },
      );
      return;
    }
    if (_isTesting) {
      _doctorRecords = [
        DoctorLicenseRecordModel(
          id: '1',
          idNum: 1,
          firstName: 'מריו ה',
          lastName: 'קורוב',
          licenseNumber: 4267,
          licenseRegistrationDate: '1969-07-28T00:00:00.000Z',
        ),
        DoctorLicenseRecordModel(
          id: '2',
          idNum: 2,
          firstName: 'אברהם',
          lastName: 'שטיינברג',
          licenseNumber: 11116,
          licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
          specialtyCertificateNumber: 7656,
          specialtyRegistrationDate: '1983-06-21T00:00:00.000Z',
          specialtyName: 'רפואת ילדים',
        ),
        DoctorLicenseRecordModel(
          id: '3',
          idNum: 3,
          firstName: 'אברהם',
          lastName: 'שטיינברג',
          licenseNumber: 11116,
          licenseRegistrationDate: '1974-08-20T00:00:00.000Z',
          specialtyCertificateNumber: 13230,
          specialtyRegistrationDate: '1993-12-02T00:00:00.000Z',
          specialtyName: 'נוירולוגיית ילדים',
        ),
      ];
      _isLoadingDoctors = false;
      notifyListeners();
      return;
    }

    if (!isFirebaseInitialized) {
      _isLoadingDoctors = false;
      notifyListeners();
      return;
    }

    AppLogger.info('Initializing doctors licenses listener in DoctorsNotifier');
    try {
      _doctorsSubscription = (testFirestore ?? FirebaseFirestore.instance)
          .collection('9c64c522-bbc2-48fe-96fb-3b2a8626f59e')
          .limit(100)
          .snapshots()
          .listen(
            (snapshot) {
              _doctorRecords = snapshot.docs
                  .map((doc) => DoctorLicenseRecordModel.fromMap(doc.data()))
                  .toList();
              _isLoadingDoctors = false;
              notifyListeners();
            },
            onError: (Object err) {
              _isLoadingDoctors = false;
              notifyListeners();
              AppLogger.error(
                'Firestore doctors collection listener error',
                err,
              );
            },
          );
    } catch (e) {
      _isLoadingDoctors = false;
      notifyListeners();
      AppLogger.error(
        'Failed to initialize doctors listener in DoctorsNotifier',
        e,
      );
    }
  }

  @override
  void dispose() {
    _doctorsSubscription?.cancel();
    super.dispose();
  }
}
