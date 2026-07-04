//
//  DinoTheme.swift
//  Dino
//

import SwiftUI
import UIKit

@MainActor
struct DinoTheme {
    // MARK: - Colors (reactive — delegate to ThemeManager)
    private static var theme: ThemeColors { ThemeManager.shared.currentTheme.colors }

    static var background: Color    { theme.background }
    static var sageGreen: Color     { theme.accent }       // accent color
    static var accent: Color        { theme.accent }
    static var lavender: Color      { theme.secondary }    // secondary color
    static var textPrimary: Color   { theme.textPrimary }
    static var textSecondary: Color { theme.textSecondary }
    static var cardBackground: Color { theme.cardBackground }
    static var divider: Color       { theme.divider }

    // Extended surface tokens
    static var surfacePrimary: Color   { theme.surfacePrimary }
    static var surfaceSecondary: Color { theme.surfaceSecondary }
    static var surfaceElevated: Color  { theme.surfaceElevated }
    static var cardBorder: Color       { theme.cardBorder }
    static var navBackground: Color    { theme.navBackground }
    static var navIconDefault: Color   { theme.navIconDefault }
    static var navIconSelected: Color  { theme.navIconSelected }
    static var iconCircleBackground: Color { theme.iconCircleBackground }

    // Fixed accent colors (unchanged across themes)
    static let peach    = Color(hex: "#F5C6AA")
    static let skyBlue  = Color(hex: "#A8D4E6")
    static let warmRose = Color(hex: "#E8B4B8")

    // MARK: - v6 Design System tokens

    // General / paper
    static let paper     = Color(hex: "#FEFBF3")
    static let cream     = Color(hex: "#FAF6EC")
    static let ink       = Color(hex: "#4A3520")
    static let muted     = Color(hex: "#8B7A5C")
    static let sageDeep  = Color(hex: "#7BA872") // alias of DinoDesignSystem.brandSageDeep

    // Calendar / streak
    // streakPeach skipped — value #F5C6AA already exists as `peach`
    static let streakSage        = Color(hex: "#A8C5A0")
    static let threadTan         = Color(hex: "#B9A580")
    static let sunYellow         = Color(hex: "#FFD56E")
    static let goldStar          = Color(hex: "#E8B86A")
    static let sunHighlight      = Color(hex: "#FFF2B3")
    static let mutedCalendar     = Color(hex: "#A8886B")
    static let monthRibbonText   = Color(hex: "#6B5A3C")
    static let hillGrassFar      = Color(hex: "#C9D9B5")
    static let hillGrassMid      = Color(hex: "#A8C5A0")
    static let hillGrassNear     = Color(hex: "#7BA872")

    // Onboarding
    // obPeach skipped — value #F5C6AA already exists as `peach`
    static let obNavy        = Color(hex: "#1A1A33")
    static let obNavy2       = Color(hex: "#0F0F22")
    static let obMoonlight   = Color(hex: "#F5E9C4")
    static let obSky         = Color(hex: "#A8D4E6")
    static let obRose        = Color(hex: "#E8B4B8")
    static let obLavender    = Color(hex: "#C4B8D4")
    static let obPlaceholder = Color(hex: "#A0958A")
    static let obMutedText   = Color(hex: "#6B7280")

    // Live Activity
    static let laInk                = Color(hex: "#11402D")
    static let laSageRing           = Color(hex: "#7BA872")
    static let laCuePeach           = Color(hex: "#E8B4B8")
    static let laCueText            = Color(hex: "#4A6852")
    static let laHillFar            = Color(hex: "#B9D3A8")
    static let laHillNear           = Color(hex: "#9FC291")
    static let laMeadowTop          = Color(hex: "#F4F8EE")
    static let laMeadowMid          = Color(hex: "#E9EFDC")
    static let laMeadowBottom       = Color(hex: "#E3EBD1")
    static let laSunCore            = Color(hex: "#FFE9B8")
    static let laSunEdge            = Color(hex: "#FBD98A")
    static let laNightTop           = Color(hex: "#1D2148")
    static let laNightMid           = Color(hex: "#2E2D5E")
    static let laNightBottom        = Color(hex: "#4B3B78")
    static let laMoonFace           = Color(hex: "#F5E9C4")
    static let laMoonStroke         = Color(hex: "#3A2E5E")
    static let laMoonCrater         = Color(hex: "#E4D4A2")
    static let laNebula             = Color(hex: "#C5ACE2")   // used at .opacity(0.22)
    static let laProgressFillStart  = Color(hex: "#C4B8D4")
    static let laProgressFillEnd    = Color(hex: "#F5E9C4")

