/// Model representing a doctor's license record row in the Firestore database.
class DoctorLicenseRecordModel {
  /// Unique document ID (string representation of the datastore _id)
  final String id;

  /// Numeric identifier corresponding to the datastore primary key (_id)
  final int idNum;

  /// Doctor's first name
  final String firstName;

  /// Doctor's last name
  final String lastName;

  /// Medical license registration number
  final int licenseNumber;

  /// Registration date of the medical license (ISO-8601 string)
  final String licenseRegistrationDate;

  /// Specialty certification number (optional)
  final int? specialtyCertificateNumber;

  /// Registration date of the specialization (optional ISO-8601 string)
  final String? specialtyRegistrationDate;

  /// Name of the medical specialty (optional Hebrew text)
  final String? specialtyName;

  /// Ingestion timestamp (optional ISO-8601 string)
  final String? createdAt;

  /// Firestore database modification timestamp (optional ISO-8601 string)
  final String? updatedAt;

  /// Source metadata modification timestamp (optional ISO-8601 string)
  final String? lastUpdated;

  /// Constructor initializing all fields
  DoctorLicenseRecordModel({
    required this.id,
    required this.idNum,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    required this.licenseRegistrationDate,
    this.specialtyCertificateNumber,
    this.specialtyRegistrationDate,
    this.specialtyName,
    this.createdAt,
    this.updatedAt,
    this.lastUpdated,
  });

  /// Factory constructor to parse a Firestore document mapping into the model.
  factory DoctorLicenseRecordModel.fromMap(Map<String, dynamic> map) {
    return DoctorLicenseRecordModel(
      id: map['id'] as String? ?? '',
      idNum: (map['_id'] as num? ?? 0).toInt(),
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      licenseNumber: (map['licenseNumber'] as num? ?? 0).toInt(),
      licenseRegistrationDate: map['licenseRegistrationDate'] as String? ?? '',
      specialtyCertificateNumber: map['specialtyCertificateNumber'] != null
          ? (map['specialtyCertificateNumber'] as num).toInt()
          : null,
      specialtyRegistrationDate: map['specialtyRegistrationDate'] as String?,
      specialtyName: map['specialtyName'] as String?,
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
      'firstName': firstName,
      'lastName': lastName,
      'licenseNumber': licenseNumber,
      'licenseRegistrationDate': licenseRegistrationDate,
      'specialtyCertificateNumber': specialtyCertificateNumber,
      'specialtyRegistrationDate': specialtyRegistrationDate,
      'specialtyName': specialtyName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastUpdated': lastUpdated,
    };
  }
}
