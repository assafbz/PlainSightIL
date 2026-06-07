/// Data model representing a vehicle recall record from the Israeli
/// Ministry of Transport's vehicle recalls dataset.
///
/// Maps to Firestore documents in the `2c33523f-87aa-44ec-a736-edbb0a82975e`
/// collection, containing manufacturer info, defect details, and repair actions.
class VehicleRecallRecordModel {
  /// Unique document identifier in Firestore.
  final String id;

  /// Numeric identifier from the source CKAN dataset (`_id` field).
  final int idNum;

  /// Ministry-assigned recall campaign identifier.
  final int recallId;

  /// Numeric code identifying the vehicle manufacturer.
  final int manufacturerCode;

  /// Display name of the vehicle manufacturer (Hebrew).
  final String manufacturerName;

  /// Vehicle model name affected by this recall.
  final String modelName;

  /// Model year of vehicles affected by this recall.
  final int recallYear;

  /// Start date of the affected vehicle build range (ISO 8601 string).
  final String buildStartDate;

  /// End date of the affected vehicle build range (ISO 8601 string).
  final String buildEndDate;

  /// Bilingual recall type label (`{'he': '...', 'en': '...'}`).
  final Map<String, String> recallType;

  /// Category of the defect (e.g., brakes, engine, electrical).
  final String defectCategory;

  /// Detailed description of the safety defect (Hebrew).
  final String defectDescription;

  /// Description of the required repair action (Hebrew).
  final String repairAction;

  /// EU vehicle category classification (e.g., M1, N1).
  final String euCategory;

  /// Name of the authorized importer responsible for the recall.
  final String importerName;

  /// Contact phone number for the importer.
  final String importerPhone;

  /// Website URL of the importer.
  final String importerWebsite;

  /// ISO 8601 timestamp of when the record was first created in Firestore.
  final String? createdAt;

  /// ISO 8601 timestamp of when the record was last modified by the scraper.
  final String? updatedAt;

  /// Source creation timestamp (optional ISO-8601 string)
  final String? sourceCreatedAt;

  /// Source modification timestamp (optional ISO-8601 string)
  final String? sourceUpdatedAt;

  /// ISO 8601 timestamp of the last successful sync operation.
  final String? lastUpdated;

  /// Creates a [VehicleRecallRecordModel] with all required recall fields.
  VehicleRecallRecordModel({
    required this.id,
    required this.idNum,
    required this.recallId,
    required this.manufacturerCode,
    required this.manufacturerName,
    required this.modelName,
    required this.recallYear,
    required this.buildStartDate,
    required this.buildEndDate,
    required this.recallType,
    required this.defectCategory,
    required this.defectDescription,
    required this.repairAction,
    required this.euCategory,
    required this.importerName,
    required this.importerPhone,
    required this.importerWebsite,
    this.createdAt,
    this.updatedAt,
    this.sourceCreatedAt,
    this.sourceUpdatedAt,
    this.lastUpdated,
  });

  /// Deserializes a Firestore document map into a [VehicleRecallRecordModel].
  ///
  /// Safely handles null, missing, and mistyped fields with sensible defaults.
  factory VehicleRecallRecordModel.fromMap(Map<String, dynamic> map) {
    Map<String, String> typeMap = {
      'he': 'תקלה סידרתית בטיחותית',
      'en': 'Safety Recall',
    };
    final rawType = map['recallType'];
    if (rawType is Map) {
      typeMap = {
        'he': rawType['he'] as String? ?? 'תקלה סידרתית בטיחותית',
        'en': rawType['en'] as String? ?? 'Safety Recall',
      };
    }

    return VehicleRecallRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      recallId: (map['recallId'] as num? ?? 0).toInt(),
      manufacturerCode: (map['manufacturerCode'] as num? ?? 0).toInt(),
      manufacturerName: map['manufacturerName'] as String? ?? '',
      modelName: map['modelName'] as String? ?? '',
      recallYear: (map['recallYear'] as num? ?? 0).toInt(),
      buildStartDate: map['buildStartDate'] as String? ?? '',
      buildEndDate: map['buildEndDate'] as String? ?? '',
      recallType: typeMap,
      defectCategory: map['defectCategory'] as String? ?? '',
      defectDescription: map['defectDescription'] as String? ?? '',
      repairAction: map['repairAction'] as String? ?? '',
      euCategory: map['euCategory'] as String? ?? '',
      importerName: map['importerName'] as String? ?? '',
      importerPhone: map['importerPhone'] as String? ?? '',
      importerWebsite: map['importerWebsite'] as String? ?? '',
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

  /// Serializes this model back into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': idNum,
      'recallId': recallId,
      'manufacturerCode': manufacturerCode,
      'manufacturerName': manufacturerName,
      'modelName': modelName,
      'recallYear': recallYear,
      'buildStartDate': buildStartDate,
      'buildEndDate': buildEndDate,
      'recallType': recallType,
      'defectCategory': defectCategory,
      'defectDescription': defectDescription,
      'repairAction': repairAction,
      'euCategory': euCategory,
      'importerName': importerName,
      'importerPhone': importerPhone,
      'importerWebsite': importerWebsite,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceCreatedAt': sourceCreatedAt,
      'sourceUpdatedAt': sourceUpdatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
