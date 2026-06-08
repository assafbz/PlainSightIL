import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { GoogleGenerativeAI, SchemaType, Schema } from "@google/generative-ai";
import { AppLogger as logger } from "../utils/logger";

export interface AiRoadmapReview {
  importance: "High" | "Medium" | "Low";
  importanceReasoning: string;
  paymentWillingness: "High" | "Medium" | "Low";
  aiScore: number;
}

/**
 * Fallback mock logic for scoring unsupported datasets when GEMINI_API_KEY is not defined.
 */
export function getMockRoadmapReview(title: string): AiRoadmapReview {
  let importance: "High" | "Medium" | "Low" = "Medium";
  let importanceReasoning = "מאגר זה מציג נתונים בעלי חשיבות ציבורית בינונית עבור הציבור בישראל.";
  let paymentWillingness: "High" | "Medium" | "Low" = "Low";
  let aiScore = 50;

  const t = title.toLowerCase();
  if (
    t.includes("תקציב") ||
    t.includes("budget") ||
    t.includes("נדלן") ||
    t.includes("דיור") ||
    t.includes("רפואה") ||
    t.includes("בריאות") ||
    t.includes("חינוך")
  ) {
    importance = "High";
    importanceReasoning = `מאגר זה (${title}) כולל מידע בעל ערך חברתי וכלכלי רב לציבור בישראל, ומאפשר שקיפות בנושאים קריטיים של תקציבים, בריאות או דיור.`;
    paymentWillingness = "Medium";
    aiScore = 85;
  } else if (
    t.includes("ארנונה") ||
    t.includes("תחבורה") ||
    t.includes("כביש") ||
    t.includes("משרות")
  ) {
    importance = "High";
    importanceReasoning = "מידע שימושי מאוד לחיי היומיום של אזרחים ועסקים מקומיים בישראל.";
    paymentWillingness = "Low";
    aiScore = 75;
  } else if (t.includes("תרופות") || t.includes("סל הבריאות")) {
    importance = "High";
    importanceReasoning = "מידע רפואי בעל השפעה ישירה על בריאות הציבור ואיכות החיים.";
    paymentWillingness = "Medium";
    aiScore = 90;
  } else if (t.includes("תרבות") || t.includes("ספורט") || t.includes("מוזיאון")) {
    importance = "Low";
    importanceReasoning = "מאגר בעל עניין פנאי או תרבותי מקומי, שאינו קריטי לשירותים יומיומיים.";
    paymentWillingness = "Low";
    aiScore = 40;
  }

  return {
    importance,
    importanceReasoning,
    paymentWillingness,
    aiScore,
  };
}

const aiReviewSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    importance: {
      type: SchemaType.STRING,
      format: "enum",
      enum: ["High", "Medium", "Low"],
      description: "How valuable or important this data is to the general Israeli public.",
    },
    importanceReasoning: {
      type: SchemaType.STRING,
      description:
        "A brief, professional explanation in Hebrew explaining why this rating was given.",
    },
    paymentWillingness: {
      type: SchemaType.STRING,
      format: "enum",
      enum: ["High", "Medium", "Low"],
      description:
        "How likely Israeli citizens or organizations would be willing to pay for access or premium features related to this dataset.",
    },
    aiScore: {
      type: SchemaType.INTEGER,
      description: "A priority assessment score from 0 (lowest) to 100 (highest priority).",
    },
  },
  required: ["importance", "importanceReasoning", "paymentWillingness", "aiScore"],
};

/**
 * Scores an unsupported dataset using Gemini API and updates its roadmap document in Firestore.
 */
export async function scoreDatasetWithAi(
  datasetId: string,
  testDb?: admin.firestore.Firestore,
): Promise<AiRoadmapReview> {
  const db = testDb || admin.firestore();
  logger.info(`Scoring dataset ${datasetId} with AI...`);

  // 1. Fetch metadata details for the dataset
  const metaDoc = await db.collection("datasets_metadata").doc(datasetId).get();
  const requestDoc = await db.collection("dataset_requests").doc(datasetId).get();

  const metadata = metaDoc.exists ? metaDoc.data() : null;
  const requestData = requestDoc.exists ? requestDoc.data() : null;

  const title = metadata?.title || requestData?.datasetTitle || datasetId;
  const publisher = metadata?.publisher || "לא ידוע";
  const notes = metadata?.notes || "אין תיאור זמין.";
  const tags = (metadata?.tags as string[]) || [];

  const apiKey = process.env.GEMINI_API_KEY;
  let review: AiRoadmapReview;

  if (!apiKey) {
    logger.warn("GEMINI_API_KEY is not defined. Falling back to mock review.");
    review = getMockRoadmapReview(title);
  } else {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-1.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: aiReviewSchema,
          temperature: 0.2,
        },
      });

      const prompt = `You are a product management and prioritization assistant for PlainSightIL, an open-data platform in Israel.
Your job is to analyze an unsupported government dataset requested by users and evaluate its integration priority.

Analyze this dataset:
- Title (Hebrew): "${title}"
- Publisher: "${publisher}"
- Description: "${notes}"
- Tags: ${tags.join(", ")}

Evaluate and return a JSON object with:
1. "importance": "High" | "Medium" | "Low" (based on how valuable/important this data is to the general Israeli public).
2. "importanceReasoning": A brief explanation in Hebrew ("why") of your importance rating. Keep it under 2 sentences.
3. "paymentWillingness": "High" | "Medium" | "Low" (how likely Israeli citizens or organizations would be willing to pay for access or premium features related to this dataset, e.g. real-time alerts or advanced filtering).
4. "aiScore": A numerical score from 0 to 100 representing the AI's priority assessment (where 100 is top priority).

Return ONLY valid JSON matching the schema.`;

      const response = await model.generateContent(prompt);
      const text = response.response.text();
      review = JSON.parse(text) as AiRoadmapReview;
    } catch (error) {
      logger.error(`Failed to generate AI review via Gemini API for ${datasetId}:`, error);
      review = getMockRoadmapReview(title);
    }
  }

  // 2. Fetch current vote/request count
  const requestCount = requestData?.requestCount ? Number(requestData.requestCount) : 0;
  const compositeScore = requestCount * 10 + review.aiScore;

  // 3. Write/update the request document with AI score and composite score
  const updateData = {
    datasetId,
    datasetTitle: title,
    requestCount: requestCount || 0,
    lastRequestedAt: requestData?.lastRequestedAt || FieldValue.serverTimestamp(),
    aiScore: review.aiScore,
    aiImportance: review.importance,
    aiImportanceReasoning: review.importanceReasoning,
    aiMonetization: review.paymentWillingness,
    aiReviewedAt: FieldValue.serverTimestamp(),
    compositeScore,
  };

  await db.collection("dataset_requests").doc(datasetId).set(updateData, { merge: true });
  logger.info(
    `Successfully saved AI review for dataset ${datasetId} (AI Score: ${review.aiScore}, Composite: ${compositeScore})`,
  );

  return review;
}
