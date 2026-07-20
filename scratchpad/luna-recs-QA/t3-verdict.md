# T3 — rewire the trigger (verdict)

Branch `feature/luna-recs` off `e46ce5b`. Server = `functions/src/`, client = `Dino/`.
No deploys, nothing pushed, main untouched, CrisisResources/crisisNet untouched.

## What changed (the trigger, nothing else)

The comfort-rec generation trigger moved from **mood-log time (client)** to the
**nightly watcher (server)**, driven by the T1+T2 concern score. F3/F4/F5/F6 and
all payload retention/TTL/delete-on-open/no-leak rules are untouched — only the
thing that *decides to generate* changed.

## Part A — DECOUPLE the concern score from the expedition-gift gates

**Decision: MOVED the shared gpt-5.6-luna call ahead of the gift gates** (the
low-risk version was not needed — the move is provably behavior-preserving).

Before: per cohort user the watcher did `14d-since-gift → attemptedAt<20h →
sinceLastRec==0to2 → continue` and only THEN made the luna call. A user in
gift-cooldown was `continue`d before scoring, so they were never scored and
never got a rec — recs were wrongly coupled to expedition cadence.

After: only the **call-frequency guard** (`attemptedAt < 20h`, one luna attempt
per night — correct for both systems) still gates the call. The two
**gift-specific gates** (`≥14d since last gift` AND `sinceLastRec != "0to2"`)
moved BELOW the call as the pure predicate `expeditionGiftGatesPass(...)` and now
gate ONLY the expedition mission.

**Expedition-unchanged proof.**
- Before, a user got an expedition iff `gate14 AND gate20h AND gateRec AND
  (act && needKind!=none && conf>=thr)`.
- After, a user gets a luna call iff `gate20h`; and an expedition iff
  `gate20h AND gate14 AND gateRec AND (act && needKind!=none && conf>=thr)` —
  the **same conjunction**. The set of users who get an expedition is identical.
- `expeditionGiftGatesPass` is the exact boolean complement of the old inline
  skip (`daysSinceLastGift >= 14` ⟺ `NOT (now-lastAt < 14d)`; `sinceLastRec !=
  "0to2"` ⟺ `NOT (sinceLastRec == "0to2")`). Proven exhaustively in
  `concernScore.test.ts` ("is the exact complement of the old inline skip",
  over days ∈ {0, 6.9, 13.999, 14, 14.001, 30, ∞} × rec ∈ all 4 buckets), plus a
  gift-gated/non-gated case test.
- `attemptedAt` is now set for more users (those previously gated out). Harmless:
  it is a server-internal "scored tonight" marker, read only by the 20h guard;
  24h > 20h so the next night is never skipped, and it never feeds expedition
  eligibility (which uses `lastAt`, not `attemptedAt`).

**Added luna-call volume + cost.** The added calls = eligible-cohort users who
pass the 20h guard but were previously skipped by the 14d-gift or
`sinceLastRec==0to2` gate (i.e. users in gift-cooldown / within ~3 days of a
rec). This cannot be measured live (no deploy), so it is bounded:
- Cost per watching call: gpt-5.6-luna, ~450 input tok + ≤200 output tok
  (reasoning bills as output), luna $1/$6 per 1M → ≈ **$0.0017/call**.
- **Hard ceiling UNCHANGED**: the cohort query is still capped at
  `EXPEDITION_LUNA_NIGHTLY_CAP = 2000` docs and the 20h guard means ≤1 call per
  user per night, so total luna calls ≤ 2000/night = **≤ ~$3.40/night ≈
  ~$100/month global**, exactly as before T3 — Part A only uses more of that
  pre-existing ceiling, it does not raise it. No new cap needed.
- Realistic per-user add: expeditions are rare (≤2/user/mo, 14d cooldown) and
  recs rare (≤3/mo), so gift-cooldown nights are a modest slice. Worst-case
  heavy user (eligible most nights, freshly gifted): ~14 extra calls/mo ≈
  **$0.02–0.03/user/mo**; typical user ≈ near zero. Well under budget.

## Part B — WIRE generateComfortRecs server-side

`generateComfortRecs`'s core generation logic was **extracted verbatim** into
`async runComfortRecGeneration(uid, input: ComfortRecInput)` in
`functions/src/index.ts`. BOTH callers use it:
- the **onCall** is now a thin adapter — same auth guard, same allow-list
  rejection, same client-payload coercion → builds a `ComfortRecInput` →
  `runComfortRecGeneration(uid, input)`. Externally byte-identical.
- the **watcher** builds the server-side input via
  `buildWatcherComfortRecInput(buckets, themes, userLocale)` and calls the
  SAME function when `decideRecGeneration(...).shouldGenerate`.

The held delivery/payload docs (recDeliveries deliveries + payloads,
deliverAfter 45–90min out of quiet hours, tz, daypart, expiresAt TTL, per-uid
daily cap + refund) are the **same single hold block** — not forked, not
rewritten. `COMFORT_REC_DAILY_LIMIT` and the scarcity/quiet-hours gates are
unchanged.

