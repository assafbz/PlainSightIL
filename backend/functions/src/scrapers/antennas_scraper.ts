import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import axios from "axios";
import { encodeGeohash } from "../utils/geohash";

export interface HebrewAntennaRecord {
  antennaId?: string | number;
  latitude?: number | string;
  longitude?: number | string;
  operatorName?: string;
  permitType?: string;
  radiationFrequency?: number | string;
  lastTestDate?: string;
  addressHebrew?: string;
  addressEnglish?: string;

  // Literal Hebrew keys mapping from data.gov.il API
  מזהה_אנטנה?: string | number;
  קו_רוחב?: number | string;
  קו_אורך?: number | string;
  שם_מפעיל?: string;
  סוג_אישור?: string;
  תדר?: number | string;
  תאריך_בדיקה_אחרון?: string;
  כתובת_אתר?: string;
}

export interface CellularAntenna {
  antennaId: string;
  coordinates: admin.firestore.GeoPoint;
  geohash: string;
  operatorName: string;
  permitType: string;
  radiationFrequency: number;
  lastTestDate: string;
  addressHebrew: string;
  addressEnglish: string;
}

function translateOperator(hebrewOperator: string): string {
  const lower = hebrewOperator.trim();
  if (lower.includes("פרטנר") || lower.toLowerCase().includes("partner")) return "Partner";
  if (lower.includes("סלקום") || lower.toLowerCase().includes("cellcom")) return "Cellcom";
  if (lower.includes("פלאפון") || lower.toLowerCase().includes("pelephone")) return "Pelephone";
  if (lower.includes("הוט") || lower.toLowerCase().includes("hot")) return "HOT Mobile";
  return hebrewOperator;
}

function translatePermit(hebrewPermit: string): string {
  const lower = hebrewPermit.trim();
  if (lower.includes("פעיל") || lower.includes("מאושר") || lower.toLowerCase().includes("active"))
    return "Active";
  if (lower.includes("הקמה") || lower.includes("זמני") || lower.toLowerCase().includes("permitted"))
    return "Permitted";
  return "Under Review";
}

function formatToISOString(dateStr: string): string {
  try {
    const timestamp = Date.parse(dateStr);
    if (!isNaN(timestamp)) {
      return new Date(timestamp).toISOString();
    }
  } catch {
    // Ignore and fallback
  }
  return new Date().toISOString();
}

function translateAddress(hebrewAddress: string): string {
  if (!hebrewAddress) return "";
  let english = hebrewAddress;
  const mappings: { [key: string]: string } = {
    "תל אביב": "Tel Aviv",
    ירושלים: "Jerusalem",
    חיפה: "Haifa",
    "ראשון לציון": "Rishon LeZion",
    "פתח תקווה": "Petah Tikva",
    אשדוד: "Ashdod",
    נתניה: "Netanya",
    "באר שבע": "Beer Sheva",
    חולון: "Holon",
    "רמת גן": "Ramat Gan",
    רחובות: "Rehovot",
    הרצליה: "Herzliya",
    רעננה: "Ra'anana",
    דיזנגוף: "Dizengoff",
    רוטשילד: "Rothschild",
    "בן גוריון": "Ben Gurion",
  };
  for (const [heb, eng] of Object.entries(mappings)) {
    english = english.replace(new RegExp(heb, "g"), eng);
  }
  return english;
}

export function parseRecord(record: HebrewAntennaRecord): CellularAntenna | null {
  const rawId = record.antennaId ?? record["מזהה_אנטנה"];
  const rawLat = record.latitude ?? record["קו_רוחב"];
  const rawLng = record.longitude ?? record["קו_אורך"];

  if (rawId === undefined || rawLat === undefined || rawLng === undefined) {
    return null;
  }

  const antennaId = String(rawId).trim();
  const latitude = typeof rawLat === "string" ? parseFloat(rawLat) : rawLat;
  const longitude = typeof rawLng === "string" ? parseFloat(rawLng) : rawLng;

  if (isNaN(latitude) || isNaN(longitude)) {
    return null;
  }

  const geohash = encodeGeohash(latitude, longitude);

  const rawOperator = record.operatorName ?? record["שם_מפעיל"] ?? "Unknown";
  const operatorName = translateOperator(rawOperator);

  const rawPermit = record.permitType ?? record["סוג_אישור"] ?? "Under Review";
  const permitType = translatePermit(rawPermit);

  const rawFreq = record.radiationFrequency ?? record["תדר"] ?? 0;
  const radiationFrequency = typeof rawFreq === "string" ? parseFloat(rawFreq) : rawFreq;

  const rawDate = record.lastTestDate ?? record["תאריך_בדיקה_אחרון"] ?? new Date().toISOString();
  const lastTestDate = formatToISOString(rawDate);

  const addressHebrew = record.addressHebrew ?? record["כתובת_אתר"] ?? "לא ידוע";
  const addressEnglish = record.addressEnglish ?? translateAddress(addressHebrew);

  return {
    antennaId,
    coordinates: new admin.firestore.GeoPoint(latitude, longitude),
    geohash,
    operatorName,
    permitType,
    radiationFrequency: isNaN(radiationFrequency) ? 0 : radiationFrequency,
    lastTestDate,
    addressHebrew,
    addressEnglish,
  };
}

export async function saveAntennasToFirestore(
  db: admin.firestore.Firestore,
  antennas: CellularAntenna[],
): Promise<void> {
  const collectionRef = db.collection("cellular_antennas");

  let batch = db.batch();
  let count = 0;

  for (const antenna of antennas) {
    const docRef = collectionRef.doc(antenna.antennaId);
    batch.set(docRef, antenna);
    count++;

    if (count === 500) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
  }
}

export async function scrapeAndSyncAntennas(
  db: admin.firestore.Firestore,
  apiUrl?: string,
): Promise<{ success: boolean; count: number }> {
  try {
    const targetUrl =
      apiUrl ??
      "https://data.gov.il/api/3/action/datastore_search?resource_id=c86e2468-b79e-4e4f-b649-43c2d47cf73b&limit=100";
    logger.info(`Fetching cellular antennas from: ${targetUrl}`);

    const response = await axios.get(targetUrl);
    const records: HebrewAntennaRecord[] = response.data?.result?.records ?? [];

    if (!records.length) {
      logger.warn("No antenna records fetched from the government portal.");
      return { success: true, count: 0 };
    }

    const parsedAntennas: CellularAntenna[] = [];
    for (const record of records) {
      const parsed = parseRecord(record);
      if (parsed) {
        parsedAntennas.push(parsed);
      }
    }

    logger.info(`Parsed ${parsedAntennas.length} valid antennas. Writing to Firestore...`);
    await saveAntennasToFirestore(db, parsedAntennas);
    logger.info("Successfully synced cellular antennas with Firestore.");

    return { success: true, count: parsedAntennas.length };
  } catch (error) {
    logger.error("Failed to scrape and sync cellular antennas:", error);
    throw error;
  }
}
