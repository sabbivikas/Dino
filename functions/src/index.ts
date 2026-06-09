import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import OpenAI from "openai";

admin.initializeApp();

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const DAILY_LIMIT = 5;

export const generateMoodPainting = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;

    const prompt = (request.data?.prompt ?? "") as string;
    if (typeof prompt !== "string" || prompt.length === 0 || prompt.length > 2000) {
      throw new HttpsError("invalid-argument", "prompt must be 1-2000 chars");
    }

    // Rate limit: DAILY_LIMIT successful generations per uid per UTC day
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10); // yyyy-MM-dd UTC
    const counterRef = db
      .collection("painting_quota")
      .doc(uid)
      .collection("days")
      .doc(dayKey);

    const count = await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const current = (snap.data()?.count as number | undefined) ?? 0;
      if (current >= DAILY_LIMIT) {
        throw new HttpsError("resource-exhausted", `daily limit of ${DAILY_LIMIT} reached`);
      }
      tx.set(counterRef, { count: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      return current + 1;
    });

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.images.generate({
        model: "dall-e-3",
        prompt,
        n: 1,
        size: "1024x1024",
        quality: "standard",
        style: "vivid",
      });
      const url = resp.data?.[0]?.url;
      if (!url) {
        throw new HttpsError("internal", "OpenAI returned no image url");
      }
      return { url, count };
    } catch (err) {
      // Refund the quota on OpenAI failure so the user isn't billed against their daily cap
      await counterRef.set(
        { count: admin.firestore.FieldValue.increment(-1) },
        { merge: true }
      );
      if (err instanceof HttpsError) throw err;
      const message = err instanceof Error ? err.message : "OpenAI request failed";
      throw new HttpsError("internal", message);
    }
  }
);

// Daily "forest letter" — short, poetic, single-paragraph note read aloud
// from the ambient sounds screen. Authenticated to avoid anonymous abuse;
// the iOS client caches per local-day so this is called ~once per user per day.
// Rate limit: FOREST_LETTER_DAILY_LIMIT successful generations per UID per UTC
// day so a cache-bypass loop can't burn OpenAI quota.
const FOREST_LETTER_DAILY_LIMIT = 3;

export const generateForestLetter = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;

    const weekday = (request.data?.weekday ?? "") as string;
    const monthName = (request.data?.monthName ?? "") as string;

    // Rate limit: FOREST_LETTER_DAILY_LIMIT successful generations per UID per
    // UTC day. Mirrors the pattern used by generateMoodPainting (subcollection-
    // free variant identical to generateWeeklyReport's per-field counter).
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10); // yyyy-MM-dd UTC
    const counterRef = db
      .collection("forestLetterLimits")
      .doc(uid);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const data = snap.data() ?? {};
      const current = (data[dayKey] as number | undefined) ?? 0;
      if (current >= FOREST_LETTER_DAILY_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          "daily forest letter limit reached"
        );
      }
      tx.set(
        counterRef,
        {
          [dayKey]: current + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    const systemPrompt =
      "You are the forest. Write one short daily letter to someone who visits a quiet waterfall to find peace. Connect nature with mental health in a warm poetic way. Write in lowercase. Never use dashes. Keep under 150 words. No greeting or sign off. Just the letter body. Make each day feel completely different.";
    const userPrompt = `Write today's forest letter. Today is ${weekday}, ${monthName}.`;

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o",
        max_tokens: 200,
        temperature: 0.9,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      });
      const content = resp.choices?.[0]?.message?.content ?? "";
      if (!content) {
        throw new HttpsError("internal", "OpenAI returned empty content");
      }
      return { content: content.trim() };
    } catch (err) {
      // Refund the quota on OpenAI failure so the user isn't billed against
      // their daily cap for a server-side failure.
      await counterRef.set(
        { [dayKey]: admin.firestore.FieldValue.increment(-1) },
        { merge: true }
      );
      if (err instanceof HttpsError) throw err;
      const message = err instanceof Error ? err.message : "OpenAI request failed";
      throw new HttpsError("internal", message);
    }
  }
);

