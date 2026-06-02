import * as admin from "firebase-admin";
import { AppLogger as logger } from "../utils/logger";
import axios from "axios";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

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
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Normalizes a numeric DDMMYYYY date from the data.gov.il datastore.
 * Restores leading zeros if they are missing (e.g. 2121993 -> 02121993).
 * Converts to ISO-8601 string format (e.g. 1993-12-02T00:00:00.000Z).
 *
 * @param val The raw input value from the datastore API
 * @returns Mapped ISO string or empty string if invalid
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
 * @param record The raw record from the API
 * @returns Mapped record, or null if key fields are missing or invalid
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

  const lastUpdated = licenseRegistrationDate || new Date().toISOString();

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
    lastUpdated,
  };
}

/**
 * Scrapes doctors licenses from data.gov.il datastore API and syncs them in-place to Firestore.
 * Performs paginated queries to handle the >63,000 document records size.
 *
 * @param db The Firestore database reference
 * @param resourceId The resource ID for data.gov.il API (defaults to 9c64c522-bbc2-48fe-96fb-3b2a8626f59e)
 * @returns Success status and count of processed records
 */
export async function scrapeAndSyncDoctorsLicenses(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.DOCTORS_LICENSES,
): Promise<{ success: boolean; count: number }> {
  const datasetId = DATASET_IDS.DOCTORS_LICENSES;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.DOCTORS_LICENSES;
    logger.info(`Starting doctors licenses sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    let offset = 0;
    const limit = isEmulator ? 10 : 1000;
    let hasMore = true;
    let processedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    // Loop and page through the datastore
    while (hasMore) {
      const baseUrl = process.env.DATA_GOV_IL_BASE_URL || "https://data.gov.il";
      const url = `${baseUrl}/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching doctors licenses data from: ${url}`);

      const response = await axios.get(url);
      const records: HebrewDoctorRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: DoctorLicenseRecord[] = [];
      for (const rec of records) {
        const parsed = parseDoctorRecord(rec);
        if (parsed) {
          parsedRecords.push(parsed);
        }
      }

      // Batch set documents in chunks of 500
      for (let i = 0; i < parsedRecords.length; i += 500) {
        const chunk = parsedRecords.slice(i, i + 500);
        const docRefs = chunk.map((r) => targetRef.doc(r.id));

        // Read existing entries to retain their original createdAt timestamp
        const snapshots = docRefs.length > 0 ? await db.getAll(...docRefs) : [];
        const existingMap = new Map<string, admin.firestore.DocumentData>();
        for (const snap of snapshots) {
          const data = snap.data();
          if (snap.exists && data) {
            existingMap.set(snap.id, data);
          }
        }

        const batch = db.batch();
        let hasWrites = false;
        for (const r of chunk) {
          const docRef = targetRef.doc(r.id);
          const existingData = existingMap.get(r.id);

          r.lastUpdated = r.lastUpdated || now;
          if (existingData) {
            const isIdentical = areRecordsEqual(existingData, r);
            if (isIdentical) {
              processedCount++;
              continue;
            }
            r.createdAt = existingData.createdAt || now;
            r.updatedAt = now;
          } else {
            r.createdAt = now;
            r.updatedAt = now;
          }

          batch.set(docRef, r);
          hasWrites = true;
          processedCount++;
        }
        if (hasWrites) {
          await batch.commit();
        }
      }

      if (isEmulator) {
        hasMore = false;
        break;
      }

      offset += limit;
    }

    logger.info(`Successfully parsed and updated ${processedCount} records in ${targetCollection}`);

    // Update document total record counts dynamically
    const countSnapshot = await targetRef.count().get();
    const totalRecords = countSnapshot.data().count;

    await metadataRef.set(
      {
        id: datasetId,
        activeCollection: targetCollection,
        lastUpdated: now,
        recordCount: totalRecords,
        status: "idle",
      },
      { merge: true },
    );

    logger.info("Updated doctors licenses metadata. Ingestion complete.");
    return { success: true, count: processedCount };
  } catch (error) {
    logger.error("Doctors licenses scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
