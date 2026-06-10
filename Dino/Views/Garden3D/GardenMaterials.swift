//
//  GardenMaterials.swift
//  Dino
//
//  Dino-palette colors and flat low-poly materials for the 3D garden.
//  Palette sourced from colors_and_type.css (sage family + accents).
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

    /// Returns the color with saturation scaled by `factor` (0...1).
    /// Used for the unwatered / wilting desaturation look.
    func gardenDesaturated(to factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let clamped = max(0, min(1, factor))
        return UIColor(hue: h, saturation: s * clamped, brightness: b, alpha: a)
    }
}

enum GardenPalette {
    // Greens (sage family)
    static let sage        = UIColor(hexRGB: 0xA8C5A0)
    static let sageDeep    = UIColor(hexRGB: 0x7BA872)
    static let grass       = UIColor(hexRGB: 0x9CC094)
    static let grassLight  = UIColor(hexRGB: 0xB8D4A8)
    static let foliage     = UIColor(hexRGB: 0x6FA065)
    static let foliageDeep = UIColor(hexRGB: 0x5A8A52)
    static let leaf        = UIColor(hexRGB: 0x7BA872)
    static let bud         = UIColor(hexRGB: 0x93C079)

    // Earth / wood / stone
    static let earth       = UIColor(hexRGB: 0x8B6E4E)
    static let bark        = UIColor(hexRGB: 0x6E5A3E)
    static let rock        = UIColor(hexRGB: 0xA8A491)
    static let rockDark    = UIColor(hexRGB: 0x8E8E7C)

    // Water
    static let water       = UIColor(hexRGB: 0xA8D4E6)
    static let waterDeep   = UIColor(hexRGB: 0x76B2C9)

    // Sunflower
    static let petal       = UIColor(hexRGB: 0xF5C842)
    static let petalWarm   = UIColor(hexRGB: 0xF5C6AA)
    static let seedHead    = UIColor(hexRGB: 0x6E4A2A)
    static let seedShell   = UIColor(hexRGB: 0x4A3520)

    // Sky / celestial
    static let moon        = UIColor(hexRGB: 0xF5E9C4)
    static let skyMorning  = UIColor(hexRGB: 0xFDE8D0)
    static let skyMidday   = UIColor(hexRGB: 0xCDE8F5)
    static let skyEvening  = UIColor(hexRGB: 0xF7C079)
    static let skyNight    = UIColor(hexRGB: 0x1B2C4C)
}

enum GardenMaterials {
    /// Flat, matte, low-poly look: lambert lighting, full roughness.
    static func flat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        m.roughness.contents = 1.0
        m.isDoubleSided = false
        return m
    }

    /// Emissive material for the moon disc and firefly-adjacent glow accents.
    static func glow(_ color: UIColor, emission: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = emission
        m.lightingModel = .constant
        return m
    }

    /// Pond surface — soft blue with an optional time-based normal shimmer
    /// (shader modifier skipped under reduce-motion for a fully static frame).
    static func pond(shimmer: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = GardenPalette.water
        m.specular.contents = UIColor(white: 1.0, alpha: 0.6)
        m.lightingModel = .blinn
        m.transparency = 0.92
        if shimmer {
            m.shaderModifiers = [
                .surface: """
                float t = u_time;
                float w = sin(_surface.diffuseTexcoord.x * 18.0 + t * 1.2)
                        * sin(_surface.diffuseTexcoord.y * 14.0 - t * 0.9);
                _surface.normal = normalize(_surface.normal + vec3(w * 0.06, 0.0, w * 0.06));
                """
            ]
        }
        return m
    }
}
