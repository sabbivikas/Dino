//
//  AmbientSoundsView.swift
//  Dino
//
//  Full-screen ambient sounds scene — a stylized waterfall with day/night
//  cycle. Translated from DinoDesignSystem-12/Ambient Sounds.html.
//  The design canvas is 402×874 (iPhone Pro logical points); we render at
//  that fixed canvas size and scaleEffect to fill the device.
//

import SwiftUI

// MARK: - Palette tokens (day / night)

private struct AmbientPalette {
    let sky1, sky2, sky3: Color
    let backlight, backlightFade: Color
    let ray: Color
    let rayOpacity: Double
    let canopy1: Color
    let treeB, treeM, treeF, treeHL: Color
    let fern, fernHL: Color
    let rock1, rock2, rock3, rockSh: Color
    let moss1, moss2: Color
    let fallBodyStart, fallBodyMid, fallBodyEnd, fallStreak, foam: Color
    let water1, water2, water3, waterDeep, waterSheen: Color
    let mist: Color
    let mistOpacity: Double
    let lily, lily2, lilyHL: Color
    let flowerA, flowerB, flowerC, flowerCore: Color
    let fish, fish2, fishFin: Color
    let uiCream: Color
    let closeBg: Color
    let sage: Color

    static let day = AmbientPalette(
        sky1: Color(hex: "#FDE8D0"), sky2: Color(hex: "#FBD79C"), sky3: Color(hex: "#F7C079"),
        backlight: Color(red: 255/255, green: 231/255, blue: 178/255).opacity(0.85),
        backlightFade: Color(red: 255/255, green: 200/255, blue: 140/255).opacity(0),
        ray: Color(red: 255/255, green: 243/255, blue: 210/255), rayOpacity: 0.18,
        canopy1: Color(hex: "#1B3322"),
        treeB: Color(hex: "#21402A"), treeM: Color(hex: "#315A36"),
        treeF: Color(hex: "#477C46"), treeHL: Color(hex: "#93C079"),
        fern: Color(hex: "#3C6B38"), fernHL: Color(hex: "#74A85C"),
        rock1: Color(hex: "#A6A491"), rock2: Color(hex: "#8E8E7C"),
        rock3: Color(hex: "#6E6E5E"), rockSh: Color(hex: "#52524A"),
        moss1: Color(hex: "#A8C5A0"), moss2: Color(hex: "#79A86A"),
        fallBodyStart: Color(hex: "#BFE4EE"), fallBodyMid: Color(hex: "#F4FBFC"),
        fallBodyEnd: Color(hex: "#BFE4EE"),
        fallStreak: .white, foam: .white,
        water1: Color(hex: "#BFE2EF"), water2: Color(hex: "#9CCBDC"),
        water3: Color(hex: "#76B2C9"), waterDeep: Color(hex: "#5896B1"),
        waterSheen: Color(red: 255/255, green: 250/255, blue: 230/255).opacity(0.22),
        mist: .white, mistOpacity: 0.55,
        lily: Color(hex: "#4E8C49"), lily2: Color(hex: "#3C6F3A"), lilyHL: Color(hex: "#82BD70"),
        flowerA: Color(hex: "#FDDCB5"), flowerB: Color(hex: "#E8B4B8"),
        flowerC: Color(hex: "#F4D58A"), flowerCore: Color(hex: "#FFF6E2"),
        fish: Color(hex: "#E59A60"), fish2: Color(hex: "#F6DCBC"), fishFin: Color(hex: "#EFC79C"),
        uiCream: Color(hex: "#FFF7E8"),
        closeBg: Color(red: 255/255, green: 250/255, blue: 238/255),
        sage: Color(hex: "#A8C5A0")
    )

    static let night = AmbientPalette(
        sky1: Color(hex: "#0B1120"), sky2: Color(hex: "#121E37"), sky3: Color(hex: "#1B2C4C"),
        backlight: Color(red: 176/255, green: 198/255, blue: 232/255).opacity(0.42),
        backlightFade: Color(red: 120/255, green: 150/255, blue: 200/255).opacity(0),
        ray: Color(red: 190/255, green: 208/255, blue: 238/255), rayOpacity: 0.12,
        canopy1: Color(hex: "#060B0F"),
        treeB: Color(hex: "#091210"), treeM: Color(hex: "#112218"),
        treeF: Color(hex: "#1A3123"), treeHL: Color(hex: "#3E5C49"),
        fern: Color(hex: "#132418"), fernHL: Color(hex: "#2E4A36"),
        rock1: Color(hex: "#525C68"), rock2: Color(hex: "#404A56"),
        rock3: Color(hex: "#2C343E"), rockSh: Color(hex: "#1E252E"),
        moss1: Color(hex: "#3C5A4A"), moss2: Color(hex: "#284036"),
        fallBodyStart: Color(hex: "#8AA6C2"), fallBodyMid: Color(hex: "#D2E2F0"),
        fallBodyEnd: Color(hex: "#8AA6C2"),
        fallStreak: Color(hex: "#E6EEF6"), foam: Color(hex: "#CFDBE8"),
        water1: Color(hex: "#1A3445"), water2: Color(hex: "#142B3A"),
        water3: Color(hex: "#0E2230"), waterDeep: Color(hex: "#091A24"),
        waterSheen: Color(red: 200/255, green: 218/255, blue: 240/255).opacity(0.20),
        mist: Color(red: 200/255, green: 214/255, blue: 232/255), mistOpacity: 0.4,
        lily: Color(hex: "#244639"), lily2: Color(hex: "#1B362C"), lilyHL: Color(hex: "#3A5E49"),
        flowerA: Color(hex: "#C7B58A"), flowerB: Color(hex: "#8E7FA6"),
        flowerC: Color(hex: "#B6A878"), flowerCore: Color(hex: "#E6EEF4"),
        fish: Color(hex: "#92A6C0"), fish2: Color(hex: "#C6D4E4"), fishFin: Color(hex: "#AABCD2"),
        uiCream: Color(hex: "#EAF1F6"),
        closeBg: Color(red: 228/255, green: 238/255, blue: 246/255),
        sage: Color(hex: "#A8C5A0")
    )
}

// MARK: - mulberry32 seeded RNG (matches HTML JS)

