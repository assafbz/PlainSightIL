/// Model representing a car importer price list record row in the Firestore database.
class CarImporterRecordModel {
  /// Unique document ID (string representation of the datastore _id)
  final String id;

  /// Numeric identifier corresponding to the datastore primary key (_id)
  final int idNum;

  /// Importer code (semel_yevuan)
  final int? importerCode;

  /// Importer name (shem_yevuan)
  final String importerName;

  /// Model type/class (sug_degem)
  final String modelType;

  /// Maker code (tozeret_cd)
  final int? makerCode;

  /// Maker name (tozeret_nm)
  final String makerName;

  /// Model code (degem_cd)
  final int? modelCode;

  /// Model name (degem_nm)
  final String modelName;

  /// Production year (shnat_yitzur)
  final int? productionYear;

  /// Price (mehir)
  final int? price;

  /// Commercial name (kinuy_mishari)
  final String commercialName;

  /// Ingestion timestamp (optional ISO-8601 string)
  final String? createdAt;

  /// Firestore database modification timestamp (optional ISO-8601 string)
  final String? updatedAt;

  /// Source creation timestamp (optional ISO-8601 string)
  final String? sourceCreatedAt;

  /// Source modification timestamp (optional ISO-8601 string)
  final String? sourceUpdatedAt;

  /// Legacy backward compatibility
  final String? lastUpdated;

  /// Constructor initializing all fields
  CarImporterRecordModel({
    required this.id,
    required this.idNum,
    this.importerCode,
    required this.importerName,
    required this.modelType,
    this.makerCode,
    required this.makerName,
    this.modelCode,
    required this.modelName,
    this.productionYear,
    this.price,
    required this.commercialName,
    this.createdAt,
    this.updatedAt,
    this.sourceCreatedAt,
    this.sourceUpdatedAt,
    this.lastUpdated,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory CarImporterRecordModel.fromMap(Map<String, dynamic> map) {
    return CarImporterRecordModel(
      id: map['id']?.toString() ?? '',
      idNum: _parseInt(map['_id']) ?? 0,
      importerCode: _parseInt(map['importerCode']),
      importerName: map['importerName']?.toString() ?? '',
      modelType: map['modelType']?.toString() ?? '',
      makerCode: _parseInt(map['makerCode']),
      makerName: map['makerName']?.toString() ?? '',
      modelCode: _parseInt(map['modelCode']),
      modelName: map['modelName']?.toString() ?? '',
      productionYear: _parseInt(map['productionYear']),
      price: _parseInt(map['price']),
      commercialName: map['commercialName']?.toString() ?? '',
      createdAt: map['createdAt']?.toString(),
      updatedAt: map['updatedAt']?.toString(),
      sourceCreatedAt:
          map['sourceCreatedAt']?.toString() ?? map['lastUpdated']?.toString(),
      sourceUpdatedAt:
          map['sourceUpdatedAt']?.toString() ?? map['lastUpdated']?.toString(),
      lastUpdated:
          map['sourceUpdatedAt']?.toString() ?? map['lastUpdated']?.toString(),
    );
  }

  /// Converts the model instance into a map structure suitable for Firestore writes or testing.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': idNum,
      'importerCode': importerCode,
      'importerName': importerName,
      'modelType': modelType,
      'makerCode': makerCode,
      'makerName': makerName,
      'modelCode': modelCode,
      'modelName': modelName,
      'productionYear': productionYear,
      'price': price,
      'commercialName': commercialName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceCreatedAt': sourceCreatedAt,
      'sourceUpdatedAt': sourceUpdatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
