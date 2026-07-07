//
//  WeatherService.swift
//  Dino
//
//  Weather-adaptive theming via Apple WeatherKit — no API key, no proxy,
//  nothing shipped in the binary. Requires the WeatherKit capability on the
//  App ID (Signing & Capabilities in Xcode + the App Services checkbox on
//  the developer portal). On ANY failure — denied location, no network,
//  missing entitlement — the existing cached theme is kept; weather theming
//  degrades gracefully, never breaks.
//

import Combine
import Foundation
import CoreLocation
import WeatherKit

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()

    private weak var themeManager: ThemeManager?

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Public

    func requestLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            themeManager?.isLoadingWeather = true
            locationManager.requestLocation()
        default:
            // Denied / restricted — keep existing cached theme
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            await self.fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.themeManager?.isLoadingWeather = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.themeManager?.isLoadingWeather = true
                manager.requestLocation()
            }
        }
    }

    // MARK: - Weather Fetch (Apple WeatherKit)

    func fetchWeather(for location: CLLocation) async {
        do {
            let current = try await WeatherKit.WeatherService.shared
                .weather(for: location, including: .current)
            let theme = Self.mapConditionToTheme(condition: current.condition,
                                                 isDaylight: current.isDaylight)
            themeManager?.updateWeatherTheme(theme, condition: Self.conditionLabel(current.condition))
        } catch {
            // Missing entitlement, offline, or a WeatherKit hiccup — the
            // cached theme stays; nothing visible breaks.
            #if DEBUG
            print("🌦️ weatherkit error: \(error)")
            #endif
        }
        themeManager?.isLoadingWeather = false
    }

    // MARK: - Condition mapping (pure → testable)

    /// Night applies to the clear family ONLY — matching the old behavior
    /// where only a clear sky could become the night theme.
    nonisolated static func mapConditionToTheme(condition: WeatherCondition, isDaylight: Bool) -> DinoAppTheme {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return isDaylight ? .sunny : .night
        case .cloudy, .mostlyCloudy, .partlyCloudy, .foggy, .haze, .smoky, .blowingDust:
            return .cloudy
        case .rain, .heavyRain, .drizzle, .freezingRain, .freezingDrizzle, .sunShowers:
            return .rainy
        case .snow, .heavySnow, .flurries, .sunFlurries, .sleet, .wintryMix, .blizzard, .blowingSnow:
            return .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane, .hail:
            return .storm
        default:
            return .defaultDino   // breezy, windy, frigid, future cases
        }
    }

    /// Fixed lowercase keyword labels — deliberately NOT WeatherKit's
    /// localized `description`. MeditationSceneBackground substring-matches
    /// these ("rain" / "drizzle" / "thunderstorm" / "snow"), so the labels
    /// must stay stable across locales.
    nonisolated static func conditionLabel(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return "clear"
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return "cloudy"
        case .foggy, .haze, .smoky, .blowingDust:
            return "hazy"
        case .drizzle, .freezingDrizzle:
            return "drizzle"
        case .rain, .heavyRain, .freezingRain, .sunShowers:
            return "rain"
        case .snow, .heavySnow, .flurries, .sunFlurries, .sleet, .wintryMix, .blizzard, .blowingSnow:
            return "snow"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane, .hail:
            return "thunderstorm"
        default:
            return "mild"
        }
    }
}