private struct Mulberry {
    private var state: UInt32
    init(seed: UInt32) { self.state = seed }
    mutating func next() -> Double {
        state = state &+ 0x6D2B79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
    mutating func d(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

// MARK: - Pre-computed scene layouts (deterministic, run once)

private struct LeafSpec { let x, y, s: Double }
private struct StarSpec { let x, y, size, delay: Double }
private struct FlySpec { let x, y, fm, fg, dm, dg: Double }

private enum SceneLayout {
    // Seeded with mulberry(20240529), called in the same order as the HTML JS.
    static let (foliageBack, foliageMid, foliageCanopy): ([LeafSpec], [LeafSpec], [LeafSpec]) = {
        var rnd = Mulberry(seed: 20240529)
        var back: [LeafSpec] = []
        var mid: [LeafSpec] = []
        var canopy: [LeafSpec] = []
        func scatter(_ out: inout [LeafSpec], _ n: Int, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ s0: Double, _ s1: Double) {
            for _ in 0..<n {
                let x = rnd.d(x0, x1)
                let y = rnd.d(y0, y1)
                let s = rnd.d(s0, s1)
                out.append(LeafSpec(x: x, y: y, s: s))
            }
        }
        // LEFT mass
        scatter(&back, 16, -16, 150, 120, 660, 0.72, 1.12)
        scatter(&mid,  12,   4, 150, 220, 660, 0.6,  1.0)
        // RIGHT mass
        scatter(&back, 16, 252, 418, 120, 660, 0.72, 1.12)
        scatter(&mid,  12, 252, 414, 220, 660, 0.6,  1.0)
        // top canopy filtering light
        scatter(&canopy, 7, 120, 282, 92, 150, 0.6, 0.95)
        return (back, mid, canopy)
    }()

    // Front overhanging clumps (hardcoded in HTML)
    static let foliageFront: [LeafSpec] = [
        LeafSpec(x: 24,  y: 360, s: 0.9), LeafSpec(x: 18,  y: 470, s: 0.8),
        LeafSpec(x: 40,  y: 300, s: 0.7),
        LeafSpec(x: 360, y: 360, s: 0.9), LeafSpec(x: 378, y: 470, s: 0.8),
        LeafSpec(x: 352, y: 300, s: 0.7),
        LeafSpec(x: 30,  y: 600, s: 0.78), LeafSpec(x: 366, y: 600, s: 0.78)
    ]
    static let foliageHL: [LeafSpec] = foliageFront.map { f in
        LeafSpec(x: f.x - 8 * f.s, y: f.y - 10 * f.s, s: f.s * 0.5)
    }

    static let stars: [StarSpec] = {
        var rnd = Mulberry(seed: 5)
        let spots: [(Double, Double)] = [
            (40,68),(88,44),(150,80),(300,58),(348,94),(120,28),(264,88),
            (210,106),(70,108),(330,38),(176,62),(238,40),(96,96),(284,110)
        ]
        return spots.map { p in
            let r = rnd.d(0.7, 1.8)
            let d = rnd.d(0, 3)
            return StarSpec(x: p.0, y: p.1, size: r, delay: d)
        }
    }()

    static let fireflies: [FlySpec] = {
        var rnd = Mulberry(seed: 9)
        let pts: [(Double, Double)] = [
            (72,560),(120,640),(300,600),(340,690),(180,706),
            (240,556),(92,720),(320,540),(210,500),(150,584)
        ]
        return pts.map { p in
            let fm = rnd.d(9, 15)
            let fg = rnd.d(2.4, 4.4)
            let dm = rnd.d(0, 8)
            let dg = rnd.d(0, 3)
            return FlySpec(x: p.0, y: p.1, fm: fm, fg: fg, dm: dm, dg: dg)
        }
    }()

    // Waterfall streaks: columns at fixed x, varied width/duration/opacity
    struct StreakSpec { let x, width, duration, opacity, delay: Double }
    static let streaks: [StreakSpec] = {
        var rnd = Mulberry(seed: 77)
        let cols: [Double] = [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]
        return cols.map { cx in
            let w  = rnd.d(1.0, 2.6)
            let du = rnd.d(0.55, 1.05)
            let op = rnd.d(0.25, 0.60)
            let de = -rnd.d(0, 1)
            return StreakSpec(x: cx, width: w, duration: du, opacity: op, delay: de)
        }
    }()
}

// MARK: - Shapes

/// 6-ellipse leaf cluster matching the SVG `<symbol id="leafclump">`.
private struct LeafClumpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Center coord = rect's midPoint; spec coords are around (0,0).
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let blobs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 26, 20),
            (-22, 6, 20, 16),
            (22, 6, 20, 16),
            (-10, 16, 18, 14),
            (12, 16, 18, 14),
            (0, -12, 16, 13)
        ]
        for b in blobs {
            p.addEllipse(in: CGRect(
                x: c.x + b.0 - b.2, y: c.y + b.1 - b.3,
                width: b.2 * 2, height: b.3 * 2
            ))
        }
        return p
    }
}

/// Trapezoid clip for the falling water column — matches CSS
/// `clip-path: polygon(33% 0, 67% 0, 86% 100%, 14% 100%)`.
private struct FallsTrapezoid: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.33, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.67, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.86, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.14, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Reusable foliage layer

private struct FoliageLayer: View {
    let positions: [LeafSpec]
    let fill: Color
    var opacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<positions.count, id: \.self) { i in
                let l = positions[i]
                LeafClumpShape()
                    .fill(fill)
                    .frame(width: 56 * l.s, height: 44 * l.s)
                    .position(x: l.x, y: l.y)
            }
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .opacity(opacity)
    }
}

// MARK: - Side tree masses (curved silhouettes that guarantee no gaps)

private struct SideTreeMasses: View {
    let palette: AmbientPalette
    var body: some View {
        Canvas { ctx, _ in
            var left = Path()
            left.move(to: CGPoint(x: -30, y: 110))
            left.addCurve(to: CGPoint(x: 158, y: 270),
                          control1: CGPoint(x: 50, y: 96),
                          control2: CGPoint(x: 150, y: 130))
            left.addLine(to: CGPoint(x: 158, y: 720))
            left.addLine(to: CGPoint(x: -30, y: 720))
            left.closeSubpath()
            ctx.fill(left, with: .color(palette.treeB))

            var right = Path()
            right.move(to: CGPoint(x: 432, y: 110))
            right.addCurve(to: CGPoint(x: 244, y: 270),
                           control1: CGPoint(x: 352, y: 96),
                           control2: CGPoint(x: 252, y: 130))
            right.addLine(to: CGPoint(x: 244, y: 720))
            right.addLine(to: CGPoint(x: 432, y: 720))
            right.closeSubpath()
            ctx.fill(right, with: .color(palette.treeB))
        }
        .frame(width: 402, height: 874)
    }
}

// MARK: - Mossy rock cliff (top ledge, flanking boulders, splash-base boulders)

