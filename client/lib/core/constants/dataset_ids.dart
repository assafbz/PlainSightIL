/// Central constants representing dataset resource GUIDs.
class DatasetIds {
  /// Active Cellular Antennas dataset ID.
  static const String cellularAntennas = '8935c8e5-ec77-421f-af86-d970583195f8';

  /// Cellular Permit Applications dataset ID.
  static const String cellularPermits = 'ff398c7e-c522-4ee8-a53a-312b188a573d';

  /// Companies in Liquidation dataset ID.
  static const String companiesLiquidation =
      'd8715392-287f-49b7-9ae3-f21ec5bf55f3';

  /// Doctors Licenses dataset ID.
  static const String doctorsLicenses = '9c64c522-bbc2-48fe-96fb-3b2a8626f59e';

  /// Patent Applications CPC Classifications dataset ID.
  static const String patentClassifications =
      'b2c59e21-c345-4b02-b071-2890a3d431d6';

  /// Travel Warnings dataset ID.
  static const String travelWarnings = '2a01d234-b2b0-4d46-baa0-cec05c401e7d';

  /// Vehicle Recalls dataset ID.
  static const String vehicleRecalls = '2c33523f-87aa-44ec-a736-edbb0a82975e';

  /// Car Importers and New Car Price Lists dataset ID.
  static const String carImporters = '39f455bf-6db0-4926-859d-017f34eacbcb';

  /// Local Market Bonds dataset ID.
  static const String localMarketBonds = 'c92fdda2-0939-4110-8ebc-edfcf35e8723';

  /// Returns a list of all registered dataset GUIDs.
  static List<String> get all => [
    cellularAntennas,
    cellularPermits,
    companiesLiquidation,
    doctorsLicenses,
    patentClassifications,
    travelWarnings,
    vehicleRecalls,
    carImporters,
    localMarketBonds,
  ];
}
