//
//  RhythmsHelixView.swift
//  Dino
//
//  The emotional-DNA helix — a 3D field of glowing fireflies (one per day,
//  colored by that day's mood) that morphs between four formations:
//  strand (double helix) · wave (mood over time) · tree (growth) · heart.
//  Math ported from the design system's rhythms/helix.js. Fireflies are
//  round emissive spheres + additive radial-gradient halos (never square);
//  ghost fireflies stand in for "tomorrow, still forming". Self-contained
//  (no dependency on the Ambient3D layer, which isn't on this branch).
//

import SwiftUI
import SceneKit

// MARK: - Shapes

enum HelixShape: String, CaseIterable, Identifiable {
    case helix, wave, tree, heart
    var id: String { rawValue }
    var label: String {
        switch self {
        case .helix: return "strand"
        case .wave:  return "wave"
        case .tree:  return "tree"
        case .heart: return "heart"
        }
    }
}

// MARK: - Mood palette (design helix.js — 5 moods; app weather maps onto it)

enum HelixMood {
    case hard, tender, growing, steady, breakthrough

    var hex: UInt32 {
        switch self {
        case .hard:         return 0xE8889A
        case .tender:       return 0xF5C6AA
        case .growing:      return 0xC4B8D4
        case .steady:       return 0x7BA872
        case .breakthrough: return 0xFFE066
        }
    }
    var valence: Double {
        switch self {
        case .hard: return 0.08
        case .tender: return 0.40
        case .growing: return 0.58
        case .steady: return 0.66
        case .breakthrough: return 0.98
        }
    }
    /// Base mapping (a rare gold "breakthrough" is decided by the adapter
    /// using energy/intensity — not here).
    static func from(_ w: EmotionalWeather) -> HelixMood {
        switch w {
        case .clear:        return .steady    // sage — the normal good day
        case .partlyCloudy: return .growing   // lavender — a mixed, in-between day
        case .overwhelmed:  return .hard      // rose
        case .drained:      return .hard      // rose
        }
    }
}

private let helixGhostHex: UInt32 = 0xEAF0E8
private let helixGhostValence: Double = 0.6