**Server payload build (each field — source / default / rec-quality effect):**

| field | source / default | effect |
|---|---|---|
| `moodTrend` | `buckets.moodTrend` | identical enum to client — full quality |
| `recentThemes` | `themes` (EXPEDITION_THEME_ALLOW == REC_THEMES) | identical — full quality |
| `userLocale` | signals doc `userLocale` (AppLanguage.current), validated to 5 langs | full quality — "why"/"length" land in-language |
| `timeOfDay` | `"night"` (nightly) | honest context; delivery still lands out of quiet hours |
| `mood` | `""` (no per-day mood server-side) | prompt uses "a quiet heaviness"; moodTrend already carries heaviness — minor |
| `quietTypes` | `[]` (no server source) | no type hard-excluded; prefs typesLanding/Ignored bias still personalizes — minor |
| `userCountry` | `""` (NO per-user country server-side) | **FLAG**: model falls back to globally-beloved works + no TMDB watch-provider/poster (film card paper-only). Loses regional resonance; "why" still in-language |
| `excludeTitles` | `[]` (no server title history; payloads deleted, ledger enum-only) | **FLAG**: a title could repeat; mitigated by 7d cooldown + 4/mo cap (recs rare) + prompt "reach widely" variety rule |

The two flagged fields (`userCountry`, `excludeTitles`) are the only rec-quality
deltas vs the client path; both use the safe default because reconstructing them
server-side would need significant new plumbing (a per-user country profile doc;
a retained title history), which no existing server data provides.

## Part C — REMOVE the client mood-log auto-trigger

`Dino/Views/EmotionalWeatherView.swift`: removed the `else`-branch `Task { await
ComfortRecCoordinator.generateAndHoldIfMomentIsRight(...) }` after
`stretchSignalFires()`. Mood-logging still (a) writes the mood entry
(`viewModel.saveMood()`, untouched) and (b) updates the `expeditionSignals` doc
(`.task` → `ExpeditionSignals.syncIfNeeded`, untouched) — only the
generateComfortRecs trigger is gone.

No OTHER client path calls generation: `generateAndHoldIfMomentIsRight` and
`ComfortRecCoordinator.fetchIfMomentIsRight` are now cleanly unreferenced (the
only two `httpsCallable("generateComfortRecs")` calls live inside them). Both
left defined + documented as no-longer-wired (kept as the client-side equivalent
/ QA hook, safe to delete after soak). `GentleRecService` (separate older
feature) untouched. The onCall `generateComfortRecs` stays deployed (harmless).

## Rubric

- **trigger-is-nightly-not-moodlog**: PASS — client mood-log trigger removed;
  the nightly watcher's concern score is the sole trigger.
- **generation-unchanged-fn+model**: PASS — `runComfortRecGeneration` extracted
  verbatim; gpt-4.1-mini, same prompt, same validation; onCall byte-identical.
- **delivery-machine-untouched**: PASS — same hold block (deliverAfter/tz/
  daypart/expiresAt/daily-cap+refund); F3/F4/F5/F6 + retention/TTL/no-leak
  untouched.
- **expedition-behavior-preserved**: PASS — same gate conjunction, proven by the
  exact-complement + gift-gated tests.
- **crisis-untouched**: PASS — CrisisResources.swift + crisisNet.ts untouched;
  no crisis input in the rec path; the cooldown/cap gate comfort recs only.
- **cost-within-target**: PASS — generation unchanged (gpt-4.1-mini ~$0.002/user/
  mo); Part A adds bounded luna volume under the unchanged 2000-cap ceiling.

## Suites

- functions: **113/113** (108 baseline + 5 new: 2× buildWatcherComfortRecInput,
  1× wiring boundary, 2× expeditionGiftGatesPass). tsc clean.
- client DinoTests: **429/429**, 0 failures (baseline held exactly; no test
  asserted the mood-log trigger, so none needed changing). Debug build green.
- Screenshot: skipped (no UI change; mood screen unmodified; simctl has no tap
  and prior runs hit Simulator tap-access denial). Mood-log flow is verified by
  the green build + the fact only the generateComfortRecs Task was removed.

## FLAGS

1. `userCountry=""` server-side → recs lose regional resonance and the film card
   loses its TMDB watch-provider + poster (paper-only reveal). Owner may want a
   per-user country profile doc if regional recs matter for the nightly path.
2. `excludeTitles=[]` server-side → a rec title can repeat; low frequency given
   the cooldown/cap, but there is no server-side title memory to prevent it.
3. Concurrency hazard observed: while editing, `index.ts` + `concernScore.ts`
   were once silently reverted to the committed state (a selective `git restore`,
   no reflog entry) — re-applied and re-verified. Something else may touch this
   worktree; the owner should confirm no parallel job runs against Dino-luna.
