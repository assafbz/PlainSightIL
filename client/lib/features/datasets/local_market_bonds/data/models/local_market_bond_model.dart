/// Model representing a local market government bond record row in the Firestore database.
class LocalMarketBondRecordModel {
  /// Unique document ID (string representation of the datastore _id)
  final String id;

  /// Numeric identifier corresponding to the datastore primary key (_id)
  final int idNum;

  /// Issuance date (ISO string)
  final String issuanceDate;

  /// Bond type translated bilingual map (he/en)
  final Map<String, String> bondType;

  /// Series number of the bond
  final int series;

  /// Actual term to maturity in years
  final double actualTermToMaturity;

  /// Original term to maturity in years
  final double originalTermToMaturity;

  /// Redemption date (ISO string)
  final String redemptionDate;

  /// Coupon rate percentage
  final double coupon;

  /// Offered quantity in millions
  final double offeredQuantity;

  /// Purchased quantity in millions
  final double purchasedQuantity;

  /// Additional purchased quantity in millions
  final double additionalPurchased;

  /// Average auction price
  final double averagePrice;

  /// Cutoff auction price
  final double cutoffPrice;

  /// Total funding in millions
  final double totalFunding;

  /// Demanded amount in millions
  final double demandedAmount;

  /// Cover ratio of the auction
  final double coverRatio;

  /// Gross average yield percentage
  final double grossAvgYield;

  /// Gross cutoff yield percentage
  final double grossCutoffYield;

  /// Ingestion timestamp (optional ISO-8601 string)
  final String? createdAt;

  /// Firestore database modification timestamp (optional ISO-8601 string)
  final String? updatedAt;

  /// Source metadata modification timestamp (optional ISO-8601 string)
  final String? lastUpdated;

  /// Constructor
  LocalMarketBondRecordModel({
    required this.id,
    required this.idNum,
    required this.issuanceDate,
    required this.bondType,
    required this.series,
    required this.actualTermToMaturity,
    required this.originalTermToMaturity,
    required this.redemptionDate,
    required this.coupon,
    required this.offeredQuantity,
    required this.purchasedQuantity,
    required this.additionalPurchased,
    required this.averagePrice,
    required this.cutoffPrice,
    required this.totalFunding,
    required this.demandedAmount,
    required this.coverRatio,
    required this.grossAvgYield,
    required this.grossCutoffYield,
    this.createdAt,
    this.updatedAt,
    this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory LocalMarketBondRecordModel.fromMap(Map<String, dynamic> map) {
    return LocalMarketBondRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      issuanceDate: map['issuanceDate'] as String? ?? '',
      bondType: Map<String, String>.from(
        map['bondType'] as Map? ?? const <String, String>{},
      ),
      series: (map['series'] as num? ?? 0).toInt(),
      actualTermToMaturity: (map['actualTermToMaturity'] as num? ?? 0.0)
          .toDouble(),
      originalTermToMaturity: (map['originalTermToMaturity'] as num? ?? 0.0)
          .toDouble(),
      redemptionDate: map['redemptionDate'] as String? ?? '',
      coupon: (map['coupon'] as num? ?? 0.0).toDouble(),
      offeredQuantity: (map['offeredQuantity'] as num? ?? 0.0).toDouble(),
      purchasedQuantity: (map['purchasedQuantity'] as num? ?? 0.0).toDouble(),
      additionalPurchased: (map['additionalPurchased'] as num? ?? 0.0)
          .toDouble(),
      averagePrice: (map['averagePrice'] as num? ?? 0.0).toDouble(),
      cutoffPrice: (map['cutoffPrice'] as num? ?? 0.0).toDouble(),
      totalFunding: (map['totalFunding'] as num? ?? 0.0).toDouble(),
      demandedAmount: (map['demandedAmount'] as num? ?? 0.0).toDouble(),
      coverRatio: (map['coverRatio'] as num? ?? 0.0).toDouble(),
      grossAvgYield: (map['grossAvgYield'] as num? ?? 0.0).toDouble(),
      grossCutoffYield: (map['grossCutoffYield'] as num? ?? 0.0).toDouble(),
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      lastUpdated: map['lastUpdated'] as String?,
    );
  }

  /// Converts the model instance into a map structure.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': idNum,
      'issuanceDate': issuanceDate,
      'bondType': bondType,
      'series': series,
      'actualTermToMaturity': actualTermToMaturity,
      'originalTermToMaturity': originalTermToMaturity,
      'redemptionDate': redemptionDate,
      'coupon': coupon,
      'offeredQuantity': offeredQuantity,
      'purchasedQuantity': purchasedQuantity,
      'additionalPurchased': additionalPurchased,
      'averagePrice': averagePrice,
      'cutoffPrice': cutoffPrice,
      'totalFunding': totalFunding,
      'demandedAmount': demandedAmount,
      'coverRatio': coverRatio,
      'grossAvgYield': grossAvgYield,
      'grossCutoffYield': grossCutoffYield,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