private struct RockCliff: View {
    let palette: AmbientPalette
    var body: some View {
        Canvas { ctx, _ in
            // Wet back face
            var back = Path()
            back.move(to: CGPoint(x: 150, y: 248))
            back.addCurve(to: CGPoint(x: 252, y: 248),
                          control1: CGPoint(x: 150, y: 232),
                          control2: CGPoint(x: 252, y: 232))
            back.addCurve(to: CGPoint(x: 256, y: 596),
                          control1: CGPoint(x: 260, y: 360),
                          control2: CGPoint(x: 258, y: 520))
            back.addLine(to: CGPoint(x: 146, y: 596))
            back.addCurve(to: CGPoint(x: 150, y: 248),
                          control1: CGPoint(x: 144, y: 520),
                          control2: CGPoint(x: 142, y: 360))
            back.closeSubpath()
            ctx.fill(back, with: .color(palette.rock3))

            // Left shadow column
            var shL = Path()
            shL.move(to: CGPoint(x: 150, y: 248))
            shL.addCurve(to: CGPoint(x: 168, y: 596),
                         control1: CGPoint(x: 168, y: 322),
                         control2: CGPoint(x: 164, y: 470))
            shL.addLine(to: CGPoint(x: 146, y: 596))
            shL.addCurve(to: CGPoint(x: 150, y: 248),
                         control1: CGPoint(x: 144, y: 520),
                         control2: CGPoint(x: 142, y: 360))
            shL.closeSubpath()
            ctx.opacity = 0.7
            ctx.fill(shL, with: .color(palette.rockSh))
            ctx.opacity = 1.0

            // Right highlight column
            var hiR = Path()
            hiR.move(to: CGPoint(x: 236, y: 250))
            hiR.addCurve(to: CGPoint(x: 244, y: 596),
                         control1: CGPoint(x: 250, y: 330),
                         control2: CGPoint(x: 248, y: 470))
            hiR.addLine(to: CGPoint(x: 256, y: 596))
            hiR.addCurve(to: CGPoint(x: 252, y: 248),
                         control1: CGPoint(x: 258, y: 520),
                         control2: CGPoint(x: 260, y: 360))
            hiR.closeSubpath()
            ctx.opacity = 0.5
            ctx.fill(hiR, with: .color(palette.rock2))
            ctx.opacity = 1.0

            // Top ledge boulders
            func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: Color, opacity: Double = 1.0) {
                ctx.opacity = opacity
                ctx.fill(Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)),
                         with: .color(color))
                ctx.opacity = 1.0
            }
            ellipse(148, 250, 34, 20, palette.rock2)
            ellipse(254, 250, 34, 20, palette.rock2)
            ellipse(142, 244, 24, 12, palette.rock1)
            ellipse(260, 244, 24, 12, palette.rock1)
            ellipse(138, 240, 20, 8,  palette.moss1)
            ellipse(262, 240, 20, 8,  palette.moss1)

            // Flanking boulders down falls
            ellipse(128, 420, 30, 40, palette.rock2)
            ellipse(120, 400, 18, 22, palette.rock1, opacity: 0.7)
            ellipse(274, 430, 30, 42, palette.rock2)
            ellipse(284, 410, 18, 22, palette.rock3, opacity: 0.6)
            ellipse(124, 392, 16, 9,  palette.moss1, opacity: 0.85)
            ellipse(278, 402, 16, 9,  palette.moss1, opacity: 0.85)
            ellipse(132, 452, 12, 7,  palette.moss2, opacity: 0.7)
            ellipse(270, 462, 12, 7,  palette.moss2, opacity: 0.7)

            // Splash-base big mossy boulders
            ellipse(118, 560, 44, 34, palette.rock2)
            ellipse(286, 566, 46, 34, palette.rock2)
            ellipse(104, 544, 26, 16, palette.rock1, opacity: 0.7)
            ellipse(300, 550, 26, 16, palette.rock1, opacity: 0.7)
            ellipse(110, 536, 30, 13, palette.moss1)
            ellipse(292, 542, 30, 13, palette.moss1)
            ellipse(132, 560, 16, 9,  palette.moss2, opacity: 0.75)
            ellipse(276, 566, 16, 9,  palette.moss2, opacity: 0.75)
        }
        .frame(width: 402, height: 874)
    }
}

// MARK: - Sky + backlight

private struct SkyLayer: View {
    let palette: AmbientPalette
    let isNight: Bool
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: palette.sky1, location: 0.0),
                    .init(color: palette.sky2, location: 0.12),
                    .init(color: palette.sky3, location: 0.26),
                    .init(color: palette.sky3, location: 0.34),
                    .init(color: palette.sky3.opacity(0), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Backlight radial glow
            RadialGradient(
                colors: [palette.backlight, palette.backlightFade],
                center: isNight ? UnitPoint(x: 0.66, y: 0.22) : UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 460
            )
            .blendMode(.normal)
        }
        .frame(width: 402, height: 874)
    }
}

// MARK: - Moon + glow + stars (night)

private struct MoonAndStars: View {
    let reduceMotion: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Moon glow
            RadialGradient(
                colors: [Color(red: 206/255, green: 222/255, blue: 242/255).opacity(0.42), .clear],
                center: .center, startRadius: 0, endRadius: 170
            )
            .frame(width: 340, height: 340)
            .position(x: 120 + 170, y: -46 + 170)

            // Moon body
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let pulse = reduceMotion ? 1.0 : (1.0 + 0.04 * sin(t * .pi * 2 / 6))
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "#FBF6E8"), Color(hex: "#EEE6D0"), Color(hex: "#DAD1B9")],
                                center: UnitPoint(x: 0.38, y: 0.36),
                                startRadius: 0, endRadius: 74
                            )
                        )
                    // Craters
                    Circle().fill(Color(red: 196/255, green: 186/255, blue: 156/255).opacity(0.55))
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -10)
                    Circle().fill(Color(red: 196/255, green: 186/255, blue: 156/255).opacity(0.5))
                        .frame(width: 14, height: 14)
                        .offset(x: -8, y: 8)
                    Circle().fill(Color(red: 196/255, green: 186/255, blue: 156/255).opacity(0.42))
                        .frame(width: 8, height: 8)
                        .offset(x: 12, y: 10)
                }
                .frame(width: 74, height: 74)
                .shadow(color: Color(red: 228/255, green: 238/255, blue: 246/255).opacity(0.5), radius: 18)
                .shadow(color: Color(red: 190/255, green: 210/255, blue: 236/255).opacity(0.28), radius: 40)
                .scaleEffect(pulse)
                .position(x: 262 + 37, y: 100 + 37)
            }

            // Stars (twinkle)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ForEach(0..<SceneLayout.stars.count, id: \.self) { i in
                    let s = SceneLayout.stars[i]
                    let phase = (t + s.delay) * (2 * .pi / 3.4)
                    let op = reduceMotion ? 0.6 : (0.25 + 0.75 * (0.5 + 0.5 * sin(phase)))
                    Circle()
                        .fill(Color(hex: "#F4EFE0"))
                        .frame(width: s.size, height: s.size)
                        .opacity(op)
                        .position(x: s.x, y: s.y)
                }
            }
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - Drifting clouds

private struct DriftingClouds: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            cloud(scale: 1.0, top: 96, period: 95, delay: 0)
            cloud(scale: 0.7, top: 150, period: 130, delay: 50)
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func cloud(scale: Double, top: Double, period: Double, delay: Double) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate + delay
            // drift: from left=-130 to left=430 over `period` seconds, linear
            let phase = reduceMotion ? 0.3 : ((t.truncatingRemainder(dividingBy: period)) / period)
            let x = -130.0 + (430.0 - (-130.0)) * phase
            ZStack {
                blob(50, 20, 0, 6)
                blob(38, 24, 24, 0)
                blob(42, 18, 48, 8)
            }
            .scaleEffect(scale)
            .position(x: x + 60, y: top + 12)
        }
    }

    private func blob(_ w: Double, _ h: Double, _ x: Double, _ y: Double) -> some View {
        Ellipse()
            .fill(palette.uiCream)
            .opacity(0.5)
            .frame(width: w, height: h)
            .blur(radius: 1)
            .offset(x: x - 25, y: y - 12)
    }
}

// MARK: - God rays

