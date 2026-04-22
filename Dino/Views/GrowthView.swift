//
//  GrowthView.swift
//  Dino
//

import SwiftUI

// MARK: - File-private helpers

private func smoothstep(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = max(0, min(1, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func hexRGB(_ hex: String) -> (Double, Double, Double) {
    let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: trimmed).scanHexInt64(&value)
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return (r, g, b)
}

private func mixHex(_ a: String, _ b: String, _ t: Double) -> Color {
    let clamped = max(0, min(1, t))
    let (ar, ag, ab) = hexRGB(a)
    let (br, bg, bb) = hexRGB(b)
    return Color(
        .sRGB,
        red: lerp(ar, br, clamped),
        green: lerp(ag, bg, clamped),
        blue: lerp(ab, bb, clamped),
        opacity: 1.0
    )
}

private func wiltColor(base: String, care: Double, clampMin: Double) -> Color {
    let amount = 1 - max(clampMin, care)
    return mixHex(base, "#9C7C50", amount)
}

private func phyllotaxis(count: Int, scale: Double) -> [CGPoint] {
    let golden = 137.5 * .pi / 180.0
    return (0..<count).map { i in
        let r = scale * sqrt(Double(i) / Double(max(count - 1, 1)))
        let theta = Double(i) * golden
        return CGPoint(x: cos(theta) * r, y: sin(theta) * r)
    }
}

private enum GardenScene {
    case morning, afternoon, evening, night, rainy, cloudy
}

private func sceneKey(theme: DinoAppTheme, date: Date) -> GardenScene {
    switch theme {
    case .rainy, .storm: return .rainy
    case .cloudy:        return .cloudy
    case .night:         return .night
    default:
        break
    }
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 6...11:  return .morning
    case 12...16: return .afternoon
    case 17...19: return .evening
    default:      return .night
    }
}

// MARK: - GrowthView

struct GrowthView: View {

    @StateObject private var vm = GrowthViewModel.shared
    @ObservedObject private var shared = SharedDataManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GrowthHeader()
                ProgressCard(vm: vm)
                GardenPanel(
                    vm: vm,
                    scene: sceneKey(theme: themeManager.currentTheme, date: Date()),
                    reduceMotion: reduceMotion
                )
                StatusLine(vm: vm)
                PracticePillsRow(vm: vm)
                WeeklyBloomLog(blooms: vm.weeklyBlooms)
                XPCard(vm: vm)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - GrowthHeader

private struct GrowthHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THIS SEASON")
                .font(DinoTheme.dinoFont(size: 12))
                .tracking(1.2)
                .foregroundColor(Color(hex: "#6B7280"))
            Text("your garden 🌻")
                .font(DinoTheme.dinoFont(size: 32))
                .foregroundColor(Color(hex: "#2D3142"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ProgressCard

private struct ProgressCard: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("day")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
                Text("\(vm.dayNumber)")
                    .font(DinoTheme.numericFont(size: 28))
                    .foregroundColor(Color(hex: "#2D3142"))
                Spacer()
            }

            PhaseBar(progress: vm.growth)

            HStack {
                phaseLabel("seed")
                Spacer()
                phaseLabel("sprout")
                Spacer()
                phaseLabel("stem")
                Spacer()
                phaseLabel("bud")
                Spacer()
                phaseLabel("bloom")
            }

            Spacer().frame(height: 2)

            CareBar(care: vm.care, daysSince: vm.daysSinceAny)

            HStack {
                phaseLabel("today")
                Spacer()
                phaseLabel("3d")
                Spacer()
                phaseLabel("7d")
                Spacer()
                phaseLabel("10d")
                Spacer()
                phaseLabel("14d+")
            }

            wateringLine
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#FFFDF5"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#E8E0CC"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private func phaseLabel(_ text: String) -> some View {
        Text(text)
            .font(DinoTheme.dinoFont(size: 10))
            .foregroundColor(Color(hex: "#6B7280"))
    }

    @ViewBuilder
    private var wateringLine: some View {
        HStack(spacing: 6) {
            if vm.wateredToday {
                Text("watered today 💧")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#2D3142"))
            } else if let d = vm.lastWateredDaysAgo {
                Text("last watered \(d)d ago")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            } else {
                Text("waiting to be watered")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            Spacer()
        }
    }
}

// MARK: - PhaseBar

private struct PhaseBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#E8DFCF"))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(Color(hex: "#6B9E44"))
                    .frame(width: max(0, w * clamped), height: 6)

                HStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(Color(hex: "#D6C7A8"))
                            .frame(width: 6, height: 6)
                        if i < 4 { Spacer(minLength: 0) }
                    }
                }

                Circle()
                    .fill(Color(hex: "#F5C842"))
                    .overlay(Circle().stroke(Color(hex: "#D49020"), lineWidth: 1))
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, w * clamped - 6))
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

