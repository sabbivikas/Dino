//
//  ThemeManager.swift
//  Dino
//

import SwiftUI
import UIKit
import Combine
import WidgetKit

// MARK: - ThemeMode

enum ThemeMode: String, Codable, CaseIterable {
    case manual
    case weather

    var displayName: String {
        switch self {
        case .manual: return "manual"
        case .weather: return "match local weather"
        }
    }
}

// MARK: - ThemeColors

struct ThemeColors {
    let background: Color
    let cardBackground: Color
    let accent: Color
    let secondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let divider: Color
    let gradientTop: Color
    let gradientBottom: Color

    // Extended surface tokens
    let surfacePrimary: Color      // main content surface (cards, lists)
    let surfaceSecondary: Color    // secondary surface (nested cards, insets)
    let surfaceElevated: Color     // elevated elements (modals, popovers)
    let cardBorder: Color          // card border color
    let navBackground: Color       // tab bar background
    let navIconDefault: Color      // unselected tab icon
    let navIconSelected: Color     // selected tab icon
    let iconCircleBackground: Color // circle behind feature icons
    let shadowColor: Color         // theme-aware shadow
}

// MARK: - DinoAppTheme

enum DinoAppTheme: String, Codable, CaseIterable, Identifiable {
    case defaultDino
    case sunny
    case rainy
    case cloudy
    case night
    case forest
    case lavenderCalm
    case snow
    case storm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultDino:   return "dino"
        case .sunny:         return "sunny"
        case .rainy:         return "rainy"
        case .cloudy:        return "cloudy"
        case .night:         return "night"
        case .forest:        return "forest"
        case .lavenderCalm:  return "lavender"
        case .snow:          return "snow"
        case .storm:         return "storm"
        }
    }

    /// Whether this theme is only available via weather mode (hidden in manual picker)
    var isWeatherOnly: Bool {
        switch self {
        case .snow, .storm: return true
        default: return false
        }
    }

    var colors: ThemeColors {
        switch self {

        // ── LIGHT THEMES ─────────────────────────────────────────────────────

        case .defaultDino:
            return ThemeColors(
                background:           Color.white,
                cardBackground:       Color(hex: "#F9FAFB"),
                accent:               Color(hex: "#A8C5A0"),
                secondary:            Color(hex: "#C4B8D4"),
                textPrimary:          Color(hex: "#2D3142"),   // dark — good on white
                textSecondary:        Color(hex: "#6B7280"),   // medium grey
                divider:              Color(hex: "#E5E7EB"),
                gradientTop:          Color.white,
                gradientBottom:       Color(hex: "#F9FAFB"),
                surfacePrimary:       Color(hex: "#F9FAFB"),
                surfaceSecondary:     Color(hex: "#F3F4F6"),
                surfaceElevated:      Color.white,
                cardBorder:           Color(hex: "#D1D5DB"),   // slightly deeper for visibility
                navBackground:        Color.white,
                navIconDefault:       Color(hex: "#6B7280"),   // darker — legible on white nav
                navIconSelected:      Color(hex: "#7BA872"),   // deeper accent green
                iconCircleBackground: Color(hex: "#A8C5A0").opacity(0.18),
                shadowColor:          Color.black.opacity(0.06)
            )

        case .sunny:
            return ThemeColors(
                background:           Color(hex: "#FFFEF5"),
                cardBackground:       Color(hex: "#FFFBEA"),
                accent:               Color(hex: "#D4920A"),   // deeper golden — readable on cream
                secondary:            Color(hex: "#C07028"),   // warm amber
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#5C4A20"),   // warm dark brown — contrast on cream
                divider:              Color(hex: "#E8D8A0"),
                gradientTop:          Color(hex: "#FFF8E1"),
                gradientBottom:       Color(hex: "#FFFBEA"),
                surfacePrimary:       Color(hex: "#FFFBEA"),
                surfaceSecondary:     Color(hex: "#FFF3CC"),
                surfaceElevated:      Color(hex: "#FFFEF5"),
                cardBorder:           Color(hex: "#DCC878"),   // golden border — visible on cream
                navBackground:        Color(hex: "#FFFEF5"),
                navIconDefault:       Color(hex: "#7A6030"),   // deep warm brown — legible
                navIconSelected:      Color(hex: "#D4920A"),   // deeper golden
                iconCircleBackground: Color(hex: "#F5C97F").opacity(0.25),
                shadowColor:          Color(hex: "#C8A050").opacity(0.12)
            )

        case .rainy:
            return ThemeColors(
                background:           Color(hex: "#F5F7FA"),
                cardBackground:       Color(hex: "#EDF0F5"),
                accent:               Color(hex: "#4A88AA"),   // deeper blue — better contrast
                secondary:            Color(hex: "#6A90A8"),
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#4A5568"),   // darker — legible on light blue-grey
                divider:              Color(hex: "#C8D4E0"),
                gradientTop:          Color(hex: "#E8EDF5"),
                gradientBottom:       Color(hex: "#EDF0F5"),
                surfacePrimary:       Color(hex: "#EDF0F5"),
                surfaceSecondary:     Color(hex: "#E4E8F0"),
                surfaceElevated:      Color(hex: "#F5F7FA"),
                cardBorder:           Color(hex: "#B8C8D8"),   // visible slate border
                navBackground:        Color(hex: "#F5F7FA"),
                navIconDefault:       Color(hex: "#4A5568"),   // dark grey-blue — legible
                navIconSelected:      Color(hex: "#4A88AA"),   // deeper accent
                iconCircleBackground: Color(hex: "#7EA8BE").opacity(0.20),
                shadowColor:          Color(hex: "#4A80A0").opacity(0.10)
            )

        case .cloudy:
            return ThemeColors(
                background:           Color(hex: "#F8F8FA"),
                cardBackground:       Color(hex: "#F0F0F4"),
                accent:               Color(hex: "#6A7690"),   // deeper slate — readable
                secondary:            Color(hex: "#8890A4"),
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#4A5165"),   // darker than pure grey — contrast on pale bg
                divider:              Color(hex: "#CCCDD8"),
                gradientTop:          Color(hex: "#EAECF0"),
                gradientBottom:       Color(hex: "#F0F0F4"),
                surfacePrimary:       Color(hex: "#F0F0F4"),
                surfaceSecondary:     Color(hex: "#E8E8EE"),
                surfaceElevated:      Color(hex: "#F8F8FA"),
                cardBorder:           Color(hex: "#C4C5D0"),   // visible border on cloudy bg
                navBackground:        Color(hex: "#F8F8FA"),
                navIconDefault:       Color(hex: "#5A6070"),   // dark slate — legible
                navIconSelected:      Color(hex: "#6A7690"),   // deeper accent
                iconCircleBackground: Color(hex: "#9EA8B8").opacity(0.20),
                shadowColor:          Color.black.opacity(0.07)
            )

        case .forest:
            return ThemeColors(
                background:           Color(hex: "#F5F8F3"),
                cardBackground:       Color(hex: "#EAF0E6"),
                accent:               Color(hex: "#4A7A4A"),   // deep forest green — strong contrast
                secondary:            Color(hex: "#6A8F5C"),
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#3A5040"),   // dark forest tone — legible on pale green
                divider:              Color(hex: "#BCD0B0"),
                gradientTop:          Color(hex: "#E8F0E4"),
                gradientBottom:       Color(hex: "#EAF0E6"),
                surfacePrimary:       Color(hex: "#EAF0E6"),
                surfaceSecondary:     Color(hex: "#E0EAD8"),
                surfaceElevated:      Color(hex: "#F5F8F3"),
                cardBorder:           Color(hex: "#B0C8A4"),   // visible green border
                navBackground:        Color(hex: "#F5F8F3"),
                navIconDefault:       Color(hex: "#3A5040"),   // dark forest — legible on pale bg
                navIconSelected:      Color(hex: "#4A7A4A"),   // deeper accent green
                iconCircleBackground: Color(hex: "#6B9B6B").opacity(0.20),
                shadowColor:          Color(hex: "#3A7040").opacity(0.10)
            )

        case .lavenderCalm:
            return ThemeColors(
                background:           Color(hex: "#F8F5FA"),
                cardBackground:       Color(hex: "#F0EAF5"),
                accent:               Color(hex: "#7A5A9A"),   // deeper purple — better contrast
                secondary:            Color(hex: "#9070B0"),
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#4A3860"),   // dark violet tone — legible on pale lavender
                divider:              Color(hex: "#CCBCD8"),
                gradientTop:          Color(hex: "#F0E8F5"),
                gradientBottom:       Color(hex: "#F0EAF5"),
                surfacePrimary:       Color(hex: "#F0EAF5"),
                surfaceSecondary:     Color(hex: "#E8E0F0"),
                surfaceElevated:      Color(hex: "#F8F5FA"),
                cardBorder:           Color(hex: "#C4AEDA"),   // visible lavender border
                navBackground:        Color(hex: "#F8F5FA"),
                navIconDefault:       Color(hex: "#4A3860"),   // dark violet — legible
                navIconSelected:      Color(hex: "#7A5A9A"),   // deeper accent
                iconCircleBackground: Color(hex: "#9B7CB8").opacity(0.20),
                shadowColor:          Color(hex: "#6040A0").opacity(0.10)
            )

        case .snow:
            return ThemeColors(
                background:           Color(hex: "#FAFAFF"),
                cardBackground:       Color(hex: "#F0F0FA"),
                accent:               Color(hex: "#5080B0"),   // deeper ice blue — contrast on white
                secondary:            Color(hex: "#7090C0"),
                textPrimary:          Color(hex: "#2D3142"),
                textSecondary:        Color(hex: "#4A5070"),   // darker blue-grey — legible on pale bg
                divider:              Color(hex: "#C8CDE0"),
                gradientTop:          Color(hex: "#F0F0FF"),
                gradientBottom:       Color(hex: "#F0F0FA"),
                surfacePrimary:       Color(hex: "#F0F0FA"),
                surfaceSecondary:     Color(hex: "#E8E8F5"),
                surfaceElevated:      Color(hex: "#FAFAFF"),
                cardBorder:           Color(hex: "#BCC5DC"),   // visible border on snowy bg
                navBackground:        Color(hex: "#FAFAFF"),
                navIconDefault:       Color(hex: "#4A5070"),   // dark blue-grey — legible
                navIconSelected:      Color(hex: "#5080B0"),   // deeper accent
                iconCircleBackground: Color(hex: "#8EACD0").opacity(0.22),
                shadowColor:          Color(hex: "#5080B0").opacity(0.10)
            )

        // ── DARK THEMES ──────────────────────────────────────────────────────

        case .night:
            return ThemeColors(
                background:           Color(hex: "#1A1B2E"),
                cardBackground:       Color(hex: "#252640"),
                accent:               Color(hex: "#7B8CDE"),
                secondary:            Color(hex: "#9B8ED4"),
                textPrimary:          Color(hex: "#F0F0F8"),   // near-white — clear on dark bg
                textSecondary:        Color(hex: "#A8A8C4"),   // medium light — legible on dark
                divider:              Color(hex: "#3A3A58"),
                gradientTop:          Color(hex: "#1A1B2E"),
                gradientBottom:       Color(hex: "#252640"),
                surfacePrimary:       Color(hex: "#252640"),
                surfaceSecondary:     Color(hex: "#2E3050"),
                surfaceElevated:      Color(hex: "#303258"),
                cardBorder:           Color(hex: "#44447A"),   // visible border — not invisible
                navBackground:        Color(hex: "#1E1F35"),
                navIconDefault:       Color(hex: "#7878A0"),   // lighter — visible on dark nav
                navIconSelected:      Color(hex: "#A0AAEE"),   // bright accent — stands out
                iconCircleBackground: Color(hex: "#7B8CDE").opacity(0.22),
                shadowColor:          Color(hex: "#7B8CDE").opacity(0.15)
            )

        case .storm:
            return ThemeColors(
                background:           Color(hex: "#2A2A3A"),
                cardBackground:       Color(hex: "#353548"),
                accent:               Color(hex: "#A090C8"),   // lighter purple — visible on dark
                secondary:            Color(hex: "#8898B8"),
                textPrimary:          Color(hex: "#EEEEF8"),   // near-white — clear on dark bg
                textSecondary:        Color(hex: "#A8A8C0"),   // medium light — legible on dark
                divider:              Color(hex: "#484860"),
                gradientTop:          Color(hex: "#2A2A3A"),
                gradientBottom:       Color(hex: "#353548"),
                surfacePrimary:       Color(hex: "#353548"),
                surfaceSecondary:     Color(hex: "#3D3D58"),
                surfaceElevated:      Color(hex: "#42425C"),
                cardBorder:           Color(hex: "#585875"),   // visible border on dark storm bg
                navBackground:        Color(hex: "#2E2E42"),
                navIconDefault:       Color(hex: "#7878A0"),   // lighter — visible on dark nav
                navIconSelected:      Color(hex: "#C0ACEC"),   // bright lavender — stands out
                iconCircleBackground: Color(hex: "#A090C8").opacity(0.22),
                shadowColor:          Color(hex: "#8B7AA8").opacity(0.18)
            )
        }
    }
}