private struct GodRays: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    private let specs: [(left: Double, width: Double, rot: Double, delay: Double)] = [
        (64,  90,  10, -1.0),
        (150, 64,   6, -4.0),
        (210, 108, 14, -2.4),
        (300, 58,  18, -6.0)
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                ForEach(0..<specs.count, id: \.self) { i in
                    let s = specs[i]
                    let phase = (t + s.delay) * (2 * .pi / 9.0)
                    let opacity = reduceMotion ? 0.8 : (0.6 + 0.4 * (0.5 + 0.5 * sin(phase)))
                    LinearGradient(
                        colors: [palette.ray.opacity(palette.rayOpacity), palette.ray.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: s.width, height: 874 * 1.3)
                    .blur(radius: 8)
                    .rotationEffect(.degrees(s.rot), anchor: .top)
                    .opacity(opacity)
                    .position(x: s.left + s.width / 2, y: -10)
                }
            }
            .frame(width: 402, height: 874, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Waterfall body + animated streaks + glow + foam + mist

private struct WaterfallSystem: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Falls glow (behind)
            LinearGradient(
                colors: [Color.white.opacity(0.32), Color.white.opacity(0.12), Color.white.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 120, height: 360)
            .blur(radius: 10)
            .blendMode(.screen)
            .position(x: 201, y: 250 + 180)

            // Falls body (clipped trapezoid)
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: .clear,                location: 0.00),
                        .init(color: palette.fallBodyStart, location: 0.14),
                        .init(color: palette.fallBodyMid,   location: 0.40),
                        .init(color: palette.fallBodyMid,   location: 0.52),
                        .init(color: palette.fallBodyMid,   location: 0.64),
                        .init(color: palette.fallBodyEnd,   location: 0.86),
                        .init(color: .clear,                location: 1.00)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 88, height: 384)

                // Streaks (animated falling lines)
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<SceneLayout.streaks.count, id: \.self) { i in
                            let s = SceneLayout.streaks[i]
                            let phase = reduceMotion ? 0.5 :
                                (((t + s.delay).truncatingRemainder(dividingBy: s.duration)) / s.duration)
                            let y = -0.45 * 384.0 + (280.0 + 0.45 * 384.0) * phase
                            LinearGradient(
                                colors: [Color.clear, palette.fallStreak, Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(width: s.width, height: 384 * 0.6)
                            .cornerRadius(99)
                            .opacity(s.opacity)
                            .offset(x: s.x, y: y)
                        }
                    }
                    .frame(width: 88, height: 384, alignment: .topLeading)
                }
            }
            .frame(width: 88, height: 384)
            .clipShape(FallsTrapezoid())
            .blur(radius: 0.4)
            .opacity(0.95)
            .position(x: 201, y: 236 + 192)

            // Mist (rising blobs)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .bottomLeading) {
                    mistBlob(t: t, size: 64, x: -32, delay: 0)
                    mistBlob(t: t, size: 50, x:  -8, delay: -1.8)
                    mistBlob(t: t, size: 58, x: -48, delay: -3.4)
                    mistBlob(t: t, size: 44, x:  10, delay: -4.6)
                }
                .frame(width: 210, height: 150, alignment: .bottomLeading)
                .position(x: 201, y: 520 + 75)
                .allowsHitTesting(false)
            }

            // Foam (pulsing blobs at the base)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    foamBlob(t: t, w: 46, h: 26, x: 8,  y: 18, delay: 0)
                    foamBlob(t: t, w: 60, h: 30, x: 52, y: 12, delay: -0.9)
                    foamBlob(t: t, w: 42, h: 24, x: 108, y: 20, delay: -1.6)
                    foamBlob(t: t, w: 34, h: 20, x: 34, y: 30, delay: -2.1)
                }
                .frame(width: 168, height: 56, alignment: .topLeading)
                .position(x: 201, y: 582 + 28)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
    }

    private func mistBlob(t: Double, size: Double, x: Double, delay: Double) -> some View {
        // rise keyframes: y 40 -> -78 over 6s, scale .5 -> 1.6, opacity 0->o->0
        let dur = 6.0
        let phase = reduceMotion ? 0.25 : (((t + delay).truncatingRemainder(dividingBy: dur)) / dur)
        let y = 40.0 + (-78.0 - 40.0) * phase
        let scale = 0.5 + (1.6 - 0.5) * phase
        let opacity: Double = {
            if phase < 0.25 { return palette.mistOpacity * (phase / 0.25) }
            return palette.mistOpacity * max(0.0, 1.0 - (phase - 0.25) / 0.75)
        }()
        return Circle()
            .fill(palette.mist)
            .frame(width: size, height: size)
            .blur(radius: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: 105 + x, y: y)
    }

    private func foamBlob(t: Double, w: Double, h: Double, x: Double, y: Double, delay: Double) -> some View {
        let dur = 2.8
        let phase = reduceMotion ? 0.5 : (((t + delay).truncatingRemainder(dividingBy: dur)) / dur)
        // foampulse: scale 1 -> 1.14 -> 1, opacity 0.92 -> 1 -> 0.92
        let s = 1.0 + 0.14 * (0.5 - 0.5 * cos(phase * 2 * .pi))
        let op = 0.92 + 0.08 * (0.5 - 0.5 * cos(phase * 2 * .pi))
        return Ellipse()
            .fill(palette.foam)
            .frame(width: w, height: h)
            .blur(radius: 1.5)
            .scaleEffect(s)
            .opacity(op)
            .offset(x: x, y: y)
    }
}

// MARK: - Pool, shimmer, ripples

private struct PoolLayer: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    private let ripples: [(x: Double, y: Double, w: Double, h: Double, delay: Double)] = [
        (201, 646, 118, 34,  0.0),
        (133, 700, 150, 42, -2.2),
        (266, 742, 172, 46, -4.4),
        (193, 796, 204, 52, -3.1)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Pool gradient
            LinearGradient(
                stops: [
                    .init(color: palette.water1, location: 0.0),
                    .init(color: palette.water2, location: 0.4),
                    .init(color: palette.water3, location: 0.76),
                    .init(color: palette.waterDeep, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 402, height: 312)
            .position(x: 201, y: 874 - 156)

            // Pool sheen
            LinearGradient(
                colors: [palette.waterSheen, .clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.26)
            )
            .frame(width: 402, height: 312)
            .blendMode(.screen)
            .position(x: 201, y: 874 - 156)

            // Shimmer column
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let dur = 4.5
                let phase = reduceMotion ? 0.5 : ((t.truncatingRemainder(dividingBy: dur)) / dur)
                let f = 0.5 - 0.5 * cos(phase * 2 * .pi)
                let op = 0.5 + 0.4 * f
                let xs = 1.0 + 0.3 * f
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.72)
                )
                .frame(width: 74, height: 250)
                .blur(radius: 3)
                .blendMode(.screen)
                .scaleEffect(x: xs, y: 1.0)
                .opacity(op)
                .position(x: 201, y: 874 - 125)
            }

            // Ripples
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(0..<ripples.count, id: \.self) { i in
                        let r = ripples[i]
                        let dur = 6.5
                        let phase = reduceMotion ? 0.5 : (((t + r.delay).truncatingRemainder(dividingBy: dur)) / dur)
                        let scale = 0.14 + (1.0 - 0.14) * phase
                        let op: Double = {
                            if phase < 0.18 { return 0.5 * (phase / 0.18) }
                            return 0.5 * max(0.0, 1.0 - (phase - 0.18) / 0.82)
                        }()
                        Ellipse()
                            .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                            .frame(width: r.w, height: r.h)
                            .scaleEffect(scale)
                            .opacity(op)
                            .position(x: r.x, y: r.y)
                    }
                }
                .frame(width: 402, height: 874, alignment: .topLeading)
            }
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - Lily pads + wildflowers + pool-edge rocks

