//
//  HillsShape.swift
//  DinoLiveActivity
//
//  Two layered rolling-hill paths from widgets.html (morning + day scenes).
//  Source viewBox 158×158 (small) / 338×158 (medium). We scale both into the
//  passed rect so the hills sit across the full bottom regardless of widget size.
//
//  Morning paths (smsall, viewBox 158×158):
//    <path d="M -5 120 Q 40 95, 80 115 T 165 110 L 165 160 L -5 160 Z" fill="#8FB578"/>
//    <path d="M -5 128 Q 55 110, 100 125 T 165 120 L 165 160 L -5 160 Z" fill="#6E9A5A"/>
//

import SwiftUI

struct HillsShape: View {
    enum Palette {
        case morning
        case day
    }

    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Back hill (lighter)
                BackHillPath()
                    .fill(palette == .morning ? DinoPalette.hillLight : DinoPalette.dayHillLight)
                    .opacity(palette == .morning ? 0.9 : 1.0)
                // Front hill (darker)
                FrontHillPath()
                    .fill(palette == .morning ? DinoPalette.hillDark : DinoPalette.dayHillDark)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// d="M -5 120 Q 40 95, 80 115 T 165 110 L 165 160 L -5 160 Z" (source viewBox 158×158)
struct BackHillPath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 158.0
        let sy = rect.height / 158.0
        var p = Path()
        p.move(to: CGPoint(x: -5 * sx, y: 120 * sy))
        p.addQuadCurve(to: CGPoint(x: 80 * sx, y: 115 * sy), control: CGPoint(x: 40 * sx, y: 95 * sy))
        // "T 165 110" is a smooth quadratic; control point is the reflection of the previous control about the current endpoint.
        // Previous control (40,95) reflected about (80,115) = (120, 135).
        p.addQuadCurve(to: CGPoint(x: 165 * sx, y: 110 * sy), control: CGPoint(x: 120 * sx, y: 135 * sy))
        p.addLine(to: CGPoint(x: 165 * sx, y: 160 * sy))
        p.addLine(to: CGPoint(x: -5 * sx, y: 160 * sy))
        p.closeSubpath()
        return p
    }
}

/// d="M -5 128 Q 55 110, 100 125 T 165 120 L 165 160 L -5 160 Z"
struct FrontHillPath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 158.0
        let sy = rect.height / 158.0
        var p = Path()
        p.move(to: CGPoint(x: -5 * sx, y: 128 * sy))
        p.addQuadCurve(to: CGPoint(x: 100 * sx, y: 125 * sy), control: CGPoint(x: 55 * sx, y: 110 * sy))
        // T reflection: (55,110) about (100,125) = (145, 140).
        p.addQuadCurve(to: CGPoint(x: 165 * sx, y: 120 * sy), control: CGPoint(x: 145 * sx, y: 140 * sy))
        p.addLine(to: CGPoint(x: 165 * sx, y: 160 * sy))
        p.addLine(to: CGPoint(x: -5 * sx, y: 160 * sy))
        p.closeSubpath()
        return p
    }
}
