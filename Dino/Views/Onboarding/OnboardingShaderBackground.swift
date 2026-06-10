//
//  OnboardingShaderBackground.swift
//  Dino
//
//  Metal-shader ambient backgrounds (aurora + light motes) with a static
//  gradient fallback under reduce-motion. Shaders live in DinoShaders.metal.
//

import SwiftUI

struct OnboardingShaderBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Brand palette
    private let sage     = Color(red: 168/255, green: 197/255, blue: 160/255)
    private let lavender = Color(red: 196/255, green: 184/255, blue: 212/255)
    private let peach    = Color(red: 245/255, green: 198/255, blue: 170/255)
    private let navy     = Color(red: 15/255,  green: 15/255,  blue: 34/255)

    var body: some View {
        if reduceMotion {
            // Static gradient fallback
            LinearGradient(
                colors: [navy, navy.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(
                RadialGradient(
                    colors: [sage.opacity(0.25), .clear],
                    center: .init(x: 0.3, y: 0.25),
                    startRadius: 0, endRadius: 400
                )
            )
            .ignoresSafeArea()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = Float(
                    timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3600)
                )

                Rectangle()
                    .fill(navy)
                    .colorEffect(
                        ShaderLibrary.auroraWash(
                            .boundingRect,
                            .float(t),
                            .color(sage),
                            .color(lavender),
                            .color(peach)
                        )
                    )
                    .colorEffect(
                        ShaderLibrary.lightMotes(
                            .boundingRect,
                            .float(t)
                        )
                    )
            }
            .ignoresSafeArea()
        }
    }
}

// Mist variant for the nature scene steps
struct NatureMistOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = Float(
                    timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3600)
                )
                Rectangle()
                    // Near-invisible fill instead of .clear — colorEffect shades the
                    // view's rasterized pixels, and a fully transparent fill can be
                    // optimized away to zero fragments on some OS versions.
                    .fill(Color.black.opacity(0.001))
                    .colorEffect(
                        ShaderLibrary.mistDrift(
                            .boundingRect,
                            .float(t),
                            .float(0.78)  // mist sits in lower quarter
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}