// MARK: - CareBar

private struct CareBar: View {
    let care: Double
    let daysSince: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(0, min(1, care))
            let careColor = mixHex("#7BA872", "#9C7C50", 1 - clamped)
            let fillW = max(0, w * clamped)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#E8DFCF"))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(careColor)
                    .frame(width: fillW, height: 6)

                HStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(Color(hex: "#D6C7A8"))
                            .frame(width: 6, height: 6)
                        if i < 4 { Spacer(minLength: 0) }
                    }
                }

                // Left = healthy (today, care=1), right = wilted (14d+, care=0)
                let dotOffset = max(0, (1 - clamped) * w - 6)
                Circle()
                    .fill(careColor)
                    .overlay(Circle().stroke(careColor.opacity(0.7), lineWidth: 1))
                    .frame(width: 12, height: 12)
                    .offset(x: dotOffset)
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

// MARK: - Plant snapshot (value captured on MainActor, safe to read in Canvas)

private struct SunflowerSnapshot {
    let sproutP: Double
    let stemP: Double
    let leafP: Double
    let budP: Double
    let bloomP: Double
    let care: Double
}

// MARK: - GardenPanel

private struct GardenPanel: View {
    @ObservedObject var vm: GrowthViewModel
    let scene: GardenScene
    let reduceMotion: Bool

    @State private var appeared: Bool = false

    var body: some View {
        let snap = SunflowerSnapshot(
            sproutP: vm.sproutP,
            stemP: vm.stemP,
            leafP: vm.leafP,
            budP: vm.budP,
            bloomP: vm.bloomP,
            care: vm.care
        )

        return TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15.0 : nil, paused: false)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawBackground(ctx: &ctx, size: size, scene: scene, t: t, reduceMotion: reduceMotion)
                drawSunflower(
                    ctx: &ctx,
                    size: size,
                    snap: snap,
                    t: t,
                    reduceMotion: reduceMotion,
                    appearScale: appeared ? 1.0 : 0.0
                )
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#A8C5A0").opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Plant rendering

private func drawSunflower(
    ctx: inout GraphicsContext,
    size: CGSize,
    snap: SunflowerSnapshot,
    t: TimeInterval,
    reduceMotion: Bool,
    appearScale: Double
) {
    // Design uses a 400x320 viewBox
    let sx = size.width / 400.0
    let sy = size.height / 320.0

    // Helper to transform design-space coords into view-space
    func px(_ x: Double) -> CGFloat { CGFloat(x * Double(sx)) }
    func py(_ y: Double) -> CGFloat { CGFloat(y * Double(sy)) }

    let cx = 200.0
    let groundY = 260.0

    let sproutP = snap.sproutP
    let stemP = snap.stemP
    let leafP = snap.leafP
    let budP = snap.budP
    let bloomP = snap.bloomP
    let care = max(0, min(1, snap.care))

    // ----- 1. Seed mound & seed -----
    do {
        let moundRect = CGRect(
            x: px(cx - 13), y: py(groundY + 3 - 3.2),
            width: px(26) - px(0), height: py(6.4) - py(0)
        )
        ctx.fill(Path(ellipseIn: moundRect), with: .color(Color(hex: "#3A2818").opacity(0.3)))

        if sproutP < 1 {
            let seedOp = 1 - sproutP
            let seedRect = CGRect(
                x: px(cx - 6), y: py(groundY + 1 - 4),
                width: px(12) - px(0), height: py(8) - py(0)
            )
            ctx.fill(Path(ellipseIn: seedRect),
                     with: .color(Color(hex: "#8B6B4A").opacity(seedOp)))
            ctx.stroke(Path(ellipseIn: seedRect),
                       with: .color(Color(hex: "#5A4028").opacity(seedOp)),
                       lineWidth: 1)
        }
    }

    // ----- Stem geometry shared by stem, leaves, bud, bloom -----
    let stemH = 6 + stemP * 120
    let stemW = 2 + stemP * 4
    let bendDeg = (1 - care) * 55
    let swayDeg: Double = {
        guard !reduceMotion else { return 0 }
        if bloomP > 0.3 && care > 0.7 {
            return sin(t * 2.0 * .pi / 5.5) * 1.8
        }
        return 0
    }()
    let totalRot = bendDeg * 0.3 + swayDeg

    // Pivot for stem rotation — base at (cx, groundY)
    let pivotX = px(cx)
    let pivotY = py(groundY)

    // ----- 2. Stem (drawn in a rotated layer) -----
    if stemP > 0.01 {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            var stem = Path()
            let bx = cx
            let by = groundY
            let topY = groundY - stemH
            stem.move(to: CGPoint(x: px(bx - stemW / 2), y: py(by)))
            stem.addQuadCurve(
                to: CGPoint(x: px(bx - stemW / 3), y: py(topY + 4)),
                control: CGPoint(x: px(bx), y: py(by - stemH * 0.6))
            )
            stem.addLine(to: CGPoint(x: px(bx + stemW / 3), y: py(topY + 4)))
            stem.addQuadCurve(
                to: CGPoint(x: px(bx + stemW / 2), y: py(by)),
                control: CGPoint(x: px(bx), y: py(by - stemH * 0.6))
            )
            stem.closeSubpath()

            layer.fill(stem, with: .color(wiltColor(base: "#5D8A3C", care: care, clampMin: 0.2)))
        }
    }

