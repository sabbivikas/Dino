//
//  LanternCeremonyView.swift
//  Dino
//
//  The lantern release — a first-class scene, not a transition. A lathe-built
//  paper sky-lantern with warm emissive paper, bamboo ribs, a flickering inner
//  flame, an ember trail, and 2–3 distant lanterns, rising ~4.5s into a dusk
//  sky while the user's words hang against the stars. CoreHaptics rides the
//  rise and no-ops gracefully where unsupported.
//

import SwiftUI
import SceneKit
import CoreHaptics
import UIKit

// MARK: - Haptics

@MainActor
final class LanternHaptics {
    private var engine: CHHapticEngine?

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            self.engine = engine
            try engine.start()

            var events: [CHHapticEvent] = []
            // two soft transients at liftoff
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ], relativeTime: 0))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.38),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ], relativeTime: 0.18))
            // swelling-then-fading continuous rumble during ascent
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ], relativeTime: 0.35, duration: 3.4))
            // one feather transient at vanish
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.16),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08),
            ], relativeTime: 4.3))

            // intensity curve: swell to the middle of the rise, fade to nothing
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.35, value: 0.15),
                    .init(relativeTime: 1.8, value: 0.55),
                    .init(relativeTime: 3.75, value: 0.02),
                ],
                relativeTime: 0)

            let pattern = try CHHapticPattern(events: events, parameterCurves: [curve])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            engine = nil   // graceful no-op
        }
    }

    func stop() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }
}

// MARK: - Scene

@MainActor
enum LanternCeremonyScene {

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let camera = SCNCamera()
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.6, 4.2)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 220
        ambient.light?.color = UIColor(red: 0.45, green: 0.42, blue: 0.55, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // main lantern rises from below the frame
        let main = makeLantern(scale: 1.0, flame: true)
        main.position = SCNVector3(0, -1.6, 0)
        scene.rootNode.addChildNode(main)
        rise(main, to: SCNVector3(0.25, 2.6, -1.2), duration: 4.5, shrinkTo: 0.5)

        // distant companions, already airborne, drifting up in the depth
        for (dx, dy, dz, s, d) in [(-1.3, 0.4, -3.0, 0.32, 9.0), (1.5, -0.2, -4.0, 0.26, 11.0), (-0.7, 1.2, -5.0, 0.2, 12.0)] {
            let far = makeLantern(scale: CGFloat(s), flame: false)
            far.position = SCNVector3(dx, dy, dz)
            far.opacity = 0.65
            scene.rootNode.addChildNode(far)
            let drift = SCNAction.moveBy(x: CGFloat.random(in: -0.2...0.2), y: 2.2, z: 0, duration: d)
            far.runAction(drift)
        }
        return scene
    }

    private static func rise(_ node: SCNNode, to destination: SCNVector3, duration: TimeInterval, shrinkTo: CGFloat) {
        let move = SCNAction.move(to: destination, duration: duration)
        move.timingMode = .easeOut
        let shrink = SCNAction.scale(to: shrinkTo, duration: duration)
        shrink.timingMode = .easeIn
        let spin = SCNAction.rotateBy(x: 0, y: 0.9, z: 0, duration: duration)
        spin.timingMode = .easeInEaseOut
        // gentle sway while rising
        let swayL = SCNAction.rotateTo(x: 0, y: 0, z: 0.07, duration: 0.9); swayL.timingMode = .easeInEaseOut
        let swayR = SCNAction.rotateTo(x: 0, y: 0, z: -0.07, duration: 0.9); swayR.timingMode = .easeInEaseOut
        let sway = SCNAction.repeatForever(.sequence([swayL, swayR]))
        let fade = SCNAction.sequence([.wait(duration: duration * 0.75), .fadeOpacity(to: 0, duration: duration * 0.25)])
        node.runAction(.group([move, shrink, spin, sway, fade]))
    }

    private static func makeLantern(scale: CGFloat, flame: Bool) -> SCNNode {
        let geometry = LanternLathe.geometry()
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        let paper = paperTexture()
        mat.diffuse.contents = paper
        mat.emission.contents = paper
        mat.emission.intensity = 0.85
        mat.isDoubleSided = true
        geometry.firstMaterial = mat

        let node = SCNNode(geometry: geometry)
        node.scale = SCNVector3(scale, scale, scale)

        if flame {
            // flickering inner flame
            let flameNode = SCNNode()
            flameNode.light = SCNLight()
            flameNode.light?.type = .omni
            flameNode.light?.color = UIColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 1)
            flameNode.light?.intensity = 500
            flameNode.light?.attenuationEndDistance = 3
            flameNode.position = SCNVector3(0, 0.3, 0)
            node.addChildNode(flameNode)
            let flicker = SCNAction.customAction(duration: 6) { fNode, t in
                let noise = sin(Float(t) * 17) * 0.5 + sin(Float(t) * 31 + 1.3) * 0.5
                fNode.light?.intensity = CGFloat(500 + 130 * noise)
            }
            flameNode.runAction(.repeatForever(flicker))

            // ember trail from the mouth
            let embers = SCNParticleSystem()
            embers.birthRate = 22
            embers.particleLifeSpan = 1.3
            embers.particleSize = 0.015
            embers.particleColor = UIColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 0.9)
            embers.blendMode = .additive
            embers.emitterShape = SCNSphere(radius: 0.05)
            embers.particleVelocity = 0.25
            embers.particleVelocityVariation = 0.15
            embers.emittingDirection = SCNVector3(0, -1, 0)
            embers.spreadingAngle = 30
            let emberNode = SCNNode()
            emberNode.position = SCNVector3(0, 0.02, 0)
            emberNode.addParticleSystem(embers)
            node.addChildNode(emberNode)
        }
        return node
    }

    /// Warm paper with bamboo ribs — generated, no asset.
    private static func paperTexture() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let g = ctx.cgContext
            // warm gradient: amber glow at the bottom → soft paper cream at top
            let colors = [UIColor(red: 1.0, green: 0.62, blue: 0.28, alpha: 1).cgColor,
                          UIColor(red: 1.0, green: 0.80, blue: 0.52, alpha: 1).cgColor,
                          UIColor(red: 1.0, green: 0.92, blue: 0.74, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 0.5, 1]) {
                g.drawLinearGradient(gradient,
                                     start: CGPoint(x: 0, y: size.height),
                                     end: CGPoint(x: 0, y: 0), options: [])
            }
            // vertical bamboo ribs
            g.setStrokeColor(UIColor(red: 0.72, green: 0.45, blue: 0.22, alpha: 0.35).cgColor)
            g.setLineWidth(3)
            for i in 0..<8 {
                let x = CGFloat(i) * size.width / 8 + size.width / 16
                g.move(to: CGPoint(x: x, y: 0))
                g.addLine(to: CGPoint(x: x, y: size.height))
                g.strokePath()
            }
            // two horizontal rings
            g.setLineWidth(2.5)
            for y in [size.height * 0.2, size.height * 0.85] {
                g.move(to: CGPoint(x: 0, y: y))
                g.addLine(to: CGPoint(x: size.width, y: y))
                g.strokePath()
            }
        }
    }
}