// Weekly AI-generated check-in report. Server-side OpenAI call so the API
// key never ships in the iOS binary. Rate limit: 2 reports per UID per ISO
// week (so a regenerate-if-not-happy path is allowed, but abuse is bounded).
const WEEKLY_LIMIT = 2;

function isoWeekKey(date: Date): string {
  // ISO 8601 week date — the Thursday of the current week defines the year.
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(
    ((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7
  );
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

export const generateWeeklyReport = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "must be signed in");
    }
    const uid = request.auth.uid;

    const weekNumber = Number(request.data?.weekNumber ?? 0);
    const dateRange = String(request.data?.dateRange ?? "");
    const questionsAndAnswers = (request.data?.questionsAndAnswers ?? []) as Array<{
      question: string;
      score: number;
    }>;
    const previousScores = (request.data?.previousScores ?? []) as Array<{ key: string; score: number }>;

    if (!Array.isArray(questionsAndAnswers) || questionsAndAnswers.length === 0) {
      throw new HttpsError("invalid-argument", "questionsAndAnswers required");
    }

    // Rate limit: WEEKLY_LIMIT successful generations per uid per ISO week.
    const db = admin.firestore();
    const weekKey = isoWeekKey(new Date());
    const counterRef = db
      .collection("weeklyReportLimits")
      .doc(uid);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const data = snap.data() ?? {};
      const current = (data[weekKey] as number | undefined) ?? 0;
      if (current >= WEEKLY_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          `weekly limit of ${WEEKLY_LIMIT} reports reached`
        );
      }
      tx.set(
        counterRef,
        {
          [weekKey]: current + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    const systemPrompt =
      "You are Dino, a warm and empathetic mental wellness companion. You analyze weekly mental health check-in responses and generate caring, insightful wellness reports. Your tone is warm, personal, and encouraging — never clinical or alarming. Always remind users this is a reflection tool not a diagnosis.";

    const userPrompt = buildWeeklyPrompt(
      weekNumber,
      dateRange,
      questionsAndAnswers,
      previousScores
    );

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o",
        max_tokens: 800,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      });
      const content = resp.choices?.[0]?.message?.content ?? "";
      if (!content) {
        throw new HttpsError("internal", "OpenAI returned empty content");
      }
      const report = JSON.parse(content);
      return { report };
    } catch (err) {
      // Refund the quota on OpenAI failure so the user isn't billed against
      // their weekly cap for a server-side failure.
      await counterRef.set(
        { [weekKey]: admin.firestore.FieldValue.increment(-1) },
        { merge: true }
      );
      if (err instanceof HttpsError) throw err;
      const message = err instanceof Error ? err.message : "OpenAI request failed";
      throw new HttpsError("internal", message);
    }
  }
);

function buildWeeklyPrompt(
  weekNumber: number,
  dateRange: string,
  questionsAndAnswers: Array<{ question: string; score: number }>,
  previousScores: Array<{ key: string; score: number }>
): string {
  const labels = [
    "not at all",
    "several days",
    "more than half the days",
    "nearly every day",
  ];
  const lines: string[] = [];
  lines.push(
    `A user completed their weekly mental health check-in (Week ${weekNumber}, ${dateRange}). Here are their responses:`
  );
  lines.push("");
  questionsAndAnswers.forEach((qa, i) => {
    const score = Math.max(0, Math.min(3, Number(qa.score) || 0));
    lines.push(`Q${i + 1}: ${qa.question}`);
    lines.push(`A: ${labels[score]} (${score}/3)`);
  });
  lines.push("");
  if (previousScores && previousScores.length > 0) {
    const prevStr = previousScores
      .map((p) => `${p.key}=${p.score}`)
      .join(", ");
    lines.push(`Previous week scores: ${prevStr}`);
  } else {
    lines.push("Previous week scores: none (first check-in)");
  }
  lines.push("");
  lines.push(
    [
      "Return JSON with this exact shape:",
      "{",
      '  "overallScore": number 0-100,',
      '  "overallLabel": string,',
      '  "overallEmoji": string,',
      '  "moodEnergyScore": number 0-100,',
      '  "moodEnergyInsight": string (2-3 warm sentences),',
      '  "anxietyStressScore": number 0-100,',
      '  "anxietyStressInsight": string (2-3 warm sentences),',
      '  "wellbeingScore": number 0-100,',
      '  "wellbeingInsight": string (2-3 warm sentences),',
      '  "weeklyReflection": string (3-4 sentences),',
      '  "trend": "improved" | "stable" | "needs attention",',
      '  "trendNote": string (one short line)',
      "}",
    ].join("\n")
  );
  return lines.join("\n");
}