    // ----- 3. Leaves -----
    if leafP > 0.01 {
        let leafFractions: [Double] = [0.35, 0.42, 0.62, 0.70]
        let leafSides: [Double] = [-1, 1, -1, 1]
        let leafAngles: [Double] = [30, 25, 35, 28]
        let droop = (1 - care) * 40
        let leafLen = 22.0 * leafP

        let leafBase = wiltColor(base: "#6B9E44", care: care, clampMin: 0.15)
        let yellowShift = max(0.0, (0.6 - care) / 0.6)
        let leafFill = mixBaseAndHex(base: leafBase, hex: "#C4A35A", t: yellowShift)

        for i in 0..<4 {
            let frac = leafFractions[i]
            let side = leafSides[i]
            let baseAngle = leafAngles[i]
            let angle = side * baseAngle + (side * droop)
            let lx = cx
            let ly = groundY - stemH * frac

            ctx.drawLayer { layer in
                // Stem rotation first
                layer.translateBy(x: pivotX, y: pivotY)
                layer.rotate(by: .degrees(totalRot))
                layer.translateBy(x: -pivotX, y: -pivotY)

                // Leaf own rotation around its attachment
                let attachX = px(lx)
                let attachY = py(ly)
                layer.translateBy(x: attachX, y: attachY)
                layer.rotate(by: .degrees(angle))

                // Draw a teardrop leaf along +x axis, length leafLen
                let len = leafLen
                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: 0))
                leaf.addQuadCurve(
                    to: CGPoint(x: px(len), y: 0),
                    control: CGPoint(x: px(len * 0.5), y: py(-len * 0.4))
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: 0, y: 0),
                    control: CGPoint(x: px(len * 0.5), y: py(len * 0.4))
                )
                leaf.closeSubpath()

