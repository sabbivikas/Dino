# Getting a July 2026 monthly story onto the phone

Everything here is configuration. Nothing in this directory ships in the app, and nothing runs
automatically — `apply-monthly-story-config.mjs` is a dry run unless you pass `--apply`.

State as audited on 2026-08-07: the client code is ready, all seven callables are deployed, the
Hume secret exists. The two things actually blocking a run are **the control document has gone
stale** and **the internal-tester grant expired on 2026-08-06**. Both are timestamp problems, not
missing configuration.

---

## The ordered checklist

### 1. Refresh the two Firestore documents

```bash
node ops/monthlyStory/apply-monthly-story-config.mjs
```

Dry run — prints current vs desired for `featureFlags/monthlyStory` and
`monthlyStoryInternalTesters/<uid>`. Read the diff, then:

```bash
node ops/monthlyStory/apply-monthly-story-config.mjs --apply
```

**Verify:**

```bash
node ops/monthlyStory/apply-monthly-story-config.mjs --check
```

This loads the *real* compiled parsers out of `functions/lib/` and runs them over what is actually
stored. It must print `OK - deterministic text path is unblocked.` and exit 0. Run `npm --prefix
functions run build` first if `functions/lib/` is missing.

> **The 24-hour clock.** `parseMonthlyStoryControl` rejects any control document whose `updatedAt`
> is more than `MONTHLY_STORY_CONTROL_MAX_AGE_MS` (24h) old, and a rejected control falls back to
> `SAFE_DISABLED_MONTHLY_STORY_CONTROL` — every gate off. There is no scheduled refresher in this
> codebase, so **re-run `--apply` on each day you want to test.** This is the single most likely
> reason a run that worked yesterday silently stops working today.

### 2. Deploy the functions

The deployed revisions are from 2026-08-05T07:52Z. `functions/src` has moved since — most
relevantly `1567745` (clears the moodOnly word floor with approved tone phrases) and `9458909`
(declare stored-settings permissions in the uploaded signal). If your July lands in `moodOnly`,
the currently-deployed composer is the version *without* that fix.

```bash
firebase deploy --only functions:getMonthlyStoryInternalAvailability,functions:getMonthlyStoryInternalSettings,functions:updateMonthlyStoryInternalSettings,functions:loadMonthlyStoryInternalStory,functions:generateMonthlyStoryInternal,functions:deleteMonthlyStoryInternal,functions:generateMonthlyStoryInternalAudio
```

**Verify:** `gcloud functions list --project dino-app-wellness --format="table(name,updateTime)" | grep -i monthly`
and confirm all seven `updateTime` values are from this deploy.

### 3. Build with the internal compile flag

The gate is `MONTHLY_STORY_INTERNAL_BUILD`. It is **not** set by any standard build — the app
target's base configuration is `Secrets.xcconfig`, and `MonthlyStoryInternalTestFlight.xcconfig`
is not wired into the project. Supply it explicitly:

```bash
xcodebuild -scheme Dino -configuration Debug -xcconfig MonthlyStoryInternalTestFlight.xcconfig -destination "platform=iOS,name=<your iPhone>"
```

Or, to run from the Xcode UI, add `MONTHLY_STORY_INTERNAL_BUILD` to the Dino app target's
**Debug → Active Compilation Conditions**.

**Verify** (this exact command was run and returned the second line):

```bash
xcodebuild -showBuildSettings -scheme Dino -configuration Debug -xcconfig MonthlyStoryInternalTestFlight.xcconfig -destination "platform=iOS Simulator,id=B1C53BE2-449A-480A-AFB6-374E2145259D" | grep SWIFT_ACTIVE_COMPILATION_CONDITIONS
#   SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG  MONTHLY_STORY_INTERNAL_BUILD
```

On the phone, the card shows a `monthly story internal: …` caption line only in this build. That
caption is the fastest confirmation the flag took.

### 4. Fix the stored timezone (optional, do it before generating)

`monthlyStorySettings/<uid>` currently stores `timezone: "UTC"`. The server rejects any signal
whose `timeZone` differs from stored settings, so the client will build a UTC-bucketed July and it
*will* parse — but your July days get cut on UTC midnight, not local midnight. To use your real
zone, change it in the app's monthly-story setup sheet before generating; changing it afterwards
means deleting the story and regenerating.

### 5. Generate

Open the card → **prepare my story**.

**Verify:** `monthlyStories/<uid>/months/2026-07` appears in Firestore. Both `monthlyStories` and
`monthlyStorySignals` are empty today, so their first appearance is the signal that the whole path
ran.

---

## If "prepare my story" just returns to the same button

That is `MonthlyStorySignalCoordinatorError.insufficientEvidence` — `MonthlyStoryCardHost` catches
it and falls back to `.noStory` with no message. It means July did not clear
`MonthlyStoryEligibility.evaluate`. The thresholds (`Dino/Services/MonthlyStoryEligibility.swift`):

| path | requires |
|---|---|
| `eligibleStandard` | ≥6 usable days **and** ≥4 mood days **and** ≥2 corroborating days **and** ≥2 high-confidence items |
| `eligibleMoodOnly` | ≥8 mood days **and** ≥2 high-confidence items |

Mood days reach high confidence at ≥4, and the mood block emits two items, so ≥8 mood-logged days
in July on their own are enough. Corroborating days come only from journal themes (a theme tagged
on ≥2 separate days) and Health (≥4 in-month sleep nights or step days, with the permission on).

A failure here is a data-volume problem, not a configuration one — no amount of control-document
editing changes it.
