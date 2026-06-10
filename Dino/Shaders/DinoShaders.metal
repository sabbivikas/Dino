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
