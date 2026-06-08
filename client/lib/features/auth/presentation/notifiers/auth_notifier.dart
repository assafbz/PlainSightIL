import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/state/local_storage.dart';
import 'package:plainsight/core/utils/app_logger.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/repositories/user_profile_repository.dart';
import '../../../profile/domain/usecases/get_user_profile.dart';
import '../../../profile/domain/usecases/update_user_profile.dart';
import '../../../profile/data/datasources/user_profile_remote_datasource.dart';
import '../../../profile/data/repositories/user_profile_repository_impl.dart';

import 'package:plainsight/core/state/app_state.dart';

/// Scoped state notifier that handles authentication, user profile management,
/// guest mode toggles, and user-specific local storage preferences.
class AuthNotifier extends ChangeNotifier {
  /// Local indicator if we are running in unit/widget mock testing mode.
  bool get _isTesting => AppStateNotifier.isTesting;

  /// Active Firebase Auth user.
  User? _currentUser;

  /// Guest mode indicator flag.
  bool _isGuestMode = false;

  /// Mock authentication state indicator.
  bool _isMockAuthenticatedInternal = false;
  bool get _isMockAuthenticated => _isTesting || _isMockAuthenticatedInternal;
  set _isMockAuthenticated(bool val) => _isMockAuthenticatedInternal = val;

  /// User specific favorites dataset ID array.
  List<String> _favorites = [];

  /// User specific recently viewed dataset ID array.
  List<String> _recents = [];

  /// User Profile entity retrieved from Firestore/Mock database.
  UserProfile? _userProfile;

  /// Profile listener stream subscription.
  StreamSubscription<UserProfile?>? _profileSubscription;

  @visibleForTesting
  UserProfileRepository? testProfileRepository;

  @visibleForTesting
  Stream<User?>? testAuthChangesStream;

  @visibleForTesting
  FirebaseFirestore? testFirestore;

  @visibleForTesting
  FirebaseAuth? testAuth;

  @visibleForTesting
  GoogleSignIn? testGoogleSignIn;

  late final UserProfileRepository _profileRepository;
  late final GetUserProfile _getUserProfileUseCase;
  late final UpdateUserProfile _updateUserProfileUseCase;

  /// Get active Firebase Auth user.
  User? get currentUser => _currentUser;

  /// Checks if user is authenticated (using real Firebase Auth or mock test mode).
  bool get isAuthenticated => _currentUser != null || _isMockAuthenticated;

  /// Checks if guest mode is enabled.
  bool get isGuestMode => _isGuestMode;

  /// Checks if active user has administrative rights.
  bool get isAdmin => _isMockAuthenticated || (_userProfile?.role == 'admin');

  /// Gets local user favorites.
  List<String> get favorites => _favorites;

  /// Gets local recently viewed datasets.
  List<String> get recents => _recents;

  /// Gets active user profile.
  UserProfile? get userProfile => _userProfile;

  /// Returns mock user details if in mock testing mode.
  Map<String, String>? get mockUser => _isMockAuthenticated
      ? {'name': 'Assaf Benzaken', 'email': 'assaf@plainsight.il'}
      : null;

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

  /// Construct and initialize the AuthNotifier state.
  AuthNotifier({
    bool isTesting = false,
    this.testProfileRepository,
    this.testAuthChangesStream,
    this.testFirestore,
    this.testAuth,
  }) {
    AppLogger.info('Initializing AuthNotifier (isTesting: $isTesting)');
    _isMockAuthenticated = isTesting;
    _initProfileUsecases();
    _initAuthListener();
    _initSharedPreferences();
    if (_isMockAuthenticated) {
      _updateProfileListener('mock_uid');
    }
  }

  void _initProfileUsecases() {
    if (testProfileRepository != null) {
      _profileRepository = testProfileRepository!;
    } else if (!_isTesting && isFirebaseInitialized) {
      final datasource = UserProfileRemoteDataSourceImpl(
        testFirestore ?? FirebaseFirestore.instance,
      );
      _profileRepository = UserProfileRepositoryImpl(datasource);
    } else {
      _profileRepository = _MockUserProfileRepository();
    }
    _getUserProfileUseCase = GetUserProfile(_profileRepository);
    _updateUserProfileUseCase = UpdateUserProfile(_profileRepository);
  }

  /// Sets the mock user profile (available only in testing mode).
  void setMockProfile(UserProfile? profile) {
    if (!_isTesting) return;
    final repo = _profileRepository;
    if (repo is _MockUserProfileRepository) {
      repo._currentProfile = profile;
      repo._controller.add(profile);
      _userProfile = profile;
      notifyListeners();
    }
  }

