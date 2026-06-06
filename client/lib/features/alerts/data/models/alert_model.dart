/// Model class representing a user in-app alert.
class AlertModel {
  /// Unique identifier of the alert document.
  final String id;

  /// UID of the target user.
  final String userId;

  /// Type of notification: 'new_dataset', 'new_government_dataset', or 'new_records'.
  final String type;

  /// Localized title map (e.g. {'en': '...', 'he': '...'}).
  final Map<String, String> title;

  /// Localized description map (e.g. {'en': '...', 'he': '...'}).
  final Map<String, String> description;

  /// Referenced dataset identifier, if applicable.
  final String? datasetId;

  /// Number of newly ingested records, if applicable.
  final int? recordCount;

  /// Flag indicating whether the user has read the alert.
  final bool isRead;

  /// Timestamp of alert creation.
  final DateTime createdAt;

  /// Constructs an [AlertModel] instance.
  AlertModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.datasetId,
    this.recordCount,
    required this.isRead,
    required this.createdAt,
  });

  /// Factory method to construct an [AlertModel] from a Firestore document map.
  factory AlertModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    if (map['createdAt'] != null) {
      try {
        parsedDate = DateTime.parse(map['createdAt'] as String);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    final rawTitle = map['title'] as Map? ?? {};
    final titleMap = rawTitle.map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );

    final rawDesc = map['description'] as Map? ?? {};
    final descMap = rawDesc.map((k, v) => MapEntry(k.toString(), v.toString()));

    return AlertModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      title: titleMap,
      description: descMap,
      datasetId: map['datasetId'] as String?,
      recordCount: map['recordCount'] as int?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parsedDate,
    );
  }

  /// Converts the [AlertModel] instance into a map structure for serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'description': description,
      'datasetId': datasetId,
      'recordCount': recordCount,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
