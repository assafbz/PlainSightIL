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

  /// Source metadata modification timestamp (optional ISO-8601 string)
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
    this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory CarImporterRecordModel.fromMap(Map<String, dynamic> map) {
    return CarImporterRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      importerCode: map['importerCode'] != null
          ? (map['importerCode'] as num).toInt()
          : null,
      importerName: map['importerName'] as String? ?? '',
      modelType: map['modelType'] as String? ?? '',
      makerCode: map['makerCode'] != null
          ? (map['makerCode'] as num).toInt()
          : null,
      makerName: map['makerName'] as String? ?? '',
      modelCode: map['modelCode'] != null
          ? (map['modelCode'] as num).toInt()
          : null,
      modelName: map['modelName'] as String? ?? '',
      productionYear: map['productionYear'] != null
          ? (map['productionYear'] as num).toInt()
          : null,
      price: map['price'] != null ? (map['price'] as num).toInt() : null,
      commercialName: map['commercialName'] as String? ?? '',
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
      'lastUpdated': lastUpdated,
    };
  }
}
