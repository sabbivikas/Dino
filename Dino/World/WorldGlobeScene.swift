//
//  WorldGlobeScene.swift
//  Dino
//
//  The DINO WORLD globe: a cream sphere with ink-dotted continents (ONE
//  point-cloud geometry → one draw call, friendly to older devices), a fixed
//  sun with a shader-computed day/night terminator, per-country mood fireflies
//  (billboard glow sprites in the locked palette), and capped weather particles
//  (ink drizzle over heavy countries, gold shimmer over clear ones).
//

import Foundation
import SceneKit
import UIKit
import simd

@MainActor
final class WorldGlobeScene {
    let scene = SCNScene()
    let globeNode = SCNNode()          // rotates; dots + fireflies + weather ride along
    private let fireflyContainer = SCNNode()
    private let weatherContainer = SCNNode()
    private var fireflies: [(node: SCNNode, base: CGFloat)] = []
    private var anchors: [String: [(lat: Double, lon: Double)]] = [:]
    private var brightnessTimer: Timer?

    /// Fixed world-space sun. The camera never moves, so this is also constant
    /// in view space — the shader terminator needs no per-frame updates.
    static let sunDirection = simd_normalize(SIMD3<Float>(-0.55, 0.35, 0.85))

    static let globeRadius: Float = 1.0
    private static let maxFireflies = 150
    private static let maxWeatherSystems = 10

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

        // Cream sphere.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 64
        let sphereMat = SCNMaterial()
        sphereMat.lightingModel = .constant
        sphereMat.diffuse.contents = DinoWorldPalette.card
        sphere.firstMaterial = sphereMat
        globeNode.geometry = sphere
        scene.rootNode.addChildNode(globeNode)

        globeNode.addChildNode(fireflyContainer)
        globeNode.addChildNode(weatherContainer)

        buildContinentDots()
        loadAnchors()
        startFireflyBrightnessUpdates()
    }

    /// ~10k fibonacci points kept where the land mask says "land", emitted as a
    /// single .point geometry with a surface-shader terminator.
    private func buildContinentDots() {
        guard let url = Bundle.main.url(forResource: "earth_land_mask", withExtension: "jpg"),
              let img = UIImage(contentsOfFile: url.path)?.cgImage,
              let mask = LandMask(image: img) else {
            #if DEBUG
            print("🌍 land mask missing — globe renders without continents")
            #endif
            return
        }

        let candidates = WorldGlobeMath.fibonacciSphere(count: 11000)
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        for p in candidates {
            let ll = WorldGlobeMath.latLon(from: p)
            guard mask.isLand(latitude: ll.lat, longitude: ll.lon) else { continue }
            let v = p * (Self.globeRadius * 1.002)   // sit just above the sphere
            vertices.append(SCNVector3(v.x, v.y, v.z))
            normals.append(SCNVector3(p.x, p.y, p.z))
        }
        guard !vertices.isEmpty else { return }

        var indices = Array(UInt32(0)..<UInt32(vertices.count))
        let element = SCNGeometryElement(data: Data(bytes: &indices, count: indices.count * 4),
                                         primitiveType: .point,
                                         primitiveCount: vertices.count,
                                         bytesPerIndex: 4)
        element.pointSize = 4
        element.minimumPointScreenSpaceRadius = 1.2
        element.maximumPointScreenSpaceRadius = 4

        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                             SCNGeometrySource(normals: normals)],
                                   elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = DinoWorldPalette.ink
        // Day/night terminator: camera is fixed, sun is fixed → constant in view
        // space. Night-side dots melt toward the cream sphere. Matches
        // WorldGlobeMath.nightFade (smoothstep, band 0.25).
        let s = Self.sunDirection
        mat.shaderModifiers = [.surface: """
        float3 sunView = normalize((scn_frame.viewTransform * float4(\(s.x), \(s.y), \(s.z), 0.0)).xyz);
        float d = dot(normalize(_surface.normal), sunView);
        float t = clamp((0.25 - d) / 0.5, 0.0, 1.0);
        t = t * t * (3.0 - 2.0 * t);
        _surface.diffuse.rgb = mix(float3(0.239, 0.227, 0.208), float3(0.972, 0.953, 0.914), t * 0.9);
        """]
        geometry.firstMaterial = mat

        let dots = SCNNode(geometry: geometry)
        globeNode.addChildNode(dots)
    }

    private func loadAnchors() {
        guard let url = Bundle.main.url(forResource: "countryAnchors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [[Double]]] else { return }
        for (code, list) in raw {
            anchors[code] = list.compactMap { $0.count == 2 ? (lat: $0[0], lon: $0[1]) : nil }
        }
    }

    // MARK: - Day application (fireflies + weather from an aggregate bucket)

    func apply(bucket: WorldDayBucket?) {
        fireflyContainer.childNodes.forEach { $0.removeFromParentNode() }
        weatherContainer.childNodes.forEach { $0.removeFromParentNode() }
        fireflies.removeAll()
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
            let size = CGFloat(0.05 + min(share, 0.35) * 0.30)   // 0.05...0.155 world units
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

        // Weather over the top countries only (bounded particle systems).
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
        // Gentle async pulse.
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
        ps.emittingDirection = SCNVector3(0, 0, -1)   // toward the surface (local -Z after look-at)
        let node = SCNNode()
        position(node, lat: lat, lon: lon, altitude: 1.12)
        // Aim local -Z at the globe center so particles fall/shimmer onto the land.
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
            node.opacity = CGFloat(0.55 + 0.45 * night)   // brighter in the dark
        }
    }

    // MARK: - Find my light

    /// Rotates the globe so `countryCode`'s first anchor faces the camera.
    /// Returns the firefly node to pulse, or nil if the country isn't on the map.
    func focus(on countryCode: String) -> SCNNode? {
        guard let spot = anchors[countryCode]?.first else { return nil }
        // Camera looks down -Z from +Z; lon 0 faces +Z at yaw 0 → target yaw = -lon.
        let targetYaw = CGFloat(-spot.lon * .pi / 180)
        let targetPitch = CGFloat(spot.lat * .pi / 180 * 0.5)   // gentle tilt toward the latitude
        let action = SCNAction.rotateTo(x: targetPitch, y: targetYaw, z: 0, duration: 1.4, usesShortestUnitArc: true)
        action.timingMode = .easeInEaseOut
        globeNode.runAction(action, forKey: "focus")
        return fireflyContainer.childNodes.first { $0.name == "firefly-\(countryCode)" }
    }

    func stop() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
    }
}
