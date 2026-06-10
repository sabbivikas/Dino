//
//  WorldMaterials.swift
//  Dino
//
//  Illustrated-style palette + materials for the onboarding world.
//  Tolan look: flat vibrant color, no specular, no reflections — a living
//  children's-book illustration. Saturation pushed ~25% above the base
//  css tokens per the illustrated-style spec.
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
    // Ground / terrain
    static let grass        = UIColor(worldHex: 0x7EC86A)   // bright sage
    static let grassTip     = UIColor(worldHex: 0xA8E896)
    static let hillFar      = UIColor(worldHex: 0xA8D5A2)   // soft mint
    static let hillNear     = UIColor(worldHex: 0x5BAD5B)   // rich green
    static let path         = UIColor(worldHex: 0xF5E6C8)   // warm cream
    static let soil         = UIColor(worldHex: 0xC4956A)

    // Trees + plants (bright crown variants)
    static let crown1       = UIColor(worldHex: 0x6BBF59)
    static let crown2       = UIColor(worldHex: 0x85CF6B)
    static let crown3       = UIColor(worldHex: 0x4FAD4F)
    static let crown4       = UIColor(worldHex: 0x98D982)
    static let trunk        = UIColor(worldHex: 0x8B5E3C)
    static let bush         = UIColor(worldHex: 0x6BBF59)

    // Flowers
    static let flowerPeach    = UIColor(worldHex: 0xFFB5A0)
    static let flowerLavender = UIColor(worldHex: 0xC4A8D4)
    static let flowerYellow   = UIColor(worldHex: 0xFFE066)
    static let flowerWhite    = UIColor(worldHex: 0xFFF8F0)

    // Water + pond life
    static let pond         = UIColor(worldHex: 0x4ECDC4)   // bright turquoise
    static let pondDeep     = UIColor(worldHex: 0x3CB8B0)
    static let lily         = UIColor(worldHex: 0x5CBF5C)
    static let cattailTop   = UIColor(worldHex: 0x8B6914)

    // Rocks (warm grey, slight purple tint)
    static let rock         = UIColor(worldHex: 0xB0A090)
    static let rockShade    = UIColor(worldHex: 0x9A8C92)

    // Celestial
    static let sunDisc      = UIColor(worldHex: 0xFFE066)
    static let moon         = UIColor(worldHex: 0xF5EFE0)
    static let star         = UIColor(worldHex: 0xF4EFE0)
    static let cloud        = UIColor(worldHex: 0xFFFFFF)

    // Sky stops per region (top, bottom)
    static let skyMeadowTop    = UIColor(worldHex: 0x87CEEB)   // sky blue
    static let skyMeadowBottom = UIColor(worldHex: 0xB8F0C8)   // mint
    static let skyPondTop      = UIColor(worldHex: 0xE8D5F5)   // soft lavender
    static let skyPondBottom   = UIColor(worldHex: 0xC5E8FF)   // pale blue
    static let skyGroveTop     = UIColor(worldHex: 0xFFB347)   // amber
    static let skyGroveBottom  = UIColor(worldHex: 0xFF8C69)   // rose
    static let skyNightTop     = UIColor(worldHex: 0x1A1A3E)   // deep navy
    static let skyNightBottom  = UIColor(worldHex: 0x2D1B69)   // purple
    static let skyDawnTop      = UIColor(worldHex: 0xFFB347)   // warm coral
    static let skyDawnBottom   = UIColor(worldHex: 0xFFD700)   // golden

    // Fog tones (match each sky's horizon so distance melts into it)
    static let fogMeadow   = UIColor(worldHex: 0xBCEDC8)
    static let fogPond     = UIColor(worldHex: 0xC9E6F8)
    static let fogGrove    = UIColor(worldHex: 0xFF9E78)
    static let fogNight    = UIColor(worldHex: 0x29215E)
    static let fogDawn     = UIColor(worldHex: 0xFFCE6E)

    // Aurora bands (overlook)
    static let auroraSage     = UIColor(worldHex: 0xA8C5A0)
    static let auroraLavender = UIColor(worldHex: 0xC4B8D4)
    static let auroraPeach    = UIColor(worldHex: 0xF5C6AA)
}

enum WorldMaterials {

    /// Flat illustrated material — lambert (soft shading, no specular),
    /// double-sided so flat planes read from any angle.
    static func flat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        m.specular.contents = UIColor.black
        m.roughness.contents = 1.0
        m.isDoubleSided = true
        return m
    }

    /// Fully unlit — always shows its exact color regardless of lighting.
    /// Used for flower dots, clouds, sun, moon, stars.
    static func unlit(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .constant
        m.isDoubleSided = true
        return m
    }

    /// Unlit emissive glow (sun disc, fireflies-adjacent accents).
    static func glow(_ color: UIColor) -> SCNMaterial {
        let m = unlit(color)
        m.emission.contents = color
        return m
    }

    /// Grass / crown material with optional vertex sway. Two-tone tip
    /// gradient for blades comes from `verticalGradient`.
    static func swaying(_ color: UIColor, sway: Bool) -> SCNMaterial {
        let m = flat(color)
        if sway {
            m.shaderModifiers = [
                .geometry: """
                float phase = u_time * 1.3 + _geometry.position.x * 0.7 + _geometry.position.z * 0.5;
                float amount = 0.05 * max(0.0, _geometry.position.y);
                _geometry.position.x += sin(phase) * amount;
                _geometry.position.z += cos(phase * 0.8) * amount * 0.5;
                """
            ]
        }
        return m
    }

    /// Two-tone gradient material (grass blades with lighter tips, sky domes).
    static func verticalGradient(top: UIColor, bottom: UIColor, sway: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = gradientImage(top: top, bottom: bottom)
        m.lightingModel = .constant
        m.isDoubleSided = true
        if sway {
            m.shaderModifiers = [
                .geometry: """
                float phase = u_time * 1.3 + _geometry.position.x * 0.7;
                float amount = 0.05 * max(0.0, _geometry.position.y);
                _geometry.position.x += sin(phase) * amount;
                """
            ]
        }
        return m
    }

    /// Bright pond water with white shimmer (shader skipped under reduce-motion).
    static func water(shimmer: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = WorldPalette.pond
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

    /// Translucent additive band (god rays, aurora, rainbow arcs).
    static func ray(_ color: UIColor, alpha: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color.withAlphaComponent(alpha)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    /// Soft translucent flat color (rainbow at 0.3 alpha, non-additive).
    static func tint(_ color: UIColor, alpha: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color.withAlphaComponent(alpha)
        m.lightingModel = .constant
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    /// Vertical 2-stop gradient image, generated in code.
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