private struct PoolForeground: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Pool-edge rocks (left + right)
            Canvas { ctx, _ in
                var left = Path()
                left.move(to: CGPoint(x: -30, y: 660))
                left.addCurve(to: CGPoint(x: 96, y: 672),
                              control1: CGPoint(x: 20, y: 632),
                              control2: CGPoint(x: 70, y: 640))
                left.addCurve(to: CGPoint(x: 30, y: 766),
                              control1: CGPoint(x: 116, y: 698),
                              control2: CGPoint(x: 92, y: 760))
                left.addCurve(to: CGPoint(x: -30, y: 660),
                              control1: CGPoint(x: -22, y: 768),
                              control2: CGPoint(x: -34, y: 706))
                left.closeSubpath()
                ctx.fill(left, with: .color(palette.rock2))

                var right = Path()
                right.move(to: CGPoint(x: 432, y: 652))
                right.addCurve(to: CGPoint(x: 304, y: 666),
                               control1: CGPoint(x: 382, y: 626),
                               control2: CGPoint(x: 330, y: 634))
                right.addCurve(to: CGPoint(x: 372, y: 764),
                               control1: CGPoint(x: 284, y: 694),
                               control2: CGPoint(x: 308, y: 758))
                right.addCurve(to: CGPoint(x: 432, y: 652),
                               control1: CGPoint(x: 426, y: 766),
                               control2: CGPoint(x: 438, y: 700))
                right.closeSubpath()
                ctx.fill(right, with: .color(palette.rock2))
            }
            .frame(width: 402, height: 874)

            // Lily pads (with subtle vertical bob)
            lilyPad(cx: 104, cy: 744, rx: 32, ry: 13, delay: 0)
            lilyPad(cx: 300, cy: 776, rx: 36, ry: 14, delay: -2.6, flower: palette.flowerB)
            lilyPad(cx: 206, cy: 806, rx: 28, ry: 11, delay: -1.4)

            // Wildflowers
            wildflower(x: 58,  y: 690, stemH: 16, head: 4.2, color: palette.flowerA)
            wildflower(x: 44,  y: 696, stemH: 12, head: 3.2, color: palette.flowerB)
            wildflower(x: 74,  y: 700, stemH: 10, head: 3.0, color: palette.flowerC)
            wildflower(x: 348, y: 694, stemH: 16, head: 4.2, color: palette.flowerC)
            wildflower(x: 364, y: 700, stemH: 11, head: 3.0, color: palette.flowerA)
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func lilyPad(cx: Double, cy: Double, rx: Double, ry: Double, delay: Double, flower: Color? = nil) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let dur = 6.0
            let phase = reduceMotion ? 0.0 : (((t + delay).truncatingRemainder(dividingBy: dur)) / dur)
            let dy = sin(phase * 2 * .pi) * -1.5 // 0 -> -3 -> 0 approximated
            ZStack {
                Ellipse().fill(palette.lily).frame(width: rx * 2, height: ry * 2)
                Ellipse().fill(palette.lily2).opacity(0.4)
                    .frame(width: rx * 2, height: ry * 2)
                    .offset(y: 3)
                Ellipse().fill(palette.lilyHL).opacity(0.7)
                    .frame(width: 26, height: 10)
                    .offset(x: -11, y: -4)
                if let flowerC = flower {
                    Circle().fill(flowerC).frame(width: 8, height: 8).offset(x: 6, y: -6)
                    Circle().fill(palette.flowerCore).frame(width: 3.2, height: 3.2).offset(x: 6, y: -6)
                }
            }
            .position(x: cx, y: cy + dy)
        }
    }

    private func wildflower(x: Double, y: Double, stemH: Double, head: Double, color: Color) -> some View {
        ZStack {
            Rectangle().fill(palette.fern).frame(width: 1.2, height: stemH).offset(y: stemH / 2)
            Circle().fill(color).frame(width: head * 2, height: head * 2).offset(y: -2)
            Circle().fill(palette.flowerCore).frame(width: 2.4, height: 2.4).offset(y: -2)
        }
        .position(x: x, y: y)
    }
}

// MARK: - Ferns (undergrowth)

private struct FernsLayer: View {
    let palette: AmbientPalette
    var body: some View {
        ZStack(alignment: .topLeading) {
            fern(x: 44,  y: 648, scale: 0.95, color: palette.fern, flip: false)
            fern(x: 80,  y: 660, scale: 0.82, color: palette.fern, flip: true)
            fern(x: 360, y: 648, scale: 0.95, color: palette.fern, flip: false)
            fern(x: 326, y: 660, scale: 0.82, color: palette.fern, flip: false)
            fern(x: 62,  y: 652, scale: 0.52, color: palette.fernHL, flip: false).opacity(0.7)
            fern(x: 344, y: 652, scale: 0.52, color: palette.fernHL, flip: false).opacity(0.7)
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
    }

    private func fern(x: Double, y: Double, scale: Double, color: Color, flip: Bool) -> some View {
        FernShape()
            .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .frame(width: 36 * scale, height: 64 * scale)
            .scaleEffect(x: flip ? -1 : 1, y: 1)
            .position(x: x, y: y - 32 * scale)
    }
}

private struct FernShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX
        let bottom = r.maxY
        // Main stalk
        p.move(to: CGPoint(x: cx, y: bottom))
        p.addCurve(to: CGPoint(x: cx, y: r.minY + 2),
                   control1: CGPoint(x: cx - 3, y: bottom - 22),
                   control2: CGPoint(x: cx - 3, y: bottom - 44))
        // Pairs of leaflets
        let pairs: [(start: Double, ctrl: Double, end: Double)] = [
            (8, 12, 24), (22, 26, 37), (36, 39, 48), (48, 50, 57)
        ]
        let scale = r.height / 64.0
        for pr in pairs {
            p.move(to: CGPoint(x: cx, y: bottom - pr.start * scale))
            p.addCurve(to: CGPoint(x: cx - 15 * scale, y: bottom - pr.end * scale),
                       control1: CGPoint(x: cx - 8 * scale, y: bottom - pr.ctrl * scale),
                       control2: CGPoint(x: cx - 13 * scale, y: bottom - pr.ctrl * scale))
            p.move(to: CGPoint(x: cx, y: bottom - pr.start * scale))
            p.addCurve(to: CGPoint(x: cx + 15 * scale, y: bottom - pr.end * scale),
                       control1: CGPoint(x: cx + 8 * scale, y: bottom - pr.ctrl * scale),
                       control2: CGPoint(x: cx + 13 * scale, y: bottom - pr.ctrl * scale))
        }
        return p
    }
}

// MARK: - Fireflies (night)

