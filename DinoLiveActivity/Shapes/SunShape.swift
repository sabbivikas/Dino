//
//  SunShape.swift
//  DinoLiveActivity
//
//  Morning sun from widgets.html (viewBox 158×158). A sun disc at (34,34) r=14
//  with 8 radiating ink lines. The entire sun rotates slowly via the timeline
//  `rotationDegrees` input so we don't need to animate the rotation in-place.
//

import SwiftUI

struct SunShape: View {
    /// Optional rotation in degrees (0...360) — driven by the Timeline entry phase.
    var rotationDegrees: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let discR = size * (14.0 / 68.0) // source sun viewbox 0,0 → ~68 extent (rays span ±24 from center)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let rayInner = size * (22.0 / 68.0)
            let rayOuter = size * (30.0 / 68.0)

            ZStack {
                // Radiating rays — 8 lines at 45° increments
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0
                    RaySegment(
                        from: polar(center: center, radius: rayInner, angleDeg: angle),
                        to: polar(center: center, radius: rayOuter, angleDeg: angle)
                    )
                    .stroke(DinoPalette.sunStroke, style: StrokeStyle(lineWidth: max(1.5, size * 0.03), lineCap: .round))
                }

                // Sun disc with soft gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DinoPalette.sunYellow, DinoPalette.flameOrange.opacity(0.85)],
                            center: .center,
                            startRadius: 0,
                            endRadius: discR
                        )
                    )
                    .frame(width: discR * 2, height: discR * 2)
                    .position(center)
            }
            .rotationEffect(.degrees(rotationDegrees))
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func polar(center: CGPoint, radius: CGFloat, angleDeg: Double) -> CGPoint {
        let rad = angleDeg * .pi / 180.0
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    }
}

private struct RaySegment: Shape {
    let from: CGPoint
    let to: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        return p
    }
}
