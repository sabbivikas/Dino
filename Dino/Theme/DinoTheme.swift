//
//  DinoTheme.swift
//  Dino
//

import SwiftUI

struct DinoTheme {
    // MARK: - Colors
    static let background = Color.white
    static let sageGreen = Color(hex: "#A8C5A0")
    static let lavender = Color(hex: "#C4B8D4")
    static let peach = Color(hex: "#F5C6AA")
    static let skyBlue = Color(hex: "#A8D4E6")
    static let warmRose = Color(hex: "#E8B4B8")
    static let textPrimary = Color(hex: "#2D3142")
    static let textSecondary = Color(hex: "#6B7280")
    static let cardBackground = Color(hex: "#F9FAFB")
    static let divider = Color(hex: "#E5E7EB")

    // MARK: - Pastel Array
    static let pastels: [Color] = [sageGreen, lavender, peach, skyBlue, warmRose]

    static func pastel(for index: Int) -> Color {
        pastels[index % pastels.count]
    }

    // MARK: - Shadows
    static func cardShadow() -> some View {
        EmptyView()
    }

    static let shadowColor = Color.black.opacity(0.04)
    static let shadowRadius: CGFloat = 12
    static let shadowY: CGFloat = 4

    // MARK: - Corner Radii
    static let cornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 20

    // MARK: - Spacing
    static let padding: CGFloat = 20
    static let largePadding: CGFloat = 24

    // MARK: - Typography
    static func titleFont() -> Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    static func headlineFont() -> Font {
        .system(.headline, design: .rounded, weight: .semibold)
    }

    static func bodyFont() -> Font {
        .system(.body, design: .rounded)
    }

    static func captionFont() -> Font {
        .system(.caption, design: .rounded)
    }

    static func caption2Font() -> Font {
        .system(.caption2, design: .rounded)
    }

    static func largeFont() -> Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    static func subheadlineFont() -> Font {
        .system(.subheadline, design: .rounded)
    }
}

// MARK: - View Extensions
extension View {
    func dinoCard() -> some View {
        self
            .background(DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
            .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)
    }

    func dinoCardWhite() -> some View {
        self
            .background(Color.white)
            .cornerRadius(DinoTheme.cornerRadius)
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
