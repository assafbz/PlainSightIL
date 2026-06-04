/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Compares two values recursively to determine if they are equal,
 * ignoring metadata timestamps: 'createdAt', and 'updatedAt'.
 * Special handling is included for Firestore GeoPoint objects.
 *
 * @param existing The existing value in Firestore
 * @param incoming The newly parsed incoming value
 * @returns true if they are structurally identical, false otherwise
 */
export function areRecordsEqual(existing: any, incoming: any): boolean {
  if (existing === incoming) return true;

  // Handle null/undefined checks
  if (
    (existing === null || existing === undefined) &&
    (incoming === null || incoming === undefined)
  ) {
    return true;
  }
  if (existing === null || existing === undefined || incoming === null || incoming === undefined) {
    return false;
  }

  // Handle type differences
  if (typeof existing !== typeof incoming) return false;

  // Handle primitives
  if (typeof existing !== "object") {
    return existing === incoming;
  }

  // Handle Date objects
  if (existing instanceof Date && incoming instanceof Date) {
    return existing.getTime() === incoming.getTime();
  }

  // Handle Firestore GeoPoint (duck-typing coordinates check)
  const isExistingGeoPoint =
    existing.latitude !== undefined &&
    existing.longitude !== undefined &&
    typeof existing.latitude === "number" &&
    typeof existing.longitude === "number";
  const isIncomingGeoPoint =
    incoming.latitude !== undefined &&
    incoming.longitude !== undefined &&
    typeof incoming.latitude === "number" &&
    typeof incoming.longitude === "number";
  if (isExistingGeoPoint || isIncomingGeoPoint) {
    if (!isExistingGeoPoint || !isIncomingGeoPoint) return false;
    return existing.latitude === incoming.latitude && existing.longitude === incoming.longitude;
  }

  // Handle Arrays
  if (Array.isArray(existing) || Array.isArray(incoming)) {
    if (!Array.isArray(existing) || !Array.isArray(incoming)) return false;
    if (existing.length !== incoming.length) return false;
    for (let i = 0; i < existing.length; i++) {
      if (!areRecordsEqual(existing[i], incoming[i])) return false;
    }
    return true;
  }

  // Handle Objects
  const ignoredKeys = new Set(["createdAt", "updatedAt"]);

  const keysExisting = Object.keys(existing).filter((k) => !ignoredKeys.has(k));
  const keysIncoming = Object.keys(incoming).filter((k) => !ignoredKeys.has(k));

  const allKeys = new Set([...keysExisting, ...keysIncoming]);

  for (const key of allKeys) {
    const valExisting = existing[key];
    const valIncoming = incoming[key];

    if (!areRecordsEqual(valExisting, valIncoming)) {
      return false;
    }
  }

  return true;
}
