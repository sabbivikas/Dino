//
//  WorldGlobeScene.swift
//  Dino
//
//  The DINO WORLD planet — a real textured earth with presence. The bundled
//  NASA land_ocean_ice map is warmed toward the dino palette (pure per-pixel
//  treatment in WorldEarthToning), lit by a fixed directional sun so the
//  terminator falls out of the lighting itself, and wrapped in a fresnel
//  atmosphere rim whose glow carries today's collective mood tint
//  (WorldMoodTint: snap when one mood clearly leads, blend when close).
//  Mood fireflies, weather particles, and find-my-light ride the planet, plus
//  a LOCAL ECHO firefly so the world is never empty for someone who just
//  logged. One sphere draw + one rim draw; sprite caps unchanged.
//

import Foundation
import SceneKit
import UIKit
import simd

@MainActor
final class WorldGlobeScene {
    let scene = SCNScene()
    let globeNode = SCNNode()          // rotates; fireflies + weather ride along
    private let fireflyContainer = SCNNode()
    private let weatherContainer = SCNNode()
    private var rimMaterial: SCNMaterial?
    private var ambientLight: SCNLight?
    private var fireflies: [(node: SCNNode, base: CGFloat)] = []
    private var fireflyMoods: [String: EmotionalWeather] = [:]
    private var anchors: [String: [(lat: Double, lon: Double)]] = [:]
    private var brightnessTimer: Timer?
    private var localEcho: (mood: EmotionalWeather, countryCode: String)?
    private var didOrientToEcho = false

    /// Fixed world-space sun — also drives the directional light, so the lit
    /// hemisphere, shading falloff, and firefly night-boost all agree.
    static let sunDirection = simd_normalize(SIMD3<Float>(-0.55, 0.35, 0.85))

    static let globeRadius: Float = 1.0
    private static let maxFireflies = 150
    private static let maxWeatherSystems = 10
    private static let localEchoName = "firefly-local-echo"

    // MARK: - Build

    func build() {
        scene.background.contents = UIColor.clear

        // Camera — fixed; the globe rotates instead.
        let camera = SCNCamera()
        camera.fieldOfView = 38
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3.4)
        scene.rootNode.addChildNode(cameraNode)

        // Night lighting: a dimmer, warmer key (moonlit campfire, not studio)
        // so the mood lights become the visual heroes against the dark.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 480
        key.color = UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        let s = Self.sunDirection
        keyNode.look(at: SCNVector3(-s.x, -s.y, -s.z))   // directional lights shine along -Z
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 140
        fill.color = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.look(at: SCNVector3(s.x, -s.y * 0.4, s.z))   // opposite-ish, softens the night side
        scene.rootNode.addChildNode(fillNode)

        // Soft ambient — keeps the dark limb cozy, tinted by the mood.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 240
        ambient.color = DinoWorldPalette.cream
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        ambientLight = ambient

        // The TOY planet: chunky rounded continents on a friendly blue ocean,
        // soft matte vinyl finish, puffy land via a generated normal map.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 72
        let toy = SCNMaterial()
        toy.lightingModel = .blinn
        let textures = DinoWorldPalette.toyPlanetTextures()
        toy.diffuse.contents = textures?.diffuse ?? DinoWorldPalette.toyOcean
        // Dusk pass: multiply darkens the whole texture reliably (cool navy
        // lean) — the space-dark restyle's "darker oceans".
        toy.multiply.contents = UIColor(red: 0.52, green: 0.56, blue: 0.70, alpha: 1)
        if let normal = textures?.normal {
            toy.normal.contents = normal
            toy.normal.intensity = 0.9
        }
        // barely-there sheen — the old vinyl highlight became a glaring white
        // limb ring against the space-dark sky
        toy.specular.contents = UIColor(white: 0.08, alpha: 1)
        toy.shininess = 0.5
        // faint self-glow so the night side never goes pitch black
        toy.emission.contents = textures?.diffuse ?? DinoWorldPalette.toyOcean
        toy.emission.intensity = 0.16         // night side stays cozy, never void
        sphere.firstMaterial = toy
        globeNode.geometry = sphere
        scene.rootNode.addChildNode(globeNode)

