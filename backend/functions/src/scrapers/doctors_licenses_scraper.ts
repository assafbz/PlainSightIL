import * as admin from "firebase-admin";
import { DATASET_IDS } from "../utils/constants";
import { BaseScraper, ScraperOptions, ScraperResult } from "./base_scraper";

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewDoctorRecord {
  _id: number;
  "שם פרטי"?: string;
  "שם משפחה"?: string;
  "מספר רישיון רופא"?: number | string;
  "תאריך רישום רישיון"?: number | string | null;
  "מספר תעודת התמחות"?: number | string | null;
  "תאריך רישום התמחות"?: number | string | null;
  "שם התמחות"?: string | null;
}

/**
 * Interface representing the normalized and sanitized doctor license record written to Firestore.
 */
export interface DoctorLicenseRecord {
  id: string;
  _id: number;
  firstName: string;
  lastName: string;
  licenseNumber: number;
  licenseRegistrationDate: string;
  specialtyCertificateNumber: number | null;
  specialtyRegistrationDate: string | null;
  specialtyName: string | null;
  sourceCreatedAt: string;
  sourceUpdatedAt: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Normalizes a numeric DDMMYYYY date from the data.gov.il datastore.
 * Restores leading zeros if they are missing (e.g. 2121993 -> 02121993).
 * Converts to ISO-8601 string format (e.g. 1993-12-02T00:00:00.000Z).
 *
 * @param val The raw input value from the datastore API.
 * @returns Mapped ISO string or empty string if invalid.
 */
export function parseDDMMYYYY(val: unknown): string {
  if (val === undefined || val === null) return "";
  let s = String(val).trim();
  if (s === "0" || s === "") return "";
  if (s.length === 7) {
    s = "0" + s; // Restore leading zero
  }
  if (s.length !== 8) {
    return "";
  }
  const day = s.substring(0, 2);
  const month = s.substring(2, 4);
  const year = s.substring(4, 8);

  const dayNum = parseInt(day, 10);
  const monthNum = parseInt(month, 10);
  const yearNum = parseInt(year, 10);

  if (isNaN(dayNum) || isNaN(monthNum) || isNaN(yearNum)) {
    return "";
  }
  if (monthNum < 1 || monthNum > 12 || dayNum < 1 || dayNum > 31) {
    return "";
  }

  return `${year}-${month}-${day}T00:00:00.000Z`;
}

/**
 * Maps a raw Hebrew database record into the clean, typed DoctorLicenseRecord format.
 * Sanitizes input and enforces numeric checks.
 *
 * @param record The raw record from the API.
 * @returns Mapped record, or null if key fields are missing or invalid.
 */
export function parseDoctorRecord(record: HebrewDoctorRecord): DoctorLicenseRecord | null {
  const rawId = record._id;
  const rawLicense = record["מספר רישיון רופא"];

  if (rawId === undefined || rawId === null || rawLicense === undefined || rawLicense === null) {
    return null;
  }

  const id = String(rawId).trim();
  const licenseNumber = Number(rawLicense);
  if (isNaN(licenseNumber) || licenseNumber <= 0) {
    return null;
  }

  const firstName = (record["שם פרטי"] ?? "").trim();
  const lastName = (record["שם משפחה"] ?? "").trim();

  // Validate we have at least one name field
  if (!firstName && !lastName) {
    return null;
  }

  const licenseRegistrationDate = parseDDMMYYYY(record["תאריך רישום רישיון"]);

  const rawSpecCert = record["מספר תעודת התמחות"];
  let specialtyCertificateNumber: number | null = null;
  if (rawSpecCert !== undefined && rawSpecCert !== null) {
    const parsedCert = Number(rawSpecCert);
    if (!isNaN(parsedCert) && parsedCert > 0) {
      specialtyCertificateNumber = parsedCert;
    }
  }

  const specialtyRegistrationDate = record["תאריך רישום התמחות"]
    ? parseDDMMYYYY(record["תאריך רישום התמחות"])
    : null;
  const specialtyName = record["שם התמחות"] ? String(record["שם התמחות"]).trim() : null;

  const sourceCreatedAt = licenseRegistrationDate || new Date().toISOString();
  const sourceUpdatedAt =
    specialtyRegistrationDate || licenseRegistrationDate || new Date().toISOString();

  return {
    id,
    _id: rawId,
    firstName,
    lastName,
    licenseNumber,
    licenseRegistrationDate: licenseRegistrationDate || new Date().toISOString(),
    specialtyCertificateNumber,
    specialtyRegistrationDate: specialtyRegistrationDate || null,
    specialtyName: specialtyName || null,
    sourceCreatedAt,
    sourceUpdatedAt,
  };
}

/**
 * Scraper class for Doctors Licenses dataset.
 */
export class DoctorsLicensesScraper extends BaseScraper<HebrewDoctorRecord, DoctorLicenseRecord> {
  readonly datasetId: string;
  readonly targetCollection = DATASET_IDS.DOCTORS_LICENSES;
  override readonly updateIntervalHours = 168; // weekly
  override readonly lastUpdatedSource = "parsed";

  constructor(resourceId = DATASET_IDS.DOCTORS_LICENSES) {
    super();
    this.datasetId = resourceId;
  }

  /**
   * Parses a raw doctor license record.
   *
   * @param raw The raw record.
   * @returns Mapped record, or null if invalid.
   */
  parseRecord(raw: HebrewDoctorRecord): DoctorLicenseRecord | null {
    return parseDoctorRecord(raw);
  }
}

/**
 * Scrapes doctors licenses from data.gov.il datastore API and syncs them in-place to Firestore.
 * Backward-compatible wrapper function.
 *
 * @param db The Firestore database reference.
 * @param resourceId The resource ID for data.gov.il API.
 * @param options Synchronizer options.
 * @returns Success status and count of processed records.
 */
export async function scrapeAndSyncDoctorsLicenses(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.DOCTORS_LICENSES,
  options?: ScraperOptions,
): Promise<ScraperResult> {
  const scraper = new DoctorsLicensesScraper(resourceId);
  return scraper.scrape(db, options);
}
