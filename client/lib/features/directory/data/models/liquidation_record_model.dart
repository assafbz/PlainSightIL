class LiquidationRecordModel {
  final int liquidationCaseId;
  final String cityOfActivity;
  final Map<String, String> caseStatus;
  final String submissionDate;
  final String liquidationOrderDate;
  final String? cancellationFreezeDate;
  final String? closureDate;
  final String? closureReason;
  final String districtCourt;
  final String companyName;
  final int companyId;

  LiquidationRecordModel({
    required this.liquidationCaseId,
    required this.cityOfActivity,
    required this.caseStatus,
    required this.submissionDate,
    required this.liquidationOrderDate,
    this.cancellationFreezeDate,
    this.closureDate,
    this.closureReason,
    required this.districtCourt,
    required this.companyName,
    required this.companyId,
  });

  factory LiquidationRecordModel.fromMap(Map<String, dynamic> map) {
    Map<String, String> statusMap = {
      'he': 'פירוק פעיל',
      'en': 'Active Winding Up',
    };
    final rawStatus = map['caseStatus'];
    if (rawStatus is Map) {
      statusMap = {
        'he': rawStatus['he'] as String? ?? 'פירוק פעיל',
        'en': rawStatus['en'] as String? ?? 'Active Winding Up',
      };
    }

    return LiquidationRecordModel(
      liquidationCaseId: (map['liquidationCaseId'] as num? ?? 0).toInt(),
      cityOfActivity: map['cityOfActivity'] as String? ?? '',
      caseStatus: statusMap,
      submissionDate: map['submissionDate'] as String? ?? '',
      liquidationOrderDate: map['liquidationOrderDate'] as String? ?? '',
      cancellationFreezeDate: map['cancellationFreezeDate'] as String?,
      closureDate: map['closureDate'] as String?,
      closureReason: map['closureReason'] as String?,
      districtCourt: map['districtCourt'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      companyId: (map['companyId'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'liquidationCaseId': liquidationCaseId,
      'cityOfActivity': cityOfActivity,
      'caseStatus': caseStatus,
      'submissionDate': submissionDate,
      'liquidationOrderDate': liquidationOrderDate,
      'cancellationFreezeDate': cancellationFreezeDate,
      'closureDate': closureDate,
      'closureReason': closureReason,
      'districtCourt': districtCourt,
      'companyName': companyName,
      'companyId': companyId,
    };
  }
}
