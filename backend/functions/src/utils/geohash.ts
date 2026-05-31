const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/**
 * Encodes a latitude and longitude into a geohash string.
 * @param latitude The latitude coordinate (-90 to 90)
 * @param longitude The longitude coordinate (-180 to 180)
 * @param precision The length of the geohash (defaults to 9, which is ~4.77m x 4.77m)
 * @returns The geohash string
 */
export function encodeGeohash(latitude: number, longitude: number, precision = 9): string {
  if (latitude < -90 || latitude > 90) {
    throw new Error("Latitude must be between -90 and 90");
  }
  if (longitude < -180 || longitude > 180) {
    throw new Error("Longitude must be between -180 and 180");
  }

  let geohash = "";
  let isEven = true;
  let latMin = -90;
  let latMax = 90;
  let lonMin = -180;
  let lonMax = 180;
  let bit = 0;
  let ch = 0;

  while (geohash.length < precision) {
    if (isEven) {
      const mid = (lonMin + lonMax) / 2;
      if (longitude >= mid) {
        ch = (ch << 1) | 1;
        lonMin = mid;
      } else {
        ch = (ch << 1) | 0;
        lonMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = (ch << 1) | 0;
        latMax = mid;
      }
    }

    isEven = !isEven;
    bit++;

    if (bit === 5) {
      geohash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }

  return geohash;
}