export const sendWelcomeEmailAfterTwoDays = functions.auth.user().onCreate(async (user) => {
  const email = (user.email || "").trim();
  const uid = user.uid;

  if (!email) return;
  const lower = email.toLowerCase();
  if (lower.includes("test") || lower.includes("privaterelay")) return;

  const scheduledMs = Date.now() + 2 * 24 * 60 * 60 * 1000;
  await admin.firestore().collection("emailQueue").doc(uid).set({
    email,
    name: user.displayName || "there",
    scheduledFor: admin.firestore.Timestamp.fromMillis(scheduledMs),
    sent: false,
    type: "welcome",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

const WELCOME_MESSAGE = `hi,

i'm vikas sabbi from the dino initiative team. i created the dino app.

honestly i just wanted to reach out personally because you downloaded it and that genuinely hit different for me.

dino exists because mental health apps felt too clinical, too corporate, too much like homework. i wanted to build something that actually felt like a safe space. something warm. something yours.

so i'm curious. what brought you here? what's been going on? what do you need right now?

no pressure, no agenda. i just actually want to know.

and if something feels off or broken in the app, tell me that too. i'm building this in real time and your feedback literally shapes what comes next.

if you ever want to chat for 15 mins, i'm here: cal.com/vikassabbi/15min

thank you for giving dino a shot 🌿

vikas sabbi
dino initiative team

p.s. try the gratitude jar if you haven't. drop one small good thing in there today. trust me.`;

export const processEmailQueue = onSchedule(
  { schedule: "every 60 minutes", region: "us-central1", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await admin.firestore()
      .collection("emailQueue")
      .where("sent", "==", false)
      .where("scheduledFor", "<=", now)
      .limit(100)
      .get();

    let sent = 0;
    let failed = 0;
    for (const doc of snap.docs) {
      const data = doc.data() as { email: string; name?: string; type?: string };
      try {
        const response = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            service_id: "service_bmmdob8",
            template_id: "template_dkc4sqt",
            user_id: "RtQfJvwvxaAyIwlsh",
            template_params: {
              to_email: data.email,
              user_name: data.name || "there",
              from_name: "vikas sabbi",
              subject: "sent with love from the dino team 🦕🌿",
              message: WELCOME_MESSAGE,
            },
          }),
        });
        if (!response.ok) {
          const body = await response.text();
          await doc.ref.update({
            attempts: admin.firestore.FieldValue.increment(1),
            lastError: `status ${response.status}: ${body.slice(0, 300)}`,
          });
          failed++;
          continue;
        }
        await doc.ref.update({ sent: true, sentAt: now });
        sent++;
      } catch (err) {
        const message = err instanceof Error ? err.message : "unknown error";
        await doc.ref.update({
          attempts: admin.firestore.FieldValue.increment(1),
          lastError: message.slice(0, 300),
        });
        failed++;
      }
    }
    functions.logger.info(`processEmailQueue: sent=${sent} failed=${failed} batch=${snap.docs.length}`);
  }
);


