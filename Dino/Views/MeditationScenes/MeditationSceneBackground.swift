//
//  MeditationSceneBackground.swift
//  Dino
//
//  Thin router that selects the storybook scene for the active weather/time.
//

import SwiftUI


// MARK: - Scene Type

enum MeditationScene: Equatable {
    case sunny
    case rainy
    case night
    case snow

    /// Pick scene: night time → night; weather condition → rain/snow; fallback → sunny
    @MainActor static func current() -> MeditationScene {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night time always shows night scene (9pm - 5am)
        if hour >= 21 || hour < 5 {
            return .night
        }

        // Check actual weather condition from OpenWeatherMap (via ThemeManager)
        if let condition = ThemeManager.shared.weatherCondition?.lowercased() {
            if condition.contains("rain") || condition.contains("drizzle") || condition.contains("thunderstorm") {
                return .rainy
            }
            if condition.contains("snow") {
                return .snow
            }
        }

        // Fallback to weather theme
        switch ThemeManager.shared.currentTheme {
        case .rainy, .cloudy, .storm:
            return .rainy
        case .snow:
            return .snow
        default:
            return .sunny
        }
    }
}

// MARK: - Scene Background

struct MeditationSceneBackground: View {
    let scene: MeditationScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch scene {
                case .sunny: SunnyScene(size: geo.size, reduceMotion: reduceMotion)
                case .rainy: RainyScene(size: geo.size, reduceMotion: reduceMotion)
                case .night: NightScene(size: geo.size, reduceMotion: reduceMotion)
                case .snow:  SnowScene(size: geo.size, reduceMotion: reduceMotion)
                }
            }
        }
        .ignoresSafeArea(.all)
        .animation(.easeInOut(duration: 2), value: scene)
    }
}
