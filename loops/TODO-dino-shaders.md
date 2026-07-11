# loop 1 — the atmosphere layer (feature/dino-shaders)

rubric per box: feels-like-tide-not-tech · storybook-not-videogame ·
text-readability-untouched · would-a-tired-person-find-it-calming — all ≥4.

- [ ] GradientSeed.swift: seed string → deterministic warm palette → mesh
      gradient, unit tests for determinism and palette warmth bounds
- [ ] breathing water: Inferno's water technique adapted to the breathing
      circle — glow breathes with the phase, subtle caustic shimmer, same
      timing source as the circle + haptic tide. Reduce Motion → static glow.
- [ ] paper grain shader: Inferno's noise adapted to a whisper-subtle static
      grain layer for paper components (comfort slip, resources cards)
- [ ] mood screen weather: WeatherKit condition → storybook rain / snow /
      fog as a gentle shader pass. Off under Reduce Motion.
- [ ] world rim-light + pulse bloom: additive edge glow on the dark globe,
      pulse blooms that bleed light into the night
- [ ] discipline pass: every shader pauses off-screen, battery-innocent
