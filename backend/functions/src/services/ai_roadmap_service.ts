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
export function getMockRoadmapReview(
  title: string,
  notes: string = "",
  publisher: string = "",
): AiRoadmapReview {
  let importance: "High" | "Medium" | "Low" = "Medium";
  let importanceReasoning = "מאגר זה מציג נתונים בעלי חשיבות ציבורית בינונית עבור הציבור בישראל.";
  let paymentWillingness: "High" | "Medium" | "Low" = "Low";
  let aiScore = 50;

  const t = title.toLowerCase();
  const n = notes.toLowerCase();
  const p = publisher.toLowerCase();

  // 1. High Priority - Critical Services & Health & Safety (85 - 95)
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
  } else if (t.includes("תרופות") || t.includes("סל הבריאות")) {
    importance = "High";
    importanceReasoning = "מידע רפואי בעל השפעה ישירה על בריאות הציבור ואיכות החיים.";
    paymentWillingness = "Medium";
    aiScore = 90;
  } else if (
    t.includes("איכות הסביבה") ||
    t.includes("קרינה") ||
    t.includes("אנטנה") ||
    t.includes("זיהום") ||
    t.includes("מזון") ||
    t.includes("רעל") ||
    n.includes("קרינה") ||
    n.includes("זיהום") ||
    n.includes("מפגע")
  ) {
    importance = "High";
    importanceReasoning = "מאגר בעל חשיבות סביבתית ובריאותית גבוהה ביותר עבור הציבור בישראל.";
    paymentWillingness = "Medium";
    aiScore = 88;
  }
  // 2. High Priority - Daily Citizen Utility & Transport (70 - 80)
  else if (
    t.includes("ארנונה") ||
    t.includes("תחבורה") ||
    t.includes("כביש") ||
    t.includes("משרות") ||
    t.includes("רכבת") ||
    t.includes("אוטובוס") ||
    t.includes("חניה") ||
    t.includes("נסיעה") ||
    t.includes("תעסוקה") ||
    n.includes("תחבורה") ||
    n.includes("נסיעה")
  ) {
    importance = "High";
    importanceReasoning = "מידע שימושי מאוד לחיי היומיום של אזרחים ועסקים מקומיים בישראל.";
    paymentWillingness = "Low";
    aiScore = 75;
  }
  // 3. Medium/High Priority - Transparency & Corporate/Financial (60 - 70)
  else if (
    t.includes("חברות") ||
    t.includes("פירוק") ||
    t.includes("עמותות") ||
    t.includes("מכרז") ||
    t.includes("חוזים") ||
    t.includes("תמיכות") ||
    t.includes("הון") ||
    t.includes("אגח") ||
    n.includes("שקיפות") ||
    n.includes("מכרזים")
  ) {
    importance = "Medium";
    importanceReasoning =
      "מאגר זה תורם לשקיפות פיננסית ותאגידית בישראל, ומאפשר לציבור לפקח על פעילות כלכלית וציבורית.";
    paymentWillingness = "Low";
    aiScore = 65;
  }
  // 4. Low Priority - Culture & Leisure (40 - 50)
  else if (
    t.includes("תרבות") ||
    t.includes("ספורט") ||
    t.includes("מוזיאון") ||
    t.includes("אומנות") ||
    t.includes("פנאי") ||
    t.includes("תיירות") ||
    t.includes("אירועים")
  ) {
    importance = "Low";
    importanceReasoning = "מאגר בעל עניין פנאי או תרבותי מקומי, שאינו קריטי לשירותים יומיומיים.";
    paymentWillingness = "Low";
    aiScore = 40;
  }
  // 5. Low Priority - Bureaucratic / Internal / Statistical (20 - 35)
  else if (
    t.includes("פרוטוקול") ||
    t.includes("ארכיון") ||
    t.includes("פנימי") ||
    t.includes("נוהל") ||
    t.includes("רישום") ||
    t.includes("סטטיסטיקה") ||
    n.includes("פנימי") ||
    n.includes("סטטיסטיקה") ||
    n.includes("נוהל")
  ) {
    importance = "Low";
    importanceReasoning =
      "מאגר זה מציג נתונים מנהליים פנימיים או סטטיסטיים בעלי עניין ציבורי נמוך יחסית ביומיום.";
    paymentWillingness = "Low";
    aiScore = 25;
  }

  // Apply dynamic score boosts for publisher/notes (capped at 100)
  if (aiScore > 0) {
    const isMajorPublisher =
      p.includes("בריאות") ||
      p.includes("אוצר") ||
      p.includes("תחבורה") ||
      p.includes("חינוך") ||
      p.includes("איכות הסביבה") ||
      p.includes("רשות המים") ||
      p.includes("משפטים") ||
      p.includes("פנים");

    if (isMajorPublisher) {
      aiScore += 5;
    }
    if (notes && notes.length > 50) {
      aiScore += 3;
    }
    aiScore = Math.max(0, Math.min(100, aiScore));
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
    review = getMockRoadmapReview(title, notes, publisher);
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
Your job is to analyze an unsupported government dataset requested by users and evaluate its integration priority based on its value for accessibility to the Israeli public.

Analyze this dataset:
- Title (Hebrew): "${title}"
- Publisher: "${publisher}"
- Description: "${notes}"
- Tags: ${tags.join(", ")}

Your prioritization criteria should focus on assessing the value of making this dataset easily accessible and visualized for the general Israeli public:
- High Priority (Scores 75-100): Datasets directly impacting daily life, health, safety, local municipal services, public transport, housing, or transparency of public funds (budgets, tenders).
- Medium Priority (Scores 40-74): Datasets of moderate public interest, corporate structures, non-critical services, or general cultural/leisure/tourism information.
- Low Priority (Scores 0-39): Obscure, niche, highly administrative, or internal bureaucratic datasets with minimal everyday public utility.

Evaluate and return a JSON object with:
1. "importance": "High" | "Medium" | "Low" (based on how valuable/important this data is to the general Israeli public).
2. "importanceReasoning": A brief explanation in Hebrew ("why") of your importance rating. Keep it under 2 sentences. Focus on the value of making this data accessible to the public.
3. "paymentWillingness": "High" | "Medium" | "Low" (how likely Israeli citizens or organizations would be willing to pay for access or premium features related to this dataset, e.g. real-time alerts or advanced filtering).
4. "aiScore": A numerical score from 0 to 100 representing the AI's priority assessment (where 100 is top priority).

Return ONLY valid JSON matching the schema.`;

      const response = await model.generateContent(prompt);
      const text = response.response.text();
      review = JSON.parse(text) as AiRoadmapReview;
    } catch (error) {
      logger.error(`Failed to generate AI review via Gemini API for ${datasetId}:`, error);
      review = getMockRoadmapReview(title, notes, publisher);
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
