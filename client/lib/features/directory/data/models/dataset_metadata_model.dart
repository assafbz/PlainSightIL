class DatasetMetadataModel {
  final String id;
  final String datasetId;
  final String name;
  final String title;
  final String notes;
  final String publisher;
  final int resourceCount;
  final DateTime lastUpdated;
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
    required this.lastUpdated,
    required this.tags,
    required this.isSupported,
  });

  factory DatasetMetadataModel.fromMap(Map<String, dynamic> map) {
    // Parse lastUpdated safely, supporting both String ISO dates and Firestore Timestamps
    DateTime parsedDate = DateTime.now();
    final rawDate = map['lastUpdated'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) parsedDate = parsed;
    } else if (rawDate != null && rawDate.toString().contains('Timestamp')) {
      // Handles potential Timestamp structure
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {}
    }

    return DatasetMetadataModel(
      id: map['id'] as String? ?? '',
      datasetId: map['datasetId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      title: map['title'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      publisher: map['publisher'] as String? ?? 'לא ידוע',
      resourceCount: (map['resourceCount'] as num? ?? 0).toInt(),
      lastUpdated: parsedDate,
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
      'lastUpdated': lastUpdated.toIso8601String(),
      'tags': tags,
      'isSupported': isSupported,
    };
  }
}