private func helixColor(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// MARK: - SwiftUI entry (manages active lifecycle)

struct RhythmsHelix: View {
    let moods: [HelixMood]          // oldest → newest, one per day
    let ghostCount: Int
    let shape: HelixShape
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isActive = false

    var body: some View {
        HelixRepresentable(moods: moods, ghostCount: ghostCount, shape: shape,
                           reduceMotion: reduceMotion, isActive: isActive)
            .onAppear { isActive = true }
            .onDisappear { isActive = false }
    }
}

// MARK: - UIViewRepresentable

private struct HelixRepresentable: UIViewRepresentable {
    let moods: [HelixMood]
    let ghostCount: Int
    let shape: HelixShape
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> HelixCoordinator {
        HelixCoordinator(moods: moods, ghostCount: ghostCount, reduceMotion: reduceMotion)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let coord = context.coordinator
        view.scene = coord.scene
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = true
        view.delegate = coord
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        coord.apply(shape: shape, animated: false)
        view.isPlaying = isActive && !reduceMotion
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coord = context.coordinator
        coord.apply(shape: shape, animated: true)
        view.isPlaying = isActive && !reduceMotion
    }

    static func dismantleUIView(_ view: SCNView, coordinator: HelixCoordinator) {
        view.isPlaying = false
    }
}

// MARK: - Coordinator (builds + drives the scene)

final class HelixCoordinator: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    private let container = SCNNode()
    private var rungs: SCNNode?
    private var waveLine: SCNNode?
    private var sweepBand: SCNNode?
    private var waveProfile: [(x: Double, y: Float)] = []   // real-day (nx, worldY), ascending
    private var realCount: Int = 0
    private let reduceMotion: Bool

    private struct Firefly {
        let node: SCNNode
        let swell: SCNNode      // sweep scales this; pulse scales `node` — they compose
        let valence: Double
        let ghost: Bool
        let waveNX: Double      // normalized x in the wave timeline
    }
    private var fireflies: [Firefly] = []
    private var currentShape: HelixShape?

    // World mapping (normalized 0...1 → world).
    private let wSpan: Float = 5.0
    private let hSpan: Float = 8.5    // taller strand → more space between levels
    private let zDepth: Float = 1.3
    private let tau = Double.pi * 2

    init(moods: [HelixMood], ghostCount: Int, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init()
        scene.background.contents = HelixCoordinator.backgroundImage()
        scene.rootNode.addChildNode(container)
        buildCamera()
        buildFireflies(moods: moods, ghostCount: ghostCount)
        buildRungs()
        buildWaveLine()
        buildSweepBand()
    }

    // MARK: Build

    private func buildCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 46
        cam.zNear = 0.1
        cam.zFar = 100
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 0, 10)   // pulled back to fit the taller strand
        scene.rootNode.addChildNode(node)
    }

    private func buildFireflies(moods: [HelixMood], ghostCount: Int) {
        realCount = moods.count
        let halo = HelixCoordinator.haloImage()
        var specs: [(hex: UInt32, valence: Double, ghost: Bool)] = moods.map {
            ($0.hex, $0.valence, false)
        }
        for _ in 0..<max(0, ghostCount) {
            specs.append((helixGhostHex, helixGhostValence, true))
        }
        let n = specs.count

        for (i, spec) in specs.enumerated() {
            let color = helixColor(spec.hex)
            let group = SCNNode()
            let swell = SCNNode()        // sweep-driven swell, between group and visuals
            group.addChildNode(swell)

            // Core sphere — bright, emissive (whitened toward center).
            let coreGeo = SCNSphere(radius: 0.045)
            coreGeo.segmentCount = 8
            let coreMat = SCNMaterial()
            let bright = UIColor(red: min(1, color.rgbaComponents.r + 0.45),
                                 green: min(1, color.rgbaComponents.g + 0.45),
                                 blue: min(1, color.rgbaComponents.b + 0.35), alpha: 1)
            coreMat.diffuse.contents = bright
            coreMat.emission.contents = color
            coreMat.lightingModel = .constant
            coreGeo.firstMaterial = coreMat
            let core = SCNNode(geometry: coreGeo)
            core.castsShadow = false
            swell.addChildNode(core)

            // Additive radial halo (round — billboarded). Kept small so each
            // day reads as a distinct point and the double strand stays legible.
            let haloGeo = SCNPlane(width: spec.ghost ? 0.30 : 0.38, height: spec.ghost ? 0.30 : 0.38)
            let haloMat = SCNMaterial()
            haloMat.diffuse.contents = halo
            haloMat.multiply.contents = color
            haloMat.lightingModel = .constant
            haloMat.blendMode = .add
            haloMat.isDoubleSided = true
            haloMat.writesToDepthBuffer = false
            haloGeo.firstMaterial = haloMat
            let haloNode = SCNNode(geometry: haloGeo)
            let bb = SCNBillboardConstraint()
            bb.freeAxes = .all
            haloNode.constraints = [bb]
            haloNode.castsShadow = false
            swell.addChildNode(haloNode)

            group.opacity = spec.ghost ? 0.42 : 1.0
            group.position = world(normalizedTarget(i: i, n: n, shape: .helix, valence: spec.valence, ghost: spec.ghost))
            container.addChildNode(group)
            let waveNX = 0.07 + (spec.ghost ? 0.86
                                            : (Double(i) / Double(max(1, realCount - 1))) * 0.86)
            fireflies.append(Firefly(node: group, swell: swell, valence: spec.valence,
                                     ghost: spec.ghost, waveNX: waveNX))

            // Per-firefly pulse (own phase), unless reduce-motion.
            if !reduceMotion {
                let phase = Double(i) * 0.7
                let pSpeed = 0.018 + Double(i % 5) * 0.004
                let period = tau / (pSpeed * 60.0)            // seconds per pulse cycle
                let up = SCNAction.scale(to: spec.ghost ? 1.0 : 1.18, duration: period / 2)
                up.timingMode = .easeInEaseOut
                let down = SCNAction.scale(to: 0.84, duration: period / 2)
                down.timingMode = .easeInEaseOut
                let startDelay = (phase.truncatingRemainder(dividingBy: tau) / tau) * period
                group.runAction(.sequence([.wait(duration: startDelay),
                                           .repeatForever(.sequence([up, down]))]), forKey: "pulse")
            }
        }
    }

    /// One line segment per helix level, connecting the two strands.
    private func buildRungs() {
        let n = fireflies.count
        guard n >= 2 else { return }
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        let levels = Int(ceil(Double(n) / 2))
        for L in 0..<levels {
            let a = L * 2, b = L * 2 + 1
            guard b < n else { continue }
            vertices.append(world(normalizedTarget(i: a, n: n, shape: .helix,
                                                   valence: fireflies[a].valence, ghost: fireflies[a].ghost)))
            vertices.append(world(normalizedTarget(i: b, n: n, shape: .helix,
                                                   valence: fireflies[b].valence, ghost: fireflies[b].ghost)))
            indices.append(Int32(vertices.count - 2))
            indices.append(Int32(vertices.count - 1))
        }
        guard !vertices.isEmpty else { return }
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .line)]
        )
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.71, green: 0.78, blue: 0.71, alpha: 1)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        geo.firstMaterial = m
        let node = SCNNode(geometry: geo)
        node.opacity = 0.14
        node.castsShadow = false
        container.addChildNode(node)
        rungs = node
    }

    /// A soft low-opacity line threading the real days in time order — the
    /// wave "ribbon" (shown only in the wave formation).
    private func buildWaveLine() {
        let realIdx = fireflies.enumerated().filter { !$0.element.ghost }.map { $0.offset }
        guard realIdx.count >= 2 else { return }
        let n = fireflies.count
        var vertices: [SCNVector3] = []
        waveProfile.removeAll(keepingCapacity: true)
        for i in realIdx {
            let p = world(normalizedTarget(i: i, n: n, shape: .wave,
                                           valence: fireflies[i].valence, ghost: false))
            vertices.append(p)
            waveProfile.append((fireflies[i].waveNX, p.y))
        }
        var indices: [Int32] = []
        for k in 0..<(vertices.count - 1) {
            indices.append(Int32(k)); indices.append(Int32(k + 1))
        }
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .line)]
        )
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.80, green: 0.84, blue: 0.78, alpha: 1)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        geo.firstMaterial = m
        let node = SCNNode(geometry: geo)
        node.opacity = 0          // shown only in the wave
        node.castsShadow = false
        container.addChildNode(node)
        waveLine = node
    }

    /// Soft warm radial glow that rides along the ribbon at the sweep position
    /// (feathered, billboarded — not a full-height column).
    private func buildSweepBand() {
        let geo = SCNPlane(width: 2.0, height: 2.0)
        let m = SCNMaterial()
        m.diffuse.contents = HelixCoordinator.haloImage()                       // soft radial, feathered
        m.multiply.contents = UIColor(red: 1.0, green: 0.84, blue: 0.58, alpha: 1)  // warm
        m.lightingModel = .constant
        m.blendMode = .add
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        geo.firstMaterial = m
        let node = SCNNode(geometry: geo)
        let bb = SCNBillboardConstraint(); bb.freeAxes = .all
        node.constraints = [bb]
        node.position = SCNVector3(0, 0, 0.02)
        node.opacity = 0
        node.castsShadow = false
        container.addChildNode(node)
        sweepBand = node
    }

    /// Wave ribbon height (world Y) at a normalized x — linear-interpolated
    /// between the surrounding real days so the glow follows the line.
    private func waveWorldY(atNX nx: Double) -> Float {
        guard let first = waveProfile.first, let last = waveProfile.last else { return 0 }
        if nx <= first.x { return first.y }
        if nx >= last.x { return last.y }
        for k in 1..<waveProfile.count {
            let a = waveProfile[k - 1], b = waveProfile[k]
            if nx <= b.x {
                let t = (nx - a.x) / max(1e-6, b.x - a.x)
                return a.y + Float(t) * (b.y - a.y)
            }
        }
        return last.y
    }

    // MARK: Apply a formation

    func apply(shape: HelixShape, animated: Bool) {
        guard shape != currentShape else { return }
        currentShape = shape
        let n = fireflies.count
        let animate = animated && !reduceMotion

        for (i, f) in fireflies.enumerated() {
            let target = world(normalizedTarget(i: i, n: n, shape: shape, valence: f.valence, ghost: f.ghost))
            f.node.removeAction(forKey: "move")
            if animate {
                let move = SCNAction.move(to: target, duration: 0.85)
                move.timingMode = .easeInEaseOut
                let delay = Double(i) * 0.006
                f.node.runAction(.sequence([.wait(duration: delay), move]), forKey: "move")
            } else {
                f.node.position = target
            }
        }

        // Rungs in helix; wave line + sweep band only in the wave; ghosts hide
        // in the wave so the timeline is purely real days across the full width.
        let isWave = (shape == .wave)
        let rungTarget: CGFloat = (shape == .helix) ? 0.14 : 0.0
        let lineTarget: CGFloat = isWave ? 0.16 : 0.0
        let bandTarget: CGFloat = (isWave && !reduceMotion) ? 0.22 : 0.0
        let setOpacities = {
            self.rungs?.opacity = rungTarget
            self.waveLine?.opacity = lineTarget
            self.sweepBand?.opacity = bandTarget
            for f in self.fireflies where f.ghost {
                f.node.opacity = isWave ? 0.0 : 0.42
            }
        }
        if animate {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.5
            setOpacities()
            SCNTransaction.commit()
        } else {
            setOpacities()
        }
        // The sweep drives swell during the wave; reset it everywhere else.
        if !isWave {
            for f in fireflies { f.swell.scale = SCNVector3(1, 1, 1) }
        }

        // Continuous spin only in the helix. Hard-reset the container's
        // rotation to identity FIRST on every change — otherwise the helix's
        // leftover Y-spin views the flat formations (wave/tree/heart) edge-on,
        // collapsing their x (time) spread into mood-stacked bands. rotateBy
        // accumulates on the node, so a snap (masked by the position morph) is
        // the reliable reset.
        container.removeAction(forKey: "spin")
        container.eulerAngles = SCNVector3Zero
        if shape == .helix && !reduceMotion {
            container.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)),
                                forKey: "spin")
        }
    }

    // MARK: Sweep (wave only)

    /// A calm warm light travels left→right across the wave, lifting each
    /// firefly's glow + scale by distance from the sweep, then loops back.
    /// Driven per render frame. No sweep under reduce-motion.
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard !reduceMotion, currentShape == .wave else { return }
        let period = 7.0                                     // seconds per pass — slow, calm
        let phase = time.truncatingRemainder(dividingBy: period) / period
        let sweepNX = 0.07 + phase * 0.86
        let sigma = 0.075
        let twoSigmaSq = 2 * sigma * sigma
        for f in fireflies where !f.ghost {
            let d = f.waveNX - sweepNX
            let lift = exp(-(d * d) / twoSigmaSq)            // 1 at the sweep, easing to 0
            let s = Float(1.0 + lift * 0.85)                // brighten + swell as it passes
            f.swell.scale = SCNVector3(s, s, s)
        }
        // Glow rides the ribbon: x = sweep position, y = ribbon height there.
        sweepBand?.position = SCNVector3(Float(sweepNX - 0.5) * wSpan,
                                        waveWorldY(atNX: sweepNX), 0.02)
    }

    // MARK: Target math (ported from helix.js _target, rot folded into spin)

    private func normalizedTarget(i: Int, n: Int, shape: HelixShape,
                                  valence: Double, ghost: Bool) -> (Double, Double, Double) {
        switch shape {
        case .wave:
            // x = real-day index across the FULL width (ghosts tuck to the
            // right edge and are hidden in the wave); y = mood height.
            let frac = ghost ? 1.0 : Double(i) / Double(max(1, realCount - 1))
            let nx = 0.07 + min(1.0, frac) * 0.86
            let v = ghost ? 0.6 : valence
            return (nx, 0.84 - v * 0.62, 0)
        case .tree:
            let trunk = Int((Double(n) * 0.16).rounded())
            if i < max(1, trunk) {
                return (0.5 + sin(Double(i) * 0.9) * 0.018, 0.95 - (Double(i) / Double(max(1, trunk))) * 0.30, 0)
            }
            let k = i - trunk, m = n - trunk
            let rr = 0.34 * (m > 0 ? sqrt(Double(k) / Double(m)) : 0)
            let a = Double(k) * 2.399963
            return (0.5 + cos(a) * rr, 0.46 - sin(a) * rr * 0.9, 0)
        case .heart:
            let t = (Double(i) / Double(max(1, n))) * tau
            let hx = 16 * pow(sin(t), 3)
            let hy = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            let shrink = (i % 2 != 0) ? 0.62 : 1.0
            return (0.5 + (hx / 38) * shrink, 0.46 - (hy / 38) * shrink, 0)
        case .helix:
            let level = i / 2, strand = i % 2
            let totalLevels = Int(ceil(Double(n) / 2))
            let angle = Double(level) * 0.52 + (strand != 0 ? Double.pi : 0)
            let ny = 0.93 - (Double(level) / Double(max(1, totalLevels - 1))) * 0.86
            return (0.5 + sin(angle) * 0.245, ny, cos(angle))
        }
    }

    private func world(_ t: (Double, Double, Double)) -> SCNVector3 {
        SCNVector3(Float(t.0 - 0.5) * wSpan, Float(0.5 - t.1) * hSpan, Float(t.2) * zDepth)
    }

    // MARK: Generated textures

    private static func haloImage() -> UIImage {
        let size = CGSize(width: 48, height: 48)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0.45).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 0.35, 1]) else { return }
            let c = CGPoint(x: 24, y: 24)
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }
    }

    private static func backgroundImage() -> UIImage {
        let size = CGSize(width: 8, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 0.11, green: 0.15, blue: 0.26, alpha: 1).cgColor,   // #1C2742
                          UIColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1).cgColor,   // #1A2238
                          UIColor(red: 0.063, green: 0.082, blue: 0.141, alpha: 1).cgColor] as CFArray // #101524
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 0.55, 1]) else { return }
            ctx.cgContext.drawLinearGradient(g, start: CGPoint(x: 0, y: 0),
                                             end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
}