    // Gratitude Jar
    // jarInk skipped — aliases `ink` (#4A3520)
    static let jarWallpaperTop    = Color(hex: "#D8B486")
    static let jarWallpaperBottom = Color(hex: "#C89C6B")
    static let jarWoodLight       = Color(hex: "#8B5A3C")
    static let jarWoodMid         = Color(hex: "#6B3F24")
    static let jarWoodDark        = Color(hex: "#5A3318")
    static let jarLacePaper       = Color(hex: "#FEFBF3")
    static let jarRoseStroke      = Color(hex: "#5C6B3A")
    static let jarRoseBloom1      = Color(hex: "#8A4B3A")
    static let jarRoseBloom2      = Color(hex: "#A85C47")
    static let jarRoseBloom3      = Color(hex: "#6F3A2C")
    static let jarMuted           = Color(hex: "#6B5A3C")
    static let jarVignetteEdge    = Color(hex: "#2A1A0C")   // used at .opacity(0.38)
    static let jarSunbeam         = Color(hex: "#FFE9B8")
    static let jarHalo            = Color(hex: "#FFF4D6")

    // MARK: - Pastel Array
    static var pastels: [Color] { [sageGreen, lavender, peach, skyBlue, warmRose] }

    static func pastel(for index: Int) -> Color {
        pastels[index % pastels.count]
    }

    // MARK: - Shadows
    static func cardShadow() -> some View {
        EmptyView()
    }

    static var shadowColor: Color { theme.shadowColor }
    static let shadowRadius: CGFloat = 12
    static let shadowY: CGFloat = 4

    // MARK: - Corner Radii
    static let cornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 20

    // MARK: - Spacing
    static let padding: CGFloat = 20
    static let largePadding: CGFloat = 24

    // MARK: - Custom Font
    // DinoInitiativeFont — custom handwritten font used app-wide
    // Note: font has no digits, so numericFont() uses system rounded for numbers only
    static let customFontName = "DinoInitiativeFont-Regular"

    // MARK: - Typography (all Dino custom font; all apply the combined scale)
    static func largeFont() -> Font {
        .custom(customFontName, size: 34 * textSizeScale)
    }

    static func titleFont() -> Font {
        .custom(customFontName, size: 22 * textSizeScale)
    }

    static func headlineFont() -> Font {
        .custom(customFontName, size: 17 * textSizeScale)
    }

    static func bodyFont() -> Font {
        .custom(customFontName, size: 17 * textSizeScale)
    }

    static func subheadlineFont() -> Font {
        .custom(customFontName, size: 15 * textSizeScale)
    }

    static func captionFont() -> Font {
        .custom(customFontName, size: 12 * textSizeScale)
    }

    static func caption2Font() -> Font {
        .custom(customFontName, size: 11 * textSizeScale)
    }

    /// Text INPUT surfaces (TextEditor/TextField) — system sans for legibility
    /// while typing, scaled like everything else. people read what they type.
    static func inputFont(size: CGFloat = 17) -> Font {
        .system(size: size * textSizeScale)
    }

    /// Combined text scale: the in-app setting (`text_size_scale`, 0.8...1.4)
    /// multiplied by the iOS Dynamic Type category factor, capped at 1.75× —
    /// the handwriting font stays legible beyond that only in scrolling
    /// surfaces. Pure → unit-testable.
    nonisolated static func combinedScale(userScale: Double, category: UIContentSizeCategory) -> CGFloat {
        let user = CGFloat(min(max(userScale == 0 ? 1.0 : userScale, 0.8), 1.4))
        let dt: CGFloat
        switch category {
        case .extraSmall: dt = 0.86
        case .small: dt = 0.92
        case .medium: dt = 0.96
        case .large: dt = 1.0            // iOS default
        case .extraLarge: dt = 1.08
        case .extraExtraLarge: dt = 1.16
        case .extraExtraExtraLarge: dt = 1.24
        case .accessibilityMedium: dt = 1.40
        case .accessibilityLarge: dt = 1.55
        default: dt = category.isAccessibilityCategory ? 1.75 : 1.0
        }
        return min(max(user * dt, 0.8), 1.75)
    }

    /// The live combined scale (in-app setting × the device's Dynamic Type).
    private static var textSizeScale: CGFloat {
        combinedScale(userScale: UserDefaults.standard.double(forKey: "text_size_scale"),
                      category: UITraitCollection.current.preferredContentSizeCategory)
    }

    /// Convenience for arbitrary sizes — applies the combined text scale.
    static func dinoFont(size: CGFloat) -> Font {
        .custom(customFontName, size: size * textSizeScale)
    }

    /// Display titles (large)
    static func dinoDisplayFont(size: CGFloat = 28) -> Font {
        .custom(customFontName, size: size * textSizeScale)
    }

    /// Section headers
    static func dinoHeaderFont(size: CGFloat = 22) -> Font {
        .custom(customFontName, size: size * textSizeScale)
    }

    /// Labels
    static func dinoLabelFont(size: CGFloat = 16) -> Font {
        .custom(customFontName, size: size * textSizeScale)
    }

    /// For numeric-only content (digits, sliders, counts) — system rounded since custom font lacks digits.
    /// Applies the combined text scale.
    static func numericFont(size: CGFloat = 17) -> Font {
        .system(size: size * textSizeScale, weight: .semibold, design: .rounded)
    }
}

// MARK: - View Extensions
extension View {
    func dinoCard() -> some View {
        self
            .background(DinoTheme.surfacePrimary)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)
    }

    func dinoCardWhite() -> some View {
        self
            .background(DinoTheme.surfacePrimary)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
