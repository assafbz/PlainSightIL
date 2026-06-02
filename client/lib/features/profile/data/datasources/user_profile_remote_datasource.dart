import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';

/// Data source interface for fetching and updating profile documents in Cloud Firestore.
abstract class UserProfileRemoteDataSource {
  /// Streams user profile data from Firestore for [uid].
  Stream<UserProfileModel?> getUserProfile(String uid);

  /// Updates user profile data in Firestore.
  Future<void> updateUserProfile(UserProfileModel model);
}

/// Firestore remote data source implementation.
class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  /// Reference to the Firestore database.
  final FirebaseFirestore firestore;

  /// Creates a [UserProfileRemoteDataSourceImpl] instance.
  UserProfileRemoteDataSourceImpl(this.firestore);

  @override
  Stream<UserProfileModel?> getUserProfile(String uid) {
    return firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserProfileModel.fromMap(doc.data()!);
    });
  }

  @override
  Future<void> updateUserProfile(UserProfileModel model) async {
    final docRef = firestore.collection('users').doc(model.uid);
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      final Map<String, dynamic> updateData = {
        'firstName': model.firstName,
        'lastName': model.lastName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.update(updateData);
    } else {
      final Map<String, dynamic> setData = {
        'uid': model.uid,
        'firstName': model.firstName,
        'lastName': model.lastName,
        'email': model.email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(setData);
    }
  }
}
