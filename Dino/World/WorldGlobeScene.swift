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
    private var anchors: [String: [(lat: Double, lon: Double)]] = [:]
    private var brightnessTimer: Timer?
    private var localEcho: (mood: EmotionalWeather, countryCode: String)?

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

        // Sun: a real directional light — the terminator comes from shading.
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 950
        sun.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        let sunNode = SCNNode()
        sunNode.light = sun
        let s = Self.sunDirection
        sunNode.look(at: SCNVector3(-s.x, -s.y, -s.z))   // directional lights shine along -Z
        scene.rootNode.addChildNode(sunNode)

        // Soft ambient — keeps the night side cozy, tinted by the mood.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 320
        ambient.color = DinoWorldPalette.cream
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        ambientLight = ambient

        // The earth: warmed NASA diffuse on a single sphere.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 72
        let earth = SCNMaterial()
        earth.lightingModel = .lambert
        let texture = DinoWorldPalette.warmedEarthTexture()
        earth.diffuse.contents = texture ?? DinoWorldPalette.card
        // faint self-glow so the night side never goes pitch black
        earth.emission.contents = texture ?? DinoWorldPalette.card
        earth.emission.intensity = 0.14
        earth.specular.contents = UIColor(white: 0.12, alpha: 1)
        sphere.firstMaterial = earth
        globeNode.geometry = sphere
        scene.rootNode.addChildNode(globeNode)

        // Fresnel atmosphere rim — a slightly larger back-face shell whose
        // emission carries the mood tint; alpha rises toward the silhouette.
        let rimSphere = SCNSphere(radius: CGFloat(Self.globeRadius) * 1.06)
        rimSphere.segmentCount = 48
        let rim = SCNMaterial()
        rim.lightingModel = .constant
        rim.cullMode = .front                       // render the far shell → halo
        rim.blendMode = .add
        rim.writesToDepthBuffer = false
        rim.emission.contents = DinoWorldPalette.peach
        rim.shaderModifiers = [.surface: """
        float rimDot = abs(dot(normalize(_surface.view), normalize(_surface.normal)));
        float glow = pow(1.0 - rimDot, 1.6);
        _surface.emission.rgb *= glow * 1.4;
        _surface.transparent.a = glow;
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
            let size = CGFloat(0.05 + min(share, 0.35) * 0.30)
            for spot in spots {
                guard placed < Self.maxFireflies else { break }
                let node = makeFirefly(color: DinoWorldPalette.moodColor(mood), size: size)
                position(node, lat: spot.lat, lon: spot.lon, altitude: 1.05)
                node.name = "firefly-\(code)"
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
        reapplyLocalEcho()
    }

    private func reapplyLocalEcho() {
        fireflyContainer.childNode(withName: Self.localEchoName, recursively: false)?.removeFromParentNode()
        guard let echo = localEcho, let spot = anchors[echo.countryCode]?.first else { return }
        let node = makeFirefly(color: DinoWorldPalette.moodColor(echo.mood), size: 0.085)
        position(node, lat: spot.lat + 1.5, lon: spot.lon + 1.5, altitude: 1.055)  // beside the country light
        node.name = Self.localEchoName
        fireflyContainer.addChildNode(node)
        fireflies.append((node, 0.085))
    }

    private func makeFirefly(color: UIColor, size: CGFloat) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = DinoWorldPalette.glowImage(color: color)
        mat.blendMode = .add
        mat.writesToDepthBuffer = false
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        let up = SCNAction.scale(to: 1.25, duration: Double.random(in: 1.1...1.9))
        up.timingMode = .easeInEaseOut
        let down = SCNAction.scale(to: 0.85, duration: Double.random(in: 1.1...1.9))
        down.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([up, down])))
        return node
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
            node.opacity = CGFloat(0.55 + 0.45 * night)
        }
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
