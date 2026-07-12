//
//  DinoShaders.metal
//  Dino
//
//  SwiftUI colorEffect shaders for ambient backgrounds:
//  auroraWash (brand-color aurora), mistDrift (low fog band),
//  lightMotes (dust drifting through god rays).
//  Requires iOS 17+ (SwiftUI Shader API).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ── Hash & noise helpers ─────────────────────

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// fbm = layered noise for organic cloud shapes
float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return v;
}

// ── Aurora background ────────────────────────
// Usage: .colorEffect with time, size, and 3 brand colors

[[ stitchable ]] half4 auroraWash(
    float2 position,
    half4 currentColor,
    float4 bounds,  // .boundingRect from SwiftUI: (x, y, width, height)
    float time,
    half4 colorA,   // sage   #A8C5A0
    half4 colorB,   // lavender #C4B8D4
    half4 colorC    // peach  #F5C6AA
) {
    float2 size = bounds.zw;
    float2 uv = position / size;

    // Slow horizontal drift, vertical squash —
    // matches the design's aurora-wash keyframe
    float2 p = uv * float2(2.0, 3.5);
    p.x += time * 0.04;                  // drift
    p.y -= time * 0.015;                 // slow rise

    // Two octaves of flowing fbm offset against
    // each other creates the "wash" movement
    float n1 = fbm(p + fbm(p + time * 0.02));
    float n2 = fbm(p * 1.7 - time * 0.03);

    // Band the aurora into the upper 60% of screen,
    // fading toward the bottom
    float band = smoothstep(0.85, 0.15, uv.y);

    // Blend the three brand colors by noise value
    half4 aurora = mix(colorA, colorB, half(smoothstep(0.3, 0.7, n1)));
    aurora = mix(aurora, colorC, half(smoothstep(0.55, 0.9, n2)) * 0.6h);

    // Intensity pulses gently (nebula-pulse spec:
    // opacity .25→.45 over the cycle)
    float pulse = 0.25 + 0.20 * (0.5 + 0.5 * sin(time * 0.35));
    float strength = band * n1 * pulse;

    return mix(currentColor, aurora, half(strength));
}

// ── Drifting mist layer ──────────────────────
// For nature scenes: low fog that drifts ±8%

[[ stitchable ]] half4 mistDrift(
    float2 position,
    half4 currentColor,
    float4 bounds,     // .boundingRect from SwiftUI: (x, y, width, height)
    float time,
    float mistHeight   // 0-1, where mist sits (0.75 = lower quarter)
) {
    float2 size = bounds.zw;
    float2 uv = position / size;

    float2 p = uv * float2(3.0, 8.0);
    p.x += sin(time * 0.12) * 0.8;   // mist-drift: translateX ±8%
    p.x += time * 0.02;

    float m = fbm(p);

    // Confine to a horizontal band around mistHeight
    float band = exp(-pow((uv.y - mistHeight) * 6.0, 2.0));

    // Opacity .35→.55 per the design spec
    float opacity = 0.35 + 0.20 * (0.5 + 0.5 * sin(time * 0.25));
    float strength = band * m * opacity;

    return mix(currentColor, half4(1.0h, 1.0h, 1.0h, 1.0h), half(strength));
}

// ── Floating motes in light ──────────────────────
// Dust particles drifting upward through god rays

[[ stitchable ]] half4 lightMotes(
    float2 position,
    half4 currentColor,
    float4 bounds,  // .boundingRect from SwiftUI: (x, y, width, height)
    float time
) {
    float2 size = bounds.zw;
    float2 uv = position / size;
    half mote = 0.0h;

    // 8 motes, each on its own seeded path
    for (int i = 0; i < 8; i++) {
        float seed = float(i) * 7.13;
        float speed = 0.025 + hash21(float2(seed, 1.0)) * 0.02;

        float2 center = float2(
            fract(hash21(float2(seed, 2.0)) + sin(time * 0.1 + seed) * 0.05),
            fract(hash21(float2(seed, 3.0)) - time * speed)
        );

        float dist = length((uv - center) * float2(size.x / size.y, 1.0));
        float radius = 0.0035 + hash21(float2(seed, 4.0)) * 0.002;

        // Soft glow dot with pulsing alpha (mote-drift spec)
        float glow = smoothstep(radius, 0.0, dist);
        float flicker = 0.5 + 0.5 * sin(time * 1.5 + seed * 3.0);
        mote += half(glow * flicker * 0.6);
    }

    half4 moteColor = half4(1.0h, 0.97h, 0.88h, 1.0h); // warm white
    return mix(currentColor, moteColor, min(mote, 0.85h));
}

// ============================================================================
// THE ATMOSPHERE LAYER (loop 1). Techniques adapted from Inferno
// (github.com/twostraws/Inferno), MIT License, Copyright (c) 2023 Paul
// Hudson and other authors — approaches borrowed, every parameter retuned
// for dino: gentle, slow, warm (cream #FAF6EC, sage #7BA872, dusk navys).
// No package dependency; these functions are ours.
// ============================================================================

