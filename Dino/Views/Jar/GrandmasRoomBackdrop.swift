//
//  GrandmasRoomBackdrop.swift
//  Dino
//
//  Phase 5 — v6 Gratitude Jar: grandma's room backdrop behind the jar.
//  Wallpaper, floral pattern, lace-curtain window, diagonal sunbeam,
//  framed sepia portrait, wooden shelf, scalloped doily, drifting dust
//  motes, vignette + film grain — all layered back-to-front in a ZStack
//  that fills its container.
//

import SwiftUI

// MARK: - Public entry

struct GrandmasRoomBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .topLeading) {
                // a) Wallpaper gradient
                LinearGradient(
                    colors: [DinoTheme.jarWallpaperTop, DinoTheme.jarWallpaperBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // b) Rose pattern overlay (tiled 120x120 @ 0.5 opacity)
                RosePatternOverlay()
                    .opacity(0.5)
                    .drawingGroup()
                    .allowsHitTesting(false)

                // c) Left window with lace curtain
                WindowFrameView()
                    .frame(width: 120, height: 200)
                    .padding(.top, 24)
                    .padding(.leading, 16)

                // d) Diagonal sunbeam (animated)
                SunbeamView(containerSize: size, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)

                // e) Top-right framed sepia portrait
                HStack {
                    Spacer()
                    PortraitFrameView()
                        .frame(width: 110, height: 130)
                        .padding(.top, 24)
                        .padding(.trailing, 16)
                }

                // g) Wooden shelf pinned to bottom
                VStack {
                    Spacer()
                    WoodenShelfView()
                        .frame(height: 180)
                        .overlay(alignment: .top) {
                            // h) Scalloped doily on shelf top
                            ScallopedDoilyView()
                                .frame(width: 240, height: 40)
                                .padding(.top, 12)
                        }
                }
                .ignoresSafeArea(edges: .bottom)

                // i) Dust motes
                DustMotesView(containerSize: size, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)

                // j) Vignette
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.55),
                        .init(color: DinoTheme.jarVignetteEdge.opacity(0.38), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 250,
                    endRadius: 700
                )
                .allowsHitTesting(false)

                // k) Film grain
                Image("noise-grain")
                    .resizable(resizingMode: .tile)
                    .opacity(0.09)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - b) Rose pattern overlay

private struct RosePatternOverlay: View {
    var body: some View {
        Canvas { context, canvasSize in
            let tile: CGFloat = 120
            let cols = Int(ceil(canvasSize.width / tile)) + 1
            let rows = Int(ceil(canvasSize.height / tile)) + 1

            for r in 0..<rows {
                for c in 0..<cols {
                    let origin = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                    drawRoseCluster(in: &context, at: origin, offset: CGPoint(x: 30, y: 36))
                    drawRoseCluster(in: &context, at: origin, offset: CGPoint(x: 88, y: 92), small: true)
                    // tiny accent dots
                    let dotColor = DinoTheme.jarRoseBloom1.opacity(0.6)
                    for dot in [CGPoint(x: 58, y: 18), CGPoint(x: 14, y: 82), CGPoint(x: 100, y: 48)] {
                        let rect = CGRect(
                            x: origin.x + dot.x - 1,
                            y: origin.y + dot.y - 1,
                            width: 2, height: 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
    }

    private func drawRoseCluster(
        in context: inout GraphicsContext,
        at origin: CGPoint,
        offset: CGPoint,
        small: Bool = false
    ) {
        let center = CGPoint(x: origin.x + offset.x, y: origin.y + offset.y)
        let r1: CGFloat = small ? 4 : 6
        let r2: CGFloat = small ? 3 : 4
        let r3: CGFloat = small ? 2.5 : 3.5

        // Stem / swoop stroke
        var stemPath = Path()
        stemPath.move(to: CGPoint(x: center.x - 12, y: center.y + 8))
        stemPath.addQuadCurve(
            to: CGPoint(x: center.x + 12, y: center.y + 8),
            control: CGPoint(x: center.x, y: center.y + 14)
        )
        context.stroke(
            stemPath,
            with: .color(DinoTheme.jarRoseStroke.opacity(0.8)),
            lineWidth: 0.8
        )

        // Three bloom circles
        let bloom1 = CGRect(x: center.x - r1, y: center.y - r1, width: r1 * 2, height: r1 * 2)
        context.fill(Path(ellipseIn: bloom1), with: .color(DinoTheme.jarRoseBloom1))

        let bloom2 = CGRect(x: center.x - r1 - 2, y: center.y - 4, width: r2 * 2, height: r2 * 2)
        context.fill(Path(ellipseIn: bloom2), with: .color(DinoTheme.jarRoseBloom2))

        let bloom3 = CGRect(x: center.x + 1, y: center.y - 6, width: r3 * 2, height: r3 * 2)
        context.fill(Path(ellipseIn: bloom3), with: .color(DinoTheme.jarRoseBloom3))
    }
}

// MARK: - c) Window frame view

private struct WindowFrameView: View {
    var body: some View {
        ZStack {
            // Outer frame
            RoundedRectangle(cornerRadius: 2)
                .fill(DinoTheme.jarWoodLight)

            // Inner border
            RoundedRectangle(cornerRadius: 2)
                .stroke(DinoTheme.jarWoodMid, lineWidth: 1.8)
                .padding(4)

            // Glass
            Rectangle()
                .fill(DinoTheme.jarLacePaper.opacity(0.75))
                .padding(10)
                .overlay(
                    // Lace diamond pattern
                    LaceDiamondPattern()
                        .padding(10)
                )

            // Cross-bar horizontal
            Rectangle()
                .fill(DinoTheme.jarWoodLight)
                .frame(height: 6)

            // Cross-bar vertical
            Rectangle()
                .fill(DinoTheme.jarWoodLight)
                .frame(width: 6)
        }
        .shadow(color: Color(hex: "#2A1A0C").opacity(0.22), radius: 6, x: 0, y: 3)
    }
}

private struct LaceDiamondPattern: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 12
            let color = DinoTheme.jarWallpaperTop.opacity(0.9)
            // Diagonal lines going NE
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += step
            }
            // Diagonal lines going NW
            var x2: CGFloat = 0
            while x2 < size.width + size.height {
                path.move(to: CGPoint(x: x2, y: 0))
                path.addLine(to: CGPoint(x: x2 - size.height, y: size.height))
                x2 += step
            }
            context.stroke(path, with: .color(color), lineWidth: 0.6)
        }
    }
}

// MARK: - d) Sunbeam view

private struct SunbeamView: View {
    let containerSize: CGSize
    let reduceMotion: Bool

