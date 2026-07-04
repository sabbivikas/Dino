//
//  GardenCreatureTextures.swift
//  Dino
//
//  Painted sprite frames for the garden creatures. Every frame is looked up
//  by name so Chloe's hand-painted replacements drop in as assets named
//  "garden_<frame>" (e.g. garden_hummingbird_profile_up) with zero code
//  changes — the asset always wins over the Core Graphics painting.
//
//  Frames:
//    hummingbird_profile_up / hummingbird_profile_down
//    hummingbird_front_up   / hummingbird_front_down
//    bee_up / bee_down
//    envelope
//    firefly
//    pollen
//

import UIKit

protocol CreatureTextureProvider {
    func frame(named name: String) -> UIImage
}

final class PaintedCreatureTextures: CreatureTextureProvider {
    private var cache: [String: UIImage] = [:]

    func frame(named name: String) -> UIImage {
        if let cached = cache[name] { return cached }
        // a painted asset in the catalog always wins over the code painting
        if let asset = UIImage(named: "garden_\(name)") {
            cache[name] = asset
            return asset
        }
        let painted = Self.paint(name)
        cache[name] = painted
        return painted
    }

    // MARK: - Painting dispatch

    private static func paint(_ name: String) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            switch name {
            case "hummingbird_profile_up":   drawHummingbirdProfile(cg, wingUp: true)
            case "hummingbird_profile_down": drawHummingbirdProfile(cg, wingUp: false)
            case "hummingbird_front_up":     drawHummingbirdFront(cg, wingUp: true)
            case "hummingbird_front_down":   drawHummingbirdFront(cg, wingUp: false)
            case "bee_up":                   drawBee(cg, wingUp: true)
            case "bee_down":                 drawBee(cg, wingUp: false)
            case "envelope":                 drawEnvelope(cg)
            case "firefly":                  drawFirefly(cg)
            case "pollen":                   drawPollen(cg)
            default:                         drawFirefly(cg)
            }
        }
    }

    // MARK: - Palette

    private static let teal = UIColor(red: 0.16, green: 0.45, blue: 0.47, alpha: 1)
    private static let tealDark = UIColor(red: 0.10, green: 0.32, blue: 0.35, alpha: 1)
    private static let headGreen = UIColor(red: 0.18, green: 0.55, blue: 0.34, alpha: 1)
    private static let mint = UIColor(red: 0.62, green: 0.88, blue: 0.72, alpha: 1)
    private static let rose = UIColor(red: 0.91, green: 0.53, blue: 0.60, alpha: 1)  // #E8889A
    private static let buff = UIColor(red: 0.91, green: 0.84, blue: 0.66, alpha: 1)
    private static let chestBlue = UIColor(red: 0.35, green: 0.56, blue: 0.78, alpha: 1)
    private static let ink = UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
    private static let tailOrange = UIColor(red: 0.95, green: 0.58, blue: 0.28, alpha: 1)
    private static let gold = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
    private static let goldSoft = UIColor(red: 1.0, green: 0.88, blue: 0.40, alpha: 1)

    private static func ellipse(_ cg: CGContext, _ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat,
                                _ color: UIColor, rotation: CGFloat = 0) {
        cg.saveGState()
        cg.translateBy(x: c.x, y: c.y)
        cg.rotate(by: rotation)
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        cg.restoreGState()
    }

    // MARK: - Hummingbird, profile (faces right; flipped in-scene via scale)

    private static func drawHummingbirdProfile(_ cg: CGContext, wingUp: Bool) {
        // forked tail with orange underside, sweeping back-left
        cg.setFillColor(tealDark.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 44, y: 66))
        cg.addLine(to: CGPoint(x: 6, y: 50))
        cg.addLine(to: CGPoint(x: 20, y: 68))
        cg.addLine(to: CGPoint(x: 4, y: 84))
        cg.addLine(to: CGPoint(x: 44, y: 80))
        cg.closePath()
        cg.fillPath()
        cg.setFillColor(tailOrange.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 42, y: 76))
        cg.addLine(to: CGPoint(x: 10, y: 82))
        cg.addLine(to: CGPoint(x: 42, y: 84))
        cg.closePath()
        cg.fillPath()

        // body — teal, tilted slightly nose-up
        ellipse(cg, CGPoint(x: 62, y: 70), 26, 17, teal, rotation: -0.18)
        // blue chest + buff band between chest and belly
        ellipse(cg, CGPoint(x: 76, y: 76), 13, 11, chestBlue)
        ellipse(cg, CGPoint(x: 66, y: 84), 12, 7, buff)

        // head — iridescent green with a mint sheen
        ellipse(cg, CGPoint(x: 88, y: 48), 16, 15, headGreen)
        cg.saveGState()
        cg.setFillColor(mint.withAlphaComponent(0.55).cgColor)
        cg.fillEllipse(in: CGRect(x: 78, y: 36, width: 16, height: 9))
        cg.restoreGState()
        // rose gorget under the chin
        ellipse(cg, CGPoint(x: 92, y: 60), 9, 6, rose)

        // long downcurved dark beak
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(2.6)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: 102, y: 48))
        cg.addQuadCurve(to: CGPoint(x: 126, y: 60), control: CGPoint(x: 118, y: 48))
        cg.strokePath()

        // eye + glint
        ellipse(cg, CGPoint(x: 93, y: 45), 2.8, 2.8, ink)
        ellipse(cg, CGPoint(x: 94, y: 44), 0.9, 0.9, .white)

        // swept wing with feather lines — the frame's only difference
        cg.saveGState()
        cg.translateBy(x: 58, y: 62)
        cg.rotate(by: wingUp ? -0.85 : 0.35)
        cg.setFillColor(tealDark.withAlphaComponent(0.92).cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 0, y: 0))
        cg.addQuadCurve(to: CGPoint(x: 46, y: -6), control: CGPoint(x: 26, y: -22))
        cg.addQuadCurve(to: CGPoint(x: 0, y: 8), control: CGPoint(x: 22, y: 6))
        cg.closePath()
        cg.fillPath()
        cg.setStrokeColor(mint.withAlphaComponent(0.35).cgColor)
        cg.setLineWidth(1.1)
        for i in 1...3 {
            let f = CGFloat(i) / 4
            cg.beginPath()
            cg.move(to: CGPoint(x: 4, y: 2))
            cg.addQuadCurve(to: CGPoint(x: 44 * f, y: -6 * f),
                            control: CGPoint(x: 24 * f, y: -20 * f))
            cg.strokePath()
        }
        cg.restoreGState()
    }

    // MARK: - Hummingbird, front (head-on — never flipped)

    private static func drawHummingbirdFront(_ cg: CGContext, wingUp: Bool) {
        // wings swept out both sides
        for side in [CGFloat(-1), CGFloat(1)] {
            cg.saveGState()
            cg.translateBy(x: 64 + side * 16, y: 62)
            cg.scaleBy(x: side, y: 1)
            cg.rotate(by: wingUp ? -0.55 : 0.25)
            cg.setFillColor(tealDark.withAlphaComponent(0.9).cgColor)
            cg.beginPath()
            cg.move(to: CGPoint(x: 0, y: 0))
            cg.addQuadCurve(to: CGPoint(x: 46, y: -14), control: CGPoint(x: 24, y: -30))
            cg.addQuadCurve(to: CGPoint(x: 0, y: 8), control: CGPoint(x: 24, y: 2))
            cg.closePath()
            cg.fillPath()
            cg.restoreGState()
        }

        // body — teal, upright
        ellipse(cg, CGPoint(x: 64, y: 78), 20, 22, teal)
        ellipse(cg, CGPoint(x: 64, y: 84), 14, 12, chestBlue)
        ellipse(cg, CGPoint(x: 64, y: 94), 11, 6, buff)

        // dangling feet
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.6)
        cg.setLineCap(.round)
        for dx in [CGFloat(-5), CGFloat(5)] {
            cg.beginPath()
            cg.move(to: CGPoint(x: 64 + dx, y: 99))
            cg.addLine(to: CGPoint(x: 64 + dx * 1.3, y: 108))
            cg.strokePath()
        }

        // head with mint sheen
        ellipse(cg, CGPoint(x: 64, y: 46), 17, 16, headGreen)
        cg.setFillColor(mint.withAlphaComponent(0.5).cgColor)
        cg.fillEllipse(in: CGRect(x: 52, y: 33, width: 20, height: 9))
        // gorget front and center
        ellipse(cg, CGPoint(x: 64, y: 62), 10, 7, rose)

        // both eyes with glints
        for dx in [CGFloat(-8), CGFloat(8)] {
            ellipse(cg, CGPoint(x: 64 + dx, y: 44), 3, 3, ink)
            ellipse(cg, CGPoint(x: 64 + dx + 1, y: 43), 1, 1, .white)
        }
        // foreshortened beak — a small dark point
        cg.setFillColor(ink.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 61, y: 52))
        cg.addLine(to: CGPoint(x: 67, y: 52))
        cg.addLine(to: CGPoint(x: 64, y: 60))
        cg.closePath()
        cg.fillPath()
    }

    // MARK: - Bee

    private static func drawBee(_ cg: CGContext, wingUp: Bool) {
        // translucent wings
        for side in [CGFloat(-1), CGFloat(1)] {
            cg.saveGState()
            cg.translateBy(x: 60 + side * 8, y: 52)
            cg.rotate(by: side * (wingUp ? -0.5 : 0.05))
            cg.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: -8, y: -22, width: 16, height: 26))
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            cg.setLineWidth(1)
            cg.strokeEllipse(in: CGRect(x: -8, y: -22, width: 16, height: 26))
            cg.restoreGState()
        }

        // chubby gold body
        ellipse(cg, CGPoint(x: 60, y: 72), 26, 19, gold)
        // ink stripes clipped to the body
        cg.saveGState()
        cg.addEllipse(in: CGRect(x: 34, y: 53, width: 52, height: 38))
        cg.clip()
        cg.setFillColor(ink.withAlphaComponent(0.9).cgColor)
        for x in [CGFloat(48), CGFloat(62), CGFloat(76)] {
            cg.fill(CGRect(x: x - 4, y: 50, width: 8, height: 44))
        }
        cg.restoreGState()

        // dark head + glint + antennae
        ellipse(cg, CGPoint(x: 90, y: 66), 11, 11, ink)
        ellipse(cg, CGPoint(x: 93, y: 62), 1.4, 1.4, .white)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.5)
        cg.setLineCap(.round)
        for dx in [CGFloat(-2), CGFloat(5)] {
            cg.beginPath()
            cg.move(to: CGPoint(x: 92 + dx, y: 56))
            cg.addQuadCurve(to: CGPoint(x: 96 + dx, y: 44), control: CGPoint(x: 90 + dx, y: 48))
            cg.strokePath()
        }

        // legs + tiny gold pollen baskets
        cg.setLineWidth(1.6)
        for x in [CGFloat(52), CGFloat(66)] {
            cg.beginPath()
            cg.move(to: CGPoint(x: x, y: 89))
            cg.addLine(to: CGPoint(x: x - 2, y: 98))
            cg.strokePath()
            ellipse(cg, CGPoint(x: x - 2, y: 100), 3.2, 3.2, goldSoft)
        }
    }

    // MARK: - Envelope

    private static func drawEnvelope(_ cg: CGContext) {
        let rect = CGRect(x: 24, y: 42, width: 80, height: 50)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
        cg.setFillColor(UIColor(red: 0.996, green: 0.984, blue: 0.953, alpha: 1).cgColor) // card cream
        cg.addPath(path.cgPath)
        cg.fillPath()
        cg.setStrokeColor(ink.withAlphaComponent(0.55).cgColor)
        cg.setLineWidth(1.6)
        cg.addPath(path.cgPath)
        cg.strokePath()
        // flap lines
        cg.beginPath()
        cg.move(to: CGPoint(x: 26, y: 44))
        cg.addLine(to: CGPoint(x: 64, y: 72))
        cg.addLine(to: CGPoint(x: 102, y: 44))
        cg.strokePath()
        // rose wax seal
        ellipse(cg, CGPoint(x: 64, y: 70), 8, 8, rose)
        ellipse(cg, CGPoint(x: 64, y: 70), 4.5, 4.5,
                UIColor(red: 0.78, green: 0.38, blue: 0.47, alpha: 1))
    }

    // MARK: - Firefly + pollen glows

    private static func drawFirefly(_ cg: CGContext) {
        let c = CGPoint(x: 64, y: 64)
        let colors = [goldSoft.withAlphaComponent(0.95).cgColor,
                      goldSoft.withAlphaComponent(0.35).cgColor,
                      goldSoft.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: [0, 0.3, 1]) {
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0,
                                  endCenter: c, endRadius: 62, options: [])
        }
        ellipse(cg, c, 7, 7, UIColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 1))
    }

    private static func drawPollen(_ cg: CGContext) {
        let c = CGPoint(x: 64, y: 64)
        let colors = [gold.withAlphaComponent(0.9).cgColor,
                      gold.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: [0.2, 1]) {
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0,
                                  endCenter: c, endRadius: 60, options: [])
        }
    }
}
