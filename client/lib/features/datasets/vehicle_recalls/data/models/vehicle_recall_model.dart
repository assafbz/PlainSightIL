class VehicleRecallRecordModel {
  final String id;
  final int idNum;
  final int recallId;
  final int manufacturerCode;
  final String manufacturerName;
  final String modelName;
  final int recallYear;
  final String buildStartDate;
  final String buildEndDate;
  final Map<String, String> recallType;
  final String defectCategory;
  final String defectDescription;
  final String repairAction;
  final String euCategory;
  final String importerName;
  final String importerPhone;
  final String importerWebsite;
  final String? createdAt;
  final String? updatedAt;
  final String? lastUpdated;

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
    this.lastUpdated,
  });

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
      lastUpdated: map['lastUpdated'] as String?,
    );
  }

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
      'lastUpdated': lastUpdated,
    };
  }
}
