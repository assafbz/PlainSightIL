import 'package:flutter/foundation.dart';

/// Represents a user profile in the system.
///
/// Contains basic identification, personal details, roles, and timestamps.
@immutable
class UserProfile {
  /// Unique identifier of the user (matching Firebase Auth uid).
  final String uid;

  /// User's first name.
  final String firstName;

  /// User's last name.
  final String lastName;

  /// User's email address.
  final String email;

  /// User's authorization role (e.g. 'user', 'admin').
  final String role;

  /// Whether the user has an active paid subscription.
  final bool isSubscribed;

  /// Timestamp when the user profile was created.
  final DateTime createdAt;

  /// Timestamp when the user profile was last updated.
  final DateTime updatedAt;

  /// Creates a new [UserProfile] instance.
  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.isSubscribed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this [UserProfile] with the given fields replaced by new values.
  UserProfile copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    bool? isSubscribed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.uid == uid &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.email == email &&
        other.role == role &&
        other.isSubscribed == isSubscribed &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      firstName,
      lastName,
      email,
      role,
      isSubscribed,
      createdAt,
      updatedAt,
    );
  }
}
