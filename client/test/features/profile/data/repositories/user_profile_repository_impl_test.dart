import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/profile/domain/entities/user_profile.dart';
import 'package:plainsight/features/profile/data/models/user_profile_model.dart';
import 'package:plainsight/features/profile/data/datasources/user_profile_remote_datasource.dart';
import 'package:plainsight/features/profile/data/repositories/user_profile_repository_impl.dart';

class MockUserProfileRemoteDataSource implements UserProfileRemoteDataSource {
  UserProfileModel? getProfileResult;
  String? getProfileUidCalled;
  UserProfileModel? updateProfileModelCalled;
  bool updateProfileCalled = false;

  @override
  Stream<UserProfileModel?> getUserProfile(String uid) {
    getProfileUidCalled = uid;
    return Stream.value(getProfileResult);
  }

  @override
  Future<void> updateUserProfile(UserProfileModel model) async {
    updateProfileModelCalled = model;
    updateProfileCalled = true;
  }
}

void main() {
  group('UserProfileRepositoryImpl Tests', () {
    final tDate = DateTime(2026, 6, 1);
    late MockUserProfileRemoteDataSource mockDataSource;
    late UserProfileRepositoryImpl repository;

    setUp(() {
      mockDataSource = MockUserProfileRemoteDataSource();
      repository = UserProfileRepositoryImpl(mockDataSource);
    });

    test(
      'getUserProfile calls remote data source and returns stream of profiles',
      () async {
        final tModel = UserProfileModel(
          uid: 'user_123',
          firstName: 'Assaf',
          lastName: 'Benzaken',
          email: 'assaf@plainsight.il',
          role: 'user',
          isSubscribed: true,
          createdAt: tDate,
          updatedAt: tDate,
        );
        mockDataSource.getProfileResult = tModel;

        final resultStream = repository.getUserProfile('user_123');
        final result = await resultStream.first;

        expect(mockDataSource.getProfileUidCalled, 'user_123');
        expect(result, isNotNull);
        expect(result?.uid, 'user_123');
        expect(result?.firstName, 'Assaf');
        expect(result?.isSubscribed, isTrue);
      },
    );

    test(
      'updateUserProfile calls remote data source with mapped model',
      () async {
        final tProfile = UserProfile(
          uid: 'user_123',
          firstName: 'Assaf',
          lastName: 'Benzaken',
          email: 'assaf@plainsight.il',
          role: 'user',
          isSubscribed: true,
          createdAt: tDate,
          updatedAt: tDate,
        );

        await repository.updateUserProfile(tProfile);

        expect(mockDataSource.updateProfileCalled, isTrue);
        expect(mockDataSource.updateProfileModelCalled?.uid, 'user_123');
        expect(mockDataSource.updateProfileModelCalled?.firstName, 'Assaf');
        expect(mockDataSource.updateProfileModelCalled?.isSubscribed, isTrue);
      },
    );
  });
}
