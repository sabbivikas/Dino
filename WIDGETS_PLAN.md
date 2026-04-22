# Dino Home-Screen Widgets — Implementation Plan

Scope: Mood Check-In, Streak, Breathing. Sizes `systemSmall` + `systemMedium` only. Design reference: `/Users/vikas/Downloads/DinoDesignSystem5/widgets.html`. SVG → SwiftUI Path/Canvas; mascot PNGs allowed. Pseudo-animation via TimelineProvider rotating ~6 snapshots/hour.

---

## § A. Current state audit

### Widget extension target
- Target name (pbxproj): **`DinoLiveActivityExtension`** (id `AA000010AAAA000000000001`)
- Product: `DinoLiveActivityExtension.appex`
- Bundle id: `com.vikassabbi.dino.LiveActivity`
- Source folder (synchronized): `/Users/vikas/Dino/DinoLiveActivity/` (`PBXFileSystemSynchronizedRootGroup` id `AA000030AAAA000000000001`)
- Info.plist: `/Users/vikas/Dino/DinoLiveActivity/Info.plist` (explicit, `GENERATE_INFOPLIST_FILE = NO`)
- No `.entitlements` file found in either target (`Glob **/*.entitlements` returned none). App Group membership must be on the extension via either an entitlements file added outside pbxproj text grep scope, or managed automatically; this needs confirmation before ship (see § G).

### Files in the widget extension (`/Users/vikas/Dino/DinoLiveActivity/`)
- `DinoLiveActivityBundle.swift` — `@main` `WidgetBundle`, lists every widget.
- `BreathingLiveActivity.swift` — Live Activity for breathing; also defines `Color(hex:)` used across the whole extension (do NOT redeclare).
- `MeditationLiveActivity.swift` — Live Activity.
- `FocusLiveActivity.swift` — Live Activity.
- `DinoActivityAttributes.swift` — `ActivityAttributes` structs for Live Activities.
- `MoodCheckInWidget.swift` — existing home-screen widget (small/medium/large) with morning/day/night time-state logic. **This is what we replace.**
- `StreakWidget.swift` — existing home-screen widget (small/medium/large) using emoji "🔥" and dots. **Replace visuals; keep data wiring.**
- `BreathingWidget.swift` — existing home-screen widget (small/medium) with concentric circles + "🌿". **Replace with bloom shape.**
- `DailyAffirmationWidget.swift` — existing home-screen widget (unchanged scope).
- `GratitudeWidget.swift` — existing home-screen widget (unchanged scope).
- `TodaysFocusWidget.swift` — existing home-screen widget (unchanged scope).
- `WidgetDataProvider.swift` — read-only reader over App Group UserDefaults; **duplicates model types** locally (extensions cannot import main-app module).
- `WidgetTheme.swift` — theme palette struct; reads `dino.currentThemeForWidget` from shared defaults; maps to 9 palettes.
- `DinoInitiativeFont-Regular.ttf` — font file present in the extension folder.
- `Info.plist` — declares `UIAppFonts: [DinoInitiativeFont-Regular.ttf]`, `NSExtensionPointIdentifier = com.apple.widgetkit-extension`, `NSSupportsLiveActivities = true`, frequent-updates enabled.
- `Assets.xcassets/` — `DinoMorning.imageset`, `DinoSleeping.imageset`, `DinoWidget.imageset`, `DinoWidgetNight.imageset` (PNG/JPG mascots).

