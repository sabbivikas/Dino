//
//  FlameShape.swift
//  DinoLiveActivity
//
//  Hand-drawn flame: three layered Bezier paths mirroring the flame SVG in
//  /Users/vikas/Downloads/DinoDesignSystem5/widgets.html. Coordinates copied
//  verbatim from the SVG viewBox (0 0 64 64) and scaled into the current rect.
//
//  Flicker is pseudo-animated by the TimelineProvider — `flickerPhase` in [0,1]
//  drives scaleX / scaleY / translateY per widgets.html @keyframes flame-flicker
//  keyframes (0 → 0.25 → 0.5 → 0.75).
//

import SwiftUI

// MARK: - Flame silhouette (outer body)

/// d="M 32 58 Q 12 50, 18 30 Q 22 20, 28 22 Q 26 12, 34 6 Q 36 16, 42 18 Q 40 26, 46 28 Q 54 36, 50 48 Q 46 58, 32 58 Z"
struct FlameOuterShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 64.0
        let sy = rect.height / 64.0
        var p = Path()
        p.move(to: CGPoint(x: 32 * sx, y: 58 * sy))
        p.addQuadCurve(to: CGPoint(x: 18 * sx, y: 30 * sy), control: CGPoint(x: 12 * sx, y: 50 * sy))
        p.addQuadCurve(to: CGPoint(x: 28 * sx, y: 22 * sy), control: CGPoint(x: 22 * sx, y: 20 * sy))
        p.addQuadCurve(to: CGPoint(x: 34 * sx, y: 6 * sy),  control: CGPoint(x: 26 * sx, y: 12 * sy))
        p.addQuadCurve(to: CGPoint(x: 42 * sx, y: 18 * sy), control: CGPoint(x: 36 * sx, y: 16 * sy))
        p.addQuadCurve(to: CGPoint(x: 46 * sx, y: 28 * sy), control: CGPoint(x: 40 * sx, y: 26 * sy))
        p.addQuadCurve(to: CGPoint(x: 50 * sx, y: 48 * sy), control: CGPoint(x: 54 * sx, y: 36 * sy))
        p.addQuadCurve(to: CGPoint(x: 32 * sx, y: 58 * sy), control: CGPoint(x: 46 * sx, y: 58 * sy))
        p.closeSubpath()
        return p
    }
}

/// d="M 32 52 Q 22 46, 26 34 Q 30 26, 34 30 Q 36 22, 40 26 Q 42 34, 44 38 Q 44 48, 34 52 Z"
struct FlameInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 64.0
        let sy = rect.height / 64.0
        var p = Path()
        p.move(to: CGPoint(x: 32 * sx, y: 52 * sy))
        p.addQuadCurve(to: CGPoint(x: 26 * sx, y: 34 * sy), control: CGPoint(x: 22 * sx, y: 46 * sy))
        p.addQuadCurve(to: CGPoint(x: 34 * sx, y: 30 * sy), control: CGPoint(x: 30 * sx, y: 26 * sy))
        p.addQuadCurve(to: CGPoint(x: 40 * sx, y: 26 * sy), control: CGPoint(x: 36 * sx, y: 22 * sy))
        p.addQuadCurve(to: CGPoint(x: 44 * sx, y: 38 * sy), control: CGPoint(x: 42 * sx, y: 34 * sy))
        p.addQuadCurve(to: CGPoint(x: 34 * sx, y: 52 * sy), control: CGPoint(x: 44 * sx, y: 48 * sy))
        p.closeSubpath()
        return p
    }
}

/// d="M 32 46 Q 28 40, 30 34 Q 34 30, 36 34 Q 38 42, 34 46 Z"
struct FlameHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 64.0
        let sy = rect.height / 64.0
        var p = Path()
        p.move(to: CGPoint(x: 32 * sx, y: 46 * sy))
        p.addQuadCurve(to: CGPoint(x: 30 * sx, y: 34 * sy), control: CGPoint(x: 28 * sx, y: 40 * sy))
        p.addQuadCurve(to: CGPoint(x: 36 * sx, y: 34 * sy), control: CGPoint(x: 34 * sx, y: 30 * sy))
        p.addQuadCurve(to: CGPoint(x: 34 * sx, y: 46 * sy), control: CGPoint(x: 38 * sx, y: 42 * sy))
        p.closeSubpath()
        return p
    }
}

// MARK: - FlameShape composite view

struct FlameShape: View {
    /// 0...1 keyframe position along the flicker cycle.
    let flickerPhase: Double

    var body: some View {
        ZStack {
            FlameOuterShape()
                .fill(DinoPalette.flameOrange)
            FlameOuterShape()
                .stroke(DinoPalette.flameBrown, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            FlameInnerShape()
                .fill(DinoPalette.flameYellow)
            FlameHighlightShape()
                .fill(Color.white.opacity(0.7))
        }
        .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
        .offset(y: translateY)
    }

    // MARK: Keyframe mapping

    private var scaleX: CGFloat {
        let t = flickerPhase.truncatingRemainder(dividingBy: 1.0)
        switch t {
        case 0.0..<0.25: return CGFloat(lerp(1.0, 1.05, t / 0.25))
        case 0.25..<0.5: return CGFloat(lerp(1.05, 0.96, (t - 0.25) / 0.25))
        case 0.5..<0.75: return CGFloat(lerp(0.96, 1.02, (t - 0.5) / 0.25))
        default:         return CGFloat(lerp(1.02, 1.0, (t - 0.75) / 0.25))
        }
    }

    private var scaleY: CGFloat {
        let t = flickerPhase.truncatingRemainder(dividingBy: 1.0)
        switch t {
        case 0.0..<0.25: return CGFloat(lerp(1.0, 0.98, t / 0.25))
        case 0.25..<0.5: return CGFloat(lerp(0.98, 1.03, (t - 0.25) / 0.25))
        case 0.5..<0.75: return CGFloat(lerp(1.03, 0.99, (t - 0.5) / 0.25))
        default:         return CGFloat(lerp(0.99, 1.0, (t - 0.75) / 0.25))
        }
    }

    private var translateY: CGFloat {
        let t = flickerPhase.truncatingRemainder(dividingBy: 1.0)
        switch t {
        case 0.0..<0.25: return CGFloat(lerp(0.0, -1.0, t / 0.25))
        case 0.25..<0.5: return CGFloat(lerp(-1.0, 0.0, (t - 0.25) / 0.25))
        case 0.5..<0.75: return CGFloat(lerp(0.0, -0.5, (t - 0.5) / 0.25))
        default:         return CGFloat(lerp(-0.5, 0.0, (t - 0.75) / 0.25))
        }
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
