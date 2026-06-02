import '../entities/user_profile.dart';

/// Repository interface contract for retrieving and updating user profiles.
abstract class UserProfileRepository {
  /// Stream that emits the user profile updates for the given [uid].
  Stream<UserProfile?> getUserProfile(String uid);

  /// Updates the user profile document in the remote store.
  Future<void> updateUserProfile(UserProfile profile);
}
