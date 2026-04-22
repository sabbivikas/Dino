//
//  MountainsShape.swift
//  DinoLiveActivity
//
//  Night-scene mountain silhouette from widgets.html (viewBox 158×158):
//    <path d="M -5 118 L 20 90 L 50 115 L 80 82 L 118 118 L 165 100 L 165 160 L -5 160 Z"
//          fill="#1A1B3D"/>
//    <path d="M -5 135 Q 60 118, 120 135 T 165 132 L 165 160 L -5 160 Z"
//          fill="#0F0F2A"/>
//

import SwiftUI

struct MountainsShape: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                BackMountainPath()
                    .fill(DinoPalette.mountainBack)
                FrontMountainPath()
                    .fill(DinoPalette.mountainFront)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct BackMountainPath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 158.0
        let sy = rect.height / 158.0
        var p = Path()
        p.move(to: CGPoint(x: -5 * sx, y: 118 * sy))
        p.addLine(to: CGPoint(x: 20 * sx, y: 90 * sy))
        p.addLine(to: CGPoint(x: 50 * sx, y: 115 * sy))
        p.addLine(to: CGPoint(x: 80 * sx, y: 82 * sy))
        p.addLine(to: CGPoint(x: 118 * sx, y: 118 * sy))
        p.addLine(to: CGPoint(x: 165 * sx, y: 100 * sy))
        p.addLine(to: CGPoint(x: 165 * sx, y: 160 * sy))
        p.addLine(to: CGPoint(x: -5 * sx, y: 160 * sy))
        p.closeSubpath()
        return p
    }
}

struct FrontMountainPath: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 158.0
        let sy = rect.height / 158.0
        var p = Path()
        p.move(to: CGPoint(x: -5 * sx, y: 135 * sy))
        p.addQuadCurve(to: CGPoint(x: 120 * sx, y: 135 * sy), control: CGPoint(x: 60 * sx, y: 118 * sy))
        // T reflection: (60,118) about (120,135) = (180, 152)
        p.addQuadCurve(to: CGPoint(x: 165 * sx, y: 132 * sy), control: CGPoint(x: 180 * sx, y: 152 * sy))
        p.addLine(to: CGPoint(x: 165 * sx, y: 160 * sy))
        p.addLine(to: CGPoint(x: -5 * sx, y: 160 * sy))
        p.closeSubpath()
        return p
    }
}
