import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';

void main() {
  group('UserProfile Entity Tests', () {
    final tProfile = UserProfile(
      uid: 'user_1',
      firstName: 'Assaf',
      lastName: 'Benzaken',
      email: 'assaf@plainsight.il',
      role: 'user',
      isSubscribed: false,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

    test('copyWith works correctly', () {
      final updated = tProfile.copyWith(
        firstName: 'John',
        role: 'admin',
        isSubscribed: true,
      );
      expect(updated.firstName, 'John');
      expect(updated.role, 'admin');
      expect(updated.isSubscribed, isTrue);
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
        isSubscribed: false,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      expect(tProfile, duplicate);
      expect(tProfile.hashCode, duplicate.hashCode);

      final different = tProfile.copyWith(firstName: 'Jane');
      expect(tProfile == different, isFalse);
    });
  });
}
