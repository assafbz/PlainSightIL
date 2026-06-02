import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/errors/exceptions.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/data/models/user_profile_model.dart';
import 'package:plainsight/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:plainsight/features/profile/data/datasources/user_profile_remote_datasource.dart';

// Fake implementations for Firestore testing
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final bool _exists;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._exists, this._data);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final bool _exists;
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(Map<String, dynamic>)? onSet;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  FakeDocumentReference(
    this._exists,
    this._data, {
    this.onUpdate,
    this.onSet,
    Stream<DocumentSnapshot<Map<String, dynamic>>>? stream,
  }) : _stream = stream;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    return FakeDocumentSnapshot(_exists, _data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      if (_stream != null) return _stream!;
      return Stream.value(FakeDocumentSnapshot(_exists, _data));
    }
    if (invocation.memberName == #update) {
      final data = invocation.positionalArguments[0] as Map;
      if (onUpdate != null) {
        onUpdate!(Map<String, dynamic>.from(data));
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #set) {
      final data = invocation.positionalArguments[0] as Map;
      if (onSet != null) {
        onSet!(Map<String, dynamic>.from(data));
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final FakeDocumentReference Function(String) docBuilder;
  FakeCollectionReference(this.docBuilder);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return docBuilder(path ?? '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  final FakeCollectionReference Function(String) collectionBuilder;
  FakeFirebaseFirestore(this.collectionBuilder);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return collectionBuilder(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake remote data source for repository testing
class FakeUserProfileRemoteDataSource implements UserProfileRemoteDataSource {
  final StreamController<UserProfileModel?> controller =
      StreamController<UserProfileModel?>.broadcast();
  UserProfileModel? lastUpdatedModel;

  @override
  Stream<UserProfileModel?> getUserProfile(String uid) {
    return controller.stream;
  }

  @override
  Future<void> updateUserProfile(UserProfileModel model) async {
    lastUpdatedModel = model;
  }
}

void main() {
  group('UserProfile Entity Tests', () {
    final tProfile = UserProfile(
      uid: 'user_1',
      firstName: 'Assaf',
      lastName: 'Benzaken',
      email: 'assaf@plainsight.il',
      role: 'user',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

    test('copyWith works correctly', () {
      final updated = tProfile.copyWith(firstName: 'John', role: 'admin');
      expect(updated.firstName, 'John');
      expect(updated.role, 'admin');
      expect(updated.lastName, 'Benzaken');
      expect(updated.uid, 'user_1');
    });

    test('equality operators and hashCode work correctly', () {
      final duplicate = UserProfile(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      expect(tProfile, duplicate);
      expect(tProfile.hashCode, duplicate.hashCode);

      final different = tProfile.copyWith(firstName: 'Jane');
      expect(tProfile == different, isFalse);
    });
  });

  group('UserProfileModel Tests', () {
    final tDate = DateTime(2026, 6, 1);

    test('fromMap parses safely', () {
      final map = {
        'uid': 'user_1',
        'firstName': 'Assaf',
        'lastName': 'Benzaken',
        'email': 'assaf@plainsight.il',
        'role': 'user',
        'createdAt': Timestamp.fromDate(tDate),
        'updatedAt': Timestamp.fromDate(tDate),
      };
      final model = UserProfileModel.fromMap(map);
      expect(model.uid, 'user_1');
      expect(model.firstName, 'Assaf');
      expect(model.createdAt, tDate);
    });

    test('_parseDateTime covers other data formats', () {
      // 1. Null
      final mapNull = {'uid': 'user_1', 'createdAt': null};
      final modelNull = UserProfileModel.fromMap(mapNull);
      expect(modelNull.createdAt, isNotNull);

      // 2. ISO 8601 String
      final mapStr = {'uid': 'user_1', 'createdAt': '2026-06-01T12:00:00.000Z'};
      final modelStr = UserProfileModel.fromMap(mapStr);
      expect(modelStr.createdAt.year, 2026);

      // 2b. Invalid String
      final mapStrInv = {'uid': 'user_1', 'createdAt': 'invalid-date-string'};
      final modelStrInv = UserProfileModel.fromMap(mapStrInv);
      expect(modelStrInv.createdAt, isNotNull);

      // 3. Milliseconds Int
      final mapMs = {'uid': 'user_1', 'createdAt': 1779840000000};
      final modelMs = UserProfileModel.fromMap(mapMs);
      expect(modelMs.createdAt.year, 2026);

      // 4. Seconds Int (length 10)
      final mapSec = {'uid': 'user_1', 'createdAt': 1779840000};
      final modelSec = UserProfileModel.fromMap(mapSec);
      expect(modelSec.createdAt.year, 2026);

      // 5. Invalid type (e.g. double)
      final mapDouble = {'uid': 'user_1', 'createdAt': 123.456};
      final modelDouble = UserProfileModel.fromMap(mapDouble);
      expect(modelDouble.createdAt, isNotNull);
    });

    test('toMap serializes properly', () {
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: tDate,
        updatedAt: tDate,
      );
      final map = model.toMap();
      expect(map['uid'], 'user_1');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), tDate);
    });

    test('fromEntity converts correctly', () {
      final entity = UserProfile(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: tDate,
        updatedAt: tDate,
      );
      final model = UserProfileModel.fromEntity(entity);
      expect(model.uid, entity.uid);
      expect(model.firstName, entity.firstName);
    });
  });

  group('UserProfileRepositoryImpl Tests', () {
    late FakeUserProfileRemoteDataSource mockDataSource;
    late UserProfileRepositoryImpl repository;

    setUp(() {
      mockDataSource = FakeUserProfileRemoteDataSource();
      repository = UserProfileRepositoryImpl(mockDataSource);
    });

    test('getUserProfile streams from datasource', () async {
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final futureProfile = repository.getUserProfile('user_1').first;
      mockDataSource.controller.add(model);
      final result = await futureProfile;

      expect(result, model);
    });

    test('updateUserProfile calls datasource', () async {
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.updateUserProfile(model);
      expect(mockDataSource.lastUpdatedModel, model);
    });
  });

  group('UserProfileRemoteDataSourceImpl Tests', () {
    final tDate = DateTime(2026, 6, 1);
    final mapData = {
      'uid': 'user_1',
      'firstName': 'Assaf',
      'lastName': 'Benzaken',
      'email': 'assaf@plainsight.il',
      'role': 'user',
      'createdAt': Timestamp.fromDate(tDate),
      'updatedAt': Timestamp.fromDate(tDate),
    };

    test('getUserProfile emits parsed profile on success', () async {
      final fakeDoc = FakeDocumentReference(true, mapData);
      final fakeCol = FakeCollectionReference((path) {
        expect(path, 'user_1');
        return fakeDoc;
      });
      final fakeFirestore = FakeFirebaseFirestore((path) {
        expect(path, 'users');
        return fakeCol;
      });

      final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
      final result = await dataSource.getUserProfile('user_1').first;

      expect(result, isNotNull);
      expect(result?.uid, 'user_1');
      expect(result?.firstName, 'Assaf');
    });

    test('getUserProfile emits null if doc does not exist', () async {
      final fakeDoc = FakeDocumentReference(false, null);
      final fakeCol = FakeCollectionReference((path) => fakeDoc);
      final fakeFirestore = FakeFirebaseFirestore((path) => fakeCol);

      final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
      final result = await dataSource.getUserProfile('user_1').first;

      expect(result, isNull);
    });

    test(
      'getUserProfile handles stream errors by throwing ServerException',
      () async {
        final streamController =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final fakeDoc = FakeDocumentReference(
          true,
          null,
          stream: streamController.stream,
        );
        final fakeCol = FakeCollectionReference((path) => fakeDoc);
        final fakeFirestore = FakeFirebaseFirestore((path) => fakeCol);

        final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
        final stream = dataSource.getUserProfile('user_1');

        final done = Completer<void>();
        stream.listen(
          (_) {},
          onError: (Object err) {
            expect(err, isA<ServerException>());
            done.complete();
          },
        );

        streamController.addError('Firestore error');
        await done.future;
        await streamController.close();
      },
    );

    test('updateUserProfile calls update if doc exists', () async {
      var updateCalled = false;
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: tDate,
        updatedAt: tDate,
      );

      final fakeDoc = FakeDocumentReference(
        true,
        mapData,
        onUpdate: (data) {
          updateCalled = true;
          expect(data['firstName'], 'Assaf');
          expect(data['lastName'], 'Benzaken');
          expect(data['updatedAt'], isA<FieldValue>());
        },
      );
      final fakeCol = FakeCollectionReference((path) => fakeDoc);
      final fakeFirestore = FakeFirebaseFirestore((path) => fakeCol);

      final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
      await dataSource.updateUserProfile(model);

      expect(updateCalled, isTrue);
    });

    test('updateUserProfile calls set if doc does not exist', () async {
      var setCalled = false;
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: tDate,
        updatedAt: tDate,
      );

      final fakeDoc = FakeDocumentReference(
        false,
        null,
        onSet: (data) {
          setCalled = true;
          expect(data['uid'], 'user_1');
          expect(data['firstName'], 'Assaf');
          expect(data['lastName'], 'Benzaken');
          expect(data['email'], 'assaf@plainsight.il');
          expect(data['role'], 'user');
          expect(data['createdAt'], isA<FieldValue>());
          expect(data['updatedAt'], isA<FieldValue>());
        },
      );
      final fakeCol = FakeCollectionReference((path) => fakeDoc);
      final fakeFirestore = FakeFirebaseFirestore((path) => fakeCol);

      final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
      await dataSource.updateUserProfile(model);

      expect(setCalled, isTrue);
    });

    test('updateUserProfile throws ServerException on failure', () async {
      final model = UserProfileModel(
        uid: 'user_1',
        firstName: 'Assaf',
        lastName: 'Benzaken',
        email: 'assaf@plainsight.il',
        role: 'user',
        createdAt: tDate,
        updatedAt: tDate,
      );

      // docRef.get() throws an exception
      final fakeFirestore = FakeFirebaseFirestore((path) {
        throw Exception('Connection failed');
      });

      final dataSource = UserProfileRemoteDataSourceImpl(fakeFirestore);
      expect(
        () => dataSource.updateUserProfile(model),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
