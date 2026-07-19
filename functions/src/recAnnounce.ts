// recAnnounce.ts — rec delivery arc F3: the announcement payload, as PURE
// functions (no firebase imports — node --test runs these directly).
// index.ts wires them to FCM.
//
// THE CONTENT-FREE RULE: the push can never carry rec content. The builder's
// signature makes this structural — it accepts a token and a deliveryId and
// nothing else, and the alert uses APNs loc-keys so every visible word lives
// in the APP's string catalog (device-side localization: en/es/ja/ko/vi
// resolve on the phone; the server ships zero copy in zero languages).

export const REC_ANNOUNCEMENT_TITLE_LOC_KEY = "rec_announcement_title";
export const REC_ANNOUNCEMENT_BODY_LOC_KEY = "rec_announcement_body";
export const REC_ANNOUNCEMENT_CATEGORY = "REC_ANNOUNCEMENT";
export const REC_PUSH_TOKENS_COLLECTION = "pushTokens";
export const REC_PUSH_TOKEN_MAX_LENGTH = 512;   // firestore.rules twin

/** dino://rec-reveal/{deliveryId} — ContentView routes it (F4's reveal). */
export function recRevealDeepLink(deliveryId: string): string {
  return `dino://rec-reveal/${deliveryId}`;
}

/** Client-registered token sanity (shape only; FCM validates for real). */
export function isPlausiblePushToken(token: unknown): token is string {
  return typeof token === "string" && token.length > 0 &&
    token.length <= REC_PUSH_TOKEN_MAX_LENGTH && !/\s/.test(token);
}

/**
 * The FCM message for one announced delivery. admin.messaging().send()
 * takes this verbatim (TokenMessage shape). Deliberately NO `notification`
 * block and NO literal alert text: the apns alert carries loc-keys only,
 * plus the deliveryId + deep link the tap needs to reach the reveal.
 */
export function buildRecAnnouncementMessage(token: string, deliveryId: string) {
  return {
    token,
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: {
            titleLocKey: REC_ANNOUNCEMENT_TITLE_LOC_KEY,
            locKey: REC_ANNOUNCEMENT_BODY_LOC_KEY,   // APNs: the BODY's key is loc-key
          },
          sound: "default",
          category: REC_ANNOUNCEMENT_CATEGORY,
        },
        deliveryId,
        deepLink: recRevealDeepLink(deliveryId),
      },
    },
  };
}