// MARK: - UIColor component helper

private extension UIColor {
    var rgbaComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

// MARK: - Previews

#if DEBUG
/// 60 days of VARIED moods that genuinely rise and fall — no long same-mood
/// runs — so the wave reads as a clear ribbon and tree/heart fill out. Built
/// from two overlaid sine waves plus per-day jitter, banded into the 5 moods;
/// gold (breakthrough) only lands on the rare top peaks.
let helixPreviewMoods: [HelixMood] = (0..<60).map { i in
    let t = Double(i)
    let raw = sin(t * 0.28) * 0.6 + sin(t * 0.11 + 0.7) * 0.4        // ~ -1 ... 1
    let jitter = [0.0, 0.18, -0.16, 0.10, -0.22, 0.07][i % 6]
    let norm = min(1, max(0, (raw + 1) / 2 + jitter))               // 0 ... 1
    if norm > 0.93 { return .breakthrough }                          // rare peak
    if norm > 0.66 { return .steady }
    if norm > 0.44 { return .growing }
    if norm > 0.22 { return .tender }
    return .hard
}

private struct HelixPreviewCard: View {
    let title: String
    let shape: HelixShape
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
            RhythmsHelix(moods: helixPreviewMoods, ghostCount: 10, shape: shape)
                .frame(height: 230)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("helix — wave (ribbon)") {
    HelixPreviewCard(title: "wave", shape: .wave).padding().background(Color.black)
}

#Preview("helix — strand") {
    HelixPreviewCard(title: "strand", shape: .helix).padding().background(Color.black)
}

#Preview("helix — tree") {
    HelixPreviewCard(title: "tree", shape: .tree).padding().background(Color.black)
}

#Preview("helix — heart") {
    HelixPreviewCard(title: "heart", shape: .heart).padding().background(Color.black)
}

#Preview("helix — all four") {
    ScrollView {
        VStack(spacing: 14) {
            HelixPreviewCard(title: "strand", shape: .helix)
            HelixPreviewCard(title: "wave",   shape: .wave)
            HelixPreviewCard(title: "tree",   shape: .tree)
            HelixPreviewCard(title: "heart",  shape: .heart)
        }
        .padding()
    }
    .background(Color.black)
}
#endif