// MARK: - ThemeManager

@MainActor
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    private let defaults = UserDefaults(suiteName: "group.com.vikassabbi.dino") ?? .standard
    private let themeModeKey = "dino.themeMode"
    private let manualThemeKey = "dino.selectedManualTheme"
    private let cachedWeatherThemeKey = "dino.cachedWeatherTheme"

    @Published private(set) var currentTheme: DinoAppTheme = .defaultDino
    @Published var themeMode: ThemeMode = .manual {
        didSet {
            persistThemeMode()
            applyTheme()
        }
    }

    /// The persisted manually-selected theme. Setting this does NOT instantly apply — call applyPreview() to commit.
    @Published var selectedManualTheme: DinoAppTheme = .defaultDino {
        didSet {
            // Only persist; do NOT call applyTheme() here.
            // Theme changes during manual mode go through startPreview/applyPreview.
            persistManualTheme()
        }
    }

    /// Non-nil while the user is previewing (but hasn't applied) a theme.
    @Published var previewTheme: DinoAppTheme? = nil

    @Published var weatherCondition: String?
    @Published var isLoadingWeather: Bool = false

    private var weatherTheme: DinoAppTheme = .defaultDino
    private var weatherService: WeatherService?
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        loadPersistedSettings()
        applyTheme()
        registerForegroundObserver()
    }

    deinit {
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func registerForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWeatherIfNeeded()
            }
        }
    }

    /// Re-fetch weather and re-apply the theme if we're in weather mode.
    /// Called automatically on app foreground; safe to call manually too.
    func refreshWeatherIfNeeded() {
        guard themeMode == .weather else { return }
        if weatherService == nil {
            weatherService = WeatherService(themeManager: self)
        }
        weatherService?.requestLocation()
    }

    // MARK: - Persistence

    private func loadPersistedSettings() {
        if let rawMode = defaults.string(forKey: themeModeKey),
           let mode = ThemeMode(rawValue: rawMode) {
            themeMode = mode
        }
        if let rawTheme = defaults.string(forKey: manualThemeKey),
           let theme = DinoAppTheme(rawValue: rawTheme) {
            selectedManualTheme = theme
        }
        if let rawCached = defaults.string(forKey: cachedWeatherThemeKey),
           let cached = DinoAppTheme(rawValue: rawCached) {
            weatherTheme = cached
        }
    }

    private func persistThemeMode() {
        defaults.set(themeMode.rawValue, forKey: themeModeKey)
    }

    private func persistManualTheme() {
        defaults.set(selectedManualTheme.rawValue, forKey: manualThemeKey)
    }

    private func persistWeatherTheme(_ theme: DinoAppTheme) {
        defaults.set(theme.rawValue, forKey: cachedWeatherThemeKey)
    }

    // MARK: - Theme Application

    /// Apply the correct theme based on current state.
    /// If previewTheme is set, use it. Otherwise use normal mode logic.
    private func applyTheme() {
        let target: DinoAppTheme = previewTheme
            ?? (themeMode == .manual ? selectedManualTheme : weatherTheme)
        withAnimation(.easeInOut(duration: 0.6)) {
            currentTheme = target
        }
        defaults.set(currentTheme.rawValue, forKey: "dino.currentThemeForWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Preview API

    /// Begin previewing a theme — updates currentTheme live so the whole app reflects it.
    func startPreview(_ theme: DinoAppTheme) {
        previewTheme = theme
        withAnimation(.easeInOut(duration: 0.6)) {
            currentTheme = theme
        }
    }

    /// Cancel preview and revert to the actual applied theme.
    func cancelPreview() {
        previewTheme = nil
        applyTheme()
    }

    /// Commit the previewed theme as the new applied manual theme, persist, and clear preview state.
    func applyPreview() {
        guard let preview = previewTheme else { return }
        previewTheme = nil
        selectedManualTheme = preview
        withAnimation(.easeInOut(duration: 0.6)) {
            currentTheme = preview
        }
        // Sync to widgets
        defaults.set(currentTheme.rawValue, forKey: "dino.currentThemeForWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Weather Theme Update

    func updateWeatherTheme(_ theme: DinoAppTheme, condition: String?) {
        weatherTheme = theme
        weatherCondition = condition
        persistWeatherTheme(theme)
        if themeMode == .weather {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentTheme = theme
            }
            defaults.set(currentTheme.rawValue, forKey: "dino.currentThemeForWidget")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
