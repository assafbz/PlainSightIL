// ignore_for_file: subtype_of_sealed_class, depend_on_referenced_packages, prefer_initializing_formals, unnecessary_non_null_assertion
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/core/errors/exceptions.dart';
import 'package:plainsight/features/profile/data/models/user_profile_model.dart';
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
  final void Function(Map<String, dynamic>)? onUpdate;
  final void Function(Map<String, dynamic>)? onSet;
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

void main() {
  group('UserProfileRemoteDataSourceImpl Tests', () {
    final tDate = DateTime(2026, 6, 1);
    final mapData = {
      'uid': 'user_1',
      'firstName': 'Assaf',
      'lastName': 'Benzaken',
      'email': 'assaf@plainsight.il',
      'role': 'user',
      'isSubscribed': true,
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
      expect(result?.isSubscribed, isTrue);
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
        isSubscribed: true,
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
          expect(data['isSubscribed'], isTrue);
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
        isSubscribed: true,
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
          expect(data['isSubscribed'], isTrue);
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
        isSubscribed: true,
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
