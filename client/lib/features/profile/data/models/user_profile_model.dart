import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_profile.dart';

/// Data model representing the user profile with JSON serialization capabilities.
class UserProfileModel extends UserProfile {
  /// Creates a new [UserProfileModel] instance.
  const UserProfileModel({
    required super.uid,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.role,
    super.isSubscribed = false,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Helper to safely parse a field into a [DateTime].
  /// Supports [Timestamp], ISO-8601 [String], and milliseconds/seconds [int].
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) {
      if (value.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  /// Deserializes a [Map] retrieved from Firestore into a [UserProfileModel].
  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      uid: map['uid'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      isSubscribed: map['isSubscribed'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  /// Serializes this [UserProfileModel] to a [Map] representation.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role,
      'isSubscribed': isSubscribed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a [UserProfileModel] instance from a [UserProfile] domain entity.
  factory UserProfileModel.fromEntity(UserProfile entity) {
    return UserProfileModel(
      uid: entity.uid,
      firstName: entity.firstName,
      lastName: entity.lastName,
      email: entity.email,
      role: entity.role,
      isSubscribed: entity.isSubscribed,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