### `WidgetDataProvider` API (extension copy — `DinoLiveActivity/WidgetDataProvider.swift`)
Exact declaration and public surface (verbatim signatures):
```swift
struct WidgetDataProvider {
    init()                                      // suite "group.com.vikassabbi.dino"
    var currentStreak: Int
    var longestStreak: Int
    var weeklyStreakDays: [Bool]                // 7 bools, Sun..Sat of current week
    var growthLevel: Int
    var userName: String
    var todayMoodEmoji: String                  // "🌤" fallback
    var todayGratitudeCount: Int
    var totalGratitudeCount: Int
    var todayFocus: String                      // "N min focused today" or ""
    var latestAffirmation: String
}
```
UserDefaults keys it reads:
- `streakData` → `StreakDataW { currentStreak, longestStreak, lastActiveDate, activeDates: Set<String> }`
- `growthStats` → `GrowthStatsW { level }`
- `moodEntries` → `[MoodEntryW { id, date, weatherType: EmotionalWeatherW, energyLevel, intensityLevel }]`
- `gratitudeNotes` → `[GratitudeNoteW { id, text, createdAt }]`
- `savedAffirmations` → `[SavedAffirmationW { id, text, savedAt }]`
- `focusSessions` → `[FocusSessionW { id, date, durationSeconds, completed }]`
- `userName` (plain string)
- Read by `WidgetTheme.current`: `dino.currentThemeForWidget`

Note: a **second** copy lives at `Dino/Data/WidgetDataProvider.swift` (main-app target). Not used by widgets. Do not modify.

