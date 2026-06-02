import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

/// Usecase to update user profile documents.
class UpdateUserProfile {
  /// The user profile repository.
  final UserProfileRepository repository;

  /// Creates a [UpdateUserProfile] usecase.
  UpdateUserProfile(this.repository);

  /// Executes the usecase to update a user profile.
  Future<void> call(UserProfile profile) {
    return repository.updateUserProfile(profile);
  }
}
