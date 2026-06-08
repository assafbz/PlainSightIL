import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/data/models/user_profile_model.dart';

void main() {
  group('UserProfileModel Tests', () {
    final tDate = DateTime(2026, 6, 1);

    test('fromMap parses safely', () {
      final map = {
        'uid': 'user_1',
        'firstName': 'Assaf',
        'lastName': 'Benzaken',
        'email': 'assaf@plainsight.il',
        'role': 'user',
        'isSubscribed': true,
        'createdAt': Timestamp.fromDate(tDate),
        'updatedAt': Timestamp.fromDate(tDate),
      };
      final model = UserProfileModel.fromMap(map);
      expect(model.uid, 'user_1');
      expect(model.firstName, 'Assaf');
      expect(model.isSubscribed, isTrue);
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
        isSubscribed: true,
        createdAt: tDate,
        updatedAt: tDate,
      );
      final map = model.toMap();
      expect(map['uid'], 'user_1');
      expect(map['isSubscribed'], isTrue);
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
        isSubscribed: true,
        createdAt: tDate,
        updatedAt: tDate,
      );
      final model = UserProfileModel.fromEntity(entity);
      expect(model.uid, entity.uid);
      expect(model.firstName, entity.firstName);
      expect(model.isSubscribed, isTrue);
    });
  });
}
