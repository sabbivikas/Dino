//
//  DinoWorldPalette.swift
//  Dino
//
//  Locked DINO WORLD colors (prototype-approved mapping):
//    clear = gold, partlyCloudy = sage, overwhelmed = lavender, drained = rose.
//  Peach is the halo/warmth accent — never a mood. The "find my light" firefly
//  is distinguished by behavior (pulse + label), not by a special color.
//

import SwiftUI
import UIKit

enum DinoWorldPalette {
    static let gold = UIColor(red: 1.0, green: 0.898, blue: 0.4, alpha: 1)        // #FFE066
    static let sage = UIColor(red: 0.482, green: 0.659, blue: 0.447, alpha: 1)    // #7BA872
    static let lavender = UIColor(red: 0.769, green: 0.722, blue: 0.831, alpha: 1) // #C4B8D4
    static let rose = UIColor(red: 0.910, green: 0.533, blue: 0.604, alpha: 1)    // #E8889A
    static let peach = UIColor(red: 0.961, green: 0.776, blue: 0.667, alpha: 1)   // #F5C6AA
    static let ink = UIColor(red: 0.239, green: 0.227, blue: 0.208, alpha: 1)     // #3D3A35
    static let cream = UIColor(red: 0.980, green: 0.965, blue: 0.925, alpha: 1)   // #FAF6EC
    static let card = UIColor(red: 0.996, green: 0.984, blue: 0.953, alpha: 1)    // #FEFBF3

    static func moodColor(_ mood: EmotionalWeather) -> UIColor {
        switch mood {
        case .clear: return gold
        case .partlyCloudy: return sage
        case .overwhelmed: return lavender
        case .drained: return rose
        }
    }

    static func moodSwiftUIColor(_ mood: EmotionalWeather) -> Color { Color(moodColor(mood)) }

    // MARK: - SwiftUI helpers

    /// Soft radial glow sprite used for fireflies (generated, no asset).
    static func glowImage(color: UIColor, diameter: CGFloat = 64) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { ctx in
            let colors = [color.withAlphaComponent(0.95).cgColor,
                          color.withAlphaComponent(0.35).cgColor,
                          color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 0.35, 1]) else { return }
            let c = CGPoint(x: diameter / 2, y: diameter / 2)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: c, startRadius: 0,
                                             endCenter: c, endRadius: diameter / 2, options: [])
        }
    }
}

extension Color {
    /// Gentle 65/35 blend toward `tint` — used for the home tile's subtle
    /// dominant-mood coloring.
    func blendedWorldTint(_ tint: Color) -> Color {
        let a = UIColor(self)
        let b = UIColor(tint)
        var (r1, g1, b1, o1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, o2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &o1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &o2)
        let t: CGFloat = 0.35
        return Color(red: Double(r1 + (r2 - r1) * t),
                     green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t))
            .opacity(Double(max(o1, 0.9)))
    }
}