  Future<void> _initSharedPreferences() async {
    try {
      await LocalStorage.init();
      _favorites = LocalStorage.getFavorites();
      _recents = LocalStorage.getRecents();
      _isGuestMode = LocalStorage.getGuestMode();
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        'Error initializing SharedPreferences in AuthNotifier',
        e,
      );
    }
  }

  /// Check if dataset is in user's favorites list.
  bool isFavorite(String datasetId) {
    return _favorites.contains(datasetId);
  }

  /// Add/Remove dataset from favorites and sync to local storage.
  Future<void> toggleFavorite(String datasetId) async {
    final isFav = _favorites.contains(datasetId);
    if (isFav) {
      _favorites.remove(datasetId);
    } else {
      _favorites.add(datasetId);
    }
    notifyListeners();
    try {
      await LocalStorage.saveFavorites(_favorites);
    } catch (e) {
      AppLogger.error('Error saving favorites for dataset $datasetId', e);
    }
  }

  /// Record dataset ID to recently viewed list.
  Future<void> addRecent(String datasetId) async {
    _recents.remove(datasetId);
    _recents.insert(0, datasetId);
    if (_recents.length > 5) {
      _recents = _recents.sublist(0, 5);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    try {
      await LocalStorage.saveRecents(_recents);
    } catch (e) {
      AppLogger.error('Error saving recents for dataset $datasetId', e);
    }
  }

  void _initAuthListener() {
    if (testAuthChangesStream != null) {
      testAuthChangesStream!.listen(
        (user) {
          final bool userChanged = _currentUser?.uid != user?.uid;
          _currentUser = user;
          if (userChanged) {
            _userProfile = null;
            _updateProfileListener(user?.uid);
          }
          notifyListeners();
        },
        onError: (Object error) {
          AppLogger.error('Test Auth Stream Error', error);
        },
      );
      return;
    }
    if (_isTesting || !isFirebaseInitialized) return;
    try {
      (testAuth ?? FirebaseAuth.instance).authStateChanges().listen(
        (user) {
          final bool userChanged = _currentUser?.uid != user?.uid;
          _currentUser = user;
          if (userChanged) {
            _userProfile = null;
            _updateProfileListener(user?.uid);
          }
          notifyListeners();
        },
        onError: (Object error) {
          AppLogger.error('Firebase Auth Stream Error', error);
        },
      );
    } catch (e) {
      AppLogger.error('Auth listener init error', e);
    }
  }

  void _updateProfileListener(String? uid) {
    _profileSubscription?.cancel();
    _profileSubscription = null;

    if (uid == null) {
      _userProfile = null;
      notifyListeners();
      return;
    }

    _profileSubscription = _getUserProfileUseCase
        .call(uid)
        .listen(
          (profile) {
            if (_userProfile != profile) {
              _userProfile = profile;
              notifyListeners();
            }
          },
          onError: (Object error) {
            AppLogger.error('Profile stream error for UID: $uid', error);
          },
        );
  }

  /// Save modifications to the user's profile card in the database.
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      await _updateUserProfileUseCase.call(profile);
      _userProfile = profile;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error updating user profile for UID: ${profile.uid}', e);
      rethrow;
    }
  }

  /// Perform secure Google single sign-in flow.
  Future<void> signInWithGoogle() async {
    if (_isTesting || !isFirebaseInitialized) {
      _isMockAuthenticated = true;
      _isGuestMode = false;
      _updateProfileListener('mock_uid');
      notifyListeners();
      return;
    }

    try {
      if ((kIsWeb ||
              (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) &&
          testGoogleSignIn == null) {
        final provider = GoogleAuthProvider();
        await (testAuth ?? FirebaseAuth.instance).signInWithPopup(provider);
      } else {
        final GoogleSignIn googleSignIn =
            testGoogleSignIn ?? GoogleSignIn.instance;
        await googleSignIn.initialize();
        final GoogleSignInAccount googleUser = await googleSignIn
            .authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await (testAuth ?? FirebaseAuth.instance).signInWithCredential(
          credential,
        );
      }
      _isGuestMode = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Google Sign-In Error', e);
      rethrow;
    }
  }

  /// Revoke credentials and clean up session tokens.
  Future<void> signOut() async {
    _isMockAuthenticated = false;
    _isGuestMode = false;
    _updateProfileListener(null);
    try {
      await LocalStorage.saveGuestMode(false);
    } catch (_) {}
    if (isFirebaseInitialized) {
      try {
        await (testAuth ?? FirebaseAuth.instance).signOut();
      } catch (e) {
        AppLogger.error('Firebase Sign-Out Error', e);
      }
    }
    notifyListeners();
  }

  /// Configure local guest mode operations.
  Future<void> setGuestMode(bool enabled) async {
    _isGuestMode = enabled;
    notifyListeners();
    try {
      await LocalStorage.saveGuestMode(enabled);
    } catch (e) {
      AppLogger.error('Error saving guest mode', e);
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
    _profileSubscription?.cancel();
    super.dispose();
  }
}

/// A Mock User Profile Repository used in testing and offline environments.
class _MockUserProfileRepository implements UserProfileRepository {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentProfile;

  _MockUserProfileRepository() {
    _currentProfile = UserProfile(
      uid: 'mock_uid',
      firstName: 'Assaf',
      lastName: 'Benzaken',
      email: 'assaf@plainsight.il',
      role: 'user',
      isSubscribed: false,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
    _controller.add(_currentProfile);
  }

  @override
  Stream<UserProfile?> getUserProfile(String uid) async* {
    yield _currentProfile;
    yield* _controller.stream;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    _currentProfile = profile;
    _controller.add(profile);
  }
}
