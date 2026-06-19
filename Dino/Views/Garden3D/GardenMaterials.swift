//
//  GardenMaterials.swift
//  Dino
//
//  Illustrated-style palette + materials for the 3D growth garden.
//  Same visual language as the onboarding world: flat vibrant color,
//  no specular, no reflections — a living children's-book page.
//

import SceneKit
import UIKit

extension UIColor {
    /// 0xRRGGBB convenience init.
    convenience init(hexRGB: UInt32) {
        let r = CGFloat((hexRGB >> 16) & 0xFF) / 255.0
        let g = CGFloat((hexRGB >> 8) & 0xFF) / 255.0
        let b = CGFloat(hexRGB & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Saturation scaled by `factor` (0...1) — the unwatered/wilting look.
    func gardenDesaturated(to factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let clamped = max(0, min(1, factor))
        return UIColor(hue: h, saturation: s * clamped, brightness: b, alpha: a)
    }
}

enum GardenPalette {
    // Ground / terrain
    static let ground      = UIColor(hexRGB: 0x7EC86A)   // bright sage
    static let hillFar     = UIColor(hexRGB: 0xA8D5A2)   // soft mint
    static let hillNear    = UIColor(hexRGB: 0x5BAD5B)   // rich green
    static let soilCream   = UIColor(hexRGB: 0xF5E6C8)   // healthy soil patch
    static let soilBrown   = UIColor(hexRGB: 0xC4956A)   // patches + dry cracked
    static let soilCrack   = UIColor(hexRGB: 0x9A6E48)

    // Trees + plants
    static let crown1      = UIColor(hexRGB: 0x6BBF59)
    static let crown2      = UIColor(hexRGB: 0x85CF6B)
    static let crown3      = UIColor(hexRGB: 0x98D982)
    static let trunk       = UIColor(hexRGB: 0x8B5E3C)
    static let grassTip    = UIColor(hexRGB: 0xA8E896)

    // Sunflower
    static let seedSoil    = UIColor(hexRGB: 0x8B6914)   // seed-stage mound
    static let stem        = UIColor(hexRGB: 0x5BAD5B)
    static let leaf        = UIColor(hexRGB: 0x7EC86A)
    static let budPale     = UIColor(hexRGB: 0xFFF0A0)   // growing-stage bud
    static let budBright   = UIColor(hexRGB: 0xFFE066)   // budding-stage bud
    static let petal       = UIColor(hexRGB: 0xFFD700)   // full bloom gold
    static let bloomCenter = UIColor(hexRGB: 0x8B4513)   // rich brown disc
    static let seedDot     = UIColor(hexRGB: 0x5C2E0D)

    // Flowers / accents
    static let flowerPeach    = UIColor(hexRGB: 0xFFB5A0)
    static let flowerLavender = UIColor(hexRGB: 0xC4A8D4)
    static let flowerYellow   = UIColor(hexRGB: 0xFFE066)
    static let flowerWhite    = UIColor(hexRGB: 0xFFFFFF)

    // Water + rocks
    static let pond         = UIColor(hexRGB: 0x4ECDC4)
    static let rock         = UIColor(hexRGB: 0xB0A090)
    static let rockShade    = UIColor(hexRGB: 0x9A8C92)

    // Photoreal sunflower
    static let stemDeep     = UIColor(hexRGB: 0x2D6A2D)
    static let leafTop      = UIColor(hexRGB: 0x4A8F3F)
    static let leafUnder    = UIColor(hexRGB: 0x6DB56D)
    static let petalBack    = UIColor(hexRGB: 0xDAA520)
    static let petalFront   = UIColor(hexRGB: 0xFFD700)
    static let discBrown    = UIColor(hexRGB: 0x3D1C02)
    static let seedDark     = UIColor(hexRGB: 0x2A1201)
    static let sepalGreen   = UIColor(hexRGB: 0x2D5A1B)
    static let witherBrown  = UIColor(hexRGB: 0x8B5A2B)

    // World regions
    static let appleRed     = UIColor(hexRGB: 0xD9483B)
    static let beehive      = UIColor(hexRGB: 0xD8A24A)
    static let willowGreen  = UIColor(hexRGB: 0x8FBF7F)
    static let benchWood    = UIColor(hexRGB: 0xA9794F)
    static let forestCrown  = UIColor(hexRGB: 0x2F6B3A)
    static let forestTrunk  = UIColor(hexRGB: 0x5E4630)
    static let mushroomCap  = UIColor(hexRGB: 0xC4554A)
    static let mushroomStem = UIColor(hexRGB: 0xEFE5D0)
    static let duckBody     = UIColor(hexRGB: 0xF2EFE6)
    static let duckHead     = UIColor(hexRGB: 0x2E7D4F)
    static let duckBill     = UIColor(hexRGB: 0xE8923A)
    static let frogGreen    = UIColor(hexRGB: 0x5BA84A)
    static let monarch      = UIColor(hexRGB: 0xFF6B00)
    static let morpho       = UIColor(hexRGB: 0x0066CC)
    static let violetWing   = UIColor(hexRGB: 0x6B35A0)
    static let beeYellow    = UIColor(hexRGB: 0xFFD700)
    static let beeBlack     = UIColor(hexRGB: 0x1C1C1C)
    static let birdInk      = UIColor(hexRGB: 0x2D3142)

    // Celestial
    static let sunDisc      = UIColor(hexRGB: 0xFFE066)
    static let moon         = UIColor(hexRGB: 0xF5EFE0)
    static let star         = UIColor(hexRGB: 0xF4EFE0)
    static let cloud        = UIColor(hexRGB: 0xFFFFFF)
    static let firefly      = UIColor(hexRGB: 0xFFE066)

    // Sky stops per period (top, bottom)
    static let skyMorningTop    = UIColor(hexRGB: 0xFFCBA4)
    static let skyMorningBottom = UIColor(hexRGB: 0xFFE4A0)
    static let skyDayTop        = UIColor(hexRGB: 0x87CEEB)
    static let skyDayBottom     = UIColor(hexRGB: 0xB8F0C8)
    static let skyEveningTop    = UIColor(hexRGB: 0xFFB347)
    static let skyEveningBottom = UIColor(hexRGB: 0xFF8C69)
    static let skyNightTop      = UIColor(hexRGB: 0x1A1A3E)
    static let skyNightBottom   = UIColor(hexRGB: 0x2D1B69)

    // Fog horizons matched to each sky
    static let fogMorning  = UIColor(hexRGB: 0xFFDCA0)
    static let fogDay      = UIColor(hexRGB: 0xBCEDC8)
    static let fogEvening  = UIColor(hexRGB: 0xFF9E78)
    static let fogNight    = UIColor(hexRGB: 0x29215E)
}

enum GardenMaterials {

    /// Flat illustrated material — lambert, no specular, double-sided.
    static func flat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        m.specular.contents = UIColor.black
        m.roughness.contents = 1.0
        m.isDoubleSided = true
        return m
    }

    /// Fully unlit — exact color regardless of lighting (dots, clouds, sun).
    static func unlit(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .constant
        m.isDoubleSided = true
        return m
    }

    /// Unlit emissive glow.
    static func glow(_ color: UIColor) -> SCNMaterial {
        let m = unlit(color)
        m.emission.contents = color
        return m
    }

    /// Crown / grass material with optional vertex sway (one shared material
    /// animates everything — far cheaper than per-node actions).
    static func swaying(_ color: UIColor, sway: Bool) -> SCNMaterial {
        let m = flat(color)
        if sway {
            m.shaderModifiers = [
                .geometry: """
                float phase = u_time * 1.3 + _geometry.position.x * 0.7 + _geometry.position.z * 0.5;
                float amount = 0.04 * max(0.0, _geometry.position.y);
                _geometry.position.x += sin(phase) * amount;
                """
            ]
        }
        return m
    }

    /// Bright turquoise water with white additive shimmer.
    static func water(shimmer: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = GardenPalette.pond
        m.lightingModel = .lambert
        m.specular.contents = UIColor.black
        m.transparency = 0.96
        m.isDoubleSided = true
        if shimmer {
            m.shaderModifiers = [
                .surface: """
                float t = u_time;
                float band = sin(_surface.diffuseTexcoord.x * 22.0 + t * 1.4)
                           * sin(_surface.diffuseTexcoord.y * 18.0 - t * 1.0);
                float sparkle = smoothstep(0.82, 1.0, band);
                _surface.diffuse.rgb += vec3(sparkle * 0.35);
                """
            ]
        }
        return m
    }

    /// Translucent additive band (sun halo).
    static func ray(_ color: UIColor, alpha: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color.withAlphaComponent(alpha)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    /// Vertical multi-stop gradient image (rich dawn/sunset skies).
    static func gradientImage(stops: [(color: UIColor, location: CGFloat)]) -> UIImage {
        let size = CGSize(width: 4, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = stops.map { $0.color.cgColor } as CFArray
            let locations: [CGFloat] = stops.map { $0.location }
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }

    /// Vertical 2-stop gradient image, generated in code (sky domes).
    static func gradientImage(top: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}
