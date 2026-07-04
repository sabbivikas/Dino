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

// Rhythms "letter from the forest" — the night before a predicted hard day.
// PRIVACY: this function receives an ANONYMIZED, STRUCTURED summary ONLY.
// It never receives or logs journal/gratitude/free text. The prompt is built
// entirely server-side from a small allowlist of enum-like fields, and any
// unexpected field is rejected so raw content cannot reach the model even if
// the client is tampered with.
const RHYTHMS_LETTER_WEEKLY_LIMIT = 3;

function getLanguageInstruction(locale: string): string {
  const names: Record<string, string> = {
    es: "Spanish", ja: "Japanese", ko: "Korean", vi: "Vietnamese",
  };
  const name = names[locale];
  if (!name) return "";
  return ` Respond in ${name}. Keep the same warm, gentle, lowercase tone. Use informal/casual register (반말 for Korean, casual for Japanese, tú for Spanish).`;
}

export const generateRhythmsLetter = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;

    // ---- Validate + sanitize the anonymized summary (allowlist only) ----
    const d = (request.data ?? {}) as Record<string, unknown>;
    const ALLOWED_KEYS = [
      "hardWeekday", "recentTrend", "recoveryDays", "helpfulPractice", "streakState", "userLocale",
    ];
    const userLocale = typeof d.userLocale === "string" ? d.userLocale : "en";
    for (const k of Object.keys(d)) {
      if (!ALLOWED_KEYS.includes(k)) {
        // Reject unknown fields outright — prevents any free-text smuggling.
        throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
      }
    }

    const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    const TRENDS = ["down", "flat", "up"];
    const PRACTICES = ["journaling", "breathing", "gratitude", "movement", "rest", "none"];
    const STREAKS = ["growing", "steady", "fresh", "broken", "none"];

    const hardWeekday = WEEKDAYS.includes(String(d.hardWeekday)) ? String(d.hardWeekday) : "";
    const recentTrend = TRENDS.includes(String(d.recentTrend)) ? String(d.recentTrend) : "flat";
    const helpfulPractice = PRACTICES.includes(String(d.helpfulPractice)) ? String(d.helpfulPractice) : "none";
    const streakState = STREAKS.includes(String(d.streakState)) ? String(d.streakState) : "none";
    let recoveryDays = Number(d.recoveryDays);
    if (!Number.isFinite(recoveryDays) || recoveryDays < 0 || recoveryDays > 30) recoveryDays = 0;
    recoveryDays = Math.round(recoveryDays);

    if (!hardWeekday) {
      throw new HttpsError("invalid-argument", "hardWeekday required");
    }

    // ---- Rate limit: per-UID, per ISO week (letters only fire on predicted
    //      hard days, so this should rarely trigger). Increment now, refund on
    //      failure so a server error never burns the cap. ----
    const db = admin.firestore();
    const weekKey = isoWeekKey(new Date());
    const counterRef = db.collection("rhythmsLetterLimits").doc(uid);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const data = snap.data() ?? {};
      const current = (data[weekKey] as number | undefined) ?? 0;
      if (current >= RHYTHMS_LETTER_WEEKLY_LIMIT) {
        throw new HttpsError("resource-exhausted", "weekly rhythms letter limit reached");
      }
      tx.set(
        counterRef,
        { [weekKey]: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });

    // ---- Build the prompt entirely server-side from the safe fields ----
    const systemPrompt =
      "you are the forest, writing one short private letter to someone the night before a day that tends to be hard for them. " +
      "you have noticed only the shape of their days, never their words. " +
      "acknowledge the coming day softly, without alarm. gently name what tends to help them, and remind them they have moved through days like this before. " +
      "voice: warm, lowercase, plain, like a kind old tree, not a doctor. " +
      "never use clinical or diagnostic language. never mention data, tracking, apps, scores, or percentages. " +
      "no greeting line. never use dashes. keep it under 90 words. end with the signature on its own final line: the forest" +
      getLanguageInstruction(userLocale);

    const trendPhrase =
      recentTrend === "down" ? "the last few days have asked more of them" :
      recentTrend === "up" ? "the last few days have felt a little lighter" :
      "the last few days have held fairly steady";
    const practicePhrase =
      helpfulPractice === "none" ? "they have not leaned on anything in particular lately" :
      `${helpfulPractice} tends to steady them`;
    const recoveryPhrase =
      recoveryDays > 0
        ? `after a hard day they usually find their feet again within about ${recoveryDays} day${recoveryDays === 1 ? "" : "s"}`
        : "they have always found their way back before";
    const streakPhrase =
      streakState === "growing" ? "they have been showing up for themselves lately" :
      streakState === "steady" ? "they have kept a steady rhythm lately" :
      streakState === "broken" ? "they have missed a few days lately, and that is okay" :
      streakState === "fresh" ? "they have just begun again" : "";

    const userPrompt = [
      `tomorrow is a ${hardWeekday}, a day that tends to ask a lot of them.`,
      `${trendPhrase}.`,
      `${practicePhrase}.`,
      `${recoveryPhrase}.`,
      streakPhrase ? `${streakPhrase}.` : "",
      "write tomorrow's letter from the forest.",
    ].filter(Boolean).join(" ");

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o",
        max_tokens: 200,
        temperature: 0.85,
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
      // Refund the weekly quota on failure so the user isn't billed against
      // their cap for a server-side error.
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

