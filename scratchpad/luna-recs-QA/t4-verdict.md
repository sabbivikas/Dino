# T4 — ledger-based personalized cadence (verdict)

Branch `feature/luna-recs` off `36b442a`. Functions-only change (no Swift, no
rules, no client). No deploys, nothing pushed, main untouched, CrisisResources
+ crisisNet untouched. Suite 125/125 (113 baseline + 12 new), tsc clean.

## What T4 does

A user's own **announcement (knock) engagement** nudges their effective rec
threshold: consistent opens LOWER the bar (slightly more recs), consistent
ignoring RAISES it (fewer). Pure deterministic ratio math folded into the
EXISTING nightly distiller — **no new job, no new model call, $0 added**.

## The mapping (open-rate → adjustment) + exact bounds + min-data floor

SIGNAL: F6 announcement outcomes in the ledger — `kind:"announcement"`,
`itemType:"parcel"`, `action ∈ {shown, opened, ignored}`.

WINDOW: the most-recent `REC_ADJ_WINDOW = 30` announcement knocks (entries
arrive newest-first, `shownAt desc`; the first 30 announcements are the most
recent). `'shown'` (not yet resolved) counts toward the window but is EXCLUDED
from the ratio.

OPEN-RATE: `opened / (opened + ignored)`.

MIN-DATA FLOOR: `REC_ADJ_MIN_RESOLVED = 4` resolved (opened+ignored) knocks. Below
that → **exactly 0** (no nudge until there is real signal). Rationale: recs are
capped 3/month, so 4 resolved knocks ≈ a month+ of delivered signal.

MAPPING (symmetric around a neutral 0.40–0.60 band; negative = lower bar / more
recs, positive = raise bar / fewer):

| open-rate r        | adjustment |
|--------------------|-----------|
| r ≥ 0.80           | **-6** (floor, very engaged)  |
| 0.60 ≤ r < 0.80    | -3        |
| 0.40 ≤ r < 0.60    | **0** (neutral band)          |
| 0.20 ≤ r < 0.40    | +3        |
| r < 0.20           | **+6** (ceiling, very ignoring) |

BOUNDS: clamped int in `[REC_ADJ_MIN, REC_ADJ_MAX] = [-6, +6]`. These live in
`concernScore.ts` and are IMPORTED by `preferences.ts`, so the producer (the
mapping) and the consumer (the threshold) share ONE source of truth — they can
never drift.

## Where it's stored + client/server/rules lockstep

- New bounded field `recThresholdAdjustment: number` on `PreferenceDoc`
  (`preferences.ts`). Computed by the pure `computeRecThresholdAdjustment(entries)`
  and stamped in `validatePrefs` (which already receives `entries`), so the
  distiller's existing `prefs/{uid}` write (`{...prefs}`, merge:false) carries it
  automatically. Enum/number ONLY — never content.
- **Server-only write**: prefs is written solely by the distiller (admin SDK).
- **Rules lockstep**: `firestore.rules` `match /prefs/{uid}` is `allow write:
  if false` — it does NOT enumerate/validate pref keys, so adding a field needs
  NO rules change and NO new rules test. Rules unchanged (31). (If rules ever
  gain a prefs key allowlist, this field must be added there + a rules test — a
  note for that future.)
- **Client**: unchanged. The client only READS its own prefs; it never writes
  and does not consume this field (the trigger is fully server-side since T3).

## How the watcher reads + applies it

`nightlyExpeditionWatch` already reads `prefs/{uid}` (for giftFatigue/avoidDomains/
needKindsLanding) — ONE existing Firestore read, no new read added. It now also:
1. `recThresholdAdjustment = sanitizeRecThresholdAdjustment(prefs.recThresholdAdjustment)`
   — clamped int, missing/garbage → 0 (no nudge).
