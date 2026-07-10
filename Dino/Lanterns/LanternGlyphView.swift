//
//  LanternGlyphView.swift
//  Dino
//
//  The paper lantern from the handoff (viewBox 72×97) as SwiftUI shapes.
//  Each lantern's paper gradient is a seeded pair — no two are alike.
//

import SwiftUI

struct LanternGlyphView: View {
    let seed: Int
    var width: CGFloat = 72

    /// The four paper palettes: classic warm, rose dusk, meadow, moonlit.
    static let papers: [(top: Color, bottom: Color)] = [
        (Color(hex: "#FFE3B3"), Color(hex: "#F5A66B")),
        (Color(hex: "#FFD9C4"), Color(hex: "#E88A9A")),
        (Color(hex: "#F3E4B8"), Color(hex: "#A8C5A0")),
        (Color(hex: "#D9E4F5"), Color(hex: "#9B8ED4")),
    ]

    private var paper: (top: Color, bottom: Color) {
        Self.papers[abs(seed) % Self.papers.count]
    }

    var body: some View {
        let s = width / 72   // design-space scale
        ZStack {
            // top cap
            RoundedRectangle(cornerRadius: 3.5 * s)
                .fill(Color(hex: "#B98A5C"))
                .frame(width: 20 * s, height: 7 * s)
                .position(x: 36 * s, y: 4.5 * s)
            // paper body
            RoundedRectangle(cornerRadius: 27 * s)
                .fill(LinearGradient(colors: [paper.top, paper.bottom],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 27 * s)
                        .fill(RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "#FFF6DC").opacity(0.95), location: 0),
                                .init(color: .clear, location: 1),
                            ]),
                            center: UnitPoint(x: 0.5, y: 0.46),
                            startRadius: 0, endRadius: 30 * s))
                )
                .overlay(ribs.stroke(Color(hex: "#3D3A35").opacity(0.13), lineWidth: 1.4 * s))
                .overlay(
                    RoundedRectangle(cornerRadius: 27 * s)
                        .stroke(Color(hex: "#3D3A35").opacity(0.22), lineWidth: 1.6 * s)
                )
                .frame(width: 58 * s, height: 70 * s)
                .position(x: 36 * s, y: 44 * s)
            // bottom cap + tassel
            RoundedRectangle(cornerRadius: 3 * s)
                .fill(Color(hex: "#B98A5C"))
                .frame(width: 16 * s, height: 6 * s)
                .position(x: 36 * s, y: 83 * s)
            Rectangle()
                .fill(Color(hex: "#B98A5C"))
                .frame(width: 1.6 * s, height: 6 * s)
                .position(x: 36 * s, y: 89 * s)
            Circle()
                .fill(Color(hex: "#E8B45C"))
                .frame(width: 4.8 * s, height: 4.8 * s)
                .position(x: 36 * s, y: 94 * s)
        }
        .frame(width: width, height: width * 1.35)
    }

    /// The three rib curves, translated into the body's local frame.
    private var ribs: Path {
        let s = width / 72
        var p = Path()
        // body frame origin is (7, 9) in design space; positions above are in
        // glyph space, so draw ribs in glyph space too
        p.move(to: CGPoint(x: 9 * s, y: 30 * s))
        p.addQuadCurve(to: CGPoint(x: 63 * s, y: 30 * s), control: CGPoint(x: 36 * s, y: 36 * s))
        p.move(to: CGPoint(x: 8 * s, y: 44 * s))
        p.addQuadCurve(to: CGPoint(x: 64 * s, y: 44 * s), control: CGPoint(x: 36 * s, y: 50 * s))
        p.move(to: CGPoint(x: 9 * s, y: 58 * s))
        p.addQuadCurve(to: CGPoint(x: 63 * s, y: 58 * s), control: CGPoint(x: 36 * s, y: 64 * s))
        // offset into the body overlay's local coordinates
        return p.offsetBy(dx: -7 * s, dy: -9 * s)
    }
}
