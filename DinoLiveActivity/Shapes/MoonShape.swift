//
//  MoonShape.swift
//  DinoLiveActivity
//
//  Crescent moon from widgets.html (night scene):
//    <g class="moon">
//      <circle cx="126" cy="36" r="14" fill="#F5EBC4"/>
//      <circle cx="130" cy="32" r="11" fill="#2A2C5A"/>
//    </g>
//
//  Rendered as a large cream disc with an offset background-colored disc
//  masking part of it to produce a crescent.
//

import SwiftUI

struct MoonShape: View {
    /// Optional override for the "sky" color used to carve the crescent.
    /// Default matches widgets.html: #2A2C5A (the mid-night gradient band).
    var skyColor: Color = DinoPalette.nightMid

    var body: some View {
        GeometryReader { geo in
            // Source: cx=126 cy=36 r=14 on a 158×158 viewBox. We normalize around
            // the view's own coordinate system so callers can place the moon via .position.
            let size = min(geo.size.width, geo.size.height)
            let fullR = size / 2
            let insetR = fullR * (11.0 / 14.0)
            let insetOffsetX = size * (4.0 / 28.0)  // moon scaling: (130-126)/28 = 4/28
            let insetOffsetY = -size * (4.0 / 28.0) // (32-36)/28 = -4/28

            ZStack {
                Circle()
                    .fill(DinoPalette.moonCream)
                    .frame(width: fullR * 2, height: fullR * 2)
                Circle()
                    .fill(skyColor)
                    .frame(width: insetR * 2, height: insetR * 2)
                    .offset(x: insetOffsetX, y: insetOffsetY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
