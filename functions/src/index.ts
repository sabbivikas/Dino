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


