# loop 1 — the atmosphere layer (feature/dino-shaders)

rubric per box: feels-like-tide-not-tech · storybook-not-videogame ·
text-readability-untouched · would-a-tired-person-find-it-calming — all ≥4.

- [x] GradientSeed.swift: seed string → deterministic warm palette → mesh
      gradient, unit tests for determinism and palette warmth bounds
      (iter 1 — rubric 4/5/5/4)
- [x] breathing water: Inferno's water technique adapted to the breathing
      circle — glow breathes with the phase, subtle caustic shimmer, same
      timing source as the circle + haptic tide. Reduce Motion → static glow.
      (iter 2 — rubric 4/4/5/4; time-precision fix landed in iter 4)
- [x] paper grain shader: Inferno's noise adapted to a whisper-subtle static
      grain layer for paper components (comfort slip, resources cards)
      (iter 3 — rubric 4/5/5/4)
- [x] mood screen weather: WeatherKit condition → storybook rain / snow /
      fog as a gentle shader pass. Off under Reduce Motion.
      (iter 4 — rain 4/4/5/4 · snow 4/4/5/4 · fog 4/4/5/5)
- [x] world rim-light + pulse bloom: additive edge glow on the dark globe,
      pulse blooms that bleed light into the night
      (iter 5 — rubric 4/4/5/4)
- [x] discipline pass: every shader pauses off-screen, battery-innocent
      (iter 6 — regression rubric 4/4/5/4)