private struct FirefliesLayer: View {
    let reduceMotion: Bool
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                ForEach(0..<SceneLayout.fireflies.count, id: \.self) { i in
                    let f = SceneLayout.fireflies[i]
                    let movePhase = reduceMotion ? 0.0 :
                        (((t + f.dm).truncatingRemainder(dividingBy: f.fm)) / f.fm)
                    let glowPhase = reduceMotion ? 0.5 :
                        (((t + f.dg).truncatingRemainder(dividingBy: f.fg)) / f.fg)
                    // Move keyframes (0..1) approximated as 5-step interp
                    let dxdy = flyOffset(phase: movePhase)
                    let op = 0.2 + 0.8 * (0.5 - 0.5 * cos(glowPhase * 2 * .pi))
                    Circle()
                        .fill(Color(hex: "#F9C784"))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color(hex: "#F9C784").opacity(0.85), radius: 5)
                        .shadow(color: Color(hex: "#F9C784").opacity(0.32), radius: 11)
                        .opacity(op)
                        .position(x: f.x + dxdy.0, y: f.y + dxdy.1)
                }
            }
            .frame(width: 402, height: 874, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private func flyOffset(phase: Double) -> (Double, Double) {
        // Keyframes: 0%(0,0) 25%(18,-15) 50%(-12,-28) 75%(-22,-8) 100%(0,0)
        let segs: [(Double, Double)] = [(0,0), (18,-15), (-12,-28), (-22,-8), (0,0)]
        let p = phase * 4
        let i = min(Int(p), 3)
        let f = p - Double(i)
        let a = segs[i]; let b = segs[i + 1]
        return (a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f)
    }
}

// MARK: - Fish + splash (two jumpers, opposite directions)

private struct FishLayer: View {
    let palette: AmbientPalette
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fish 1: leap leftward to rightward arc starting at 142,646, period 12s
            jumper(homeX: 142, homeY: 646, duration: 12, delay: 0, flip: false)
            // Splashes for fish 1
            splash(at: CGPoint(x: 152, y: 650), duration: 12, delay: 0, direction: .up)
            splash(at: CGPoint(x: 190, y: 662), duration: 12, delay: 0, direction: .down)

            // Fish 2: leap rightward to leftward, 15s, offset -7.5
            jumper(homeX: 268, homeY: 724, duration: 15, delay: -7.5, flip: true)
            splash(at: CGPoint(x: 262, y: 728), duration: 15, delay: -7.5, direction: .up)
            splash(at: CGPoint(x: 228, y: 738), duration: 15, delay: -7.5, direction: .down)
        }
        .frame(width: 402, height: 874, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private enum SplashDir { case up, down }

    private func jumper(homeX: Double, homeY: Double, duration: Double, delay: Double, flip: Bool) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 1.0 :
                (((t + delay).truncatingRemainder(dividingBy: duration)) / duration)
            let arc = leapArc(phase: phase, mirror: flip)
            FishGlyph(palette: palette)
                .scaleEffect(x: flip ? -arc.scale : arc.scale, y: arc.scale)
                .rotationEffect(.degrees(flip ? -arc.rot : arc.rot))
                .opacity(arc.opacity)
                .position(x: homeX + arc.x, y: homeY + arc.y)
        }
    }

    /// Leap keyframes from CSS — phase 0..1 over the cycle.
    private func leapArc(phase p: Double, mirror: Bool) -> (x: Double, y: Double, rot: Double, scale: Double, opacity: Double) {
        // Times (%): 0, 1.5, 4, 8, 13, 16, 17.5, 100
        // (x,y,rot,scale,opacity):
        let keys: [(Double, Double, Double, Double, Double, Double)] = [
            (0.000, 0,    8,  -42, 0.90, 0.0),
            (0.015, 0,    8,  -42, 0.90, 1.0),
            (0.040, 8,   -42, -18, 1.00, 1.0),
            (0.080, 20,  -68,  6,  1.00, 1.0),
            (0.130, 34,  -26,  34, 0.98, 1.0),
            (0.160, 42,   12,  56, 0.90, 1.0),
            (0.175, 42,   12,  56, 0.90, 0.0),
            (1.000, 42,   12,  56, 0.90, 0.0)
        ]
        for i in 0..<(keys.count - 1) {
            let a = keys[i]
            let b = keys[i + 1]
            if p >= a.0 && p <= b.0 {
                let f = (p - a.0) / max(0.0001, (b.0 - a.0))
                let x = a.1 + (b.1 - a.1) * f
                let y = a.2 + (b.2 - a.2) * f
                let r = a.3 + (b.3 - a.3) * f
                let s = a.4 + (b.4 - a.4) * f
                let o = a.5 + (b.5 - a.5) * f
                return (x, y, r, s, o)
            }
        }
        return (0, 8, -42, 0.9, 0)
    }

    private func splash(at pt: CGPoint, duration: Double, delay: Double, direction: SplashDir) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 1.0 :
                (((t + delay).truncatingRemainder(dividingBy: duration)) / duration)
            let s: (scale: Double, opacity: Double) = {
                switch direction {
                case .up:
                    if phase < 0.02 { return (0.1, 0) }
                    if phase < 0.09 {
                        let f = (phase - 0.02) / 0.07
                        return (0.4 + (1.1 - 0.4) * f, 0.85 * (1.0 - f))
                    }
                    return (1.1, 0)
                case .down:
                    if phase < 0.13 { return (0.1, 0) }
                    if phase < 0.24 {
                        let f = (phase - 0.13) / 0.11
                        return (0.45 + (1.2 - 0.45) * f, 0.85 * (1.0 - f))
                    }
                    return (1.2, 0)
                }
            }()
            Ellipse()
                .stroke(Color.white.opacity(0.6), lineWidth: 1.6)
                .frame(width: 26, height: 10)
                .scaleEffect(s.scale)
                .opacity(s.opacity)
                .position(x: pt.x, y: pt.y)
        }
    }
}

private struct FishGlyph: View {
    let palette: AmbientPalette
    var body: some View {
        ZStack {
            // Body
            Ellipse().fill(palette.fish).frame(width: 32, height: 16)
            // Belly highlight
            Ellipse().fill(palette.fish2).opacity(0.85)
                .frame(width: 26, height: 6).offset(y: 3)
            // Cheek highlight
            Ellipse().fill(palette.fish2).opacity(0.7)
                .frame(width: 12, height: 7).offset(x: 4, y: -1)
            // Tail
            Triangle()
                .fill(palette.fish)
                .frame(width: 14, height: 16)
                .offset(x: -16)
            // Fin
            Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addQuadCurve(to: CGPoint(x: 10, y: 8), control: CGPoint(x: 5, y: 0))
                p.closeSubpath()
            }
            .fill(palette.fishFin)
            .frame(width: 10, height: 8)
            .offset(x: 4, y: -8)
            // Eye
            Circle().fill(Color(hex: "#2D3142")).frame(width: 2.6, height: 2.6).offset(x: 12, y: -1)
        }
        .frame(width: 42, height: 24)
        .shadow(color: Color(red: 20/255, green: 30/255, blue: 30/255).opacity(0.28), radius: 2, y: 3)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Vignette

private struct VignetteOverlay: View {
    let isNight: Bool
    var body: some View {
        RadialGradient(
            colors: [.clear,
                     isNight
                        ? Color(red: 4/255,  green: 8/255,  blue: 14/255).opacity(0.52)
                        : Color(red: 18/255, green: 26/255, blue: 14/255).opacity(0.26)],
            center: UnitPoint(x: 0.5, y: isNight ? 0.38 : 0.44),
            startRadius: isNight ? 170 : 200,
            endRadius: 460
        )
        .frame(width: 402, height: 874)
        .allowsHitTesting(false)
    }
}

// MARK: - UI Overlay (label, close, wave bars)

private struct AmbientUIOverlay: View {
    let palette: AmbientPalette
    let isPlaying: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Top center label
            Text("ambient sounds")
                .font(DinoTheme.dinoFont(size: 13))
                .tracking(2)
                .foregroundColor(palette.uiCream.opacity(0.4))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 62)