        // Face layer placeholder — a decision for later: a smiley reads adorable
        // but rotates away during spins/find-my-light. Anchored at lat 8, lon 15
        // so adding it later is one child node here.
        let faceContainer = SCNNode()
        faceContainer.name = "faceContainer"
        globeNode.addChildNode(faceContainer)

        // Fresnel atmosphere rim — a slightly larger back-face shell whose
        // emission carries the mood tint; alpha rises toward the silhouette.
        let rimSphere = SCNSphere(radius: CGFloat(Self.globeRadius) * 1.06)
        rimSphere.segmentCount = 48
        let rim = SCNMaterial()
        rim.lightingModel = .constant
        rim.cullMode = .front                       // render the far shell → halo
        rim.blendMode = .add
        rim.writesToDepthBuffer = false
        // Black diffuse: with constant lighting + additive blending, an unset
        // (white) diffuse renders as a hard white ring against the dark sky —
        // only the mood-tinted emission should glow.
        rim.diffuse.contents = UIColor.black
        rim.emission.contents = DinoWorldPalette.peach
        rim.shaderModifiers = [.surface: """
        float rimDot = abs(dot(normalize(_surface.view), normalize(_surface.normal)));
        float glow = pow(1.0 - rimDot, 2.0);
        // the atmosphere breathes — a ~12s swell, never a blink
        float breathe = 0.90 + 0.10 * sin(u_time * 0.5);
        _surface.emission.rgb *= glow * 1.1 * breathe;
        _surface.transparent.a = glow * breathe;
        """]
        rim.transparencyMode = .singleLayer
        rimSphere.firstMaterial = rim
        let rimNode = SCNNode(geometry: rimSphere)
        scene.rootNode.addChildNode(rimNode)
        rimMaterial = rim

        globeNode.addChildNode(fireflyContainer)
        globeNode.addChildNode(weatherContainer)