// Break-finder — suggest the best free calendar slot for a meditation break
// after a low mood. PRIVACY: receives ONLY anonymized, structured fields:
// free-slot TIME LABELS (never event titles), enum mood/time/day strings, and
// an optional minimal rhythms context. No calendar titles, journal, mood notes,
// or any free text. Unknown keys are rejected (defense in depth).
const BREAK_SLOT_DAILY_LIMIT = 5;

export const suggestBreakSlot = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;

    const d = (request.data ?? {}) as Record<string, unknown>;
    const ALLOWED_KEYS = [
      "userMessage", "currentMood", "freeSlots", "timeOfDay", "dayOfWeek", "isAfter7pm", "rhythmsContext", "userLocale", "nowTime",
    ];
    const userLocale = typeof d.userLocale === "string" ? d.userLocale : "en";
    for (const k of Object.keys(d)) {
      if (!ALLOWED_KEYS.includes(k)) {
        throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
      }
    }

    // freeSlots: short time-range labels ONLY (e.g. "7:30pm-8:00pm"). May be
    // empty (calendar full) — that is handled, not an error.
    const SLOT_RE = /^[0-9:\sapm\-–]{1,40}$/i;
    const rawSlots = Array.isArray(d.freeSlots) ? d.freeSlots : [];
    const freeSlots = rawSlots
      .map((s) => String(s).trim())
      .filter((s) => s.length > 0 && s.length <= 40 && SLOT_RE.test(s))
      .slice(0, 12);

    // userMessage: the user's own free text. Capped + trimmed. Sent to the
    // model ONLY — never logged, never stored. Empty string == skipped.
    const userMessage = String(d.userMessage ?? "").slice(0, 300).trim();

    const MOODS = ["drained", "overwhelmed", "partlyCloudy", "clear"];
    const TIMES = ["morning", "afternoon", "evening", "night"];
    const DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    const ACTIVITIES = ["breathing", "meditation", "journaling"];
    const currentMood = MOODS.includes(String(d.currentMood)) ? String(d.currentMood) : "drained";
    const timeOfDay = TIMES.includes(String(d.timeOfDay)) ? String(d.timeOfDay) : "afternoon";
    const dayOfWeek = DAYS.includes(String(d.dayOfWeek)) ? String(d.dayOfWeek) : "";
    const nowTime = String(d.nowTime ?? "").trim();

    const rc = (d.rhythmsContext ?? {}) as Record<string, unknown>;
    const PRACTICES = ["journaling", "breathing", "gratitude", "movement", "rest", "none"];
    const rhythmsAvailable = rc.available === true;
    const helpfulPractice = PRACTICES.includes(String(rc.helpfulPractice)) ? String(rc.helpfulPractice) : "none";

    // Safe fallback — also used on any JSON parse failure.
    const fallbackTime = freeSlots.length > 0 ? freeSlots[0] : "";
    const FALLBACK = {
      acknowledgment: "today sounds heavy",
      suggestedActivity: "breathing",
      reason: "a quiet moment to breathe 🌿",
      recommendedTime: fallbackTime,
    };

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

    const slotList = freeSlots.length > 0 ? freeSlots.join(", ") : "(none available)";
    const systemPrompt =
      "you are dino, a gentle wellness companion. " +
      `a user just logged that they're feeling ${currentMood}. ` +
      (userMessage ? `they wrote: "${userMessage}". ` : "they did not write anything; respond based on mood alone. ") +
      `it is currently around ${nowTime || timeOfDay} on a ${dayOfWeek || "weekday"} ${timeOfDay}. ` +
      `these are their free slots, earliest first: ${slotList}. ` +
      "choose the ONE slot that best fits BOTH their words and their calendar: " +
      "if they sound exhausted, urgent, or overwhelmed, prefer the soonest slot; " +
      "if they mention a specific commitment or time (e.g. a meeting at 2), pick a slot comfortably after it; " +
      "if their message mentions no timing constraints, prefer sooner over later. " +
      "respond ONLY with valid JSON, no markdown, of the form " +
      '{"acknowledgment":"...","suggestedActivity":"breathing","reason":"...","recommendedTime":"9:00am","theme":"work"}. ' +
      "acknowledgment: one short warm sentence acknowledging what they wrote, lowercase, no clinical language. " +
      "suggestedActivity: exactly one of breathing, meditation, journaling. " +
      "reason: one short warm sentence on why this activity and this time fit what they shared, lowercase. " +
      "recommendedTime: copy ONE of the listed times EXACTLY as written. " +
      "theme: the life area their message is mainly about — exactly one of work, sleep, relationships, health, money, self, or none. use none if there is no message or no clear theme. never guess. " +
      "activity rules: overwhelmed or overthinking -> breathing; low energy or exhausted -> meditation; emotional, sad, or hard day -> journaling. " +
      (userMessage ? "" : "with no message: overwhelmed -> breathing, drained -> meditation. ") +
      (rhythmsAvailable && helpfulPractice !== "none" ? `if it fits, prefer ${helpfulPractice}. ` : "") +
      "never mention data, tracking, ai, or apps." +
      getLanguageInstruction(userLocale);

    const userPrompt = userMessage
      ? `now: ${nowTime || timeOfDay}. mood: ${currentMood}. message: "${userMessage}". day: ${dayOfWeek || "today"} ${timeOfDay}. free slots (earliest first): ${slotList}.`
      : `now: ${nowTime || timeOfDay}. mood: ${currentMood}. (no message). day: ${dayOfWeek || "today"} ${timeOfDay}. free slots (earliest first): ${slotList}.`;

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o",
        max_tokens: 200,
        temperature: 0.85,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      });
      const content = resp.choices?.[0]?.message?.content ?? "";
      let parsed: any = {};
      try { parsed = JSON.parse(content); } catch { parsed = {}; }

      const acknowledgment =
        typeof parsed.acknowledgment === "string" && parsed.acknowledgment.trim().length > 0 && parsed.acknowledgment.length <= 200
          ? parsed.acknowledgment.trim()
          : (userMessage ? FALLBACK.acknowledgment : "today sounds heavy — let's find you a moment");
      const suggestedActivity = ACTIVITIES.includes(String(parsed.suggestedActivity))
        ? String(parsed.suggestedActivity)
        : FALLBACK.suggestedActivity;
      const reason =
        typeof parsed.reason === "string" && parsed.reason.trim().length > 0 && parsed.reason.length <= 200
          ? parsed.reason.trim()
          : FALLBACK.reason;

      // Keep only model slots whose time matches a real provided slot.
      const norm = (s: string) => s.trim().toLowerCase().replace(/\s+/g, "");
      const byNorm = new Map(freeSlots.map((s) => [norm(s), s]));
      const recommendedTime =
        (typeof parsed.recommendedTime === "string" ? byNorm.get(norm(parsed.recommendedTime)) : undefined)
          ?? FALLBACK.recommendedTime;

      const THEMES = ["work", "sleep", "relationships", "health", "money", "self", "none"];
      const theme = THEMES.includes(String(parsed.theme)) ? String(parsed.theme) : "none";

      return { acknowledgment, suggestedActivity, reason, recommendedTime, theme };
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

