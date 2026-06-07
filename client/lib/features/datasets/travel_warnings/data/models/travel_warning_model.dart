/// Model representing a travel warning record row in the Firestore database.
class TravelWarningRecordModel {
  /// Unique document ID (string representation of the datastore _id)
  final String id;

  /// Numeric identifier corresponding to the datastore primary key (_id)
  final int idNum;

  /// Continent name in Hebrew
  final String continent;

  /// Country name in Hebrew
  final String country;

  /// Recommendations text or HTML link
  final String recommendations;

  /// Details link or text description
  final String details;

  /// HTML img tag and text for publisher logo
  final String logo;

  /// Registration/update date of the warning (optional ISO-8601 string)
  final String? date;

  /// Mapped office/ministry in Hebrew
  final String office;

  /// Numeric risk threat warning level (1 to 4)
  final int warningLevel;

  /// Ingestion timestamp (optional ISO-8601 string)
  final String? createdAt;

  /// Firestore database modification timestamp (optional ISO-8601 string)
  final String? updatedAt;

  /// Source creation timestamp (optional ISO-8601 string)
  final String? sourceCreatedAt;

  /// Source modification timestamp (optional ISO-8601 string)
  final String? sourceUpdatedAt;

  /// Source metadata modification timestamp (optional ISO-8601 string) - Legacy backward compatibility
  final String? lastUpdated;

  /// Constructor initializing all fields
  TravelWarningRecordModel({
    required this.id,
    required this.idNum,
    required this.continent,
    required this.country,
    required this.recommendations,
    required this.details,
    required this.logo,
    this.date,
    required this.office,
    required this.warningLevel,
    this.createdAt,
    this.updatedAt,
    this.sourceCreatedAt,
    this.sourceUpdatedAt,
    this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory TravelWarningRecordModel.fromMap(Map<String, dynamic> map) {
    return TravelWarningRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      continent: map['continent'] as String? ?? '',
      country: map['country'] as String? ?? '',
      recommendations: map['recommendations'] as String? ?? '',
      details: map['details'] as String? ?? '',
      logo: map['logo'] as String? ?? '',
      date: map['date'] as String?,
      office: map['office'] as String? ?? '',
      warningLevel: (map['warningLevel'] as num? ?? 1).toInt(),
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      sourceCreatedAt:
          map['sourceCreatedAt'] as String? ?? map['lastUpdated'] as String?,
      sourceUpdatedAt:
          map['sourceUpdatedAt'] as String? ?? map['lastUpdated'] as String?,
      lastUpdated:
          map['sourceUpdatedAt'] as String? ?? map['lastUpdated'] as String?,
    );
  }

  /// Converts the model instance into a map structure suitable for Firestore writes or testing.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': idNum,
      'continent': continent,
      'country': country,
      'recommendations': recommendations,
      'details': details,
      'logo': logo,
      'date': date,
      'office': office,
      'warningLevel': warningLevel,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceCreatedAt': sourceCreatedAt,
      'sourceUpdatedAt': sourceUpdatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