                layer.fill(leaf, with: .color(leafFill))
                layer.stroke(leaf,
                             with: .color(wiltColor(base: "#3F6B50", care: care, clampMin: 0.15)),
                             lineWidth: 0.7)
            }
        }
    }

    // ----- 4. Bud -----
    let hxBase = cx
    let hyBase = groundY - stemH

    if budP > 0.01 && bloomP < 0.5 {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            let budOp = 1 - bloomP * 2
            let bx = hxBase
            let by = hyBase
            let rxD = 6 + budP * 4
            let ryD = 8 + budP * 4
            let rect = CGRect(
                x: px(bx - rxD), y: py(by - ryD),
                width: px(rxD * 2) - px(0), height: py(ryD * 2) - py(0)
            )
            let budFill = wiltColor(base: "#6B9E44", care: care, clampMin: 0.15)
            layer.fill(Path(ellipseIn: rect), with: .color(budFill.opacity(budOp)))
            layer.stroke(Path(ellipseIn: rect),
                         with: .color(wiltColor(base: "#3F6B50", care: care, clampMin: 0.15).opacity(budOp)),
                         lineWidth: 0.7)

            // 4 sepal strokes
            let sepalAngles: [Double] = [-35, -10, 15, 40]
            for a in sepalAngles {
                let rad = a * .pi / 180
                let tipX = bx + cos(rad) * (rxD + 3)
                let tipY = by + sin(rad) * (ryD + 3)
                var sep = Path()
                sep.move(to: CGPoint(x: px(bx), y: py(by + ryD * 0.2)))
                sep.addQuadCurve(
                    to: CGPoint(x: px(tipX), y: py(tipY)),
                    control: CGPoint(x: px((bx + tipX) / 2), y: py(by + ryD * 0.5))
                )
                layer.stroke(sep,
                             with: .color(budFill.opacity(budOp)),
                             lineWidth: 1.2)
            }
        }
    }

    // ----- 5. Bloom -----
    if bloomP > 0.01 {
        let headR = 30.0 * bloomP
        let headDroopDeg = (1 - care) * 30

        ctx.drawLayer { layer in
            // Stem rotation
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            // Head droop pivot at head base
            let hx = hxBase
            let hy = hyBase
            let droopPivotX = px(hx)
            let droopPivotY = py(hy + 2)
            layer.translateBy(x: droopPivotX, y: droopPivotY)
            layer.rotate(by: .degrees(headDroopDeg))
            layer.translateBy(x: -droopPivotX, y: -droopPivotY)

            // Outer ring — 14 petals
            let petalFill = wiltColor(base: "#F5C842", care: care, clampMin: 0.3)
            let petalEdge = wiltColor(base: "#D49020", care: care, clampMin: 0.3)
            for i in 0..<14 {
                let a = (Double(i) / 14.0) * 360.0
                let rad = (a - 90) * .pi / 180
                let pxd = hx + cos(rad) * headR * 0.55
                let pyd = hy + sin(rad) * headR * 0.55
                let petalRX = headR * 0.95 * 0.75
                let petalRY = headR * 0.95 * 0.32

                layer.drawLayer { sub in
                    sub.translateBy(x: px(pxd), y: py(pyd))
                    sub.rotate(by: .degrees(a))
                    let rect = CGRect(
                        x: px(-petalRX / 2), y: py(-petalRY / 2),
                        width: px(petalRX) - px(0), height: py(petalRY) - py(0)
                    )
                    sub.fill(Path(ellipseIn: rect), with: .color(petalFill))
                    sub.stroke(Path(ellipseIn: rect), with: .color(petalEdge), lineWidth: 0.7)
                }
            }

            // Inner ring — 10 petals offset by 18°
            let innerTint = mixHex("#F5C842", "#FFE5A0", 0.4)
            for i in 0..<10 {
                let a = (Double(i) / 10.0) * 360.0 + 18.0
                let rad = (a - 90) * .pi / 180
                let pxd = hx + cos(rad) * headR * 0.45
                let pyd = hy + sin(rad) * headR * 0.45
                let petalRX = headR * 0.72 * 0.7
                let petalRY = headR * 0.72 * 0.3

                layer.drawLayer { sub in
                    sub.translateBy(x: px(pxd), y: py(pyd))
                    sub.rotate(by: .degrees(a))
                    let rect = CGRect(
                        x: px(-petalRX / 2), y: py(-petalRY / 2),
                        width: px(petalRX) - px(0), height: py(petalRY) - py(0)
                    )
                    sub.fill(Path(ellipseIn: rect), with: .color(innerTint))
                }
            }

            // Center disk
            let centerR = headR * 0.42
            let centerRect = CGRect(
                x: px(hx - centerR), y: py(hy - centerR),
                width: px(centerR * 2) - px(0), height: py(centerR * 2) - py(0)
            )
            let centerGradient = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Color(hex: "#9C5A2A"), Color(hex: "#8B4513")]),
                center: CGPoint(x: px(hx), y: py(hy)),
                startRadius: 0,
                endRadius: px(centerR)
            )
            layer.fill(Path(ellipseIn: centerRect), with: centerGradient)
            layer.stroke(Path(ellipseIn: centerRect),
                         with: .color(Color(hex: "#4A2810")), lineWidth: 1)

            // Seed dots (phyllotaxis)
            if bloomP > 0.6 {
                let pts = phyllotaxis(count: 16, scale: headR * 0.38)
                for p in pts {
                    let dotRect = CGRect(
                        x: px(hx + p.x - 0.6), y: py(hy + p.y - 0.6),
                        width: px(1.2) - px(0), height: py(1.2) - py(0)
                    )
                    layer.fill(Path(ellipseIn: dotRect),
                               with: .color(Color(hex: "#3F2610")))
                }
            }
        }

        // Falling petal (outside head droop layer so it can fall straight)
        if care < 0.45 && bloomP > 0.3 && !reduceMotion {
            let phase = (t.truncatingRemainder(dividingBy: 3.5)) / 3.5
            let fallX = hxBase - 30 - phase * 25
            let fallY = hyBase + 20 + phase * 140
            let rotation = phase * 180
            let opacity = max(0, 1 - phase * 1.2)

            ctx.drawLayer { layer in
                layer.translateBy(x: px(fallX), y: py(fallY))
                layer.rotate(by: .degrees(rotation))
                let rect = CGRect(
                    x: px(-5), y: py(-2.2),
                    width: px(10) - px(0), height: py(4.4) - py(0)
                )
                layer.opacity = opacity
                layer.fill(Path(ellipseIn: rect),
                          with: .color(wiltColor(base: "#F5C842", care: care, clampMin: 0.3)))
            }
        }
    }

    // Apply appearScale as a minor scale-in (scale the whole thing is tricky —
    // we instead fade via opacity proxy by drawing nothing when appearScale=0).
    _ = appearScale // referenced; Canvas opacity handled at GardenPanel level if needed
}

