# convergence notes — integration/convergence

overnight autonomous arc, 2026-07-19. owner asleep; judgments recorded here.
branch built from main @ 758c14c, merging feature/localization then feature/agent-memory.
hard limits honored: main untouched, nothing pushed, no deploys, CrisisResources.swift content never hand-edited.

## merge 1: feature/localization

fast-forward — feature/localization already contained main's tip (758c14c, the 2.0.1 forward-port merge), so git fast-forwarded to ab46e9d with **zero conflicts**. crisis hash already at the protected baseline after this merge.

catalog validation after merge 1 (python json.load; note: `plutil -lint` rejects these files on this machine with "Unexpected character { at line 1" even though they are valid JSON — xcstrings are JSON, not plists, so json.load is the authoritative check; flagged, not fixed):

| catalog | keys | en | es | ja | ko | vi |
|---|---|---|---|---|---|---|
| Dino/Localizable.xcstrings | 1319 | 818 | 1267 | 1267 | 1267 | 1267 |
| DinoLiveActivity/Localizable.xcstrings | 128 | 128 | 123 | 123 | 123 | 123 |
| Dino/InfoPlist.xcstrings | 12 | 12 | 11 | 11 | 11 | 11 |
| Dino/AppShortcuts.xcstrings | 9 | 9 | 9 | 9 | 9 | 9 |
| DinoLiveActivity/InfoPlist.xcstrings | 1 | 1 | 1 | 1 | 1 | 1 |

(per-language counts below key totals are by design: keys whose value equals the en key carry no explicit en unit, and the no-translate set stays english.)

## merge 2: feature/agent-memory

four conflicted files; everything else auto-merged (including Dino/Views/EmotionalWeatherView.swift and Dino/Views/RecKeepsakesView.swift — both verified to carry localized strings AND the shelf chip/filter features; firestore.rules and the rest of functions/ auto-merged because agent-memory had already unified its server tree with localization's).

### Dino/Localizable.xcstrings
- what conflicted: localization's full catalog (1319 keys) vs agent-memory's catalog (67 keys: main's 60 + 7 shelf strings with es/ja/ko/vi).
- resolution: three-way union built programmatically from the git index stages (not marker editing). localization's side is base truth for every overlapping key; agent-memory's 5 genuinely-new keys grafted verbatim with their translations: `everything`, `kept`, `when dino brings you something, it will rest here 🌿`, `your little shelf · %lld things dino has brought you`, `your little shelf · 1 thing dino has brought you`. the 2 overlap keys (`%lld kept`, `keep this`) were already in localization's catalog with translations — localization's entries kept (agent-memory's copies were near-identical; only divergence was ko `keep this`: "간직하기" [kept] vs "이거 간직하기" [dropped] — localization's translation pass wins per the resolution law). no key lost from either side. keys re-sorted, formatting preserved.

### Dino/Services/ComfortRecService.swift
- what conflicted: the ComfortRecVoice shelf block — localization's simple `shelfRowLine` composition vs agent-memory's F4 block (`shelfBroughtLine` singular/plural, filter labels, `keep this`, empty-state line, `shelfRowLine` redefined to the brought-line).
- resolution: agent-memory's side taken — it is a strict superset and every string in it is already `String(localized:)`-wrapped, so localized strings and the keepsake/ledger features both survive.

### functions/src/index.ts
- what conflicted: six hunks — preferences import; `attemptMission` signature (`keptKinds` param); `runExpeditionMission` signature; the `attemptMission` call site; the watcher act-block (recentSources/avoidDomains/userLocale/keptKinds wiring); the comfort-recs system prompt tail (prefs bias sentence).
- resolution: agent-memory's side on all six — it already carried localization's `userLocale` threading (the branch had unified the server tree) and adds prefs/keptKinds/avoidDomains on top. superset confirmed hunk-by-hunk: crisis nets + userLocale + outcomes + prefs all survive. localization's auto-merged regions elsewhere in the file untouched (markers edited in place, no whole-file checkout). `tsc` clean afterward.

### progress.txt
- what conflicted: both branches appended distinct arc ledgers at the same spot.
- resolution: union — localization's arc sections first, then the memory+shelf arc section. no lines lost.

## crisis file assertion

`shasum -a 256 Dino/Services/CrisisResources.swift` after both merges:
`ba2ebd5645e249d0f5148235e6c83de25ebd39b4b653654e60b1a048a763e090` — matches the protected baseline exactly. content never touched by hand; merge carried feature/localization's version.

## final catalog counts (post merge 2, all valid JSON)

| catalog | keys | en | es | ja | ko | vi |
|---|---|---|---|---|---|---|
| Dino/Localizable.xcstrings | **1324** | 823 | 1272 | 1272 | 1272 | 1272 |
| DinoLiveActivity/Localizable.xcstrings | 128 | 128 | 123 | 123 | 123 | 123 |
| Dino/InfoPlist.xcstrings | 12 | 12 | 11 | 11 | 11 | 11 |
| Dino/AppShortcuts.xcstrings | 9 | 9 | 9 | 9 | 9 | 9 |
| DinoLiveActivity/InfoPlist.xcstrings | 1 | 1 | 1 | 1 | 1 | 1 |

0 gaps: every one of the 5 grafted keys carries all five languages; es=ja=ko=vi counts identical in every catalog.

## build + tests

- xcodebuild build (scheme Dino, sim B1C53BE2): **succeeded**, zero merge-induced compile errors — no post-merge source fixes were needed.
- DinoTests suite: **385/385 green** (0 failures, 0 unexpected) — the union suite incl LocalizationTests, MemoryShelfLocalizationTests, OutcomeLedgerTests, CrisisNetTests, ComfortRecTests, ExpeditionTests and the rest. no tests deleted or weakened. note: the worktree needed the gitignored `Secrets.xcconfig` + `functions/.env` copied from the primary checkout (read-only copies; both remain gitignored).
- functions: `npm ci` + `npm test` (tsc build + node --test): **51/51 pass, 0 fail** across credits/crisisNet/mission/modelRouter/preferences/season/world test files. no deploys performed.

## flags for the owner

- `plutil -lint` fails on all xcstrings ("Unexpected character {") — plist tooling quirk, files are valid JSON; validation done via python json.load.
- ko `keep this`: agent-memory's "이거 간직하기" dropped in favor of localization's "간직하기" (native reviewers may want to confirm, along with the rest of the ko review sheet).
- known pre-existing caveats from both branch ledgers still stand (BreakScheduler slot displayTime en-format, persisted notifications keep creation language, safety-critical keyword-net native review pending).
