# Analytics Identity Lifecycle (PostHog + Firebase Auth)

This app is **native SwiftUI**. PostHog is the **iOS SDK** (`PostHogSDK.shared`).
The identity lifecycle lives in [`Dino/Analytics/IdentityLifecycle.swift`](Dino/Analytics/IdentityLifecycle.swift),
wired into [`Dino/DinoApp.swift`](Dino/DinoApp.swift) and
[`Dino/Data/AuthManager.swift`](Dino/Data/AuthManager.swift).

> Note: there is intentionally **no `reset(true)`**. The iOS SDK's `reset()`
> takes no Boolean argument.

## Stable ID strategy

- The **Firebase UID** is the only authenticated PostHog distinct id.
- The **email is never** used as a distinct id.
- `identify()` is only ever called with a Firebase UID — never an anonymous UUID.
- A new authenticated id is **not** generated per session; PostHog persists the
  distinct id across launches, and re-`identify()` with the same UID is stable.
- `safeProperties()` person properties are **non-sensitive only** (`platform`).
  No journal text, gratitude text, mood notes, private reflections, tokens, or
  full user profiles are ever sent as person properties.

## Cold-start flow (`handleColdStart`, runs once per process)

1. `session restoration started`
2. `resolveAuthenticatedUser()` waits up to **5s** for the first Firebase auth
   callback (`addStateDidChangeListener`), settling exactly once:
   - returns the UID if present,
   - returns `nil` on timeout or signed-out,
   - clears the timer and removes the listener on completion,
   - is safe if the listener fires synchronously before assignment.
3. If a UID is present → `identify(uid, safeProperties)` (`PostHog identify completed`).
   Otherwise → start **late identity recovery** (below).
4. Capture **one** `app_opened` with `open_type: "cold_start"` (and `is_first_open`).

Order guarantee: **identify happens before** `app_opened` for a logged-in cold launch.

## Foreground-return flow (`handleForegroundReturn`)

- On `scenePhase == .active` **after** cold start, capture **one** `app_opened`
  with `open_type: "foreground"`.
- No re-`identify()`, no second cold-start event.
- In SwiftUI, `onChange(of: scenePhase)` does **not** fire for the initial
  `.active` at mount, so the cold-launch active is never misclassified as a
  foreground return (the RN "first AppState active" pitfall does not apply here).
  A `coldStartComplete` guard adds belt-and-suspenders.

## Late identity recovery (`startLateIdentityRecovery`)

Closes the gap where Firebase restores **after** the 5s cold-start window:

- Armed **only** when cold start timed out / found no user.
- Listens for Firebase auth to become available.
- On the first non-nil UID → `identify(uid, safeProperties)` **once**
  (`lateIdentityRecoveryComplete` guard), then removes its listener.
- Does **not** fire another `app_opened` and does not change product behavior.
- Because PostHog only `reset()`s on logout, the earlier anonymous cold-start
  events merge into the now-identified person.

## Logout flow (`handleLogout`, used by `AuthManager.signOut`)

1. `capture("user_signed_out", properties)` — while still identified.
2. `reset()` — **no arguments**.
3. Caller clears the Firebase/Google/local session (`Auth.auth().signOut()`, …).

Because `reset()` runs between accounts, a **second account on the same device is
not aliased** to the previous account.

## Duplicate-event protections

- Cold-start logic runs **once per process** (`coldStartComplete`).
- PostHog automatic lifecycle capture is **disabled**
  (`config.captureApplicationLifecycleEvents = false` in `DinoApp.init`) so the
  custom `app_opened` is never combined with PostHog's `Application Opened`.
- Signup / login call `identify()` (in `AuthManager`) but do **not** emit a
  duplicate `app_opened`.
- Foreground returns use `open_type: "foreground"`; cold launch uses
  `open_type: "cold_start"`.

## DEBUG-only validation logs

Gated behind `#if DEBUG`, prefixed `[Identity]`. Only high-level lifecycle
messages are logged (session restoration started, authenticated user found,
Firebase timeout reached, PostHog identify completed, late identity recovery
completed, app_opened captured with open type, logout reset completed, duplicate
lifecycle call blocked). **Never** tokens, journal/gratitude/mood/private text,
or full profiles.

## Manual physical-device checklist

Run on a real iPhone with the **Xcode console** attached and **PostHog →
Activity / Live Events** open. DEBUG logs are prefixed `[Identity]` (and `[Auth]`
for sign-in). The UID in logs is redacted to the last 4 chars (`uid:…XXXX`).

> **Verification status — 2026-06-30: T1–T8 all PASSED on a physical iPhone.**
> Observed PostHog ingestion lag: Live Events trailed the `[Identity]` console
> logs by roughly 10–30s (normal SDK batching). All sequences, `open_type`
> values, and distinct ids matched expectations once events arrived.

### ☑ T1 — Logged-in cold launch — PASS (2026-06-30)
- **Action:** While signed in, force-quit the app, then relaunch.
- **Console:** `session restoration started` → `authenticated user found` →
  `identify called (uid:…XXXX)` → `PostHog identify completed` →
  `app_opened captured: cold_start`.
- **PostHog:** `$identify` (distinct id = Firebase UID) **then** `app_opened`
  with `open_type=cold_start`.
- **Pass/Fail:** PASS if identify precedes `app_opened`, distinct id is the UID,
  and exactly one `app_opened`. FAIL on anonymous id, wrong order, or duplicates.