// Coarse theme classification of a single journal entry (DinoMind, opt-in on
// the client). Text is used ONLY for the OpenAI call — never logged or stored;
// only the enum theme is returned. Rate limit: THEME_EXTRACT_DAILY_LIMIT per
// UID per UTC day — journal entries are infrequent, so the cap is low; the
// client degrades silently (no theme tag) when it's hit.
const THEME_EXTRACT_DAILY_LIMIT = 12;

export const extractJournalTheme = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 20, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;
    const d = (request.data ?? {}) as Record<string, unknown>;
    for (const k of Object.keys(d)) {
      if (k !== "text") throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
    }
    const text = String(d.text ?? "").slice(0, 1000).trim();
    if (!text) return { theme: "none" };   // free — no model call, no quota burn

    // Rate limit — house pattern: per-UID daily counter, refund on failure.
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10);
    const counterRef = db.collection("themeExtractLimits").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const current = ((snap.data() ?? {})[dayKey] as number | undefined) ?? 0;
      if (current >= THEME_EXTRACT_DAILY_LIMIT) {
        throw new HttpsError("resource-exhausted", "daily theme extraction limit reached");
      }
      tx.set(
        counterRef,
        { [dayKey]: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });

    const systemPrompt =
      "you are a careful classifier. read one private journal entry and label the single life area it is mainly about. " +
      'respond ONLY with valid JSON, no markdown: {"theme":"work"}. ' +
      "theme is exactly one of work, sleep, relationships, health, money, self, or none. " +
      "use none if the entry is empty, ambiguous, or has no clear single theme. never guess. " +
      "never quote, repeat, or store the entry; output only the JSON.";

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        max_tokens: 20,
        temperature: 0,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `entry: "${text}"` },
        ],
      });
      const content = resp.choices[0]?.message?.content ?? "";
      let parsed: any = {};
      try { parsed = JSON.parse(content); } catch { parsed = {}; }
      const THEMES = ["work", "sleep", "relationships", "health", "money", "self", "none"];
      const theme = THEMES.includes(String(parsed.theme)) ? String(parsed.theme) : "none";
      return { theme };
    } catch (err) {
      // Refund — a server-side failure never burns the user's daily cap.
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

// One warm, context-aware daily check-in nudge (DinoMind). Anonymized payload
// only; the client caches one per local day and falls back to static copy.
const DAILY_NUDGE_LIMIT = 3;

export const generateDailyNudge = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 20, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;
    const d = (request.data ?? {}) as Record<string, unknown>;
    const ALLOWED_KEYS = ["lastMood", "streakState", "sleepSummary", "weekday", "riskLevel", "topTheme", "userLocale"];
    for (const k of Object.keys(d)) {
      if (!ALLOWED_KEYS.includes(k)) throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
    }
    const userLocale = typeof d.userLocale === "string" ? d.userLocale : "en";
    const lastMood = String(d.lastMood ?? "").slice(0, 40);
    const streakState = String(d.streakState ?? "").slice(0, 40);
    const sleepSummary = String(d.sleepSummary ?? "").slice(0, 60);
    const weekday = String(d.weekday ?? "").slice(0, 20);
    const riskLevel = String(d.riskLevel ?? "").slice(0, 20);
    const topTheme = String(d.topTheme ?? "").slice(0, 20);

    // Rate limit: DAILY_NUDGE_LIMIT per uid per UTC day (defense in depth; the
    // client already caches one nudge per local day).
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10);
    const counterRef = db.collection("dailyNudgeLimits").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const data = snap.data() ?? {};
      const current = (data[dayKey] as number | undefined) ?? 0;
      if (current >= DAILY_NUDGE_LIMIT) {
        throw new HttpsError("resource-exhausted", "daily nudge limit reached");
      }
      tx.set(counterRef, { [dayKey]: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });

    const systemPrompt =
      "you are dino, a warm, gentle wellness companion. " +
      "write ONE short check-in nudge as a single lowercase sentence in dino's voice: warm, no dashes, " +
      "no clinical language, never pressuring or guilt-inducing. keep it very short, it is a notification. " +
      "gently invite them to check in when they can. you may lightly reflect their recent context but never " +
      'mention data, tracking, ai, apps, scores, or numbers. respond ONLY with valid JSON, no markdown: {"nudge":"..."}.' +
      getLanguageInstruction(userLocale);

    const parts = [`mood lately: ${lastMood || "unknown"}.`, `streak: ${streakState || "unknown"}.`];
    if (sleepSummary) parts.push(`last night: ${sleepSummary}.`);
    if (weekday) parts.push(`today is ${weekday}.`);
    if (riskLevel) parts.push(`tomorrow looks ${riskLevel}.`);
    if (topTheme) parts.push(`a recurring theme for them is ${topTheme}.`);
    const userPrompt = parts.join(" ");

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        max_tokens: 60,
        temperature: 0.8,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      });
      const content = resp.choices[0]?.message?.content ?? "";
      let parsed: any = {};
      try { parsed = JSON.parse(content); } catch { parsed = {}; }
      const nudge = typeof parsed.nudge === "string" && parsed.nudge.trim().length > 0 && parsed.nudge.length <= 200
        ? parsed.nudge.trim()
        : "";
      if (!nudge) throw new HttpsError("internal", "empty nudge");
      return { nudge };
    } catch (err) {
      await counterRef.set({ [dayKey]: admin.firestore.FieldValue.increment(-1) }, { merge: true });
      if (err instanceof HttpsError) throw err;
      const message = err instanceof Error ? err.message : "OpenAI request failed";
      throw new HttpsError("internal", message);
    }
  }
);

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

