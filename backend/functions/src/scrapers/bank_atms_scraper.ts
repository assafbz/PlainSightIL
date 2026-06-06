import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import axios from "axios";
import { encodeGeohash } from "../utils/geohash";
import { DATASET_IDS } from "../utils/constants";
import { areRecordsEqual } from "../utils/equality";

/**
 * Validates that coordinates fall within Israel's approximate bounding box (WGS84).
 */
export function isValidIsraelCoordinates(latitude: number, longitude: number): boolean {
  return latitude >= 29.3 && latitude <= 33.4 && longitude >= 34.2 && longitude <= 35.9;
}

/**
 * Maps Hebrew yes/no (כן/לא) values to boolean.
 */
export function parseHebrewBoolean(val: unknown): boolean {
  if (val === undefined || val === null) return false;
  const s = String(val).trim();
  return s === "כן";
}

// Translation mapping for Hebrew bank names to English
// prettier-ignore
const BANK_NAME_TRANSLATIONS: Record<string, string> = {
  'בנק אוצר החייל בע"מ': "Bank Otsar HaHayal",
  'בנק דיסקונט לישראל בע"מ': "Israel Discount Bank",
  'בנק הבינלאומי הראשון לישראל בע"מ': "First International Bank of Israel",
  'בנק הפועלים בע"מ': "Bank Hapoalim",
  'בנק יהב לעובדי המדינה בע"מ': "Bank Yahav",
  'בנק ירושלים בע"מ': "Bank of Jerusalem",
  'בנק לאומי לישראל בע"מ': "Bank Leumi",
  'בנק מזרחי טפחות בע"מ': "Mizrahi Tefahot Bank",
  'בנק מסד בע"מ': "Bank Massad",
  'בנק מרכנתיל דיסקונט בע"מ': "Mercantile Discount Bank",
  'בנק פועלי אגודת ישראל בע"מ': "Bank Poalei Agudat Yisrael",
  'יו-בנק בע"מ': "U-Bank",
};

// Translation mapping for ATM location descriptions
const ATM_LOCATION_TRANSLATIONS: Record<string, string> = {
  "אינו סמוך לסניף": "Not Near Branch",
  "במרחק עד 500 מטר מהסניף": "Within 500m of Branch",
  "במרחק של יותר מ- 500 מטר מהסניף": "Over 500m from Branch",
  "במרחק של עד 500 מטר מהסניף": "Within 500m of Branch",
  "בתוך הסניף": "Inside Branch",
  כן: "Yes",
  "על קיר הסניף": "On Branch Wall",
};

/**
 * Interface representing the raw record layout received from data.gov.il CKAN datastore API.
 */
export interface HebrewAtmRecord {
  _id: number;
  Bank_Code?: number | string;
  Bank_Name?: string;
  Branch_Code?: number | string;
  Sub_Branch_Code?: number | string;
  Atm_Num?: number | string;
  ATM_Address?: string;
  ATM_Address_Extra?: string;
  City?: string;
  Commission?: string;
  Casd_Withdrawal?: string;
  Cash_Deposit?: string;
  Cheque_Deposit?: string;
  Envelope_Deposit?: string;
  Forex_Transaction?: string;
  Additional_Transactions?: string;
  ATM_Location?: string;
  Handicap_Access?: string;
  X_Coordinate?: number | string;
  Y_Coordinate?: number | string;
}

/**
 * Interface representing the normalized and sanitized ATM record written to Firestore.
 */
