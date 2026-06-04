/// Model representing a patent classification record row in the Firestore database.
class PatentClassificationRecordModel {
  /// Unique document ID (string representation of the datastore _id)
  final String id;

  /// Numeric identifier corresponding to the datastore primary key (_id)
  final int idNum;

  /// Patent application number
  final int applicationNumber;

  /// Title of invention in Hebrew
  final String titleHebrew;

  /// Title of invention in English
  final String titleEnglish;

  /// CPC classification code
  final String cpcClassification;

  /// Indicates if the classification is primary
  final bool isPrimary;

  /// Ingestion timestamp (optional ISO-8601 string)
  final String? createdAt;

  /// Firestore database modification timestamp (optional ISO-8601 string)
  final String? updatedAt;

  /// Source metadata modification timestamp (optional ISO-8601 string)
  final String? lastUpdated;

  /// Constructor
  PatentClassificationRecordModel({
    required this.id,
    required this.idNum,
    required this.applicationNumber,
    required this.titleHebrew,
    required this.titleEnglish,
    required this.cpcClassification,
    required this.isPrimary,
    this.createdAt,
    this.updatedAt,
    this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory PatentClassificationRecordModel.fromMap(Map<String, dynamic> map) {
    return PatentClassificationRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      applicationNumber: (map['applicationNumber'] as num? ?? 0).toInt(),
      titleHebrew: map['titleHebrew'] as String? ?? '',
      titleEnglish: map['titleEnglish'] as String? ?? '',
      cpcClassification: map['cpcClassification'] as String? ?? '',
      isPrimary: map['isPrimary'] as bool? ?? false,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      lastUpdated: map['lastUpdated'] as String?,
    );
  }

  /// Converts the model instance into a map structure suitable for Firestore writes or testing.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': idNum,
      'applicationNumber': applicationNumber,
      'titleHebrew': titleHebrew,
      'titleEnglish': titleEnglish,
      'cpcClassification': cpcClassification,
      'isPrimary': isPrimary,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
