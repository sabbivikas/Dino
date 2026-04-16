//
//  WeatherService.swift
//  Dino
//

import Combine

import Foundation
import CoreLocation

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private let apiKey = "bd5e378503939ddaee76f12ad7a97608"

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
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        Task { @MainActor in
            await self.fetchWeather(lat: lat, lon: lon)
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

    // MARK: - Weather Fetch

    func fetchWeather(lat: Double, lon: Double) async {
        guard let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)") else {
            themeManager?.isLoadingWeather = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            let theme = mapConditionToTheme(response: response)
            let condition = response.weather.first?.description ?? response.weather.first?.main
            themeManager?.updateWeatherTheme(theme, condition: condition)
            themeManager?.isLoadingWeather = false
        } catch {
            themeManager?.isLoadingWeather = false
        }
    }

    // MARK: - Condition Mapping

    private func mapConditionToTheme(response: WeatherResponse) -> DinoAppTheme {
        let main = response.weather.first?.main ?? ""
        let sunset = response.sys?.sunset ?? 0
        let now = Int(Date().timeIntervalSince1970)
        let isNight = sunset > 0 && now > sunset

        switch main {
        case "Clear":
            return isNight ? .night : .sunny
        case "Clouds":
            return .cloudy
        case "Rain", "Drizzle":
            return .rainy
        case "Snow":
            return .snow
        case "Thunderstorm":
            return .storm
        default:
            return .defaultDino
        }
    }
}

// MARK: - Response Models

private struct WeatherResponse: Decodable {
    let weather: [WeatherCondition]
    let sys: SysInfo?
}

private struct WeatherCondition: Decodable {
    let main: String
    let description: String?
}

private struct SysInfo: Decodable {
    let sunset: Int?
}
