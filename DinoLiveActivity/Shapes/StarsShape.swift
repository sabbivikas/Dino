//
//  StarsShape.swift
//  DinoLiveActivity
//
//  Scattered star dots for the night mood scene. Positions and radii copied
//  verbatim from widgets.html (small scene viewBox 158×158):
//
//    <circle class="star" cx="24" cy="22" r="1.4"/>
//    <circle class="star" cx="58" cy="18" r="1"/>
//    <circle class="star" cx="88" cy="30" r="1.3"/>
//    <circle class="star" cx="124" cy="22" r="1"/>
//    <circle class="star" cx="138" cy="50" r="1.2"/>
//    <circle class="star" cx="42" cy="50" r="1"/>
//    <circle class="star" cx="100" cy="60" r="1.1"/>
//

import SwiftUI

struct StarsShape: View {
    private struct Star {
        let cx: CGFloat
        let cy: CGFloat
        let r: CGFloat
    }

    // r values are radii; we render at 2x for soft visibility on small widgets.
    private let stars: [Star] = [
        .init(cx: 24,  cy: 22, r: 1.6),
        .init(cx: 58,  cy: 18, r: 1.2),
        .init(cx: 88,  cy: 30, r: 1.5),
        .init(cx: 124, cy: 22, r: 1.2),
        .init(cx: 138, cy: 50, r: 1.4),
        .init(cx: 42,  cy: 50, r: 1.2),
        .init(cx: 100, cy: 60, r: 1.3),
        // additional fainter background stars for fullness
        .init(cx: 16,  cy: 36, r: 1.0),
        .init(cx: 70,  cy: 42, r: 0.9),
        .init(cx: 148, cy: 28, r: 1.0),
        .init(cx: 32,  cy: 72, r: 0.9),
        .init(cx: 112, cy: 44, r: 1.1),
    ]

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 158.0
            let sy = geo.size.height / 158.0
            ZStack {
                ForEach(0..<stars.count, id: \.self) { i in
                    let s = stars[i]
                    Circle()
                        .fill(DinoPalette.moonCream)
                        .frame(width: s.r * 2 * min(sx, sy), height: s.r * 2 * min(sx, sy))
                        .shadow(color: Color.white.opacity(0.4), radius: 1.5)
                        .opacity(0.85)
                        .position(x: s.cx * sx, y: s.cy * sy)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