// ---------------------------------------------------------------------------
// DINO WORLD — hourly aggregation of anonymous worldMoods into ONE summary doc.
// Raw docs: {mood, countryCode, dayKey, createdAt, expiresAt(TTL ~48h)}.
// Output worldAggregate/current: { updatedAt, days: { dayKey: { global, countries } } }
// • countries with fewer than WORLD_PRIVACY_FLOOR logs that day fold into
//   "elsewhere" (privacy floor — small countries never singled out)
// • only the newest 7 dayKeys are retained (week rewind)
// • idempotent: days still inside the 48h raw window are rebuilt from scratch
//   each run; older retained days keep their final values.
// ---------------------------------------------------------------------------
const WORLD_PRIVACY_FLOOR = 5;
const WORLD_MOODS = ["clear", "partlyCloudy", "overwhelmed", "drained"] as const;

export const aggregateWorldMoods = onSchedule("every 60 minutes", async () => {
  const db = admin.firestore();
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 48 * 3600 * 1000);
  const snap = await db.collection("worldMoods").where("createdAt", ">", cutoff).get();

  // dayKey -> countryCode -> mood -> count
  const grouped: Record<string, Record<string, Record<string, number>>> = {};
  snap.forEach((doc) => {
    const d = doc.data();
    const mood = String(d.mood ?? "");
    if (!(WORLD_MOODS as readonly string[]).includes(mood)) return;
    const dayKey = String(d.dayKey ?? "");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dayKey)) return;
    const rawCountry = String(d.countryCode ?? "").toUpperCase();
    const country = /^[A-Z]{2}$/.test(rawCountry) ? rawCountry : "elsewhere";
    grouped[dayKey] ??= {};
    grouped[dayKey][country] ??= {};
    grouped[dayKey][country][mood] = (grouped[dayKey][country][mood] ?? 0) + 1;
  });

  const aggRef = db.collection("worldAggregate").doc("current");
  const existing = (await aggRef.get()).data() ?? {};
  const outDays: Record<string, unknown> = { ...((existing.days ?? {}) as Record<string, unknown>) };

  for (const [dayKey, countries] of Object.entries(grouped)) {
    const global: Record<string, number> = { clear: 0, partlyCloudy: 0, overwhelmed: 0, drained: 0, total: 0 };
    const elsewhere: Record<string, number> = { clear: 0, partlyCloudy: 0, overwhelmed: 0, drained: 0, total: 0 };
    const outCountries: Record<string, Record<string, number>> = {};

    for (const [country, moods] of Object.entries(countries)) {
      const counts: Record<string, number> = { clear: 0, partlyCloudy: 0, overwhelmed: 0, drained: 0, total: 0 };
      for (const m of WORLD_MOODS) {
        const n = moods[m] ?? 0;
        counts[m] = n;
        counts.total += n;
        global[m] += n;
        global.total += n;
      }
      if (country === "elsewhere" || counts.total < WORLD_PRIVACY_FLOOR) {
        for (const m of WORLD_MOODS) elsewhere[m] += counts[m];
        elsewhere.total += counts.total;
      } else {
        outCountries[country] = counts;
      }
    }
    if (elsewhere.total > 0) outCountries["elsewhere"] = elsewhere;
    outDays[dayKey] = { global, countries: outCountries };
  }

  // Retain only the newest 7 dayKeys (lexicographic == chronological for yyyy-MM-dd).
  const keep = Object.keys(outDays).sort().slice(-7);
  const trimmed: Record<string, unknown> = {};
  for (const k of keep) trimmed[k] = outDays[k];

  await aggRef.set({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    days: trimmed,
  });
});

