import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_remote_datasource.dart';
import '../models/user_profile_model.dart';

/// Implementation of [UserProfileRepository] delegating to remote datasource.
class UserProfileRepositoryImpl implements UserProfileRepository {
  /// The remote data source.
  final UserProfileRemoteDataSource remoteDataSource;

  /// Creates a [UserProfileRepositoryImpl] instance.
  UserProfileRepositoryImpl(this.remoteDataSource);

  @override
  Stream<UserProfile?> getUserProfile(String uid) {
    return remoteDataSource.getUserProfile(uid);
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) {
    final model = UserProfileModel.fromEntity(profile);
    return remoteDataSource.updateUserProfile(model);
  }
}