### ☑ T2 — Signup (new account) — PASS (2026-06-30)
- **Action:** Fresh signup (email/Google/Apple) from a signed-out state.
- **Console:** `[Auth] … sign-up succeeded` and an `$identify` to PostHog. No
  `[Identity] app_opened captured` line is expected from signup itself.
- **PostHog:** `$identify` (UID) → `user_signed_up`. No extra `app_opened`.
- **Pass/Fail:** PASS if signup creates exactly one identified person (UID) with
  no duplicate `app_opened`. FAIL if a second `app_opened` or an anonymous id.

### ☑ T3 — Returning login — PASS (2026-06-30)
- **Action:** Sign out, then sign back in as the same user.
- **Console:** `[Auth] … sign-in succeeded` + `$identify`.
- **PostHog:** `$identify` resolves to the **same** distinct id (UID) as before;
  `user_signed_in` captured.
- **Pass/Fail:** PASS if the same UID person is reused (no new id per session).
  FAIL if a new authenticated id appears.

### ☑ T4 — Logout — PASS (2026-06-30)
- **Action:** From signed-in, tap sign out.
- **Console:** `user_signed_out captured` → `PostHog reset completed` →
  `Firebase sign-out completed`.
- **PostHog:** `user_signed_out` captured **while still under the UID**, then the
  distinct id becomes anonymous for subsequent events.
- **Pass/Fail:** PASS if `user_signed_out` is attributed to the UID and the next
  events are anonymous. FAIL if reset precedes the capture.

### ☑ T5 — Second account on the same device — PASS (2026-06-30)
- **Action:** After T4, sign in as a **different** user B on the same device.
- **Console:** `[Auth] … succeeded` + `$identify` for B.
- **PostHog:** B's events are under **B's** UID.
- **Pass/Fail:** PASS if B is **not** aliased/merged into A (reset in T4
  separated them). FAIL if B's events attach to A's person.

### ☑ T6 — Background and foreground — PASS (2026-06-30)
- **Action:** With the app open, background it ~10s, then reopen (no relaunch).
- **Console:** `app_opened captured: foreground` (and no `[Identity] identify`
  line).
- **PostHog:** one `app_opened` with `open_type=foreground`; **no** new
  `$identify`, **no** `cold_start`.
- **Pass/Fail:** PASS if exactly one foreground `app_opened` and no re-identify.
  FAIL on a `cold_start` event or a second identify.

### ☑ T7 — Reinstall and login — PASS (2026-06-30)
- **Action:** Delete the app, reinstall, launch (cold launch, signed out), then
  sign in.
- **Console:** cold launch: `no authenticated user found, starting late identity
  recovery` → `app_opened captured: cold_start`; on sign-in: `[Auth] … succeeded`.
- **PostHog:** first an **anonymous** `app_opened (cold_start)`; after sign-in an
  `$identify` to the UID; the anonymous launch events merge into the UID person.
- **Pass/Fail:** PASS if post-login the UID person contains the pre-login
  anonymous `app_opened`. FAIL if events are split across two persons.

### ☑ T8 — Offline / delayed Firebase restoration — PASS (2026-06-30)
- **Action:** Signed in, enable Airplane Mode (or heavy network throttling),
  force-quit, relaunch; after `app_opened` appears, restore connectivity.
- **Console:** `session restoration started` → (if restore is slow)
  `no authenticated user found, starting late identity recovery` →
  `app_opened captured: cold_start` → later `late recovery listener started` is
  already logged, then `authenticated user recovered (uid:…XXXX)` →
  `identify completed (late recovery); no additional app_opened captured`.
  (If Firebase restores within 5s, you'll instead see the T1 sequence.)
- **PostHog:** an anonymous `app_opened (cold_start)`, then a later `$identify`
  (same UID) with **no** extra `app_opened`; anonymous events merge into the UID.
- **Pass/Fail:** PASS if the session is recovered to the UID with exactly one
  identify and no second `app_opened`. FAIL if the session stays anonymous or a
  duplicate `app_opened` fires.

## PostHog verification steps

- **Activity / Live Events**: confirm the event order and `open_type` values above.
- **Persons**: the authenticated person's distinct id is the Firebase UID; email
  is a property, never the id; no journal/gratitude/mood content in properties.
- **Funnels**: `app_opened (is_first_open) → user_signed_up → home_opened` stays intact.
- Confirm there is **no** `Application Opened` autocapture event alongside `app_opened`.

## Known remaining risks

- **Anonymous → identified merge** relies on PostHog default merge behavior; a
  pre-auth anonymous person is merged on `identify()`. Verified per launch.
- **Firebase first-callback semantics**: iOS `addStateDidChangeListener` fires
  immediately with the current (possibly nil) user. Cold start settles on that
  first callback; if a session restores slightly later, **late recovery** is the
  safety net that issues the identify.
- **Incremental Xcode builds** can cache the synchronized-group file list; if a
  newly added file/string seems missing, do a clean build.
- Person-property minimization is enforced by `safeProperties()`; any future
  caller adding properties must keep them non-sensitive.
- **PostHog batching delay** (observed 2026-06-30): Live Events lag the console
  by ~10–30s. This is normal SDK batching, not a correctness issue — use the
  `[Identity]` console logs as the immediate signal during verification.
- DEBUG `[Identity]` logs do **not** appear in Release/TestFlight builds; on-device
  log verification requires a Debug build run from Xcode.
