//
//  WidgetTheme.swift
//  DinoLiveActivity
//
//  Standalone theme color provider for the widget extension.
//  Reads the current app theme from shared UserDefaults and maps to colors.
//  Color(hex:) is defined in BreathingLiveActivity.swift — do NOT redeclare here.
//

import SwiftUI

struct WidgetTheme {
    static var current: WidgetTheme {
        let defaults = UserDefaults(suiteName: "group.com.vikassabbi.dino") ?? .standard
        let raw = defaults.string(forKey: "dino.currentThemeForWidget") ?? "defaultDino"
        return WidgetTheme(rawTheme: raw)
    }

    let background: Color
    let cardBackground: Color
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    let divider: Color
    let isDark: Bool

    /// Returns the correct dino image name for the current theme
    var dinoImageName: String {
        isDark ? "DinoWidgetNight" : "DinoWidget"
    }

    init(rawTheme: String) {
        // Map theme names to color values — must match ThemeManager exactly
        switch rawTheme {
        case "night":
            background = Color(hex: "1A1B2E")
            cardBackground = Color(hex: "252640")
            accent = Color(hex: "7B8CDE")
            textPrimary = Color(hex: "F0F0F8")
            textSecondary = Color(hex: "A8A8C4")
            divider = Color(hex: "3A3A55")
            isDark = true
        case "storm":
            background = Color(hex: "2A2A3A")
            cardBackground = Color(hex: "353548")
            accent = Color(hex: "8B7AA8")
            textPrimary = Color(hex: "EEEEF8")
            textSecondary = Color(hex: "A0A0B8")
            divider = Color(hex: "454560")
            isDark = true
        case "sunny":
            background = Color(hex: "FFFEF5")
            cardBackground = Color(hex: "FFFBEA")
            accent = Color(hex: "D4A843")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "5C4A20")
            divider = Color(hex: "F0E8D0")
            isDark = false
        case "rainy":
            background = Color(hex: "F5F7FA")
            cardBackground = Color(hex: "EDF0F5")
            accent = Color(hex: "5A8BA5")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "4A5568")
            divider = Color(hex: "D8E0EA")
            isDark = false
        case "cloudy":
            background = Color(hex: "F8F8FA")
            cardBackground = Color(hex: "F0F0F4")
            accent = Color(hex: "7A8498")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "555566")
            divider = Color(hex: "DCDDE8")
            isDark = false
        case "forest":
            background = Color(hex: "F5F8F3")
            cardBackground = Color(hex: "EAF0E6")
            accent = Color(hex: "4A7A4A")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "3A5040")
            divider = Color(hex: "D0DCC8")
            isDark = false
        case "lavenderCalm":
            background = Color(hex: "F8F5FA")
            cardBackground = Color(hex: "F0EAF5")
            accent = Color(hex: "7A5A9E")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "4A3860")
            divider = Color(hex: "DDD0E8")
            isDark = false
        case "snow":
            background = Color(hex: "FAFAFF")
            cardBackground = Color(hex: "F0F0FA")
            accent = Color(hex: "6A8CB8")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "4A5570")
            divider = Color(hex: "D8DFF0")
            isDark = false
        default: // defaultDino
            background = Color.white
            cardBackground = Color(hex: "F9FAFB")
            accent = Color(hex: "A8C5A0")
            textPrimary = Color(hex: "2D3142")
            textSecondary = Color(hex: "6B7280")
            divider = Color(hex: "E5E7EB")
            isDark = false
        }
    }
}
