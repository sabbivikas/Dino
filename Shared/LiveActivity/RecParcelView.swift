//
//  RecParcelView.swift
//  Shared (Dino + DinoLiveActivityExtension)
//
//  Rec delivery F3 — the paper parcel: cream box, string cross, washi "?"
//  sticker. Drawn in pure SwiftUI (no assets) so the live activity, the
//  dynamic island, and the app render the identical parcel, matching the
//  app's paper aesthetic. The glow is a warm halo that gently breathes;
//  Reduce Motion gets a calm static glow.
//

import SwiftUI

struct RecParcelView: View {
    var size: CGFloat = 96
    var glowing: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    // paper palette (mirrors DinoPalette.cream / laInk — duplicated because
    // this file compiles into both targets and neither theme type is shared)
    private let cream       = Color(red: 0.984, green: 0.965, blue: 0.922)   // #FBF6EB
    private let creamShade  = Color(red: 0.937, green: 0.906, blue: 0.839)   // #EFE7D6
    private let paperEdge   = Color(red: 0.816, green: 0.769, blue: 0.667)   // #D0C4AA
    private let twine       = Color(red: 0.545, green: 0.463, blue: 0.322)   // #8B7652
    private let washiPink   = Color(red: 0.910, green: 0.706, blue: 0.722)   // #E8B4B8
    private let ink         = Color(red: 0.067, green: 0.251, blue: 0.176)   // #11402D
    private let glowWarm    = Color(red: 1.0, green: 0.914, blue: 0.722)     // #FFE9B8

    var body: some View {
        ZStack {
            if glowing {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowWarm.opacity(0.85), glowWarm.opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: size * 0.72)
                    )
                    .frame(width: size * 1.45, height: size * 1.45)
                    .scaleEffect(reduceMotion ? 1.0 : (breathing ? 1.08 : 0.94))
                    .opacity(reduceMotion ? 0.75 : (breathing ? 1.0 : 0.6))
            }

            // the box
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [cream, creamShade],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.12)
                        .stroke(paperEdge, lineWidth: max(1, size * 0.016))
                )
                .frame(width: size, height: size * 0.82)

            // lid crease
            Rectangle()
                .fill(paperEdge.opacity(0.55))
                .frame(width: size, height: max(1, size * 0.012))
                .offset(y: -size * 0.22)

            // string cross
            Rectangle()
                .fill(twine)
                .frame(width: max(1.5, size * 0.028), height: size * 0.82)
            Rectangle()
                .fill(twine)
                .frame(width: size, height: max(1.5, size * 0.028))
            // the knot — a small bow of two loops + a heart of twine
            HStack(spacing: size * 0.02) {
                Ellipse()
                    .stroke(twine, lineWidth: max(1.2, size * 0.022))
                    .frame(width: size * 0.13, height: size * 0.085)
                    .rotationEffect(.degrees(-24))
                Ellipse()
                    .stroke(twine, lineWidth: max(1.2, size * 0.022))
                    .frame(width: size * 0.13, height: size * 0.085)
                    .rotationEffect(.degrees(24))
            }
            Circle()
                .fill(twine)
                .frame(width: size * 0.06, height: size * 0.06)

            // washi "?" sticker, slightly tilted, top-right
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(washiPink.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.05)
                        .stroke(Color.white.opacity(0.65), lineWidth: max(0.8, size * 0.012))
                )
                .frame(width: size * 0.30, height: size * 0.30)
                .overlay(
                    Text("?")
                        .font(.custom("DinoInitiativeFont-Regular", size: size * 0.21))
                        .foregroundColor(ink)
                )
                .rotationEffect(.degrees(12))
                .offset(x: size * 0.30, y: -size * 0.30)
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .onAppear {
            guard glowing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)   // the accompanying line carries the meaning
    }
}