// Helper to mix a resolved base Color with a hex target by amount t (0..1).
private func mixBaseAndHex(base: Color, hex: String, t: Double) -> Color {
    // We can't introspect arbitrary Color RGB cheaply, so approximate by
    // layering: return a LinearInterp via hex assumption — callers pass base
    // as a hex-origin color. In practice we mix from the original hex name,
    // but since wiltColor already returned a mixed Color, we fall back to
    // returning `base` with a tint overlay approximation.
    guard t > 0 else { return base }
    // Simple approach: blend base toward hex using UIColor introspection.
    #if canImport(UIKit)
    let ui = UIColor(base)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return base }
    let (tr, tg, tb) = hexRGB(hex)
    let clamped = max(0, min(1, t))
    return Color(
        .sRGB,
        red: lerp(Double(r), tr, clamped),
        green: lerp(Double(g), tg, clamped),
        blue: lerp(Double(b), tb, clamped),
        opacity: Double(a)
    )
    #else
    return base
    #endif
}

// MARK: - Background rendering

private func drawBackground(
    ctx: inout GraphicsContext,
    size: CGSize,
    scene: GardenScene,
    t: TimeInterval,
    reduceMotion: Bool
) {
    let w = size.width
    let h = size.height

    // 1. Sky gradient (top 45%)
    let skyRect = CGRect(x: 0, y: 0, width: w, height: h * 0.55)
    let skyColors: [Color]
    switch scene {
    case .morning:   skyColors = [Color(hex: "#FFE4B5"), Color(hex: "#87CEEB")]
    case .afternoon: skyColors = [Color(hex: "#8DC9EC"), Color(hex: "#B8D9E8"), Color(hex: "#E6F1EC")]
    case .evening:   skyColors = [Color(hex: "#FF9A5C"), Color(hex: "#FF6B6B"), Color(hex: "#6B4FA0")]
    case .night:     skyColors = [Color(hex: "#1A1A2E"), Color(hex: "#16213E")]
    case .rainy:     skyColors = [Color(hex: "#6B7280"), Color(hex: "#4A5568")]
    case .cloudy:    skyColors = [Color(hex: "#9CA3AF"), Color(hex: "#D1D5DB")]
    }
    let skyShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: skyColors),
        startPoint: CGPoint(x: w / 2, y: 0),
        endPoint: CGPoint(x: w / 2, y: h * 0.55)
    )
    ctx.fill(Path(skyRect), with: skyShading)

    // 2. Celestial
    switch scene {
    case .morning, .afternoon:
        let sunCenter = CGPoint(x: w * 0.78, y: h * 0.18)
        let r: CGFloat = 22
        // Rays
        ctx.drawLayer { layer in
            layer.translateBy(x: sunCenter.x, y: sunCenter.y)
            layer.rotate(by: .radians(t * 0.05))
            for i in 0..<8 {
                let a = Double(i) * (.pi / 4)
                var ray = Path()
                ray.move(to: CGPoint(x: cos(a) * (r + 4), y: sin(a) * (r + 4)))
                ray.addLine(to: CGPoint(x: cos(a) * (r + 14), y: sin(a) * (r + 14)))
                layer.stroke(ray, with: .color(Color(hex: "#F5D28A").opacity(0.75)), lineWidth: 2.5)
            }
        }
        let sunRect = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: sunRect), with: .color(Color(hex: "#F5D28A")))
        ctx.stroke(Path(ellipseIn: sunRect), with: .color(Color(hex: "#D4A55A")), lineWidth: 1)

    case .evening:
        let sunCenter = CGPoint(x: w * 0.80, y: h * 0.30)
        let r: CGFloat = 18
        let sunRect = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: sunRect), with: .color(Color(hex: "#FFCF7A")))
        ctx.stroke(Path(ellipseIn: sunRect), with: .color(Color(hex: "#D4884A")), lineWidth: 1)

    case .night:
        let moonCenter = CGPoint(x: w * 0.78, y: h * 0.18)
        let r: CGFloat = 18
        let moonRect = CGRect(x: moonCenter.x - r, y: moonCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: moonRect), with: .color(Color(hex: "#F5F0D8")))
        ctx.stroke(Path(ellipseIn: moonRect), with: .color(Color(hex: "#BFB88E")), lineWidth: 1)
        // Craters
        let craters: [(Double, Double, Double)] = [(-4, -3, 2), (3, 1, 1.5), (-2, 4, 1.2)]
        for (dx, dy, cr) in craters {
            let cRect = CGRect(
                x: moonCenter.x + dx - cr, y: moonCenter.y + dy - cr,
                width: cr * 2, height: cr * 2
            )
            ctx.fill(Path(ellipseIn: cRect), with: .color(Color(hex: "#BFB88E").opacity(0.5)))
        }

    case .rainy, .cloudy:
        break
    }

    // 3. Stars (night)
    if scene == .night {
        let stars: [(Double, Double, Double, Double)] = [
            (0.08, 0.10, 3.1, 0.0),
            (0.15, 0.18, 2.4, 0.8),
            (0.22, 0.08, 2.9, 1.6),
            (0.30, 0.22, 3.3, 2.4),
            (0.37, 0.14, 2.6, 0.4),
            (0.44, 0.30, 2.8, 1.2),
            (0.50, 0.06, 3.0, 0.2),
            (0.58, 0.24, 2.5, 2.0),
            (0.62, 0.12, 3.2, 0.9),
            (0.70, 0.28, 2.7, 1.8),
            (0.13, 0.32, 3.4, 2.6),
            (0.27, 0.38, 2.3, 0.1),
            (0.42, 0.40, 2.9, 1.5),
            (0.55, 0.36, 3.1, 2.2),
            (0.68, 0.40, 2.4, 0.7),
            (0.82, 0.10, 2.8, 1.4),
            (0.88, 0.24, 3.0, 2.8),
            (0.92, 0.36, 2.5, 0.5),
            (0.05, 0.22, 2.6, 1.1),
            (0.19, 0.26, 3.0, 1.9)
        ]
        let count = reduceMotion ? 10 : 20
        for i in 0..<min(count, stars.count) {
            let (fx, fy, period, phase) = stars[i]
            let alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 2 * .pi / period + phase))
            let r: CGFloat = 1.2
            let rect = CGRect(x: w * fx - r, y: h * fy - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(Color(hex: "#F5F0D8").opacity(alpha)))
        }
    }

    // 4. Clouds (morning / afternoon / cloudy)
    if scene == .morning || scene == .afternoon || scene == .cloudy {
        let clouds: [(Double, Double, Double, Double)] = [
            (0.14, 60.0, 1.0, 0.20),
            (0.10, 75.0, 0.8, 0.55),
            (0.22, 90.0, 1.2, 0.10)
        ]
        for (fy, dur, scale, initialFX) in clouds {
            let span = w + 200
            let progress: Double
            if reduceMotion {
                progress = initialFX
            } else {
                progress = (t / dur).truncatingRemainder(dividingBy: 1.0)
            }
            let x = (progress + initialFX).truncatingRemainder(dividingBy: 1.0) * Double(span) - 100
            let y = h * fy
            drawCloud(ctx: &ctx, center: CGPoint(x: CGFloat(x), y: y), scale: CGFloat(scale))
        }
    }

    // 5. Rain
    if scene == .rainy {
        let dropCount = reduceMotion ? 60 : 120
        for i in 0..<dropCount {
            let seed = Double(i) * 17.31
            let fx = (sin(seed) * 0.5 + 0.5)
            let phase = (cos(seed * 0.7) * 0.5 + 0.5) * h
            let speed = 180.0 + (sin(seed * 1.3) * 0.5 + 0.5) * 120.0
            let y = (t * speed + phase).truncatingRemainder(dividingBy: Double(h))
            let x = Double(w) * fx
            var drop = Path()
            let dx = 2.0
            let dy = 10.0
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x + dx, y: y + dy))
            ctx.stroke(drop, with: .color(Color(hex: "#B8CFDA").opacity(0.6)), lineWidth: 1)
        }
    }

    // 8. Soil (bottom 45% → y = h*0.55 to h)
    let soilRect = CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45)
    let soilTop: Color
    let soilBottom: Color
    switch scene {
    case .night:
        soilTop = Color(hex: "#6B4A30")
        soilBottom = Color(hex: "#3A2818")
    default:
        soilTop = Color(hex: "#9A7550")
        soilBottom = Color(hex: "#5E4220")
    }
    let soilShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [soilTop, soilBottom]),
        startPoint: CGPoint(x: w / 2, y: h * 0.55),
        endPoint: CGPoint(x: w / 2, y: h)
    )
    ctx.fill(Path(soilRect), with: soilShading)

    // Speckles
    let speckles: [(Double, Double)] = [
        (0.08, 0.70), (0.18, 0.82), (0.26, 0.74), (0.34, 0.88),
        (0.46, 0.78), (0.55, 0.86), (0.62, 0.72), (0.72, 0.80),
        (0.83, 0.84), (0.91, 0.76)
    ]
    for (fx, fy) in speckles {
        let r: CGFloat = 1.2
        let rect = CGRect(x: w * fx - r, y: h * fy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#3F2A1C").opacity(0.35)))
    }

    // 9. Grass strip (18pt tall, just above soil)
    let grassTop = h * 0.55 - 18
    let grassRect = CGRect(x: 0, y: grassTop, width: w, height: 18)
    let grassShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [Color(hex: "#A8C5A0"), Color(hex: "#7BA872")]),
        startPoint: CGPoint(x: w / 2, y: grassTop),
        endPoint: CGPoint(x: w / 2, y: h * 0.55)
    )
    ctx.fill(Path(grassRect), with: grassShading)

    // Tufts
    let tuftCount = 11
    for i in 0..<tuftCount {
        let fx = (Double(i) + 0.5) / Double(tuftCount)
        let x = w * CGFloat(fx)
        var tuft = Path()
        tuft.move(to: CGPoint(x: x - 3, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x, y: grassTop + 4))
        tuft.move(to: CGPoint(x: x, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x + 2, y: grassTop + 6))
        tuft.move(to: CGPoint(x: x + 3, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x + 5, y: grassTop + 4))
        ctx.stroke(tuft, with: .color(Color(hex: "#4A8A5C")), lineWidth: 1.5)
    }

    // 6. Fireflies (night)
    if scene == .night {
        let count = reduceMotion ? 4 : 8
        let firefliesBase: [(Double, Double, Double, Double, Double)] = [
            (0.40, 0.45, 2.0, 1.8, 0.0),
            (0.55, 0.50, 2.4, 2.1, 0.7),
            (0.48, 0.55, 1.8, 2.5, 1.3),
            (0.60, 0.42, 2.2, 2.0, 0.4),
            (0.45, 0.62, 2.6, 1.9, 1.1),
            (0.62, 0.58, 2.0, 2.3, 0.9),
            (0.50, 0.40, 2.3, 2.6, 1.6),
            (0.58, 0.52, 2.5, 2.2, 0.2)
        ]
        for i in 0..<min(count, firefliesBase.count) {
            let (fx, fy, p1, p2, phase) = firefliesBase[i]
            let bx = w * fx
            let by = h * fy
            let x = bx + 8 * sin(t * 2 * .pi / p1 + phase)
            let y = by + 6 * cos(t * 2 * .pi / p2 + phase)
            let pulse = 0.2 + 0.8 * (0.5 + 0.5 * sin(t * 2 * .pi / 2.3 + phase))
            let outerRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
            let innerRect = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
            ctx.fill(Path(ellipseIn: outerRect),
                     with: .color(Color(hex: "#FFEB8F").opacity(0.3 * pulse)))
            ctx.fill(Path(ellipseIn: innerRect),
                     with: .color(Color(hex: "#FFEB8F").opacity(pulse)))
        }
    }
}

