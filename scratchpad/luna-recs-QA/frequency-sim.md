# luna-recs — frequency-shape simulation (cap = 3)

Re-run of the Task-2.4 frequency-shape sim after lowering the monthly safety
cap from **4 → 3** deliveries per rolling 30 days. The sim lives in
`functions/src/concernScore.test.ts` (deterministic `mulberry32` harness,
`SEEDS = 400`) and drives the SAME `decideRecGeneration` production uses, so the
band numbers below are exactly what the shipped trigger math produces.

## Trigger constants (UNCHANGED — no retune needed)

| constant        | value | note |
|-----------------|-------|------|
| `BASE_THRESHOLD`| 58    | full-confidence bar |
| `CONFIDENCE_K`  | 20    | confidence penalty slope |
| `COOLDOWN_DAYS` | 7     | hard ≥7d between deliveries |
| `MONTHLY_CAP`   | **3** | hard ≤3 deliveries / rolling 30d (was 4) |

## Results at cap = 3 (base 58 / K 20, 400 seeds/profile)

| profile   | avg / month | max | month-count histogram (0/1/2/3) | target band | verdict |
|-----------|-------------|-----|---------------------------------|-------------|---------|
| stable    | **0.000**   | 0   | 400 / 0 / 0 / 0                 | 0–1         | clean   |
| typical   | **2.595**   | 3   | 1 / 21 / 117 / 261              | 2–3         | clean   |
| declining | **3.000**   | 3   | 0 / 0 / 0 / 400                 | at/near 3   | clean   |

Ordering holds: `stable (0.0) < typical (2.60) < declining (3.0)`.

## Assessment — NO threshold retune

Lowering the cap to 3 did **not** blur the bands, so `BASE_THRESHOLD` and
`CONFIDENCE_K` are left at 58 / 20 (unchanged).

- **stable** is pinned at 0 — never even reaches the bar. Well inside 0–1.
- **typical** averages 2.60 and is genuinely *distributed* (35% of months land
  at 0–2, only 65% hit the cap). It sits squarely in its 2–3 target and stays
  clearly below declining on average.
- **declining** wants ~6 (eligible ~85% of nights at high severity) but is held
  to exactly 3 every month by the cap — i.e. it sits **at the new ceiling**,
  which is exactly the intended shape.

A retune would only push `typical` *down* (e.g. base 60 → typical ≈ 2.33; base
62 → ≈ 1.98). Since 2.60 is already inside the 2–3 target and the three bands
are cleanly ordered and separated, moving the threshold would be change for its
own sake. **Left unchanged.**

## Pathological caps (firewall proof, 60-day horizon)

Worst case: `score = 100, confidence = 1.0` every night for 60 days, driven
through `decideRecGeneration`.

| variant                         | deliveries / 60d | max in any 30d window | min gap |
|---------------------------------|------------------|-----------------------|---------|
| score 100 (no adjustment)       | 6 (days 0,7,14,30,37,44) | 3 | 7 |
| score 100 + max downward (−6)   | 6 (days 0,7,14,30,37,44) | 3 | 7 |

The most-engaged possible user (`recThresholdAdjustment = REC_ADJ_MIN = −6`)
produces the **identical** delivery set: the cooldown and cap are independent
code-level checks evaluated BEFORE the score, so neither a top score nor the
max downward cadence nudge can breach **≤1 / 7d** or **≤3 / 30d**. Total over
60 days = 6 (two rolling months of 3 + boundary), comfortably under the test's
≤7 runaway bound.

_Regenerated after the cap 4→3 change; supersedes the cap=4 figures._
