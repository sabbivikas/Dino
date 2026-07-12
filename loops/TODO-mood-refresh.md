# loop 2 — the mood screen refresh (feature/mood-refresh)

design law: NO EMOJI in new UI — all iconography is designed vector glyphs
(SwiftUI paths, hand-drawn weight). new copy: lowercase, zero dashes, no emoji.

rubric per box (1–5, ALL ≥4): paper-not-plastic ·
selection-feels-like-choosing-a-card · button-feels-alive-not-needy ·
glyphs-feel-hand-drawn-not-icon-pack · gentle-when-heavy · survives-XXL-type

- [x] designed weather glyphs: DinoWeatherGlyph — four hand-drawn-feel vector
      marks (sun with soft uneven rays / drifting cloud / storm cloud with rain
      strokes / low mist bands), irregular strokes, idle animation <4s cycle,
      Reduce Motion static, per-glyph structure for Chloe's future art swap
      (iter 1 — glyphs 5 · gentle 4 · XXL 4 · selection 4)
- [x] the log button: sage breathing pulse (3.2s), selected mood's glyph,
      honest muted disabled state, pressed squish, adaptive handwritten line
      after selection (heavy: "however it is, it counts" / light: "glad the
      sky is kind today") — in voice tests
      (iter 2 — alive 4 · gentle 5 · glyphs 5 · paper 4)
- [x] mood cards in paper: shader grain material, radius 8–10, hairline
      #EFE7D2, glyphs replace illustrations, selection = lift + 1.4°
      alternating tilt + sage tape + deeper shadow (spring .28s overshoot),
      heavy-mood selection SOFTER than light (dimmer tape, gentler lift)
      (iter 3 — paper 5 · choosing 5 · gentle 5 · glyphs 5)
- [x] sliders as light: energy fills warm gold (#E8B84A family), intensity
      fills lavender (#9C8FB8 family), designed thumbs (warm disc, hand-drawn
      ring), native accessibility + haptics preserved
      (iter 4 — paper 4 · drawn 4 · alive 4; a11y added where none existed)
- [x] week strip → seven skies: seeded gradient sky squares via GradientSeed
      (seed = userId + dayKey + mood; heavy dusk, light warm, no-log faint
      empty paper), day labels stay, a11y label = day + mood, radius 8,
      hairline, soft inner light
      (iter 5 — paper 4 · gentle 5 · painterly 4)
- [x] state sweep: nothing-selected · each mood selected · logged · XXL type ·
      Reduce Motion — screenshot-verified, breakages fixed
      (iter 6 — XXL 5 · all states green, zero breakages found)
