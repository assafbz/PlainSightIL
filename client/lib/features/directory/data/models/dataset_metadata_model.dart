class DatasetMetadataModel {
  final String id;
  final String datasetId;
  final String name;
  final String title;
  final String notes;
  final String publisher;
  final int resourceCount;
  final DateTime sourceCreatedAt;
  final DateTime sourceUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastUpdated; // Legacy backward compatibility
  final List<String> tags;
  final bool isSupported;

  DatasetMetadataModel({
    required this.id,
    required this.datasetId,
    required this.name,
    required this.title,
    required this.notes,
    required this.publisher,
    required this.resourceCount,
    required this.sourceCreatedAt,
    required this.sourceUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUpdated,
    required this.tags,
    required this.isSupported,
  });

  factory DatasetMetadataModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic rawDate) {
      if (rawDate is String) {
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null) return parsed;
      } else if (rawDate != null && rawDate.toString().contains('Timestamp')) {
        try {
          return (rawDate as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      return DateTime.now();
    }

    final sourceCreatedAt = parseDate(
      map['sourceCreatedAt'] ?? map['lastUpdated'],
    );
    final sourceUpdatedAt = parseDate(
      map['sourceUpdatedAt'] ?? map['lastUpdated'],
    );
    final createdAt = parseDate(map['createdAt'] ?? map['lastUpdated']);
    final updatedAt = parseDate(map['updatedAt'] ?? map['lastUpdated']);
    final lastUpdated = sourceUpdatedAt;

    return DatasetMetadataModel(
      id: map['id'] as String? ?? '',
      datasetId: map['datasetId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      title: map['title'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      publisher: map['publisher'] as String? ?? 'לא ידוע',
      resourceCount: (map['resourceCount'] as num? ?? 0).toInt(),
      sourceCreatedAt: sourceCreatedAt,
      sourceUpdatedAt: sourceUpdatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUpdated: lastUpdated,
      tags: List<String>.from((map['tags'] as Iterable?) ?? []),
      isSupported: map['isSupported'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'datasetId': datasetId,
      'name': name,
      'title': title,
      'notes': notes,
      'publisher': publisher,
      'resourceCount': resourceCount,
      'sourceCreatedAt': sourceCreatedAt.toIso8601String(),
      'sourceUpdatedAt': sourceUpdatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'tags': tags,
      'isSupported': isSupported,
    };
  }
}
