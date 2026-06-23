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

// Break-finder — suggest the best free calendar slot for a meditation break
// after a low mood. PRIVACY: receives ONLY anonymized, structured fields:
// free-slot TIME LABELS (never event titles), enum mood/time/day strings, and
// an optional minimal rhythms context. No calendar titles, journal, mood notes,
// or any free text. Unknown keys are rejected (defense in depth).
const BREAK_SLOT_DAILY_LIMIT = 2;

export const suggestBreakSlot = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;

    const d = (request.data ?? {}) as Record<string, unknown>;
    const ALLOWED_KEYS = [
      "freeSlots", "currentMood", "timeOfDay", "dayOfWeek", "isAfter7pm", "targetDay", "rhythmsContext",
    ];
    for (const k of Object.keys(d)) {
      if (!ALLOWED_KEYS.includes(k)) {
        throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
      }
    }

    // freeSlots: short time-range labels ONLY (e.g. "2:30pm-3:00pm"). Anything
    // not matching a tight time pattern is dropped, so a title can never slip in.
    const SLOT_RE = /^[0-9:\sapm\-–]{1,40}$/i;
    const rawSlots = Array.isArray(d.freeSlots) ? d.freeSlots : [];
    const freeSlots = rawSlots
      .map((s) => String(s).trim())
      .filter((s) => s.length > 0 && s.length <= 40 && SLOT_RE.test(s))
      .slice(0, 12);
    if (freeSlots.length === 0) {
      throw new HttpsError("invalid-argument", "freeSlots required");
    }

    const MOODS = ["drained", "overwhelmed", "partlyCloudy", "clear"];
    const TIMES = ["morning", "afternoon", "evening", "night"];
    const DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    const TARGETS = ["today", "tonight", "tomorrow"];
    const currentMood = MOODS.includes(String(d.currentMood)) ? String(d.currentMood) : "drained";
    const timeOfDay = TIMES.includes(String(d.timeOfDay)) ? String(d.timeOfDay) : "afternoon";
    const dayOfWeek = DAYS.includes(String(d.dayOfWeek)) ? String(d.dayOfWeek) : "";
    const targetDay = TARGETS.includes(String(d.targetDay)) ? String(d.targetDay) : "today";

    const rc = (d.rhythmsContext ?? {}) as Record<string, unknown>;
    const TRENDS = ["down", "flat", "up"];
    const PRACTICES = ["journaling", "breathing", "gratitude", "movement", "rest", "none"];
    const rhythmsAvailable = rc.available === true;
    const hardWeekday = DAYS.includes(String(rc.hardWeekday)) ? String(rc.hardWeekday) : "";
    const recentTrend = TRENDS.includes(String(rc.recentTrend)) ? String(rc.recentTrend) : "flat";
    const helpfulPractice = PRACTICES.includes(String(rc.helpfulPractice)) ? String(rc.helpfulPractice) : "none";

    // Rate limit: max BREAK_SLOT_DAILY_LIMIT per uid per UTC day. Increment now,
    // refund on OpenAI failure so a server error never burns the cap.
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10);
    const counterRef = db.collection("breakSlotLimits").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const data = snap.data() ?? {};
      const current = (data[dayKey] as number | undefined) ?? 0;
      if (current >= BREAK_SLOT_DAILY_LIMIT) {
        throw new HttpsError("resource-exhausted", "daily break suggestion limit reached");
      }
      tx.set(
        counterRef,
        { [dayKey]: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });

    const systemPrompt =
      "you are dino, a gentle wellness companion. " +
      `a user just logged that they're feeling ${currentMood} on a ${dayOfWeek || "weekday"} ${timeOfDay}. ` +
      "pick the single best free slot from the list for a 15-20 minute meditation break. " +
      'respond ONLY with valid JSON of the form {"slot":"2:30pm","duration":20,"reason":"..."}. ' +
      "rules: lowercase, warm, under 20 words for the reason, no clinical language, no mention of data or ai, " +
      "pick the slot that gives the most buffer before the next commitment. " +
      (rhythmsAvailable
        ? `gently reference their pattern in the reason (a ${recentTrend} stretch lately` +
          `${helpfulPractice !== "none" ? `, ${helpfulPractice} tends to steady them` : ""}` +
          `${hardWeekday ? `, ${hardWeekday}s tend to be heavy` : ""}).`
        : "do not reference any patterns or history.");

    const userPrompt = `free slots: ${freeSlots.join(", ")}. target: ${targetDay}. choose one and write the reason.`;

    // Earliest slot's start time — the safe fallback if the model misbehaves.
    const fallbackSlot = freeSlots[0].split(/[-–]/)[0].trim();

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o",
        max_tokens: 150,
        temperature: 0.7,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      });
      const content = resp.choices?.[0]?.message?.content ?? "";
      let parsed: { slot?: string; duration?: number; reason?: string } = {};
      try {
        parsed = JSON.parse(content);
      } catch {
        parsed = {};
      }
      const slot = typeof parsed.slot === "string" && parsed.slot.trim().length > 0 && parsed.slot.length <= 20
        ? parsed.slot.trim()
        : fallbackSlot;
      let duration = Number(parsed.duration);
      if (!Number.isFinite(duration) || duration < 5 || duration > 30) duration = 20;
      duration = Math.round(duration);
      const reason = typeof parsed.reason === "string" && parsed.reason.trim().length > 0 && parsed.reason.length <= 200
        ? parsed.reason.trim()
        : "you have a quiet pocket coming up — a good moment to breathe 🌿";
      return { slot, duration, reason };
    } catch (err) {
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