2. passes it into `decideRecGeneration({ ..., recThresholdAdjustment })`.
3. `effectiveThreshold(confidence, adjustment)` = `BASE(58) + (1-conf)*CONFIDENCE_K(20)
   + clampedAdj`, then clamped to `[THRESHOLD_MIN, THRESHOLD_MAX] = [50, 80]`.
   Normal range: 52 (full conf, -6) … 76 (mood-only, +6); the envelope is a
   safety net that never bites in normal operation.
4. logs `recThresholdAdjustment` in the enum/number-only `luna_rec_decision` facet.

## Extended pathological-cap result (caps hold under max downward adjustment)

New test `PATHOLOGICAL CAP + MAX DOWNWARD ADJUSTMENT`: the most-engaged user
(`recThresholdAdjustment = REC_ADJ_MIN = -6`, easiest possible eligibility) with
`score=100, confidence=1.0` every night for 60 days → **≤1 rec per rolling 7 days
AND ≤3 per rolling 30 days**, ≤7 total over 60 days. **PASS.** The 7-day cooldown
and 3/30-day cap are checked in `decideRecGeneration` BEFORE the score and are
independent of BOTH score and adjustment — lowering the threshold only eases
eligibility WITHIN the caps and can never breach them.

## Rubric

- **no-new-job**: PASS — folded into `nightlyPreferenceDistill` (compute) +
  `nightlyExpeditionWatch` (consume); no new cron.
- **no-new-model-call**: PASS — `computeRecThresholdAdjustment` is pure ratio
  math over already-stored enum entries; NOT fed into the luna call, not a
  second call. $0 added.
- **enum-only**: PASS — the field is a clamped int; the signal is enum
  announcement outcomes. No content anywhere.
- **caps-still-hard-under-max-adjustment**: PASS — extended pathological test
  (above) with `REC_ADJ_MIN` applied.
- **opens-fewer-never-breach-ceiling**: PASS — opens LOWER the bar (more
  eligible nights) but the 3/month cap is a hard independent gate; the pathological
  test proves ≤3/30d even at max downward nudge + score 100 every night.

## Suite counts

- functions: **125/125** (113 baseline + 12 new: 8 in preferences.test.ts, 4 in
  concernScore.test.ts incl the extended pathological cap). tsc clean.
- rules: unchanged (31) — firestore.rules not modified.
- Swift: not touched (functions-only) — client suite unaffected (429).

## Files changed

- `functions/src/concernScore.ts` — REC_ADJ_MIN/MAX + THRESHOLD_MIN/MAX bounds,
  `sanitizeRecThresholdAdjustment`, `effectiveThreshold(confidence, adjustment=0)`
  (adds clamped adjustment + final clamp), `recThresholdAdjustment?` on
  `RecDecisionInput`, threaded through `decideRecGeneration`.
- `functions/src/preferences.ts` — `recThresholdAdjustment` on `PreferenceDoc`,
  `REC_ADJ_WINDOW`/`REC_ADJ_MIN_RESOLVED`, pure `computeRecThresholdAdjustment`,
  stamped in `validatePrefs`; imports the bounds from concernScore (lockstep).
- `functions/src/index.ts` — watcher reads+sanitizes `prefs.recThresholdAdjustment`
  (no new Firestore read), passes it into `decideRecGeneration`, logs it.
- `functions/src/preferences.test.ts` — 8 mapping/bounds/window/stamp tests.
- `functions/src/concernScore.test.ts` — 4 tests (threshold shift, sanitize,
  borderline-eligible, extended pathological cap under max downward adjustment).

## Flags

1. `recThresholdAdjustment` is deterministic from entries but written only on a
   SUCCESSFUL distill (bundled into the prefs doc; `validatePrefs`→null on a
   malformed model night writes nothing, so the previous value persists). Minor,
   documented — acceptable given `prefs_invalid` is rare and the field is
   recomputed on the next good run.
2. If `firestore.rules` ever adds a prefs key allowlist, `recThresholdAdjustment`
   must be added there + a rules test (currently N/A — prefs is `write:false`).

## Sanity

main `36b442a`, crisis hash `ba2ebd56…`, crisisNet.ts untouched, nothing
pushed, nothing deployed.