// MARK: - SwiftUI stage

struct LanternCeremonyView: View {
    let words: String
    let onComplete: () -> Void

    @State private var wordsVisible = false
    private let haptics = LanternHaptics()

    var body: some View {
        ZStack {
            // dusk sky
            LinearGradient(colors: [Color(hex: "#1A1A33"),
                                    Color(hex: "#2E2749"),
                                    Color(hex: "#5A4468"),
                                    Color(hex: "#C4886E")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            StarsField()
                .ignoresSafeArea()

            CeremonySceneView()
                .ignoresSafeArea()

            // the user's words against the sky
            VStack {
                Spacer().frame(height: 90)
                Text("\u{201C}\(words)\u{201D}")
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(Color(hex: "#FAF6EC").opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 44)
                    .opacity(wordsVisible ? 1 : 0)
                Spacer()
            }
        }
        .onAppear {
            haptics.play()
            withAnimation(.easeIn(duration: 1.2).delay(0.6)) { wordsVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                haptics.stop()
                onComplete()
            }
        }
    }
}

private struct CeremonySceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.scene = LanternCeremonyScene.makeScene()
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

/// Still, softly twinkling stars — SwiftUI canvas, deterministic layout.
private struct StarsField: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var seed: UInt64 = 42
                func rand() -> CGFloat {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                }
                for _ in 0..<70 {
                    let x = rand() * size.width
                    let y = rand() * size.height * 0.7
                    let r = 0.6 + rand() * 1.3
                    let phase = rand() * 2 * .pi
                    let tw = 0.45 + 0.55 * (sin(t * 1.6 + phase) * 0.5 + 0.5)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(.white.opacity(0.55 * tw)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