private func drawCloud(ctx: inout GraphicsContext, center: CGPoint, scale: CGFloat) {
    let base: [(CGFloat, CGFloat, CGFloat)] = [
        (-18, 0, 14),
        (-4, -4, 16),
        (10, 0, 14),
        (22, 2, 12)
    ]
    for (dx, dy, r) in base {
        let rr = r * scale
        let rect = CGRect(
            x: center.x + dx * scale - rr, y: center.y + dy * scale - rr,
            width: rr * 2, height: rr * 2
        )
        ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.8)))
    }
}

// MARK: - StatusLine

private struct StatusLine: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("your sunflower is \(vm.stageLabel)")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(Color(hex: "#2D3142"))
            Text("\(vm.growthPercent)% GROWN")
                .font(DinoTheme.dinoFont(size: 10))
                .tracking(1)
                .foregroundColor(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PracticePillsRow

private struct PracticePillsRow: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PracticePill(
                    label: "journal",
                    count: vm.journalSessionCount,
                    dotColor: Color(hex: "#F5C842"),
                    usedToday: vm.usedJournalToday
                )
                PracticePill(
                    label: "mood",
                    count: vm.moodSessionCount,
                    dotColor: Color(hex: "#E8A0A8"),
                    usedToday: vm.usedMoodToday
                )
                PracticePill(
                    label: "gratitude",
                    count: vm.gratitudeSessionCount,
                    dotColor: Color(hex: "#C4A35A"),
                    usedToday: vm.usedGratitudeToday
                )
                PracticePill(
                    label: "breathing",
                    count: vm.breathingSessionCount,
                    dotColor: Color(hex: "#A594C4"),
                    usedToday: vm.usedBreathingToday
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct PracticePill: View {
    let label: String
    let count: Int
    let dotColor: Color
    let usedToday: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(Color(hex: "#2D3142"))
            Text("\(count)")
                .font(DinoTheme.numericFont(size: 13))
                .foregroundColor(Color(hex: "#2D3142"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(usedToday ? dotColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            Capsule().stroke(usedToday ? dotColor : Color(hex: "#6B7280").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - WeeklyBloomLog

private struct WeeklyBloomLog: View {
    let blooms: [DayBloom]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("this week")
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(Color(hex: "#2D3142"))
            HStack(spacing: 0) {
                ForEach(Array(blooms.enumerated()), id: \.offset) { index, day in
                    WeekDayColumn(
                        label: day.dayLabel,
                        practices: day.practices,
                        appearDelay: Double(index) * 0.08
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct WeekDayColumn: View {
    let label: String
    let practices: Set<PracticeType>
    let appearDelay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#6B7280"))
                .tracking(0.8)
            VStack(spacing: 3) {
                ForEach(PracticeType.allCases) { p in
                    Circle()
                        .fill(practices.contains(p) ? p.bloomColor : Color(hex: "#E8E4D5"))
                        .frame(width: 6, height: 6)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - XPCard

private struct XPCard: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.levelLabel)
                    .font(DinoTheme.titleFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text(vm.xpLabel)
                    .font(DinoTheme.numericFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color(hex: "#E8E4D5"))
                    RoundedRectangle(cornerRadius: 999)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#A8C5A0"), Color(hex: "#A8D4E6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(12, geo.size.width * vm.xpProgress))
                }
            }
            .frame(height: 12)
        }
        .padding(20)
        .background(DinoTheme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DinoTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: DinoTheme.shadowColor, radius: 12, x: 0, y: 4)
    }
}
