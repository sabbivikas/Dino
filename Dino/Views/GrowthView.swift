//
//  GrowthView.swift
//  Dino
//

import SwiftUI

// MARK: - GrowthView

struct GrowthView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: GrowthViewModel = GrowthViewModel(dataManager: SharedDataManager.shared)
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlant: PlantState? = nil
    @State private var appeared = false

    private let gardenBG = Color("#FDF8F0")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    gardenPanel
                    weeklyBloomLog
                    xpCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
            .sheet(item: $selectedPlant) { plant in
                PlantDetailSheet(plant: plant)
                    .environmentObject(dataManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("your garden")
                .font(DinoTheme.dinoFont(size: 26))
                .foregroundColor(DinoTheme.textPrimary)
            Text("tends to grow with your practice")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Garden panel (2x2 grid of plants)

    private var gardenPanel: some View {
        let plants = viewModel.plantStates
        return VStack(spacing: 0) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 8
            ) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { index, plant in
                    GardenPlotTile(
                        plant: plant,
                        appearDelay: Double(index) * 0.2
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedPlant = plant
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(gardenBG)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color("#A8C5A0").opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: Weekly bloom log

    private var weeklyBloomLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("this week")
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(DinoTheme.textPrimary)
            HStack(spacing: 0) {
                ForEach(Array(viewModel.weeklyBlooms.enumerated()), id: \.offset) { index, day in
                    WeekDayColumn(label: day.dayLabel, practices: day.practices, appearDelay: Double(index) * 0.08)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: XP card (preserved from original)

    private var xpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.levelLabel)
                    .font(DinoTheme.titleFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text(viewModel.xpLabel)
                    .font(DinoTheme.numericFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color("#E8E4D5"))
                    RoundedRectangle(cornerRadius: 999)
                        .fill(LinearGradient(
                            colors: [Color("#A8C5A0"), Color("#A8D4E6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(12, geo.size.width * viewModel.xpProgress))
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

// MARK: - GardenPlotTile (single plant in 2x2 grid)

private struct GardenPlotTile: View {
    let plant: PlantState
    let appearDelay: Double

    @State private var swayPhase: Double = 0
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            PlantCanvas(
                species: plant.practice,
                growth: plant.growth,
                care: plant.care
            )
            .frame(width: 130, height: 160)
            .rotationEffect(
                plant.care >= 0.5
                    ? .degrees(sin(swayPhase) * 1.5)
                    : .degrees(max(0, (0.5 - plant.care)) * 12),
                anchor: .bottom
            )
            .scaleEffect(scale, anchor: .bottom)
            .opacity(opacity)

            Text(plant.practice.displayName)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(plant.practice.bloomColor)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                    scale = 1.0
                    opacity = 1.0
                }
                if plant.care >= 0.5 {
                    withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                        swayPhase = .pi
                    }
                }
            }
        }
    }
}

// MARK: - WeekDayColumn

private struct WeekDayColumn: View {
    let label: String
    let practices: Set<Practice>
    let appearDelay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(DinoTheme.textSecondary)
                .tracking(0.8)
            VStack(spacing: 3) {
                ForEach(Practice.allCases) { p in
                    Circle()
                        .fill(practices.contains(p) ? p.bloomColor : Color("#E8E4D5"))
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

// MARK: - PlantCanvas (procedural plant rendering)

struct PlantCanvas: View {
    let species: Practice
    let growth: Double
    let care: Double

    // Canvas coordinate system: 70 wide x 140 tall. Scaled to fit frame.

    var body: some View {
        GeometryReader { geo in
            let scaleX = geo.size.width / 70.0
            let scaleY = geo.size.height / 140.0
            let s = min(scaleX, scaleY)
            let offsetX = (geo.size.width - 70.0 * s) / 2
            let offsetY = (geo.size.height - 140.0 * s) / 2

            Canvas { context, _ in
                var ctx = context
                ctx.translateBy(x: offsetX, y: offsetY)
                ctx.scaleBy(x: s, y: s)
                drawPlant(context: &ctx)
            }
        }
    }

    private func drawPlant(context: inout GraphicsContext) {
        let g = max(0, min(1, growth))
        let c = max(0, min(1, care))

        // Phase progressions
        let sprout = smoothstep(g, 0.04, 0.18)
        let cotyP = smoothstep(g, 0.12, 0.28)
        let stemP = smoothstep(g, 0.22, 0.70)
        let trueLeafP = smoothstep(g, 0.32, 0.78)
        let budP = smoothstep(g, 0.55, 0.82)
        let bloomP = smoothstep(g, 0.78, 1.00)

        // Geometry
        let soilY: Double = 132
        let maxH: Double = 110
        let stemH = 4 + sprout * 10 + stemP * (maxH - 14)
        let stemTopY = soilY - stemH
        let wiltBend = (1 - c) * 14 * (species == .gratitude ? 0.7 : 1)
        let bendDir: Double = species == .journal ? -1 : 1
        let stemTipX = 35 + wiltBend * bendDir
        let ctrlX = 35 + (stemTipX - 35) * 0.45
        let ctrlY = soilY - stemH * 0.55
        let stemW = species == .gratitude ? 2.8 : species == .breathing ? 1.6 : 2.2

        let pal = palette(for: species)
        let leafColor = wiltColor(pal.leaf, care: c)
        let leafStroke = wiltColor(pal.leafDark, care: c)
        let flowerColor = wiltColor(pal.flower, care: max(0.2, c))
        let centerColor = wiltColor(pal.center, care: max(0.3, c))

        // --- Soil mound ---
        var soil = Path()
        soil.addEllipse(in: CGRect(x: 35 - 13, y: soilY + 2 - 3.2, width: 26, height: 6.4))
        context.fill(soil, with: .color(Color("#6B4A30").opacity(0.65)))

        // --- Seed phase (g < 0.25) ---
        if g < 0.25 {
            let seedOpacity = 1 - max(0, (g - 0.18) / 0.07)
            let seedRX = 6.5 - sprout * 2.0
            let seedRY = 4.5 - sprout * 1.0
            let seedCY = soilY - 1 + (1 - sprout) * 2
            var seed = Path()
            seed.addEllipse(in: CGRect(x: 35 - seedRX, y: seedCY - seedRY, width: seedRX * 2, height: seedRY * 2))
            context.fill(seed, with: .color(Color("#8B6B4A").opacity(seedOpacity)))
            context.stroke(seed, with: .color(Color("#5A4530").opacity(seedOpacity)), lineWidth: 1.3)

            // Seed crack
            if g > 0.04 && g < 0.2 {
                let crackOp = smoothstep(g, 0.04, 0.12)
                var crack = Path()
                crack.move(to: CGPoint(x: 32, y: soilY - 1))
                crack.addQuadCurve(to: CGPoint(x: 38, y: soilY - 1), control: CGPoint(x: 35, y: soilY - 4))
                context.stroke(crack, with: .color(Color("#3F2A1C").opacity(crackOp)), lineWidth: 0.8)
            }
        }

        // --- Stem ---
        if sprout > 0.05 {
            var stem = Path()
            stem.move(to: CGPoint(x: 35, y: soilY))
            stem.addQuadCurve(to: CGPoint(x: stemTipX, y: stemTopY), control: CGPoint(x: ctrlX, y: ctrlY))
            let stemGradient = Gradient(colors: [
                wiltColor(Color("#5A8A5C"), care: c),
                wiltColor(Color("#3F6B50"), care: c)
            ])
            context.stroke(
                stem,
                with: .linearGradient(
                    stemGradient,
                    startPoint: CGPoint(x: 35, y: stemTopY),
                    endPoint: CGPoint(x: 35, y: soilY)
                ),
                style: StrokeStyle(lineWidth: stemW * (0.6 + sprout * 0.4), lineCap: .round)
            )
        }

        // --- Cotyledons ---
        if cotyP > 0.05 {
            let cotyOp = max(0, 1 - trueLeafP * 0.9)
            let cy = soilY - 4 - sprout * 4
            drawEllipseRotated(
                context: &context,
                cx: 35 - 5 * cotyP, cy: cy,
                rx: 4 * cotyP, ry: 2.5 * cotyP,
                rotationDeg: -25 + (1 - c) * 20,
                fill: leafColor.opacity(cotyOp),
                stroke: leafStroke.opacity(cotyOp),
                strokeWidth: 0.8
            )
            drawEllipseRotated(
                context: &context,
                cx: 35 + 5 * cotyP, cy: cy,
                rx: 4 * cotyP, ry: 2.5 * cotyP,
                rotationDeg: 25 - (1 - c) * 20,
                fill: leafColor.opacity(cotyOp),
                stroke: leafStroke.opacity(cotyOp),
                strokeWidth: 0.8
            )
        }

        // --- True leaves (species-specific) ---
        if trueLeafP > 0.1 {
            drawTrueLeaves(
                context: &context,
                species: species, stemP: stemP, stemH: stemH,
                stemTipX: stemTipX, soilY: soilY, care: c,
                leafColor: leafColor, leafStroke: leafStroke
            )
        }

        // --- Bud phase ---
        if budP > 0.1 && bloomP < 0.9 {
            let budOp = max(0, 1 - bloomP)
            drawEllipseRotated(
                context: &context,
                cx: stemTipX, cy: stemTopY + 2,
                rx: 3 + budP * 2, ry: 5 + budP * 3,
                rotationDeg: 0,
                fill: wiltColor(pal.leaf, care: c).opacity(budOp),
                stroke: leafStroke.opacity(budOp),
                strokeWidth: 0.8
            )
            drawEllipseRotated(
                context: &context,
                cx: stemTipX, cy: stemTopY - 1,
                rx: 1.5 + budP, ry: 2 + budP,
                rotationDeg: 0,
                fill: wiltColor(pal.flower, care: c * 0.7).opacity(budP * budOp),
                stroke: leafStroke.opacity(budP * budOp),
                strokeWidth: 0.5
            )
        }

        // --- Bloom (species-specific) ---
        if bloomP > 0.1 {
            drawBloom(
                context: &context,
                species: species, bloomP: bloomP,
                stemTipX: stemTipX, stemTopY: stemTopY, care: c,
                flowerColor: flowerColor, centerColor: centerColor, pal: pal
            )
        }

        // --- Wilt: fallen leaves ---
        if c < 0.45 && trueLeafP > 0.5 {
            let fallenOp = (1 - c) * 0.9
            let fallenColor = wiltColor(Color("#6B4A30"), care: c).opacity(fallenOp)
            let strokeColor = Color("#3F2A1C").opacity(fallenOp)
            let positions: [(Double, Double, Double)] = [(14, 118, 40), (52, 122, -30), (22, 128, 10)]
            for (x, y, r) in positions {
                var leaf = Path()
                leaf.move(to: CGPoint(x: x, y: y))
                leaf.addQuadCurve(to: CGPoint(x: x - 6, y: y - 3), control: CGPoint(x: x - 3, y: y - 4))
                leaf.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3, y: y + 1))
                leaf.closeSubpath()
                let t = CGAffineTransform(translationX: -x, y: -y)
                    .concatenating(CGAffineTransform(rotationAngle: r * .pi / 180))
                    .concatenating(CGAffineTransform(translationX: x, y: y))
                let rotated = leaf.applying(t)
                context.fill(rotated, with: .color(fallenColor))
                context.stroke(rotated, with: .color(strokeColor), lineWidth: 0.5)
            }
        }

        // --- Withered stump ---
        if g > 0.3 && c < 0.08 {
            var stump = Path()
            stump.move(to: CGPoint(x: 35, y: soilY))
            stump.addLine(to: CGPoint(x: 38, y: soilY - 10))
            context.stroke(
                stump,
                with: .color(Color("#6B4A30").opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
    }

    // ----- Leaves per species -----

    private func drawTrueLeaves(
        context: inout GraphicsContext,
        species: Practice, stemP: Double, stemH: Double, stemTipX: Double, soilY: Double,
        care c: Double, leafColor: Color, leafStroke: Color
    ) {
        switch species {
        case .journal: // vine: 5 alternating leaves
            for i in 0..<5 {
                let leafT = Double(i + 1) / 5.0
                let show = smoothstep(stemP, leafT * 0.6, leafT * 0.6 + 0.25)
                if show < 0.02 { continue }
                let ty = soilY - stemH * leafT
                let tx = 35 + (stemTipX - 35) * (leafT * leafT)
                let side: Double = i % 2 == 0 ? -1 : 1
                drawLeafShape(
                    context: &context,
                    base: CGPoint(x: tx, y: ty),
                    angle: side * (40 + (1 - c) * 30),
                    length: 9 + show * 6,
                    curl: 0.3,
                    care: c,
                    fill: leafColor.opacity(show),
                    stroke: leafStroke.opacity(show)
                )
            }
        case .mood: // daisy: 3 leaves curl=0.25
            for i in 0..<3 {
                let leafT = 0.2 + Double(i) * 0.25
                let show = smoothstep(stemP, leafT + 0.1, leafT + 0.35)
                if show < 0.02 { continue }
                let ty = soilY - stemH * leafT
                let tx = 35 + (stemTipX - 35) * leafT * leafT
                let side: Double = i % 2 == 0 ? -1 : 1
                drawLeafShape(
                    context: &context,
                    base: CGPoint(x: tx, y: ty),
                    angle: side * (55 + (1 - c) * 25),
                    length: 8 + show * 4,
                    curl: 0.25,
                    care: c,
                    fill: leafColor.opacity(show),
                    stroke: leafStroke.opacity(show)
                )
            }
        case .gratitude: // sunflower: 3 leaves curl=0.45
            for i in 0..<3 {
                let leafT = 0.25 + Double(i) * 0.22
                let show = smoothstep(stemP, leafT + 0.05, leafT + 0.3)
                if show < 0.02 { continue }
                let ty = soilY - stemH * leafT
                let tx = 35 + (stemTipX - 35) * leafT * leafT
                let side: Double = i % 2 == 0 ? -1 : 1
                drawLeafShape(
                    context: &context,
                    base: CGPoint(x: tx, y: ty),
                    angle: side * (35 + (1 - c) * 30),
                    length: 10 + show * 6,
                    curl: 0.45,
                    care: c,
                    fill: leafColor.opacity(show),
                    stroke: leafStroke.opacity(show)
                )
            }
        case .breathing: // lavender: paired narrow leaves curl=0.15
            for i in 0..<2 {
                let leafT = 0.2 + Double(i) * 0.2
                let show = smoothstep(stemP, leafT + 0.05, leafT + 0.3)
                if show < 0.02 { continue }
                let ty = soilY - stemH * leafT
                let tx = 35 + (stemTipX - 35) * leafT * leafT
                drawLeafShape(
                    context: &context,
                    base: CGPoint(x: tx - 2, y: ty),
                    angle: -70 + (1 - c) * 30,
                    length: 7 + show * 3, curl: 0.15, care: c,
                    fill: leafColor.opacity(show), stroke: leafStroke.opacity(show)
                )
                drawLeafShape(
                    context: &context,
                    base: CGPoint(x: tx + 2, y: ty),
                    angle: -110 - (1 - c) * 30,
                    length: 7 + show * 3, curl: 0.15, care: c,
                    fill: leafColor.opacity(show), stroke: leafStroke.opacity(show)
                )
            }
        }
    }

    // ----- Bloom per species -----

    private func drawBloom(
        context: inout GraphicsContext,
        species: Practice, bloomP: Double, stemTipX: Double, stemTopY: Double,
        care c: Double, flowerColor: Color, centerColor: Color,
        pal: SpeciesPalette
    ) {
        switch species {
        case .journal: // vine: small circle + secondary bud
            var main = Path()
            let r1 = 4 * bloomP * (0.7 + c * 0.3)
            main.addEllipse(in: CGRect(x: stemTipX - r1, y: stemTopY - 2 - r1, width: r1 * 2, height: r1 * 2))
            context.fill(main, with: .color(flowerColor.opacity(bloomP)))
            context.stroke(main, with: .color(centerColor.opacity(bloomP)), lineWidth: 1)
            if bloomP > 0.4 {
                var bud = Path()
                let r2 = 2.5 * bloomP
                bud.addEllipse(in: CGRect(x: stemTipX - 6 - r2, y: stemTopY + 10 - r2, width: r2 * 2, height: r2 * 2))
                context.fill(bud, with: .color(flowerColor.opacity(0.8 * bloomP)))
                context.stroke(bud, with: .color(centerColor.opacity(0.8 * bloomP)), lineWidth: 0.8)
            }
        case .mood: // daisy: 8 petals + center + fallen petals
            let petalStrokeColor = pal.petalStroke ?? Color("#B06B8A")
            let angles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
            let cx = stemTipX
            let cy = stemTopY - 4
            for a in angles {
                let ar = a * .pi / 180
                let wilt = (1 - c) * (0.4 + 0.4 * sin(ar))
                let px = cos(ar) * 8 * bloomP
                let py = sin(ar) * 8 * bloomP + wilt * 6
                let rx = 6 * bloomP * (0.7 + c * 0.3)
                let ry = 3.5 * bloomP
                drawEllipseRotated(
                    context: &context,
                    cx: cx + px, cy: cy + py,
                    rx: rx, ry: ry,
                    rotationDeg: a,
                    fill: flowerColor.opacity(bloomP * (0.4 + c * 0.6)),
                    stroke: petalStrokeColor.opacity(bloomP * (0.4 + c * 0.6)),
                    strokeWidth: 0.8
                )
            }
            var center = Path()
            let cr = 4 * bloomP
            center.addEllipse(in: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2))
            context.fill(center, with: .color(centerColor.opacity(bloomP)))
            context.stroke(center, with: .color(Color("#D4A55A").opacity(bloomP)), lineWidth: 0.8)
            // Fallen petals
            if c < 0.5 && bloomP > 0.5 {
                let fallenOp = (1 - c) * 0.7
                let fallen: [(Double, Double, Double)] = [(-14, 14, 30), (12, 18, -20), (-8, 22, 60)]
                for (dx, dy, r) in fallen {
                    drawEllipseRotated(
                        context: &context,
                        cx: cx + dx, cy: cy + dy,
                        rx: 5, ry: 3, rotationDeg: r,
                        fill: flowerColor.opacity(fallenOp),
                        stroke: petalStrokeColor.opacity(fallenOp),
                        strokeWidth: 0.6
                    )
                }
            }
        case .gratitude: // sunflower: 12 petals with head droop + seed dots
            let petalStrokeColor = pal.petalStroke ?? Color("#C99520")
            let cx = stemTipX
            let cy = stemTopY - 2
            let headDroop = (1 - c) * 55 * .pi / 180
            let angles: [Double] = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]
            for a in angles {
                let ar = a * .pi / 180
                let baseX = cos(ar) * 11 * bloomP
                let baseY = sin(ar) * 11 * bloomP
                // Apply head-droop rotation around (0,0) then translate
                let rotX = baseX * cos(headDroop) - baseY * sin(headDroop)
                let rotY = baseX * sin(headDroop) + baseY * cos(headDroop)
                let rx = 6 * bloomP * (0.6 + c * 0.4)
                let ry = 3.5 * bloomP
                drawEllipseRotated(
                    context: &context,
                    cx: cx + rotX, cy: cy + rotY,
                    rx: rx, ry: ry,
                    rotationDeg: a + (1 - c) * 55,
                    fill: flowerColor.opacity(bloomP * (0.3 + c * 0.7)),
                    stroke: petalStrokeColor.opacity(bloomP * (0.3 + c * 0.7)),
                    strokeWidth: 0.8
                )
            }
            var center = Path()
            let cr = 6.5 * bloomP
            center.addEllipse(in: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2))
            context.fill(center, with: .color(centerColor.opacity(bloomP)))
            context.stroke(center, with: .color(Color("#3F2A1C").opacity(bloomP)), lineWidth: 1)
            if bloomP > 0.6 {
                let dotAngles: [Double] = [0, 60, 120, 180, 240, 300]
                for a in dotAngles {
                    let ar = a * .pi / 180
                    let dx = cos(ar) * 3
                    let dy = sin(ar) * 3
                    var dot = Path()
                    dot.addEllipse(in: CGRect(x: cx + dx - 0.6, y: cy + dy - 0.6, width: 1.2, height: 1.2))
                    context.fill(dot, with: .color(Color("#3F2A1C").opacity(0.5 * bloomP)))
                }
            }
        case .breathing: // lavender: 5 ascending floret pairs + fallen florets
            for i in 0..<5 {
                let t = Double(i) / 5.0
                let show = smoothstep(bloomP, t * 0.4, t * 0.4 + 0.4)
                if show < 0.02 { continue }
                let sy = stemTopY + 6 - Double(i) * 5
                let sx = stemTipX + (1 - c) * Double(i) * 1.2
                var left = Path()
                left.addEllipse(in: CGRect(x: sx - 2.5 - 2.3, y: sy - 3.5, width: 4.6, height: 7))
                context.fill(left, with: .color(flowerColor.opacity(show)))
                context.stroke(left, with: .color(centerColor.opacity(show)), lineWidth: 0.7)
                var right = Path()
                right.addEllipse(in: CGRect(x: sx + 2.5 - 2.3, y: sy - 3.5, width: 4.6, height: 7))
                context.fill(right, with: .color(flowerColor.opacity(show)))
                context.stroke(right, with: .color(centerColor.opacity(show)), lineWidth: 0.7)
            }
            if c < 0.4 {
                let fallenOp = (1 - c) * 0.8
                let fallen: [(Double, Double)] = [(-12, 30), (10, 40), (-4, 34)]
                for (dx, dy) in fallen {
                    var f = Path()
                    f.addEllipse(in: CGRect(x: stemTipX + dx - 2, y: stemTopY + dy - 3, width: 4, height: 6))
                    context.fill(f, with: .color(flowerColor.opacity(fallenOp)))
                    context.stroke(f, with: .color(centerColor.opacity(fallenOp)), lineWidth: 0.5)
                }
            }
        }
    }

    // ----- Shared drawing helpers -----

    private func drawLeafShape(
        context: inout GraphicsContext,
        base: CGPoint, angle: Double, length: Double, curl: Double, care c: Double,
        fill: Color, stroke: Color
    ) {
        let droop = (1 - c) * 35 * (angle >= 0 ? 1 : -1)
        let a = angle + droop
        let rad = a * .pi / 180
        let tip = CGPoint(x: base.x + cos(rad) * length, y: base.y + sin(rad) * length)
        let perpX = -sin(rad); let perpY = cos(rad)
        let mid = CGPoint(x: base.x + cos(rad) * length * 0.5, y: base.y + sin(rad) * length * 0.5)
        let c1 = CGPoint(x: mid.x + perpX * length * curl, y: mid.y + perpY * length * curl)
        let c2 = CGPoint(x: mid.x - perpX * length * curl, y: mid.y - perpY * length * curl)
        var leaf = Path()
        leaf.move(to: base)
        leaf.addQuadCurve(to: tip, control: c1)
        leaf.addQuadCurve(to: base, control: c2)
        leaf.closeSubpath()
        context.fill(leaf, with: .color(fill))
        context.stroke(leaf, with: .color(stroke), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
    }

    private func drawEllipseRotated(
        context: inout GraphicsContext,
        cx: Double, cy: Double, rx: Double, ry: Double, rotationDeg: Double,
        fill: Color, stroke: Color, strokeWidth: Double
    ) {
        var path = Path()
        path.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        let t = CGAffineTransform(rotationAngle: rotationDeg * .pi / 180)
            .concatenating(CGAffineTransform(translationX: cx, y: cy))
        let transformed = path.applying(t)
        context.fill(transformed, with: .color(fill))
        if strokeWidth > 0 {
            context.stroke(transformed, with: .color(stroke), lineWidth: strokeWidth)
        }
    }

    // ----- Math helpers -----

    private func smoothstep(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = max(0, min(1, (t - a) / (b - a)))
        return x * x * (3 - 2 * x)
    }

    private func wiltColor(_ healthy: Color, care: Double) -> Color {
        guard let rgb = healthy.rgbComponents() else { return healthy }
        let (r1, g1, b1) = rgb
        let r2: Double = 156.0 / 255.0
        let g2: Double = 124.0 / 255.0
        let b2: Double = 80.0 / 255.0
        let t = 1 - care
        return Color(
            red: r1 * (1 - t) + r2 * t,
            green: g1 * (1 - t) + g2 * t,
            blue: b1 * (1 - t) + b2 * t
        )
    }

    // ----- Palette -----

    private struct SpeciesPalette {
        let leaf: Color
        let leafDark: Color
        let flower: Color
        let center: Color
        let petalStroke: Color?
    }

    private func palette(for species: Practice) -> SpeciesPalette {
        switch species {
        case .journal:
            return SpeciesPalette(
                leaf: Color("#6BAA7C"), leafDark: Color("#3F6B50"),
                flower: Color("#F5D28A"), center: Color("#D4A55A"),
                petalStroke: nil
            )
        case .mood:
            return SpeciesPalette(
                leaf: Color("#7BBC8C"), leafDark: Color("#3F6B50"),
                flower: Color("#E8B4B8"), center: Color("#F5D28A"),
                petalStroke: Color("#B06B8A")
            )
        case .gratitude:
            return SpeciesPalette(
                leaf: Color("#8BC8A0"), leafDark: Color("#3F6B50"),
                flower: Color("#F5C84F"), center: Color("#8B5A2B"),
                petalStroke: Color("#C99520")
            )
        case .breathing:
            return SpeciesPalette(
                leaf: Color("#7BBC8C"), leafDark: Color("#3F6B50"),
                flower: Color("#B4A4C8"), center: Color("#7B6BA0"),
                petalStroke: nil
            )
        }
    }
}

// MARK: - Color RGB helper

private extension Color {
    /// Returns (r, g, b) in 0..1, or nil if not resolvable.
    func rgbComponents() -> (Double, Double, Double)? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (Double(r), Double(g), Double(b))
        #else
        return nil
        #endif
    }
}

// MARK: - PlantDetailSheet

private struct PlantDetailSheet: View {
    let plant: PlantState
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PlantCanvas(species: plant.practice, growth: plant.growth, care: plant.care)
                        .frame(width: 220, height: 280)
                        .padding(.top, 12)

                    Text(plant.practice.displayName)
                        .font(DinoTheme.dinoFont(size: 20))
                        .foregroundColor(plant.practice.bloomColor)

                    HStack(spacing: 6) {
                        Text("\(plant.totalSessions)")
                            .font(DinoTheme.numericFont(size: 16))
                            .foregroundColor(DinoTheme.textPrimary)
                        Text("sessions")
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(DinoTheme.textSecondary)
                        Text("·")
                            .foregroundColor(DinoTheme.textSecondary)
                        Text("\(plant.currentStreak)")
                            .font(DinoTheme.numericFont(size: 16))
                            .foregroundColor(DinoTheme.textPrimary)
                        Text("day streak")
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(DinoTheme.textSecondary)
                    }

                    // Status pill
                    if plant.totalSessions > 0 {
                        Text(plant.careStatus.label)
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(plant.careStatus.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(plant.careStatus.color.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    // Italic note
                    Text("\"\(noteText)\"")
                        .font(.system(size: 14, weight: .regular, design: .default).italic())
                        .foregroundColor(DinoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Go practice button
                    goPracticeButton
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color("#FDF8F0").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var noteText: String {
        if plant.totalSessions == 0 {
            return "a seed waiting to be watered"
        }
        return plant.careStatus.note
    }

    @ViewBuilder
    private var goPracticeButton: some View {
        if let tab = plant.practice.deepLinkTab {
            Button {
                dataManager.deepLinkTab = tab
                dismiss()
                // Re-assert tab after sheet dismissal finishes animating.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    dataManager.deepLinkTab = tab
                }
            } label: {
                goButtonLabel
            }
        } else {
            // Breathing: push via NavigationLink
            NavigationLink {
                BreathingView().environmentObject(dataManager)
            } label: {
                goButtonLabel
            }
        }
    }

    private var goButtonLabel: some View {
        Text("go practice")
            .font(DinoTheme.dinoFont(size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color("#A8C5A0"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color("#A8C5A0").opacity(0.4), radius: 12, x: 0, y: 4)
    }
}