export interface BankAtmRecord {
  id: string;
  _id: number;
  bankCode: number;
  bankName: { he: string; en: string };
  branchCode: number;
  subBranchCode: number;
  atmNumber: number;
  address: string;
  addressExtra: string;
  city: string;
  commission: boolean;
  cashWithdrawal: boolean;
  cashDeposit: boolean;
  chequeDeposit: boolean;
  envelopeDeposit: boolean;
  forexTransaction: boolean;
  additionalTransactions: boolean;
  atmLocation: { he: string; en: string };
  handicapAccess: boolean;
  coordinates: GeoPoint;
  geohash: string;
  lastUpdated: string;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Maps a raw Hebrew ATM record into the clean, typed BankAtmRecord format.
 * Sanitizes input and enforces numeric/coordinate checks.
 *
 * @param record The raw record from the API
 * @returns Mapped record, or null if key fields are missing or invalid
 */
export function parseAtmRecord(record: HebrewAtmRecord): BankAtmRecord | null {
  const rawId = record._id;

  if (rawId === undefined || rawId === null) {
    return null;
  }

  const id = String(rawId).trim();

  // Parse and validate bank code
  const bankCode = Number(record.Bank_Code);
  if (isNaN(bankCode) || bankCode <= 0) {
    return null;
  }

  // Parse coordinates - X_Coordinate is latitude, Y_Coordinate is longitude (already WGS84)
  const rawLat = record.X_Coordinate;
  const rawLon = record.Y_Coordinate;

  if (rawLat === undefined || rawLat === null || rawLon === undefined || rawLon === null) {
    return null;
  }

  const latitude = typeof rawLat === "string" ? parseFloat(rawLat) : rawLat;
  const longitude = typeof rawLon === "string" ? parseFloat(rawLon) : rawLon;

  if (isNaN(latitude) || isNaN(longitude)) {
    return null;
  }

  if (!isValidIsraelCoordinates(latitude, longitude)) {
    return null;
  }

  const geohash = encodeGeohash(latitude, longitude);

  // Translate bank name
  const rawBankName = (record.Bank_Name ?? "").trim();
  const bankNameEn = BANK_NAME_TRANSLATIONS[rawBankName] || rawBankName;

  // Translate ATM location
  const rawAtmLocation = (record.ATM_Location ?? "").trim();
  const atmLocationEn = ATM_LOCATION_TRANSLATIONS[rawAtmLocation] || rawAtmLocation;

  const branchCode = Number(record.Branch_Code) || 0;
  const subBranchCode = Number(record.Sub_Branch_Code) || 0;
  const atmNumber = Number(record.Atm_Num) || 0;

  return {
    id,
    _id: rawId,
    bankCode,
    bankName: { he: rawBankName, en: bankNameEn },
    branchCode,
    subBranchCode,
    atmNumber,
    address: (record.ATM_Address ?? "").trim(),
    addressExtra: (record.ATM_Address_Extra ?? "").trim(),
    city: (record.City ?? "").trim(),
    commission: parseHebrewBoolean(record.Commission),
    cashWithdrawal: parseHebrewBoolean(record.Casd_Withdrawal),
    cashDeposit: parseHebrewBoolean(record.Cash_Deposit),
    chequeDeposit: parseHebrewBoolean(record.Cheque_Deposit),
    envelopeDeposit: parseHebrewBoolean(record.Envelope_Deposit),
    forexTransaction: parseHebrewBoolean(record.Forex_Transaction),
    additionalTransactions: parseHebrewBoolean(record.Additional_Transactions),
    atmLocation: { he: rawAtmLocation, en: atmLocationEn },
    handicapAccess: parseHebrewBoolean(record.Handicap_Access),
    coordinates: new GeoPoint(latitude, longitude),
    geohash,
    lastUpdated: new Date().toISOString(),
  };
}

/**
 * Scrapes Bank ATMs from data.gov.il datastore API and syncs them in-place to Firestore.
 * Performs paginated queries to handle the ~3019 document records size.
 *
 * @param db The Firestore database reference
 * @param resourceId The resource ID for data.gov.il API (defaults to 21fde05f-62e3-401b-81cf-5c385862026d)
 * @returns Success status and count of processed records
 */
export async function scrapeAndSyncBankAtms(
  db: admin.firestore.Firestore,
  resourceId = DATASET_IDS.BANK_ATMS,
  options?: { forceFullSync?: boolean },
): Promise<{ success: boolean; count: number; changedCount: number }> {
  const datasetId = DATASET_IDS.BANK_ATMS;
  const metadataRef = db.collection("dataset_metadata").doc(datasetId);

  try {
    const targetCollection = DATASET_IDS.BANK_ATMS;
    logger.info(`Starting bank ATMs sync. Target collection: ${targetCollection}`);

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const forceFullSync = options?.forceFullSync === true;
    let offset = 0;
    const limit = isEmulator && !forceFullSync ? 100 : 10000;
    let hasMore = true;
    let processedCount = 0;
    let changedCount = 0;

    const targetRef = db.collection(targetCollection);
    const now = new Date().toISOString();

    // Loop and page through the datastore
    while (hasMore) {
      const url = `https://data.gov.il/api/3/action/datastore_search?resource_id=${resourceId}&limit=${limit}&offset=${offset}`;
      logger.info(`Fetching bank ATMs data from: ${url}`);

      const response = await axios.get(url, { timeout: 15000 });
      const records: HebrewAtmRecord[] = response.data?.result?.records ?? [];

      if (records.length === 0) {
        hasMore = false;
        break;
      }

      const parsedRecords: BankAtmRecord[] = [];
      for (const rec of records) {
        const parsed = parseAtmRecord(rec);
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
            r.lastUpdated = existingData.lastUpdated;
            const isIdentical = areRecordsEqual(existingData, r);
            if (isIdentical) {
              processedCount++;
              continue;
            }
            r.createdAt = existingData.createdAt || now;
            r.updatedAt = now;
            r.lastUpdated = now;
          } else {
            r.createdAt = now;
            r.updatedAt = now;
            r.lastUpdated = now;
          }

          batch.set(docRef, r);
          hasWrites = true;
          processedCount++;
          changedCount++;
        }
        if (hasWrites) {
          await batch.commit();
        }
      }

      if (isEmulator && !forceFullSync) {
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

    logger.info("Updated bank ATMs metadata. Ingestion complete.");
    return { success: true, count: processedCount, changedCount };
  } catch (error) {
    logger.error("Bank ATMs scraper failed:", error);
    await metadataRef.set({ status: "error" }, { merge: true });
    throw error;
  }
}
