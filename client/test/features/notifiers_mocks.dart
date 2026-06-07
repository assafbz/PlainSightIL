// ignore_for_file: subtype_of_sealed_class, inference_failure_on_function_return_type, unused_import, depend_on_referenced_packages, prefer_initializing_formals, unnecessary_non_null_assertion, unused_local_variable, unawaited_futures, close_sinks, must_be_immutable
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:plainsight/core/errors/exceptions.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/domain/repositories/user_profile_repository.dart';

// Fake implementations for Firestore classes
class FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final bool _exists;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._id, this._exists, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake User implementation
class FakeUser implements User {
  final String _uid;
  final String _email;
  FakeUser(this._uid, this._email);

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async =>
      'mock-id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake User Profile Repository
class FakeUserProfileRepository implements UserProfileRepository {
  final StreamController<UserProfile?> controller =
      StreamController<UserProfile?>.broadcast();
  UserProfile? mockProfile;
  UserProfile? lastUpdated;
  bool throwOnUpdate = false;

  FakeUserProfileRepository(this.mockProfile);

  @override
  Stream<UserProfile?> getUserProfile(String uid) async* {
    yield mockProfile;
    yield* controller.stream;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    if (throwOnUpdate) {
      throw Exception('Update profile database error');
    }
    lastUpdated = profile;
    mockProfile = profile;
    controller.add(profile);
  }
}

// Fake HTTP Client
class FakeHttpClient implements http.Client {
  final FutureOr<http.Response> Function(Uri, {Map<String, String>? headers})?
  onGet;
  final FutureOr<http.Response> Function(
    Uri, {
    Object? body,
    Map<String, String>? headers,
  })?
  onPost;

  FakeHttpClient({this.onGet, this.onPost});

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    if (onGet != null) {
      return onGet!(url, headers: headers);
    }
    return http.Response('{}', 200);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    dynamic encoding,
  }) async {
    if (onPost != null) {
      return onPost!(url, headers: headers, body: body);
    }
    return http.Response('{}', 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  final CollectionReference Function(String) collectionBuilder;
  bool transactionExists = true;
  bool throwOnTransaction = false;

  FakeFirebaseFirestore(this.collectionBuilder);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return collectionBuilder(path) as CollectionReference<Map<String, dynamic>>;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (throwOnTransaction) {
      throw Exception('Transaction failed');
    }
    final transaction = FakeTransaction(exists: transactionExists);
    return await transactionHandler(transaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransaction implements Transaction {
  final bool exists;
  FakeTransaction({this.exists = true});

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    return FakeDocumentSnapshot(documentReference.id, exists, {
          'requestCount': 5,
        })
        as DocumentSnapshot<T>;
  }

  @override
  Transaction delete(DocumentReference documentReference) => this;

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) => this;

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Query Function(int)? limitBuilder;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final DocumentReference<Map<String, dynamic>> Function(String)? docBuilder;

  FakeCollectionReference({this.limitBuilder, this.stream, this.docBuilder});

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (docBuilder != null && path != null) {
      return docBuilder!(path);
    }
    return FakeDocumentReference(id: path ?? 'mock-id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return stream ?? const Stream.empty();
    }
    if (invocation.memberName == #where) {
      return this;
    }
    if (invocation.memberName == #orderBy) {
      return this;
    }
    if (invocation.memberName == #limit) {
      final limitVal = invocation.positionalArguments[0] as int;
      if (limitBuilder != null) {
        return limitBuilder!(limitVal);
      }
      return this;
    }
    if (invocation.memberName == #startAfterDocument) {
      return this;
    }
    if (invocation.memberName == #get) {
      if (stream != null) {
        return stream!.first;
      }
      return Future.value(FakeQuerySnapshot([]));
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeCollectionReferenceWithDocs extends FakeCollectionReference {
  int getCallCount = 0;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeCollectionReferenceWithDocs(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      getCallCount++;
      if (getCallCount == 1) {
        return Future.value(FakeQuerySnapshot(docs));
      }
      return Future.value(FakeQuerySnapshot([]));
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? snapshotStream;
  final bool exists;
  final Map<String, dynamic>? data;
  FakeDocumentReference({
    String id = 'mock-id',
    this.snapshotStream,
    this.exists = false,
    this.data,
  }) : _id = id;

  @override
  String get id => _id;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      return snapshotStream ?? const Stream.empty();
    }
    if (invocation.memberName == #get) {
      final exists = _id == 'existing-doc' || _id == 'existing-dataset-id';
      final data = exists
          ? {
              'scheduler': {'nextRun': '2026-06-04T12:00:00Z'},
            }
          : {'requestCount': 5};
      return Future.value(FakeDocumentSnapshot(_id, exists, data));
    }
    if (invocation.memberName == #set) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeFirebaseAuth implements FirebaseAuth {
  final User? mockCurrentUser;
  final Stream<User?> authChanges;
  final Future<UserCredential> Function()? onSignInAnonymously;
  final Future<UserCredential> Function()? onSignInWithPopup;
  final Future<void> Function()? onSignOut;

  FakeFirebaseAuth({
    this.mockCurrentUser,
    required this.authChanges,
    this.onSignInAnonymously,
    this.onSignInWithPopup,
    this.onSignOut,
  });

  @override
  User? get currentUser => mockCurrentUser;

  @override
  Stream<User?> authStateChanges() => authChanges;

  @override
  Future<UserCredential> signInWithPopup(dynamic provider) async {
    if (onSignInWithPopup != null) {
      return onSignInWithPopup!();
    }
    return FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    if (onSignOut != null) {
      await onSignOut!();
    }
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    if (onSignInAnonymously != null) {
      return onSignInAnonymously!();
    }
    return FakeUserCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  User get user => FakeUser('mock_anonymous_uid', 'anonymous@plainsight.il');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ThrowingSharedPreferencesStore extends SharedPreferencesStorePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<bool> clear() => throw Exception('Prefs write error');

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      throw Exception('Prefs write error');

  @override
  Future<Map<String, Object>> getAll() => throw Exception('Prefs read error');

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => throw Exception('Prefs read error');

  @override
  Future<bool> remove(String key) => throw Exception('Prefs write error');

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw Exception('Prefs write error');
}

final tDate = DateTime(2026, 6, 1);
final tProfile = UserProfile(
  uid: 'user_123',
  firstName: 'Assaf',
  lastName: 'Benzaken',
  email: 'assaf@plainsight.il',
  role: 'user',
  createdAt: tDate,
  updatedAt: tDate,
);
