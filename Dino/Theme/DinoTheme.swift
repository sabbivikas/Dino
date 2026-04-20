//
//  DinoTheme.swift
//  Dino
//

import SwiftUI

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

    // MARK: - Typography (all Dino custom font)
    static func largeFont() -> Font {
        .custom(customFontName, size: 34)
    }

    static func titleFont() -> Font {
        .custom(customFontName, size: 22)
    }

    static func headlineFont() -> Font {
        .custom(customFontName, size: 17)
    }

    static func bodyFont() -> Font {
        .custom(customFontName, size: 17)
    }

    static func subheadlineFont() -> Font {
        .custom(customFontName, size: 15)
    }

    static func captionFont() -> Font {
        .custom(customFontName, size: 12)
    }

    static func caption2Font() -> Font {
        .custom(customFontName, size: 11)
    }

    /// Convenience for arbitrary sizes
    static func dinoFont(size: CGFloat) -> Font {
        .custom(customFontName, size: size)
    }

    /// Display titles (large)
    static func dinoDisplayFont(size: CGFloat = 28) -> Font {
        .custom(customFontName, size: size)
    }

    /// Section headers
    static func dinoHeaderFont(size: CGFloat = 22) -> Font {
        .custom(customFontName, size: size)
    }

    /// Labels
    static func dinoLabelFont(size: CGFloat = 16) -> Font {
        .custom(customFontName, size: size)
    }

    /// For numeric-only content (digits, sliders, counts) — system rounded since custom font lacks digits
    static func numericFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - View Extensions
extension View {
    func dinoCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)
    }

    func dinoCardWhite() -> some View {
        self
            .background(.ultraThinMaterial)
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
