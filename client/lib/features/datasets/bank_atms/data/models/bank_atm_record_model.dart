/// Model representing a Bank ATM record row in the Firestore database.
class BankAtmRecordModel {
  /// Unique document ID
  final String id;

  /// ATM number
  final int atmNum;

  /// Bank code
  final int bankCode;

  /// Translated bank name (he/en)
  final Map<String, String> bankName;

  /// Branch code
  final int branchCode;

  /// Hebrew address
  final String address;

  /// Detailed address
  final String addressExtra;

  /// Hebrew city name
  final String city;

  /// Translated ATM location type (he/en)
  final Map<String, String> atmLocation;

  /// Latitude
  final double latitude;

  /// Longitude
  final double longitude;

  /// Geohash string
  final String geohash;

  /// Whether the ATM charges commission
  final bool hasCommission;

  /// Whether the ATM supports cash withdrawal
  final bool hasCashWithdrawal;

  /// Whether the ATM supports cash deposit
  final bool hasCashDeposit;

  /// Whether the ATM supports cheque deposit
  final bool hasChequeDeposit;

  /// Whether the ATM supports envelope deposit
  final bool hasEnvelopeDeposit;

  /// Whether the ATM supports forex transactions
  final bool hasForexTransaction;

  /// Whether the ATM supports additional transactions
  final bool hasAdditionalTransactions;

  /// Whether the ATM has handicap access
  final bool hasHandicapAccess;

  /// Source created at timestamp (ISO-8601 string)
  final String sourceCreatedAt;

  /// Source updated at timestamp (ISO-8601 string)
  final String sourceUpdatedAt;

  /// Created at timestamp (ISO-8601 string)
  final String createdAt;

  /// Updated at timestamp (ISO-8601 string)
  final String updatedAt;

  /// Last updated timestamp (ISO-8601 string) - Legacy backward compatibility
  final String lastUpdated;

  /// Constructor initializing all fields
  BankAtmRecordModel({
    required this.id,
    required this.atmNum,
    required this.bankCode,
    required this.bankName,
    required this.branchCode,
    required this.address,
    required this.addressExtra,
    required this.city,
    required this.atmLocation,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.hasCommission,
    required this.hasCashWithdrawal,
    required this.hasCashDeposit,
    required this.hasChequeDeposit,
    required this.hasEnvelopeDeposit,
    required this.hasForexTransaction,
    required this.hasAdditionalTransactions,
    required this.hasHandicapAccess,
    required this.sourceCreatedAt,
    required this.sourceUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory BankAtmRecordModel.fromMap(Map<String, dynamic> map) {
    // Extract coordinates from GeoPoint or nested map
    double lat = 0.0;
    double lng = 0.0;
    final coords = map['coordinates'];
    if (coords != null) {
      if (coords is Map) {
        lat =
            (coords['latitude'] as num?)?.toDouble() ??
            (coords['_latitude'] as num?)?.toDouble() ??
            0.0;
        lng =
            (coords['longitude'] as num?)?.toDouble() ??
            (coords['_longitude'] as num?)?.toDouble() ??
            0.0;
      } else {
        // GeoPoint from Firestore SDK
        try {
          lat = (coords as dynamic).latitude as double;
          lng = (coords as dynamic).longitude as double;
        } catch (_) {}
      }
    }

    return BankAtmRecordModel(
      id: map['id'] as String? ?? '',
      atmNum: (map['atmNum'] as num? ?? 0).toInt(),
      bankCode: (map['bankCode'] as num? ?? 0).toInt(),
      bankName: _parseTranslatedMap(map['bankName']),
      branchCode: (map['branchCode'] as num? ?? 0).toInt(),
      address: map['address'] as String? ?? '',
      addressExtra: map['addressExtra'] as String? ?? '',
      city: map['city'] as String? ?? '',
      atmLocation: _parseTranslatedMap(map['atmLocation']),
      latitude: lat,
      longitude: lng,
      geohash: map['geohash'] as String? ?? '',
      hasCommission: map['hasCommission'] as bool? ?? false,
      hasCashWithdrawal: map['hasCashWithdrawal'] as bool? ?? false,
      hasCashDeposit: map['hasCashDeposit'] as bool? ?? false,
      hasChequeDeposit: map['hasChequeDeposit'] as bool? ?? false,
      hasEnvelopeDeposit: map['hasEnvelopeDeposit'] as bool? ?? false,
      hasForexTransaction: map['hasForexTransaction'] as bool? ?? false,
      hasAdditionalTransactions:
          map['hasAdditionalTransactions'] as bool? ?? false,
      hasHandicapAccess: map['hasHandicapAccess'] as bool? ?? false,
      sourceCreatedAt:
          map['sourceCreatedAt'] as String? ??
          map['lastUpdated'] as String? ??
          '',
      sourceUpdatedAt:
          map['sourceUpdatedAt'] as String? ??
          map['lastUpdated'] as String? ??
          '',
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
      lastUpdated:
          map['sourceUpdatedAt'] as String? ??
          map['lastUpdated'] as String? ??
          '',
    );
  }

  /// Parses a translated map field (e.g. {he: '...', en: '...'})
  static Map<String, String> _parseTranslatedMap(dynamic value) {
    if (value is Map) {
      return {
        'he': value['he'] as String? ?? '',
        'en': value['en'] as String? ?? '',
      };
    }
    return {'he': '', 'en': ''};
  }

  /// Converts the model instance into a map structure suitable for Firestore writes or testing.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'atmNum': atmNum,
      'bankCode': bankCode,
      'bankName': bankName,
      'branchCode': branchCode,
      'address': address,
      'addressExtra': addressExtra,
      'city': city,
      'atmLocation': atmLocation,
      'coordinates': {'latitude': latitude, 'longitude': longitude},
      'geohash': geohash,
      'hasCommission': hasCommission,
      'hasCashWithdrawal': hasCashWithdrawal,
      'hasCashDeposit': hasCashDeposit,
      'hasChequeDeposit': hasChequeDeposit,
      'hasEnvelopeDeposit': hasEnvelopeDeposit,
      'hasForexTransaction': hasForexTransaction,
      'hasAdditionalTransactions': hasAdditionalTransactions,
      'hasHandicapAccess': hasHandicapAccess,
      'sourceCreatedAt': sourceCreatedAt,
      'sourceUpdatedAt': sourceUpdatedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
