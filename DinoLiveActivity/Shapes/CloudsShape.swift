//
//  CloudsShape.swift
//  DinoLiveActivity
//
//  Two rounded cloud blobs matching widgets.html day scene. Each cloud is a
//  pair of overlapping ellipses. Coordinates from the small widget viewBox
//  (158×158). Rendered at the top of the scene.
//
//  Source:
//    <g opacity=".65"><ellipse cx=40 cy=28 rx=18 ry=7/><ellipse cx=52 cy=24 rx=12 ry=6/></g>
//    <g opacity=".55"><ellipse cx=115 cy=44 rx=20 ry=6/><ellipse cx=128 cy=40 rx=10 ry=5/></g>
//

import SwiftUI

struct CloudsShape: View {
    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 158.0
            let sy = geo.size.height / 158.0
            ZStack {
                cloud(at: CGPoint(x: 40 * sx, y: 28 * sy), size: CGSize(width: 36 * sx, height: 14 * sy), opacity: 0.65)
                cloud(at: CGPoint(x: 52 * sx, y: 24 * sy), size: CGSize(width: 24 * sx, height: 12 * sy), opacity: 0.65)
                cloud(at: CGPoint(x: 115 * sx, y: 44 * sy), size: CGSize(width: 40 * sx, height: 12 * sy), opacity: 0.55)
                cloud(at: CGPoint(x: 128 * sx, y: 40 * sy), size: CGSize(width: 20 * sx, height: 10 * sy), opacity: 0.55)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func cloud(at point: CGPoint, size: CGSize, opacity: Double) -> some View {
        Ellipse()
            .fill(Color.white.opacity(opacity))
            .frame(width: size.width, height: size.height)
            .position(point)
    }
}