    var body: some View {
        let width = containerSize.width * 0.60
        let height = containerSize.height * 0.80

        Group {
            if reduceMotion {
                sunbeamShape
                    .opacity(0.70)
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = (sin(t * (2 * .pi / 12.0)) + 1) / 2 // 0..1
                    let opacity = 0.55 + 0.30 * phase
                    let scale = 1.0 + 0.04 * phase
                    sunbeamShape
                        .opacity(opacity)
                        .scaleEffect(scale, anchor: .topLeading)
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .rotationEffect(.degrees(18), anchor: .topLeading)
        .offset(x: containerSize.width * 0.10, y: containerSize.height * 0.10)
        .blur(radius: 10)
    }

    private var sunbeamShape: some View {
        TrapezoidShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#FFE9B8").opacity(0.35),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

private struct TrapezoidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = rect.width * 0.15
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - e) Portrait frame (sepia Dino)

private struct PortraitFrameView: View {
    var body: some View {
        ZStack {
            // Frame fill
            RoundedRectangle(cornerRadius: 3)
                .fill(DinoTheme.jarWoodLight)

            // Inner double-line
            RoundedRectangle(cornerRadius: 2)
                .stroke(DinoTheme.jarWoodMid, lineWidth: 2)
                .padding(4)

            RoundedRectangle(cornerRadius: 2)
                .stroke(DinoTheme.jarWoodMid.opacity(0.6), lineWidth: 1.2)
                .padding(8)

            // Portrait (sepia)
            Image("dino-only")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 100)
                .saturation(0.5)
                .colorMultiply(Color(hex: "#C9A888"))
                .brightness(-0.05)
                .clipShape(Rectangle())
                .padding(10)
        }
        .rotationEffect(.degrees(3))
        .shadow(color: Color(hex: "#2A1A0C").opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

// MARK: - g) Wooden shelf

private struct WoodenShelfView: View {
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: DinoTheme.jarWoodLight, location: 0.0),
                            .init(color: DinoTheme.jarWoodMid, location: 0.6),
                            .init(color: DinoTheme.jarWoodDark, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top inset shadow
            Rectangle()
                .fill(Color.black.opacity(0.22))
                .frame(height: 6)
                .blur(radius: 4)

            // Front-edge highlight
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#B8885A"), DinoTheme.jarWoodLight],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)

            // Wood-grain overlay
            WoodGrainCanvas()
                .opacity(0.45)
        }
    }
}

private struct WoodGrainCanvas: View {
    var body: some View {
        Canvas { context, size in
            let color = Color(hex: "#5A3318").opacity(0.45)
            let tileH: CGFloat = 80
            let rows = Int(ceil(size.height / tileH)) + 1

            for r in 0..<rows {
                let baseY = CGFloat(r) * tileH
                // 3 wavy strokes per tile
                for (offset, amp) in [(8.0, 6.0), (28.0, 4.0), (56.0, 7.0)] {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: baseY + offset))
                    var x: CGFloat = 0
                    while x < size.width {
                        let nextX = x + 80
                        path.addQuadCurve(
                            to: CGPoint(x: min(nextX, size.width), y: baseY + offset),
                            control: CGPoint(x: x + 40, y: baseY + offset + amp)
                        )
                        x = nextX
                    }
                    context.stroke(path, with: .color(color), lineWidth: 0.8)
                }
            }
        }
    }
}

// MARK: - h) Scalloped doily

private struct ScallopedDoilyView: View {
    var body: some View {
        ZStack {
            // Main oval body
            Ellipse()
                .fill(DinoTheme.jarLacePaper.opacity(0.95))

            // Scalloped edge bumps around perimeter
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ForEach(0..<18, id: \.self) { i in
                    let angle = Double(i) / 18.0 * 2 * .pi
                    let rx = w / 2 - 4
                    let ry = h / 2 - 2
                    let cx = w / 2 + CGFloat(cos(angle)) * rx
                    let cy = h / 2 + CGFloat(sin(angle)) * ry
                    Circle()
                        .fill(DinoTheme.jarLacePaper.opacity(0.95))
                        .frame(width: 7, height: 7)
                        .position(x: cx, y: cy)
                }
            }

            // Lace dots inside
            GeometryReader { geo in
                let w = geo.size.width
                ForEach(0..<14, id: \.self) { i in
                    Circle()
                        .fill(DinoTheme.jarWallpaperTop.opacity(0.45))
                        .frame(width: 3, height: 3)
                        .position(x: 25 + CGFloat(i) * (w - 50) / 13, y: geo.size.height / 2)
                }
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

// MARK: - i) Dust motes

private struct DustMotesView: View {
    let containerSize: CGSize
    let reduceMotion: Bool

    // Deterministic seed=42 positions
    private let motes: [(x: CGFloat, y: CGFloat, dur: Double, phase: Double)] = {
        // Simple LCG seeded with 42 for determinism
        var s: UInt64 = 42
        func nextRand() -> Double {
            s &*= 6364136223846793005
            s &+= 1442695040888963407
            return Double(s >> 33) / Double(UInt32.max)
        }
        var result: [(CGFloat, CGFloat, Double, Double)] = []
        for _ in 0..<16 {
            let x = CGFloat(0.12 + nextRand() * 0.76) // 12..88% of width
            let y = CGFloat(0.20 + nextRand() * 0.70) // 20..90% of height
            let dur = 14.0 + nextRand() * 8.0         // 14..22s
            let phase = nextRand()                    // 0..1
            result.append((x, y, dur, phase))
        }
        return result
    }()

    var body: some View {
        ZStack {
            if reduceMotion {
                ForEach(0..<motes.count, id: \.self) { i in
                    Circle()
                        .fill(DinoTheme.jarSunbeam.opacity(0.55))
                        .frame(width: 2, height: 2)
                        .position(
                            x: motes[i].x * containerSize.width,
                            y: motes[i].y * containerSize.height
                        )
                }
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ForEach(0..<motes.count, id: \.self) { i in
                        let m = motes[i]
                        let p = (sin((t / m.dur + m.phase) * 2 * .pi) + 1) / 2 // 0..1
                        let yOffset: CGFloat = -20 * CGFloat(p)
                        let opacity = 0.35 + 0.35 * p
                        Circle()
                            .fill(DinoTheme.jarSunbeam.opacity(opacity))
                            .frame(width: 2, height: 2)
                            .position(
                                x: m.x * containerSize.width,
                                y: m.y * containerSize.height + yOffset
                            )
                    }
                }
            }
        }
    }
}
