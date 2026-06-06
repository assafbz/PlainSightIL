import * as admin from "firebase-admin";

export interface LocalizedString {
  he: string;
  en: string;
}

export interface AlertPayload {
  type: "new_dataset" | "new_government_dataset" | "new_records";
  title: LocalizedString;
  description: LocalizedString;
  datasetId?: string;
  recordCount?: number;
}

/**
 * Creates a localized alert document in a user's private alerts subcollection.
 */
export async function createAlert(
  db: admin.firestore.Firestore,
  userId: string,
  payload: AlertPayload,
): Promise<void> {
  const alertsRef = db.collection("users").doc(userId).collection("alerts");
  const alertDocRef = alertsRef.doc(); // Auto-generated ID
  const now = new Date().toISOString();

  const alertData = {
    id: alertDocRef.id,
    userId,
    type: payload.type,
    title: payload.title,
    description: payload.description,
    datasetId: payload.datasetId || null,
    recordCount: payload.recordCount !== undefined ? payload.recordCount : null,
    isRead: false,
    createdAt: now,
  };

  await alertDocRef.set(alertData);
}

/**
 * Broadcasts an alert to all registered users in the database in batches of 500.
 */
export async function broadcastAlert(
  db: admin.firestore.Firestore,
  payload: AlertPayload,
): Promise<void> {
  const usersSnapshot = await db.collection("users").get();
  if (usersSnapshot.empty) {
    return;
  }

  const now = new Date().toISOString();
  let batch = db.batch();
  let operationCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const alertDocRef = db.collection("users").doc(userId).collection("alerts").doc();

    const alertData = {
      id: alertDocRef.id,
      userId,
      type: payload.type,
      title: payload.title,
      description: payload.description,
      datasetId: payload.datasetId || null,
      recordCount: payload.recordCount !== undefined ? payload.recordCount : null,
      isRead: false,
      createdAt: now,
    };

    batch.set(alertDocRef, alertData);
    operationCount++;

    if (operationCount === 500) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}

/**
 * Notifies all users subscribed to a specific dataset.
 */
export async function notifySubscribers(
  db: admin.firestore.Firestore,
  datasetId: string,
  payload: AlertPayload,
): Promise<void> {
  const subscriptionsSnapshot = await db
    .collection("subscriptions")
    .where("datasetId", "==", datasetId)
    .get();

  if (subscriptionsSnapshot.empty) {
    return;
  }

  const now = new Date().toISOString();
  let batch = db.batch();
  let operationCount = 0;

  for (const subDoc of subscriptionsSnapshot.docs) {
    const userId = subDoc.data().userId;
    if (!userId) continue;

    const alertDocRef = db.collection("users").doc(userId).collection("alerts").doc();

    const alertData = {
      id: alertDocRef.id,
      userId,
      type: payload.type,
      title: payload.title,
      description: payload.description,
      datasetId: payload.datasetId || null,
      recordCount: payload.recordCount !== undefined ? payload.recordCount : null,
      isRead: false,
      createdAt: now,
    };

    batch.set(alertDocRef, alertData);
    operationCount++;

    if (operationCount === 500) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}
