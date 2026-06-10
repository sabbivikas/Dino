//
//  WorldMaterials.swift
//  Dino
//
//  Palette + materials for the 3D onboarding world. Colors from
//  colors_and_type.css (sage family) and season-scenes.jsx (soft skies).
//  Flat lambert for the low-poly look; shader-modifier sway and shimmer
//  are attached here so reduce-motion can skip them at build time.
//

import SceneKit
import UIKit

fileprivate extension UIColor {
    convenience init(worldHex: UInt32) {
        self.init(
            red: CGFloat((worldHex >> 16) & 0xFF) / 255.0,
            green: CGFloat((worldHex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(worldHex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

enum WorldPalette {
    // Greens (sage family — colors_and_type.css)
    static let sage         = UIColor(worldHex: 0xA8C5A0)
    static let sageDeep     = UIColor(worldHex: 0x7BA872)
    static let grass        = UIColor(worldHex: 0x9CC094)
    static let grassWarm    = UIColor(worldHex: 0xB8D4A8)
    static let foliage      = UIColor(worldHex: 0x6FA065)
    static let foliageDeep  = UIColor(worldHex: 0x5A8A52)

    // Earth / wood / stone
    static let bark         = UIColor(worldHex: 0x6E5A3E)
    static let rock         = UIColor(worldHex: 0xA8A491)
    static let rockDark     = UIColor(worldHex: 0x8E8E7C)

    // Water + pond life
    static let water        = UIColor(worldHex: 0xA8D4E6)
    static let lily         = UIColor(worldHex: 0x4E8C49)
    static let cattail      = UIColor(worldHex: 0x8A6A42)

    // Flowers / accents (lavender, peach, rose, cream)
    static let lavender     = UIColor(worldHex: 0xC4B8D4)
    static let peach        = UIColor(worldHex: 0xF5C6AA)
    static let rose         = UIColor(worldHex: 0xE8B4B8)
    static let cream        = UIColor(worldHex: 0xFFF7E8)
    static let gold         = UIColor(worldHex: 0xF5C842)

    // Celestial
    static let moon         = UIColor(worldHex: 0xF5E9C4)
    static let star         = UIColor(worldHex: 0xF4EFE0)

    // Sky stops (day from season-scenes.jsx spring; night from starfield navy)
    static let skyDayTop      = UIColor(worldHex: 0xD9E4EF)
    static let skyDayMid      = UIColor(worldHex: 0xEDE2D0)
    static let skyDayBottom   = UIColor(worldHex: 0xE4D5BE)
    static let skyNightTop    = UIColor(worldHex: 0x0F0F22)
    static let skyNightMid    = UIColor(worldHex: 0x1B2C4C)
    static let skyNightBottom = UIColor(worldHex: 0x2A3C5E)

    // Fog tones per region grade
    static let fogMeadow   = UIColor(worldHex: 0xE6DEC8)
    static let fogPond     = UIColor(worldHex: 0xD8E4DE)
    static let fogGrove    = UIColor(worldHex: 0xE8CFA8)
    static let fogNight    = UIColor(worldHex: 0x1E2A44)
}

enum WorldMaterials {

    /// Flat matte low-poly material.
    static func flat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        m.roughness.contents = 1.0
        return m
    }

    /// Unlit emissive (moon, stars).
    static func glow(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.lightingModel = .constant
        return m
    }

    /// Foliage / grass material with optional vertex-sway shader modifier.
    /// Sway lives in the GEOMETRY stage so one material animates every blade
    /// and crown — far cheaper than per-node actions.
    static func swaying(_ color: UIColor, sway: Bool) -> SCNMaterial {
        let m = flat(color)
        if sway {
            m.shaderModifiers = [
                .geometry: """
                float phase = u_time * 1.4 + _geometry.position.x * 0.7 + _geometry.position.z * 0.5;
                float amount = 0.05 * max(0.0, _geometry.position.y);
                _geometry.position.x += sin(phase) * amount;
                _geometry.position.z += cos(phase * 0.8) * amount * 0.5;
                """
            ]
        }
        return m
    }

    /// Pond water with time-based normal shimmer (skipped under reduce-motion).
    static func water(shimmer: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = WorldPalette.water
        m.specular.contents = UIColor(white: 1, alpha: 0.55)
        m.lightingModel = .blinn
        m.transparency = 0.92
        if shimmer {
            m.shaderModifiers = [
                .surface: """
                float t = u_time;
                float w = sin(_surface.diffuseTexcoord.x * 16.0 + t * 1.1)
                        * sin(_surface.diffuseTexcoord.y * 13.0 - t * 0.8);
                _surface.normal = normalize(_surface.normal + vec3(w * 0.05, 0.0, w * 0.05));
                """
            ]
        }
        return m
    }

    /// Translucent additive material for god-ray cones and aurora planes.
    static func ray(_ color: UIColor, alpha: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color.withAlphaComponent(alpha)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    /// Vertical 3-stop gradient image for the sky domes (generated in code,
    /// no bundled assets).
    static func gradientImage(top: UIColor, mid: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 0.55, 1.0]
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