// Inferno's noise trick (dot-product sine hash) with TIME REMOVED for the
// grain use — paper never boils.
static float dinoHash(float2 position, float offset) {
    float sum = dot(position, float2(12.9898, 78.233));
    return fract(sin(sum) * 43758.5453 * offset);
}

// ── paper grain — whisper-subtle, STATIC (colorEffect) ────────────────
// amount ~0.035 reads as fiber, not sandpaper. floor() cells keep retina
// densities from shimmering.
[[ stitchable ]] half4 dinoPaperGrain(float2 position, half4 color, float amount) {
    if (color.a <= 0.0h) { return color; }
    float g = dinoHash(floor(position * 0.9), 1.0);
    half delta = half((g - 0.5) * amount);
    return half4(color.rgb + half3(delta) * color.a, color.a);
}

// ── breathing water (distortionEffect) ───────────────────────────
// Inferno's water slowed to a tide: their speed 3 becomes 0.35, and the
// strength swells with `breath` (0 rest → 1 full inhale) so the water
// breathes WITH the circle — the phase clock lives outside, shared with
// the animation and the haptic tide.
[[ stitchable ]] float2 dinoBreathingWater(float2 position, float2 size, float time, float breath, float strength) {
    float2 uv = position / size;
    const float TWO_PI = 6.28318530718;
    float phase = fmod(time * 0.35, TWO_PI);
    float s = (strength / 100.0) * (0.35 + 0.65 * breath);
    uv.x += sin(uv.y * 6.0 + phase) * s;
    uv.y += cos(uv.x * 5.0 + phase) * s;
    return uv * size;
}

// ── caustic shimmer (colorEffect) ──────────────────────────────
// Two crossed slow sines brighten by at most 15% at full breath — light on
// water you can actually see from arm's length, still never a disco.
[[ stitchable ]] half4 dinoCausticShimmer(float2 position, half4 color, float2 size, float time, float breath) {
    if (color.a <= 0.0h) { return color; }
    float2 uv = position / size;
    float phase = fmod(time * 0.4, 6.28318530718);
    float band = sin(10.0 * uv.x + phase) * sin(9.0 * uv.y - phase * 0.8);
    half glow = half(max(0.0, band) * 0.15 * breath);
    return half4(color.rgb + half3(glow) * color.a, color.a);
}

// ── storybook weather (colorEffect on a clear overlay) ───────────────
// kind: 1 rain · 2 snow · 3 fog. intensity 0..1. Drawn INTO transparency:
// the overlay rect is clear and the shader paints gentle weather onto it.
// Column/cell hashes keep patterns from visibly repeating; speeds are
// storybook-slow — never particle spam.
[[ stitchable ]] half4 dinoWeather(float2 position, half4 color, float2 size, float time, float kind, float intensity) {
    float2 uv = position / size;
    half4 out = half4(0.0h);
    if (kind < 0.5) { return out; }

    // NOTE: callers pass a PRE-WRAPPED time (seconds mod 3600, wrapped in
    // Swift as Double) — raw timeIntervalSinceReferenceDate quantizes to
    // ~64 s steps in float32 and freezes every animation here.
    if (kind < 1.5) {
        // rain: sparse thin streaks drifting down, dusk-navy at whisper alpha
        float col = floor(uv.x * 30.0);
        float colHash = dinoHash(float2(col, 7.0), 1.3);
        float speed = 0.14 + colHash * 0.10;
        float y = fract(uv.y * 0.9 - time * speed - colHash * 7.0);
        float fall = smoothstep(0.0, 0.04, y) * smoothstep(0.14, 0.04, y);
        float xin = fract(uv.x * 30.0);
        float thin = smoothstep(0.22, 0.08, fabs(xin - 0.5));   // a thread, not a band
        float gate = step(0.72, colHash);            // ~1 in 4 columns rains
        float a = fall * thin * gate * 0.16 * intensity;
        out = half4(0.36h, 0.40h, 0.52h, 1.0h) * half(a);
    } else if (kind < 2.5) {
        // snow: soft motes with a cool dusk tint so they read on cream skies
        float2 grid = float2(14.0, 10.0);
        float2 cell = floor(uv * grid);
        float h = dinoHash(cell, 2.1);
        float fall = fract(h * 5.0 + time * (0.03 + h * 0.03));
        float sway = sin(time * 0.4 + h * 6.28318) * 0.08;
        float2 inCell = fract(uv * grid) - 0.5;
        float2 moteCenter = float2(sway, (fall - 0.5) * 0.9);
        float mote = smoothstep(0.14, 0.04, length(inCell - moteCenter));
        float gate = step(0.55, h);
        float a = mote * gate * 0.26 * intensity;
        out = half4(0.72h, 0.77h, 0.88h, 1.0h) * half(a);
    } else {
        // fog: two low-frequency bands breathing across — dusk-gray, since
        // cream mist vanishes on dino's light skies
        float band = sin(uv.x * 2.2 + time * 0.06) * sin(uv.y * 1.4 - time * 0.045);
        float a = max(0.0, band) * 0.07 * intensity * (0.7 + 0.3 * sin(time * 0.1));
        out = half4(0.55h, 0.58h, 0.68h, 1.0h) * half(a);
    }
    return out;
}