            // Close button (top right)
            HStack {
                Spacer()
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(palette.closeBg.opacity(0.16))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.uiCream)
                    }
                }
                .padding(.trailing, 22)
                .padding(.top, 58)
            }

            // Wave equalizer bars (bottom center, only when playing)
            if isPlaying {
                WaveBars(color: palette.sage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 34)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
    }
}

private struct WaveBars: View {
    let color: Color
    private let bars: [(height: Double, delay: Double)] = [
        (12, -0.9), (26, -0.3), (16, -0.6), (22, -0.45), (14, -0.75)
    ]
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<bars.count, id: \.self) { i in
                    let b = bars[i]
                    let phase = ((t + b.delay).truncatingRemainder(dividingBy: 1.5)) / 1.5
                    let s = 0.4 + 0.6 * (0.5 - 0.5 * cos(phase * 2 * .pi))
                    Capsule()
                        .fill(color)
                        .frame(width: 5, height: b.height)
                        .scaleEffect(y: s, anchor: .center)
                        .shadow(color: color.opacity(0.5), radius: 3, y: 1)
                }
            }
            .frame(height: 30)
        }
    }
}

// MARK: - Reusable scene wrappers

/// The full waterfall scene at a given palette — used both as the live ambient
/// view and as the blurred backdrop behind the forest letter intro.
struct WaterfallScene: View {
    let palette: AmbientPalette
    let isNight: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let scale = max(geo.size.width / 402.0, geo.size.height / 874.0)
            ZStack {
                SkyLayer(palette: palette, isNight: isNight)
                if isNight {
                    MoonAndStars(reduceMotion: reduceMotion)
                }
                DriftingClouds(palette: palette, reduceMotion: reduceMotion)
                GodRays(palette: palette, reduceMotion: reduceMotion)
                SideTreeMasses(palette: palette)
                FoliageLayer(positions: SceneLayout.foliageBack, fill: palette.treeB)
                FoliageLayer(positions: SceneLayout.foliageMid,  fill: palette.treeM)
                FoliageLayer(positions: SceneLayout.foliageCanopy, fill: palette.canopy1, opacity: 0.96)
                RockCliff(palette: palette)
                FernsLayer(palette: palette)
                FoliageLayer(positions: SceneLayout.foliageFront, fill: palette.treeF)
                FoliageLayer(positions: SceneLayout.foliageHL, fill: palette.treeHL, opacity: 0.6)
                WaterfallSystem(palette: palette, reduceMotion: reduceMotion)
                PoolLayer(palette: palette, reduceMotion: reduceMotion)
                PoolForeground(palette: palette, reduceMotion: reduceMotion)
                FishLayer(palette: palette, reduceMotion: reduceMotion)
                if isNight {
                    FirefliesLayer(reduceMotion: reduceMotion)
                }
                VignetteOverlay(isNight: isNight)
            }
            .frame(width: 402, height: 874)
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

/// Thin wrapper that always renders the daytime palette — used by
/// `ForestLetterView` as a hauntingly dim background.
struct WaterfallDayScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        WaterfallScene(palette: .day, isNight: false, reduceMotion: reduceMotion)
    }
}

// MARK: - ForestLetterView (aged-parchment airmail letter)

/// Full-screen letter shown before AmbientSoundsView. The waterfall scene
/// sits behind, dimmed and blurred. The letter itself is a parchment page
/// with airmail border, postage stamp, postmark, and a hand-drawn signature.
struct ForestLetterView: View {
    let onEnter: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed: Bool = false
    @State private var fadingOut: Bool = false

    var body: some View {
        ZStack {
            // Hauntingly dim, blurred waterfall in the background.
            // Audio is NOT started until "enter the forest" is tapped.
            ZStack {
                WaterfallDayScene()
                Color.black.opacity(0.35)
            }
            .blur(radius: 3)
            .ignoresSafeArea()

            // Letter + CTAs centered vertically.
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                LetterPaper()
                    .padding(.horizontal, 20)
                    .rotationEffect(.degrees(restRotation), anchor: .center)
                    .offset(y: yOffset)
                    .scaleEffect(scaleAmount)
                    .opacity(landed ? (fadingOut ? 0 : 1) : 0)

                Spacer(minLength: 12)

                // CTAs sit outside the letter, glowing softly against the dark scene.
                Button(action: enterForest) {
                    Text("enter the forest →")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(Color(hex: "#FEFBF3"))
                        .shadow(color: Color(hex: "#A8C5A0").opacity(0.6), radius: 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(fadingOut ? 0 : 1)

                Button(action: onDismiss) {
                    Text("maybe later")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .opacity(fadingOut ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .onAppear { startEntrance() }
    }

    // MARK: Entrance / exit

    private var restRotation: Double {
        if reduceMotion { return -1 }
        return landed ? -1 : -8
    }
    private var yOffset: Double {
        if reduceMotion { return 0 }
        return landed ? 0 : -60
    }
    private var scaleAmount: Double {
        if reduceMotion { return 1.0 }
        return landed ? 1.0 : 0.94
    }

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.4)
                    : .spring(response: 0.65, dampingFraction: 0.72)
            ) {
                landed = true
            }
        }
    }

    private func enterForest() {
        let audio = AudioManager.shared
        audio.setVolume(0.7)
        audio.play(track: "rain", playback: false)
        audio.fadeIn(duration: 2.0)

        withAnimation(.easeOut(duration: 0.4)) { fadingOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onEnter()
        }
    }
}

// MARK: - Letter paper (parchment + airmail border + stamp + postmark + content)

private struct LetterPaper: View {
    private let letterBody: String = """
find a quiet spot.
close your eyes.

you're standing at the edge of a still forest.
somewhere nearby, a waterfall breathes.

there is nothing to do here.
no goals. no rush. no noise.

just let the sounds find you.
breathe slowly.
stay as long as you like.

the forest will be here,
whenever you need it.
"""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Parchment background + subtle grain lines
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#FBF4E4"),
                        Color(hex: "#F5EDD8"),
                        Color(hex: "#EFE4CA")
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                Canvas { ctx, size in
                    for i in 0..<4 {
                        var p = Path()
                        let y = Double(i + 1) * size.height / 5.0
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y + 24))
                        ctx.stroke(p, with: .color(Color(hex: "#8B7355").opacity(0.03)), lineWidth: 0.5)
                    }
                }
            }

            // Letter content (header + body + footer + fold line)
            VStack(alignment: .leading, spacing: 0) {
                Text("dear friend,")
                    .font(DinoTheme.dinoFont(size: 15))
                    .italic()
                    .foregroundColor(Color(hex: "#6B5B3E"))
                    .padding(.top, 20)
                    .padding(.leading, 20)

                Text(letterBody)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(Color(hex: "#4A3520"))
                    .lineSpacing(7)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("with love,")
                        .font(DinoTheme.dinoFont(size: 15))
                        .italic()
                        .foregroundColor(Color(hex: "#6B5B3E"))
                    Text("the forest")
                        .font(DinoTheme.dinoFont(size: 18))
                        .foregroundColor(Color(hex: "#3D6B3A"))
                    ForestLeafShape()
                        .fill(Color(hex: "#A8C5A0"))
                        .frame(width: 12, height: 14)
                        .padding(.top, 2)
                }
                .padding(.leading, 20)
                .padding(.top, 18)

                Rectangle()
                    .fill(Color(hex: "#D4C4A0").opacity(0.6))
                    .frame(height: 0.5)
                    .padding(.top, 16)

                Color.clear.frame(height: 14)
            }
            .padding(.bottom, 4)

            // Airmail border sits over the parchment but BELOW the stamp.
            AirmailStripes(thickness: 8)
                .padding(6)
                .allowsHitTesting(false)

            // Postage stamp + postmark in top-right — drawn on top of the border.
            ZStack(alignment: .topTrailing) {
                PostageStamp()
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                PostmarkCircle()
                    .offset(x: -8, y: 30)
            }
        }
        .background(Color(hex: "#FBF4E4"))
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Airmail stripes