        loadAnchors()
        startFireflyBrightnessUpdates()
    }

    private func loadAnchors() {
        guard let url = Bundle.main.url(forResource: "countryAnchors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [[Double]]] else { return }
        for (code, list) in raw {
            anchors[code] = list.compactMap { $0.count == 2 ? (lat: $0[0], lon: $0[1]) : nil }
        }
    }

    // MARK: - Day application (fireflies + weather + mood tint)

    func apply(bucket: WorldDayBucket?) {
        fireflyContainer.childNodes.forEach { $0.removeFromParentNode() }
        weatherContainer.childNodes.forEach { $0.removeFromParentNode() }
        fireflies.removeAll()
        fireflyMoods.removeAll()

        applyMoodTint(bucket?.global)

        defer { reapplyLocalEcho() }   // the user's own light survives every rebuild
        guard let bucket, bucket.global.total > 0 else { return }

        let globalTotal = Double(bucket.global.total)
        var placed = 0
        let ranked = bucket.countries
            .filter { $0.key != "elsewhere" }
            .sorted { $0.value.total > $1.value.total }

        for (code, counts) in ranked {
            guard placed < Self.maxFireflies,
                  let spots = anchors[code], !spots.isEmpty,
                  let mood = counts.dominantMood else { continue }
            let share = Double(counts.total) / globalTotal
            let size = CGFloat(0.06 + min(share, 0.35) * 0.30)
            fireflyMoods[code] = mood
            for spot in spots {
                guard placed < Self.maxFireflies else { break }
                let node = makeFirefly(color: DinoWorldPalette.moodColor(mood), size: size)
                // lift so the solid core clears the sphere at the limb (the
                // faint halo may still kiss the surface — invisible in practice)
                position(node, lat: spot.lat, lon: spot.lon, altitude: 1.03 + Float(size) * 0.4)
                node.name = "firefly-\(code)"
                addTapTarget(to: node, size: size, name: "tap-firefly-\(code)")
                fireflyContainer.addChildNode(node)
                fireflies.append((node, size))
                placed += 1
            }
        }

        for (code, counts) in ranked.prefix(Self.maxWeatherSystems) {
            guard let spots = anchors[code], let first = spots.first,
                  let mood = counts.dominantMood else { continue }
            switch mood {
            case .overwhelmed, .drained: addWeather(kind: .drizzle, lat: first.lat, lon: first.lon)
            case .clear: addWeather(kind: .shimmer, lat: first.lat, lon: first.lon)
            case .partlyCloudy: break
            }
        }
    }

    /// Atmosphere glow + ambient light shift with the day's collective mood —
    /// strongest in the rim, subtle on the surface.
    private func applyMoodTint(_ counts: WorldMoodCounts?) {
        let rgb: SIMD3<Float>
        if let c = counts, c.total > 0 {
            rgb = WorldMoodTint.tint(clear: c.clear, partlyCloudy: c.partlyCloudy,
                                     overwhelmed: c.overwhelmed, drained: c.drained)
        } else {
            rgb = WorldMoodTint.neutral
        }
        let tint = UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.2
        rimMaterial?.emission.contents = tint
        // subtle wash on the surface via the ambient light (cream → 25% mood)
        ambientLight?.color = UIColor.blendWorld(DinoWorldPalette.cream, tint, t: 0.25)
        SCNTransaction.commit()
    }

    // MARK: - Local echo (the user's own light — never an empty world)

    /// Renders the user's own firefly at their country anchor, independent of
    /// the aggregate and the 5-log privacy floor. Local only; writes nothing.
    func setLocalEcho(mood: EmotionalWeather, countryCode: String) {
        localEcho = (mood, countryCode)
        // First echo orients the planet so the user's country faces the camera
        // before the first frame — the world opens with your light greeting you
        // instead of hiding on the far side (auto-rotate continues from here).
        if !didOrientToEcho, let spot = anchors[countryCode]?.first {
            didOrientToEcho = true
            globeNode.eulerAngles = SCNVector3(Float(spot.lat * .pi / 180 * 0.5),
                                               Float(-spot.lon * .pi / 180), 0)
        }
        reapplyLocalEcho()
    }

    private func reapplyLocalEcho() {
        if let old = fireflyContainer.childNode(withName: Self.localEchoName, recursively: false) {
            old.removeFromParentNode()
            fireflies.removeAll { $0.node === old }
        }
        guard let echo = localEcho, let spot = anchors[echo.countryCode]?.first else { return }
        let node = makeFirefly(color: DinoWorldPalette.moodColor(echo.mood), size: 0.095)
        position(node, lat: spot.lat + 1.5, lon: spot.lon + 1.5, altitude: 1.03 + 0.095 * 0.4)  // beside the country light
        node.name = Self.localEchoName
        addTapTarget(to: node, size: 0.095, name: "tap-" + Self.localEchoName)
        fireflyContainer.addChildNode(node)
        fireflies.append((node, 0.095))
    }

    /// Invisible, comfortably oversized hit sphere — the visible sprites are
    /// ~10pt on screen, too small to tap reliably.
    private func addTapTarget(to node: SCNNode, size: CGFloat, name: String) {
        let sphere = SCNSphere(radius: max(size * 0.9, 0.075))
        let mat = SCNMaterial()
        mat.colorBufferWriteMask = []      // renders nothing, still hit-testable
        mat.writesToDepthBuffer = false
        sphere.firstMaterial = mat
        let tap = SCNNode(geometry: sphere)
        tap.name = name
        node.addChildNode(tap)
    }

    private func makeFirefly(color: UIColor, size: CGFloat, breathing: Bool = true) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        // Additive glow — against the space-dark planet the lights ARE the
        // heroes (alpha beads were for the bright toy-planet era).
        mat.diffuse.contents = DinoWorldPalette.fireflySprite(color: color)
        mat.blendMode = .add
        mat.writesToDepthBuffer = false
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        if breathing {
            let up = SCNAction.scale(to: 1.25, duration: Double.random(in: 1.1...1.9))
            up.timingMode = .easeInEaseOut
            let down = SCNAction.scale(to: 0.85, duration: Double.random(in: 1.1...1.9))
            down.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([up, down])))
        }
        return node
    }

    // MARK: - Live pulses (real-time blooms riding the aggregate glow)

    /// A fresh log somewhere in the world right now: bloom bright at the
    /// country anchor, breathe, then fade into the ambient glow. "elsewhere"
    /// pulses shimmer over open ocean — below-floor countries are never
    /// singled out (the server already folded them; this is just the render).
    func pulse(countryCode: String, mood: EmotionalWeather) {
        let spot: (lat: Double, lon: Double)
        if let spots = anchors[countryCode], let first = spots.randomElement() ?? spots.first {
            spot = (first.lat + Double.random(in: -1.5...1.5),
                    first.lon + Double.random(in: -1.5...1.5))
        } else {
            // open-ocean shimmer bands (mid-pacific / mid-atlantic)
            let lon = Bool.random() ? Double.random(in: -155 ... -125) : Double.random(in: -38 ... -18)
            spot = (Double.random(in: -32...32), lon)
        }
        let node = makeFirefly(color: DinoWorldPalette.moodColor(mood), size: 0.11, breathing: false)
        node.name = "pulse"
        node.opacity = 0
        position(node, lat: spot.lat, lon: spot.lon, altitude: 1.05)
        fireflyContainer.addChildNode(node)

        // bleeding light: a wider, fainter halo blooms outward behind the core
        // and dissolves first — the light spills, then settles into the glow
        let halo = makeFirefly(color: DinoWorldPalette.moodColor(mood), size: 0.26, breathing: false)
        halo.name = "pulse-halo"
        halo.opacity = 0
        position(halo, lat: spot.lat, lon: spot.lon, altitude: 1.048)
        fireflyContainer.addChildNode(halo)
        let haloIn = SCNAction.group([
            .fadeOpacity(to: 0.55, duration: 0.4),
            .scale(to: 1.6, duration: 0.6),
        ])
        haloIn.timingMode = .easeOut
        let haloOut = SCNAction.group([
            .scale(to: 2.3, duration: 2.4),
            .fadeOpacity(to: 0, duration: 2.4),
        ])
        haloOut.timingMode = .easeInEaseOut
        halo.runAction(.sequence([haloIn, haloOut, .removeFromParentNode()]))

        let appear = SCNAction.group([
            .fadeOpacity(to: 1.0, duration: 0.35),
            .scale(to: 1.9, duration: 0.45),
        ])
        appear.timingMode = .easeOut
        let settle = SCNAction.scale(to: 1.0, duration: 1.2)
        settle.timingMode = .easeInEaseOut
        let linger = SCNAction.wait(duration: 3.0)
        let fade = SCNAction.fadeOpacity(to: 0, duration: 2.0)
        node.runAction(.sequence([appear, settle, linger, fade, .removeFromParentNode()]))
    }

    private func position(_ node: SCNNode, lat: Double, lon: Double, altitude: Float) {
        let v = WorldGlobeMath.unitVector(latitude: lat, longitude: lon) * (Self.globeRadius * altitude)
        node.position = SCNVector3(v.x, v.y, v.z)
    }

    private enum WeatherKind { case drizzle, shimmer }

    private func addWeather(kind: WeatherKind, lat: Double, lon: Double) {
        let ps = SCNParticleSystem()
        ps.birthRate = kind == .drizzle ? 14 : 8
        ps.particleLifeSpan = 1.4
        ps.particleSize = kind == .drizzle ? 0.012 : 0.02
        ps.particleColor = kind == .drizzle
            ? DinoWorldPalette.ink.withAlphaComponent(0.4)
            : DinoWorldPalette.gold.withAlphaComponent(0.8)
        // soft round puff — without an image SceneKit draws hard squares,
        // which read as dark specks of dirt on the bright toy planet
        ps.particleImage = DinoWorldPalette.glowImage(color: .white)
        ps.blendMode = kind == .drizzle ? .alpha : .additive
        ps.emitterShape = SCNSphere(radius: 0.06)
        ps.spreadingAngle = 12
        ps.particleVelocity = kind == .drizzle ? 0.10 : 0.04
        ps.particleVelocityVariation = 0.03
        ps.emittingDirection = SCNVector3(0, 0, -1)
        let node = SCNNode()
        position(node, lat: lat, lon: lon, altitude: 1.12)
        node.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        node.addParticleSystem(ps)
        weatherContainer.addChildNode(node)
    }

    // MARK: - Night-side firefly boost (cheap 2 Hz CPU pass)

    private func startFireflyBrightnessUpdates() {
        brightnessTimer?.invalidate()
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateFireflyBrightness() }
        }
    }

    private func updateFireflyBrightness() {
        for (node, _) in fireflies {
            let w = node.worldPosition
            let n = simd_normalize(SIMD3<Float>(w.x, w.y, w.z))
            let night = WorldGlobeMath.nightFade(normal: n, sunDirection: Self.sunDirection)
            // always clearly visible — just a whisper brighter on the night side
            node.opacity = CGFloat(0.88 + 0.12 * night)
        }
    }

    // MARK: - Glow tap lookup

    struct WorldGlowHit {
        let countryCode: String
        let mood: EmotionalWeather
        let isLocalEcho: Bool
    }

    /// Resolves a hit-tested node (sprite or its invisible tap sphere) to the
    /// glow it belongs to. Walks up the parent chain so child hits count.
    func glowHit(for node: SCNNode) -> WorldGlowHit? {
        var current: SCNNode? = node
        while let n = current {
            if let name = n.name {
                if name == Self.localEchoName || name == "tap-" + Self.localEchoName {
                    if let echo = localEcho {
                        return WorldGlowHit(countryCode: echo.countryCode, mood: echo.mood, isLocalEcho: true)
                    }
                } else if name.hasPrefix("tap-firefly-") {
                    let code = String(name.dropFirst("tap-firefly-".count))
                    if let mood = fireflyMoods[code] {
                        return WorldGlowHit(countryCode: code, mood: mood, isLocalEcho: false)
                    }
                } else if name.hasPrefix("firefly-") {
                    let code = String(name.dropFirst("firefly-".count))
                    if let mood = fireflyMoods[code] {
                        return WorldGlowHit(countryCode: code, mood: mood, isLocalEcho: false)
                    }
                }
            }
            current = n.parent
        }
        return nil
    }

    // MARK: - Find my light

    /// Rotates the globe so `countryCode` faces the camera. Prefers the user's
    /// local echo when it's there; falls back to the country firefly.
    func focus(on countryCode: String) -> SCNNode? {
        guard let spot = anchors[countryCode]?.first else { return nil }
        let targetYaw = CGFloat(-spot.lon * .pi / 180)
        let targetPitch = CGFloat(spot.lat * .pi / 180 * 0.5)
        let action = SCNAction.rotateTo(x: targetPitch, y: targetYaw, z: 0, duration: 1.4, usesShortestUnitArc: true)
        action.timingMode = .easeInEaseOut
        globeNode.runAction(action, forKey: "focus")
        if localEcho?.countryCode == countryCode,
           let echo = fireflyContainer.childNode(withName: Self.localEchoName, recursively: false) {
            return echo
        }
        return fireflyContainer.childNodes.first { $0.name == "firefly-\(countryCode)" }
    }

    func stop() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
    }
}
