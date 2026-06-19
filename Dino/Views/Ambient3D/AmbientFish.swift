//
//  AmbientFish.swift
//  Dino
//
//  A small fish that leaps from the pool in an arc, twists, and drops back
//  with an expanding splash ring — then waits ~9s and repeats. Billboard
//  sprite drawn in code, tinted per fish (warm / olive by day, grey-blue at
//  night). The node itself is the pool anchor; the sprite arcs relative to it.
//

import SceneKit
import UIKit

final class AmbientFish: SCNNode {

    private let sprite = SCNNode()
    private let spriteMaterial = SCNMaterial()
    private let dayTint: UIColor
    private let startDelay: TimeInterval
    private let animate: Bool

    init(tint: UInt32, startDelay: TimeInterval, reduceMotion: Bool) {
        self.dayTint = UIColor(hexRGB: tint)
        self.startDelay = startDelay
        self.animate = !reduceMotion
        super.init()
        castsShadow = false

        let plane = SCNPlane(width: 0.95, height: 0.52)
        spriteMaterial.diffuse.contents = AmbientFish.fishImage()
        spriteMaterial.multiply.contents = dayTint
        spriteMaterial.lightingModel = .constant
        spriteMaterial.isDoubleSided = true
        spriteMaterial.transparencyMode = .aOne
        spriteMaterial.writesToDepthBuffer = false
        plane.firstMaterial = spriteMaterial
        sprite.geometry = plane
        sprite.opacity = 0
        let bb = SCNBillboardConstraint()
        bb.freeAxes = .all
        sprite.constraints = [bb]
        sprite.castsShadow = false
        addChildNode(sprite)

        if animate { startLeaping() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    func setPeriod(isNight: Bool) {
        spriteMaterial.multiply.contents = isNight ? UIColor(hexRGB: 0x92A6C0) : dayTint
    }

    // MARK: - Leap cycle

    private func startLeaping() {
        let up = SCNAction.group([
            .moveBy(x: 0.5, y: 3.0, z: 0, duration: 0.6),
            .rotateBy(x: 0, y: 0, z: -0.5, duration: 0.6),
            .fadeIn(duration: 0.12)
        ])
        up.timingMode = .easeOut
        let down = SCNAction.group([
            .moveBy(x: 0.5, y: -3.0, z: 0, duration: 0.6),
            .rotateBy(x: 0, y: 0, z: -0.9, duration: 0.6)
        ])
        down.timingMode = .easeIn
        let land = SCNAction.run { [weak self] _ in self?.splash() }
        let fade = SCNAction.fadeOut(duration: 0.12)
        let reset = SCNAction.run { [weak self] _ in
            self?.sprite.position = SCNVector3Zero
            self?.sprite.eulerAngles = SCNVector3Zero
        }
        let cycle = SCNAction.sequence([up, down, land, fade, reset, .wait(duration: 9.0)])
        sprite.runAction(.sequence([.wait(duration: startDelay), .repeatForever(cycle)]))
    }

    private func splash() {
        let ring = SCNNode(geometry: SCNPlane(width: 0.7, height: 0.7))
        let m = SCNMaterial()
        m.diffuse.contents = AmbientFish.ringImage()
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        ring.geometry?.firstMaterial = m
        let bb = SCNBillboardConstraint()
        bb.freeAxes = .all
        ring.constraints = [bb]
        ring.opacity = 0.85
        ring.castsShadow = false
        addChildNode(ring)
        ring.runAction(.sequence([
            .group([.scale(to: 2.4, duration: 0.6), .fadeOut(duration: 0.6)]),
            .removeFromParentNode()
        ]))
    }

    // MARK: - Sprites

    private static var cachedFish: UIImage?
    private static func fishImage() -> UIImage {
        if let cachedFish { return cachedFish }
        let size = CGSize(width: 88, height: 48)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let white = UIColor.white.cgColor
            // body
            cg.setFillColor(white)
            cg.fillEllipse(in: CGRect(x: 26, y: 14, width: 50, height: 22))
            // tail
            cg.beginPath()
            cg.move(to: CGPoint(x: 30, y: 24))
            cg.addLine(to: CGPoint(x: 6, y: 10))
            cg.addLine(to: CGPoint(x: 14, y: 24))
            cg.addLine(to: CGPoint(x: 6, y: 38))
            cg.closePath()
            cg.fillPath()
            // top fin
            cg.beginPath()
            cg.move(to: CGPoint(x: 44, y: 15))
            cg.addQuadCurve(to: CGPoint(x: 60, y: 15), control: CGPoint(x: 52, y: 2))
            cg.closePath()
            cg.fillPath()
            // eye
            cg.setFillColor(UIColor(hexRGB: 0x2D3142).cgColor)
            cg.fillEllipse(in: CGRect(x: 66, y: 21, width: 4, height: 4))
        }
        cachedFish = img
        return img
    }

    private static var cachedRing: UIImage?
    private static func ringImage() -> UIImage {
        if let cachedRing { return cachedRing }
        let size = CGSize(width: 64, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(3)
            cg.strokeEllipse(in: CGRect(x: 6, y: 22, width: 52, height: 20))
        }
        cachedRing = img
        return img
    }
}