// ---------------------------------------------------------------------------
// DINO WORLD PHASE 2 — LANTERNS.
// moderateLantern: strict gpt-4o-mini gate; ONLY approved lanterns enter the
// pool, written SERVER-SIDE with no uid in the doc (sender anonymity). The
// user's words are never rewritten — approved verbatim or rejected.
// claimLantern: transactional oldest-undelivered pick; receiver capped at one
// per day via lanternClaims/{uid} (receiver identity known, sender's never).
// ---------------------------------------------------------------------------
const LANTERN_DAILY_SEND_LIMIT = 3;
const LANTERN_MAX_CHARS = 140;

export const moderateLantern = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;
    const d = (request.data ?? {}) as Record<string, unknown>;
    for (const k of Object.keys(d)) {
      if (k !== "text" && k !== "countryCode") {
        throw new HttpsError("invalid-argument", `unexpected field: ${k}`);
      }
    }
    const text = String(d.text ?? "").trim();
    if (text.length === 0 || text.length > LANTERN_MAX_CHARS) {
      throw new HttpsError("invalid-argument", `text must be 1-${LANTERN_MAX_CHARS} chars`);
    }
    const rawCountry = String(d.countryCode ?? "").toUpperCase();
    const countryCode = /^[A-Z]{2}$/.test(rawCountry) ? rawCountry : "elsewhere";

    // Rate limit: LANTERN_DAILY_SEND_LIMIT sends per uid per UTC day.
    // Rejections COUNT toward the cap (prevents brute-forcing the moderator);
    // only server-side failures are refunded.
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10);
    const counterRef = db.collection("lanternLimits").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(counterRef);
      const current = ((snap.data() ?? {})[dayKey] as number | undefined) ?? 0;
      if (current >= LANTERN_DAILY_SEND_LIMIT) {
        throw new HttpsError("resource-exhausted", "daily lantern limit reached");
      }
      tx.set(counterRef, { [dayKey]: current + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });

    const systemPrompt =
      "you are a strict content gate for lanterns: tiny anonymous kindness notes sent between strangers " +
      "in a mental wellness app. many receivers are having a hard day and may be fragile. " +
      "approve ONLY messages that are warm, kind, gentle, and safe for anyone to read. " +
      "reject if the message contains ANY of: a person's name or signature; contact info, usernames, or social handles; " +
      "urls, apps, or promotion of anything; negativity, criticism, sarcasm, or dark humor; " +
      "anything sexual, violent, or about self harm, even supportive mentions; " +
      "medical, financial, legal, or life advice; religious or political content; " +
      "requests to meet, reply, or connect; anything that could identify the sender or the receiver. " +
      "when unsure, reject. " +
       'respond ONLY with valid JSON, no markdown: {"approved": true, "reason": "one short lowercase phrase"}. ' +
      "never rewrite, correct, or quote the message.";

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const resp = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        max_tokens: 60,
        temperature: 0,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `lantern: "${text}"` },
        ],
      });
      const content = resp.choices[0]?.message?.content ?? "";
      let parsed: any = {};
      try { parsed = JSON.parse(content); } catch { parsed = {}; }
      const approved = parsed.approved === true;

      if (approved) {
        // Server-side pool write — the delivered doc carries NO uid, ever.
        await db.collection("lanterns").add({
          text,
          countryCode,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          delivered: false,
        });
      }
      return { approved };
    } catch (err) {
      await counterRef.set({ [dayKey]: admin.firestore.FieldValue.increment(-1) }, { merge: true });
      if (err instanceof HttpsError) throw err;
      const message = err instanceof Error ? err.message : "moderation failed";
      throw new HttpsError("internal", message);
    }
  }
);

export const claimLantern = onCall(
  { timeoutSeconds: 20, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();
    const dayKey = new Date().toISOString().slice(0, 10);
    const claimRef = db.collection("lanternClaims").doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const claimSnap = await tx.get(claimRef);
      const lastDay = (claimSnap.data() ?? {}).lastClaimDayKey as string | undefined;
      if (lastDay === dayKey) {
        return null;   // max one received lantern per day
      }
      const poolQuery = db.collection("lanterns")
        .where("delivered", "==", false)
        .orderBy("createdAt", "asc")
        .limit(1);
      const pool = await tx.get(poolQuery);
      if (pool.empty) {
        return null;   // empty pool → nothing shows client-side
      }
      const doc = pool.docs[0];
      const data = doc.data();
      tx.update(doc.ref, { delivered: true, deliveredDayKey: dayKey });
      tx.set(claimRef, { lastClaimDayKey: dayKey, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      // Payload exposes only what the card shows — never any sender identity.
      return {
        text: String(data.text ?? ""),
        countryCode: String(data.countryCode ?? "elsewhere"),
        createdAt: (data.createdAt?.toMillis?.() as number | undefined) ?? Date.now(),
      };
    });

    return { lantern: result };
  }
);

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