/// 45° alternating red/blue stripes filling a ring around the parent rect.
/// Uses Canvas + `.destinationOut` to punch the inner area transparent.
private struct AirmailStripes: View {
    let thickness: Double

    var body: some View {
        Canvas { ctx, size in
            let red  = Color(hex: "#E85444")
            let blue = Color(hex: "#4A7FC1")
            let stripeW: Double = 8
            let cycle: Double = 16   // red(8) + blue(8)
            let span = size.width + size.height

            var x: Double = -span
            while x < span {
                var r = Path()
                r.move(to: CGPoint(x: x, y: 0))
                r.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(r, with: .color(red), lineWidth: stripeW)
                var b = Path()
                b.move(to: CGPoint(x: x + 8, y: 0))
                b.addLine(to: CGPoint(x: x + 8 + size.height, y: size.height))
                ctx.stroke(b, with: .color(blue), lineWidth: stripeW)
                x += cycle
            }

            // Punch out the inner area so only the border ring remains visible.
            ctx.blendMode = .destinationOut
            let inner = CGRect(
                x: thickness,
                y: thickness,
                width: max(0, size.width  - 2 * thickness),
                height: max(0, size.height - 2 * thickness)
            )
            ctx.fill(Path(inner), with: .color(.black))
        }
    }
}

// MARK: - Postage stamp

private struct PostageStamp: View {
    var body: some View {
        ZStack {
            // Cream outer frame
            Rectangle()
                .fill(Color(hex: "#FEFBF3"))
                .frame(width: 56, height: 68)
            // Sage interior
            Rectangle()
                .fill(Color(hex: "#A8C5A0"))
                .frame(width: 52, height: 64)
            // Inner sage-deep hairline for the classic stamp look
            Rectangle()
                .stroke(Color(hex: "#7BA872"), lineWidth: 0.6)
                .frame(width: 46, height: 58)
            // Leaf + label
            VStack(spacing: 2) {
                ForestLeafShape()
                    .fill(Color.white)
                    .frame(width: 18, height: 22)
                Text("dino")
                    .font(DinoTheme.dinoFont(size: 8))
                    .foregroundColor(.white)
                    .tracking(0.6)
            }
            .offset(y: -2)
        }
        // Faint scalloped "perforation" suggestion via repeated white dots
        .overlay(PerforationDots(width: 56, height: 68))
        .rotationEffect(.degrees(4))
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

/// Small white circles arrayed around the edge to suggest postage perforations.
private struct PerforationDots: View {
    let width: Double
    let height: Double
    var body: some View {
        Canvas { ctx, size in
            let r: Double = 1.4
            let step: Double = 5.0
            func dot(_ x: Double, _ y: Double) {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(hex: "#FEFBF3"))
                )
            }
            // Top + bottom edges
            var x = step
            while x < size.width {
                dot(x, 0)
                dot(x, size.height)
                x += step
            }
            // Left + right edges
            var y = step
            while y < size.height {
                dot(0, y)
                dot(size.width, y)
                y += step
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Postmark

private struct PostmarkCircle: View {
    var body: some View {
        ZStack {
            // Outer dashed circle
            Circle()
                .stroke(
                    Color(hex: "#8B7355").opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
                .frame(width: 44, height: 44)

            // Two horizontal lines around the center text
            VStack(spacing: 1.5) {
                Rectangle()
                    .fill(Color(hex: "#8B7355").opacity(0.5))
                    .frame(width: 22, height: 0.5)
                Text("forest post")
                    .font(DinoTheme.dinoFont(size: 7))
                    .foregroundColor(Color(hex: "#8B7355").opacity(0.7))
                    .tracking(0.4)
                Rectangle()
                    .fill(Color(hex: "#8B7355").opacity(0.5))
                    .frame(width: 22, height: 0.5)
            }
        }
        .rotationEffect(.degrees(-12))
    }
}

// MARK: - Forest leaf shape (used by seal, footer signature, and stamp)

private struct ForestLeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let top = CGPoint(x: r.midX, y: r.minY)
        let bottom = CGPoint(x: r.midX, y: r.maxY)
        p.move(to: top)
        p.addQuadCurve(to: bottom, control: CGPoint(x: r.maxX, y: r.midY))
        p.addQuadCurve(to: top,    control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        p.move(to: top)
        p.addLine(to: bottom)
        return p
    }
}

// MARK: - AmbientSoundsView (composition root)

struct AmbientSoundsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var audio = AudioManager.shared
    @State private var isClosing: Bool = false

    private let isNight: Bool = {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 6 || h >= 18
    }()
    private var palette: AmbientPalette { isNight ? .night : .day }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WaterfallScene(palette: palette, isNight: isNight, reduceMotion: reduceMotion)
                .ignoresSafeArea()
            AmbientUIOverlay(
                palette: palette,
                isPlaying: audio.isPlaying,
                onClose: close
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .preferredColorScheme(isNight ? .dark : .light)
        .onAppear {
            // If the user came in via ForestLetterView, audio is already playing
            // and fading in — don't restart it. Otherwise kick it off fresh.
            let audio = AudioManager.shared
            if audio.currentTrack != "rain" || !audio.isPlaying {
                audio.setVolume(0.7)
                audio.play(track: "rain", playback: false)
                audio.fadeIn(duration: 1.5)
            }
            AnalyticsManager.shared.trackScreenViewed("ambient_sounds")
        }
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        AudioManager.shared.fadeOut(duration: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioManager.shared.stop()
            dismiss()
        }
    }
}