### Existing widget kinds and families
- `MoodCheckInWidget` kind `"MoodCheckInWidget"`, supports small/medium/**large**.
- `StreakWidget` kind `"StreakWidget"`, supports small/medium/**large**.
- `BreathingWidget` kind `"BreathingWidget"`, supports small/medium only.
- `DailyAffirmationWidget`, `GratitudeWidget`, `TodaysFocusWidget` — untouched.

### Info.plist excerpts
```xml
<key>NSExtension</key>
  <key>NSExtensionPointIdentifier</key> com.apple.widgetkit-extension
<key>NSSupportsLiveActivities</key> true
<key>NSSupportsLiveActivitiesFrequentUpdates</key> true
<key>UIAppFonts</key>
  <array><string>DinoInitiativeFont-Regular.ttf</string></array>
```
No `WKAppBundleIdentifier` (iOS extension, not watchOS).

### Entitlements
No `.entitlements` file in repo tree. `project.pbxproj` does not reference any entitlements path for the widget target or app-group strings. This means the App Group is likely configured through the Signing & Capabilities UI with auto-generated entitlements in DerivedData, OR the capability is not yet wired. **Action item flagged in § G** — user must confirm the widget target has `com.apple.security.application-groups` containing `group.com.vikassabbi.dino` in Xcode's Signing & Capabilities pane. The fact that the existing widgets already read via `UserDefaults(suiteName: "group.com.vikassabbi.dino")` suggests this is already in place; confirmation is a 10-second UI check.

### Font registration state
- `DinoInitiativeFont-Regular.ttf` physically exists under `DinoLiveActivity/`.
- Since `DinoLiveActivity/` is a `PBXFileSystemSynchronizedRootGroup`, every file under it is automatically a resource of the widget target. No explicit `PBXBuildFile` needed.
- `UIAppFonts` entry already present. Existing widgets use `Font.custom("DinoInitiativeFont-Regular", size:)` throughout — works today.
- The string used in `Font.custom` is the filename minus extension, which only works if the PostScript name matches. Since existing widgets render correctly today, the name is verified by the current production state.

### Main-app widget reload calls
- `Dino/Theme/ThemeManager.swift:381, 406` — `WidgetCenter.shared.reloadAllTimelines()` called on theme apply/preview-apply.
- **No other call sites.** The app does NOT reload widget timelines after logging a mood, completing a breathing session, or finishing focus. This is a gap; flagged in § F.

---

## § B. File-by-file change plan

Recommended folder layout (all under `/Users/vikas/Dino/DinoLiveActivity/` — auto-added via synchronized root group):

```
DinoLiveActivity/
├── Widgets/
│   ├── MoodWidget.swift              (NEW — replaces MoodCheckInWidget.swift)
│   ├── StreakWidget.swift            (MODIFIED in place)
│   └── BreathingWidget.swift         (MODIFIED in place)
├── Views/
│   ├── MoodWidgetView.swift          (NEW)
│   ├── MoodMorningView.swift         (NEW)
│   ├── MoodDayView.swift             (NEW)
│   ├── MoodNightView.swift           (NEW)
│   ├── StreakWidgetView.swift        (NEW — small+medium bodies)
│   └── BreathingWidgetView.swift     (NEW — small+medium bodies)
├── Shapes/
│   ├── FlameShape.swift              (NEW)
│   ├── BreathingBloomShape.swift     (NEW)
│   ├── HillsShape.swift              (NEW)
│   ├── CloudsShape.swift             (NEW)
│   ├── StarsShape.swift              (NEW — multiple circles view, not Path)
│   ├── MoonShape.swift               (NEW — crescent Path)
│   ├── MountainsShape.swift          (NEW)
│   ├── SunShape.swift                (NEW — circle + ray lines)
│   └── MoodPill.swift                (NEW — reusable pill chip)
├── Theme/
│   └── WidgetWidgetTheme.swift       (MODIFIED — add gradients + widgetFont helper)
├── Data/
│   └── TimelineSnapshot.swift        (NEW — entry payload value types)
└── (root)
    ├── DinoLiveActivityBundle.swift  (MODIFIED — swap MoodCheckInWidget → MoodWidget)
    ├── Info.plist                    (UNCHANGED — UIAppFonts already present)
    └── WidgetDataProvider.swift      (MODIFIED only if gaps found in § F)
```

### NEW files (18)

1. `DinoLiveActivity/Widgets/MoodWidget.swift`
   Top-level types: `struct MoodWidget: Widget`, `struct MoodEntry: TimelineEntry`, `struct MoodProvider: TimelineProvider`. Replaces the existing `MoodCheckInWidget` (see § G decision).
2. `DinoLiveActivity/Widgets/StreakWidget.swift` — **rewrite existing file in place**. New `StreakEntry` adds `animationPhase: Int` and weekly-dot metadata already present. Keep `kind = "StreakWidget"` for continuity so existing user-placed widgets don't vanish.
3. `DinoLiveActivity/Widgets/BreathingWidget.swift` — **rewrite existing file in place**. New `BreathingEntry { date, breathPhase: Double }`. Keep `kind = "BreathingWidget"`.
4. `DinoLiveActivity/Views/MoodWidgetView.swift` — `MoodWidgetEntryView` dispatcher by time-of-day × family.
5. `DinoLiveActivity/Views/MoodMorningView.swift` — `MoodMorningSmallView`, `MoodMorningMediumView` (sun + rays + hills + dino morning scene).
6. `DinoLiveActivity/Views/MoodDayView.swift` — `MoodDaySmallView`, `MoodDayMediumView` (clouds + tree silhouette + dino).
7. `DinoLiveActivity/Views/MoodNightView.swift` — `MoodNightSmallView`, `MoodNightMediumView` (stars + moon + mountains + sleeping dino).
8. `DinoLiveActivity/Views/StreakWidgetView.swift` — `StreakSmallView`, `StreakMediumView` using `FlameShape` + weekly dots.
9. `DinoLiveActivity/Views/BreathingWidgetView.swift` — `BreathingSmallView`, `BreathingMediumView` using `BreathingBloomShape`.
10. `DinoLiveActivity/Shapes/FlameShape.swift` — `struct FlameShape: Shape` with `flickerPhase: Double` animatable via `animatableData`.
11. `DinoLiveActivity/Shapes/BreathingBloomShape.swift` — `struct BreathingBloomShape: Shape` + gradient fill helper.
12. `DinoLiveActivity/Shapes/HillsShape.swift` — two `Path`s rendered as back/front rolling hills.
13. `DinoLiveActivity/Shapes/CloudsShape.swift` — two rounded-blob `Path`s.
14. `DinoLiveActivity/Shapes/StarsShape.swift` — `View` struct that scatters small filled Circles at deterministic positions (seeded).
15. `DinoLiveActivity/Shapes/MoonShape.swift` — crescent built by subtracting two circles via `.fill(.evenOdd)` Path.
16. `DinoLiveActivity/Shapes/MountainsShape.swift` — 3 layered triangular `Path`s.
17. `DinoLiveActivity/Shapes/SunShape.swift` — central Circle + 8 ray lines drawn as `Path`.
18. `DinoLiveActivity/Shapes/MoodPill.swift` — reusable pill chip `View` (emoji + label, rounded-rect background).
19. `DinoLiveActivity/Data/TimelineSnapshot.swift` — value types: `enum DinoTimeOfDay { morning, day, night }` (consolidated replacement for the old `DinoTimeState`), `struct MoodSnapshot`, `struct StreakSnapshot`, `struct BreathingSnapshot`.

### MODIFIED files (3)

1. `DinoLiveActivity/DinoLiveActivityBundle.swift`
   - Replace `MoodCheckInWidget()` with `MoodWidget()`.
   - `StreakWidget()` and `BreathingWidget()` lines unchanged (same type names reused).
   - Leave `DailyAffirmationWidget`, `GratitudeWidget`, `TodaysFocusWidget`, and Live Activities untouched.
2. `DinoLiveActivity/WidgetTheme.swift`
   - Additive extension: `static func widgetFont(size: CGFloat) -> Font` returning `Font.custom("DinoInitiativeFont-Regular", size: size)`.
   - Add gradient helpers: `var morningSkyGradient`, `var dayCloudGradient`, `var nightSkyGradient`, `var flameGradient`, `var bloomGradient`. Computed from existing palette fields so they remain theme-aware.
   - Do NOT change existing palette fields — existing Affirmation/Gratitude/Focus widgets rely on them.
3. `DinoLiveActivity/WidgetDataProvider.swift` — **only if gaps confirmed** (see § F):
   - Add `var todayBreathingSessionCount: Int` if we decide to show it.
   - Add `var lastBreathingSessionDate: Date?`.
   - Existing `weeklyStreakDays` and `longestStreak` cover streak needs; no change needed there.
   - Additive only; no existing signatures changed.

### UNCHANGED files

- `Info.plist` — `UIAppFonts` entry is already correct.
- `BreathingLiveActivity.swift`, `MeditationLiveActivity.swift`, `FocusLiveActivity.swift`, `DinoActivityAttributes.swift` — Live Activities, out of scope.
- `DailyAffirmationWidget.swift`, `GratitudeWidget.swift`, `TodaysFocusWidget.swift` — not in this round.
- `Assets.xcassets/` — existing mascot assets reused. No new assets.
- `project.pbxproj` — no manual edits. New Swift files are picked up automatically via `PBXFileSystemSynchronizedRootGroup` (id `AA000030AAAA000000000001`).

### Decision on existing `MoodCheckInWidget.swift`

**Recommendation: REPLACE IN PLACE.** Rationale:
- The existing file's `kind = "MoodCheckInWidget"` should be preserved as the new `MoodWidget.swift`'s kind so home-screen instances users have already placed continue to render (swapping the `kind` string would orphan them).
- The existing file defines `DinoTimeState`, `MoodCheckInEntry`, three Morning views, three Night views, three Day views, `WeeklyTrackerRow`, and private color palettes. The new design subsumes all of these — keeping them alongside invites name collisions (e.g. `DinoTimeState` vs `DinoTimeOfDay`) and doubles binary size.
- Side-by-side would also show both widgets in the Widget Gallery, confusing users.
- Concrete steps: delete `DinoLiveActivity/MoodCheckInWidget.swift`, add `DinoLiveActivity/Widgets/MoodWidget.swift` with `struct MoodWidget: Widget { let kind = "MoodCheckInWidget" … }`. The `struct` type rename (MoodCheckInWidget → MoodWidget) is only a Swift symbol change; the `kind` string is what WidgetKit persists on the home screen.
- Update `DinoLiveActivityBundle.swift` to reference `MoodWidget()`.

---

## § C. Widget behavior details

### 1. Mood Widget

- **kind**: `"MoodCheckInWidget"` (preserve existing string so placed widgets persist)
- **Swift type name**: `MoodWidget`
- **configurationDisplayName**: `"Mood Check-In"`
- **description**: `"A gentle nudge to notice how you feel, morning, day, and night."`
- **supportedFamilies**: `[.systemSmall, .systemMedium]`
- **TimelineProvider strategy**:
  - Build 6 entries per hour at 10-minute cadence starting from `now` aligned to the next 10-minute boundary.
  - Additionally, insert boundary entries at the next occurrence of **06:00**, **12:00**, and **20:00** so the time-of-day variant flips exactly on schedule (constraint: morning 6–12, day 12–20, night 20–6).
  - Merge, sort by date, dedupe.
  - `Timeline(entries:, policy: .after(lastEntry.date))` — WidgetKit will request the next timeline when the last entry passes.
  - Each entry includes `timeOfDay: DinoTimeOfDay`, `sceneAnimPhase: Int (0...5)`, and a pre-read `WidgetDataProvider().todayMoodEmoji` for the small variant's optional last-mood indicator.
- **widgetURL**: `dino://mood` for morning/day; `dino://journal` for night (matches existing behavior — user-approved).
- **Placeholder / snapshot**: `MoodSnapshot(timeOfDay: .day, sceneAnimPhase: 0, lastMoodEmoji: "🌤")`. The Widget Gallery preview shows the Day variant.

### 2. Streak Widget

- **kind**: `"StreakWidget"` (preserved)
- **Swift type name**: `StreakWidget` (keep name)
- **configurationDisplayName**: `"Streak"`
- **description**: `"Your streak at a glance — with this week's progress."`
- **supportedFamilies**: `[.systemSmall, .systemMedium]` (**drop large**; out of scope for this round — update `.supportedFamilies`)
- **TimelineProvider strategy**:
  - One primary entry at `now` with the current streak snapshot.
  - One boundary entry at the next `startOfDay` (midnight) to handle streak rollover without requiring the app to reload.
  - Six additional entries per hour at 10-minute cadence for the **flame flicker** keyframes. Flame flickerPhase values: `[0.00, 0.18, 0.36, 0.58, 0.80, 0.95]` cycled.
  - `policy: .after(lastEntry.date)`.
- **widgetURL**: `dino://streak` (already exists).
- **Placeholder**: `StreakSnapshot(currentStreak: 7, longestStreak: 14, weeklyDays: [T,T,T,F,T,F,F], flickerPhase: 0.4)`.

### 3. Breathing Widget

- **kind**: `"BreathingWidget"` (preserved)
- **Swift type name**: `BreathingWidget` (keep)
- **configurationDisplayName**: `"Breathe"`
- **description**: `"Tap anytime for a one-minute breathing reset."`
- **supportedFamilies**: `[.systemSmall, .systemMedium]`
- **TimelineProvider strategy**:
  - 6 entries per hour at 10-minute cadence. `breathPhase` walks through `[0.92, 0.96, 1.00, 1.04, 1.08, 1.04]`.
  - `policy: .after(lastEntry.date)`.
  - No day-boundary entries needed.
- **widgetURL**: `dino://breathe` (already exists).
- **Placeholder**: `BreathingSnapshot(breathPhase: 1.0)`.

---

## § D. Shape drawing specs

All shapes are `Shape` or `View` in SwiftUI. **All bezier control points must be copied from the SVG `<path d="...">` commands in `/Users/vikas/Downloads/DinoDesignSystem5/widgets.html` at implementation time.** The plan below specifies what to look for and canvas-level geometry; do not hand-guess from prose.

### FlameShape
- ViewBox: 24 × 32 (normalize then scale via `GeometryReader`).
- Re-read `widgets.html` for the `<path d>` of the flame icon. Approx anchors: tip ≈ (12, 2), shoulder-left ≈ (4, 14), shoulder-right ≈ (20, 14), base ≈ (12, 30) with cubic bezier smoothing.
- Fill: `LinearGradient(flameGradient)` (top `theme.accent.opacity(1.0)` → bottom `theme.accent.opacity(0.7)`).
- Stroke: none.
- Animatable state: `flickerPhase: Double in [0,1]`. Exposed via `var animatableData: Double { get flickerPhase; set flickerPhase = newValue }`.
- Effect: affine transform — scaleY `1.0 + 0.08 * sin(2π * phase)`, scaleX `1.0 - 0.04 * sin(2π * phase)`, translateY `-1 * sin(2π * phase)`. Matches CSS `@keyframes flame-flicker` in the HTML.

### BreathingBloomShape
- ViewBox: 100 × 100.
- Flower-like bloom — 6 petals arranged radially. Re-read `widgets.html` for the `<path d>` (look for `class="bloom"` or `#bloom`).
- Fill: `RadialGradient(colors: [theme.accent.opacity(0.95), theme.accent.opacity(0.35)], center: .center, startRadius: 0, endRadius: 48)`.
- State: `breathPhase: Double` (value = scale multiplier from entry). Applied via `.scaleEffect(entry.breathPhase)` — shape itself does NOT animate; outer View applies scale keyframe per timeline entry.

### HillsShape (morning + day backgrounds)
- ViewBox: 200 × 80 (wide, short band sitting at bottom).
- Two stacked `Path`s: `backHill` (lower amplitude, rear) and `frontHill` (higher amplitude, front). Approximate shape: `move(0,60) curve through (50,35),(100,55),(150,30),(200,55) line(200,80) line(0,80) close`.
- Back fill: morning `Color(hex:"E8B867")`, day `theme.accent.opacity(0.25)`. Front fill: morning `Color(hex:"C48A3A")`, day `theme.accent.opacity(0.45)`.

### CloudsShape (day background)
- Two cloud blobs. Each cloud is a `Path` built from 3 overlapping circles fused with bezier curves (common rounded-cloud construction).
- Fill: `Color.white.opacity(0.85)` overlaid on blue sky gradient.

### StarsShape (night background)
- **Not a Path** — a `View` struct that lays out 14 filled `Circle()`s with deterministic positions from a fixed RNG seed (so stars don't jump on reload).
- Sizes: small (1.5pt), medium (2.5pt), large (3.5pt) with soft glow via `.shadow(color: .white.opacity(0.4), radius: 1.5)`.

### MoonShape (night background)
- Canvas 40 × 40.
- Crescent: `Path` that combines an outer circle (r=18) with an inner offset circle (r=16, offset +6,-2) using `.fill(style: FillStyle(eoFill: true))`.
- Fill: `Color(hex:"F3E8A8")`.

### MountainsShape (night background)
- Three layered triangles across a 200-wide canvas. Back layer `Color(hex:"2A2A4E")` highest/softest, mid `Color(hex:"1E1E3A")`, front `Color(hex:"141428")` lowest.
- Snow cap: small cap triangle at each peak tip, `Color.white.opacity(0.75)`.

### SunShape (morning background)
- Central filled `Circle()` radius 16 at (50,50). Gradient fill sunrise-yellow → orange.
- 8 ray lines drawn as `Path`: start 22pt from center, end 34pt from center, at angles `0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°`. Stroke `Color(hex:"F5B731")` linewidth 2, rounded caps.
- For morning, also draw 2 concentric faint arc rings around the sun (radius 28 and 40, stroke opacity 0.25).

### MoodPill (reusable chip)
- `View` with `HStack { emoji; Text(label).widgetFont(11) }`, horizontal pad 10, vertical pad 6, background `Capsule().fill(theme.cardBackground.opacity(0.9))`, overlay `Capsule().stroke(theme.divider, lineWidth: 1)`.
- Used in the medium Mood widget for the 4 mood options (mirroring existing `moodOptions: ["calm","happy","okay","low"]`).

### Scene composition summary
- **Morning**: sky gradient `#FFD27A` → `#F5B731`, `SunShape` top-left, faint rays, `HillsShape` bottom, dino mascot `Image("DinoMorning")` bottom-right.
- **Day**: sky gradient `#CFE8FF` → `#E9F5FF`, 2 `CloudsShape` blobs top, simple tree silhouette (`Path` trunk rectangle + ellipse crown) mid-left, `HillsShape` bottom, dino `Image("DinoWidget")` bottom-right.
- **Night**: sky gradient `#1A1B3D` → `#0F1025`, `StarsShape` upper half, `MoonShape` top-right, `MountainsShape` bottom, dino `Image("DinoSleeping")` bottom-right.

---

## § E. Font registration

- Current font path: `/Users/vikas/Dino/DinoLiveActivity/DinoInitiativeFont-Regular.ttf` — already a resource of the widget target (via `PBXFileSystemSynchronizedRootGroup`).
- Also present at `/Users/vikas/Dino/Dino/DinoInitiativeFont-Regular.ttf` for the main app.
- No pbxproj edit required.
- `Info.plist` already contains `<key>UIAppFonts</key><array><string>DinoInitiativeFont-Regular.ttf</string></array>` — no change.
- PostScript name: existing widgets successfully render via `Font.custom("DinoInitiativeFont-Regular", size:)`, so the PostScript name equals the base filename. To explicitly verify at implementation time, run from the repo root:
  ```
  otfinfo --postscript-name DinoLiveActivity/DinoInitiativeFont-Regular.ttf
  # or
  fc-query DinoLiveActivity/DinoInitiativeFont-Regular.ttf | head
  ```
- Recommended helper (added to `WidgetTheme.swift`):
  ```swift
  extension WidgetTheme {
      static func widgetFont(size: CGFloat) -> Font { .custom("DinoInitiativeFont-Regular", size: size) }
  }
  ```
  All new widget views should call `WidgetTheme.widgetFont(size: 14)` instead of `Font.custom(...)` inline — single source of truth, no dependency on main-app `DinoTheme` types.

---

## § F. Data integration

### Values each widget needs
- **Mood widget**
  - Current hour (from `entry.date` — computed in provider, stored as `DinoTimeOfDay` on the entry).
  - `todayMoodEmoji` (already in provider) — optional, shown in corner of small variant if already logged today.
- **Streak widget**
  - `currentStreak` (present)
  - `longestStreak` (present; medium shows it)
  - `weeklyStreakDays: [Bool]` (present)
  - `flickerPhase: Double` (timeline-driven, not from provider)
- **Breathing widget**
  - `breathPhase: Double` (timeline-driven)
  - **Optional** — `todayBreathingSessionCount`, `lastBreathingSessionDate` (not currently in provider).

### Gaps and proposed additive changes to `WidgetDataProvider`
Needed only if medium Breathing widget is to show "N sessions today" copy. Alternatives:
- (a) Skip — show static "take 1 minute" copy. Zero provider change. **Recommended v1.**
- (b) Add additive props:
  ```swift
  var todayBreathingSessionCount: Int    // reads "breathingSessions" key if main app writes it
  var lastBreathingSessionDate: Date?
  ```
  Requires confirming that the main-app `SharedDataManager` already writes breathing session data to the shared suite. If it doesn't, main-app changes would be needed — **out of scope per constraints**. So v1 sticks with (a).

### Refresh triggers in the main app
Current state:
- `WidgetCenter.shared.reloadAllTimelines()` is called **only** in `Dino/Theme/ThemeManager.swift` (lines 381, 406).
- **Not called** after: logging a mood, completing a breathing session, completing a focus session, recording a gratitude note.

Required additions (each is a single-line `WidgetCenter.shared.reloadAllTimelines()` after the data write). **These are main-app changes — flagged because the scope constraint restricts us to widget files + Info.plist + WidgetDataProvider additives.** Call sites to instrument:
- After a mood entry is saved (likely `Dino/ViewModels/MoodViewModel.swift` or `SharedDataManager.saveMoodEntry`).
- After a breathing session completes.
- After a streak-contributing action that rolls the day counter.
- At app launch / scene activation (cheap safety net).

**Decision for this round**: Do not add these calls now. The 10-minute timeline cadence + the midnight boundary entry in the Streak timeline means widgets will update within ~10 minutes of any mood/breathing event anyway. If snappier updates are wanted, the user can approve main-app edits in a follow-up. Mentioned as open question in § G.

---

## § G. Open questions for user

1. **Mood pill tap target.** Small widgets on iOS 16 cannot have per-element tap zones; only `widgetURL` works. On iOS 17+, `Button` + `AppIntent` allow per-pill tap. **Recommendation v1**: whole-widget `widgetURL(dino://mood)`; defer pill-tap AppIntents. Approve?
2. **Weekly dots locale**. Hard-code `"S M T W T F S"` (current behavior in `StreakWidget.swift`) or switch to `Calendar.current.veryShortWeekdaySymbols`? Localization implications.
3. **Mood night deep link** — current code routes night to `dino://journal`. Constraint says `dino://mood`, `dino://breathe`, `dino://journal` are registered. Keep night → journal or unify to `dino://mood`?
4. **Entitlements confirmation**. No `.entitlements` file found in repo. Please confirm in Xcode → DinoLiveActivityExtension → Signing & Capabilities that App Group `group.com.vikassabbi.dino` is present. (The existing widgets render, so this is almost certainly already wired — just double-check.)
5. **Main-app reload calls** (§ F). OK to defer for v1 and rely on 10-minute timeline cadence? Or patch `SharedDataManager` / mood/breathing write paths now?
6. **PostScript name verification**. Who runs `otfinfo --postscript-name`? If existing widgets already render via `Font.custom("DinoInitiativeFont-Regular", …)`, this may be a skip.
7. **Preview sample data**. Hard-coded ("7 day streak", mood "calm"), or varied mocks for Widget Gallery polish?

---

## § H. Build + verification

- Build command:
  ```
  xcodebuild -scheme Dino \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    clean build
  ```
  (The widget extension is embedded into the `Dino` scheme; no separate widget scheme.)
- Preview in Xcode: open any new widget file, use the `#Preview(as: .systemSmall) { … } timeline: { … }` blocks at the bottom of each widget file. Preview canvas renders without running the simulator.
- Widget Gallery test in simulator:
  1. Run `Dino` scheme on an iOS simulator.
  2. Long-press home screen → tap **+** → search "Dino" → tap the widget → pick small or medium.
  3. Verify: mood time-of-day switches at 6/12/20; streak dots reflect `weeklyStreakDays`; flame flickers slightly as minutes pass; bloom gentle-scales.
- Bundle size: widget extensions cap ~30MB. Mascot PNGs (`DinoMorning.png`, `DinoSleeping.jpg`, `DinoWidget.png`, `DinoWidgetNight.png`) already in extension's `Assets.xcassets` — total under 1MB. No new assets. No risk.
- Accessibility: all `widgetFont` text should pair with `.accessibilityLabel(...)` on the containing view (e.g. "7 day streak, 3 of 7 days this week active").

---

## § I. Scope guardrails (restated)

**In scope:**
- New/modified Swift files under `/Users/vikas/Dino/DinoLiveActivity/` only.
- Edit `DinoLiveActivity/DinoLiveActivityBundle.swift` to swap `MoodCheckInWidget()` for `MoodWidget()`.
- Additive extensions/properties on `WidgetDataProvider` (only if § F gap approved; otherwise untouched).
- `DinoLiveActivity/WidgetTheme.swift` additive helpers.

**Out of scope (do not touch):**
- `Dino/` main-app Swift files (including `SharedDataManager.swift`, `ThemeManager.swift`, all views/viewmodels).
- `Dino/Data/WidgetDataProvider.swift` (main-app's duplicate copy).
- `Dino/Info.plist` URL schemes (already registered).
- `Dino.xcodeproj/project.pbxproj` — no manual edits; synchronized root groups pick up new files automatically.
- `Assets.xcassets` — reuse existing mascot assets.
- Live Activity files.
- Other widgets: `DailyAffirmationWidget`, `GratitudeWidget`, `TodaysFocusWidget`.
- Lock-screen / accessory widget families.
