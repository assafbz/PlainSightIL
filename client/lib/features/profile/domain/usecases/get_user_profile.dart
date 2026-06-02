import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

/// Usecase to retrieve or stream user profile documents.
class GetUserProfile {
  /// The user profile repository.
  final UserProfileRepository repository;

  /// Creates a [GetUserProfile] usecase.
  GetUserProfile(this.repository);

  /// Executes the usecase to retrieve a user profile stream.
  Stream<UserProfile?> call(String uid) {
    return repository.getUserProfile(uid);
  }
}
