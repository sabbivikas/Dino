//
//  WeatherKitMappingTests.swift
//  DinoTests
//
//  Pure weather→app-state mapping: every WeatherKit condition family lands
//  on the right DinoAppTheme, night applies to clear skies only, and the
//  fixed lowercase labels keep MeditationSceneBackground's substring routing
//  working in every locale.
//

import XCTest
import WeatherKit
@testable import Dino

final class WeatherKitMappingTests: XCTestCase {

    private func theme(_ c: WeatherCondition, day: Bool = true) -> DinoAppTheme {
        WeatherService.mapConditionToTheme(condition: c, isDaylight: day)
    }

    // MARK: - Theme families

    func testClearFamily() {
        XCTAssertEqual(theme(.clear), .sunny)
        XCTAssertEqual(theme(.mostlyClear), .sunny)
        XCTAssertEqual(theme(.hot), .sunny)
    }

    func testCloudFamily() {
        for c: WeatherCondition in [.cloudy, .mostlyCloudy, .partlyCloudy, .foggy, .haze, .smoky, .blowingDust] {
            XCTAssertEqual(theme(c), .cloudy, "\(c) should map to cloudy")
        }
    }

    func testRainFamily() {
        for c: WeatherCondition in [.rain, .heavyRain, .drizzle, .freezingRain, .freezingDrizzle, .sunShowers] {
            XCTAssertEqual(theme(c), .rainy, "\(c) should map to rainy")
        }
    }

    func testSnowFamily() {
        for c: WeatherCondition in [.snow, .heavySnow, .flurries, .sunFlurries, .sleet, .wintryMix, .blizzard, .blowingSnow] {
            XCTAssertEqual(theme(c), .snow, "\(c) should map to snow")
        }
    }

    func testStormFamily() {
        for c: WeatherCondition in [.thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms,
                                    .strongStorms, .tropicalStorm, .hurricane, .hail] {
            XCTAssertEqual(theme(c), .storm, "\(c) should map to storm")
        }
    }

    func testNeutralConditionsKeepDefaultTheme() {
        for c: WeatherCondition in [.breezy, .windy, .frigid] {
            XCTAssertEqual(theme(c), .defaultDino, "\(c) should map to defaultDino")
        }
    }

    // MARK: - Night applies to clear skies only

    func testNightOnlyForClearFamily() {
        XCTAssertEqual(theme(.clear, day: false), .night)
        XCTAssertEqual(theme(.mostlyClear, day: false), .night)
        // everything else ignores daylight
        XCTAssertEqual(theme(.rain, day: false), .rainy)
        XCTAssertEqual(theme(.cloudy, day: false), .cloudy)
        XCTAssertEqual(theme(.snow, day: false), .snow)
        XCTAssertEqual(theme(.thunderstorms, day: false), .storm)
    }

    // MARK: - Fixed labels (never localized)

    func testConditionLabels() {
        XCTAssertEqual(WeatherService.conditionLabel(.clear), "clear")
        XCTAssertEqual(WeatherService.conditionLabel(.partlyCloudy), "cloudy")
        XCTAssertEqual(WeatherService.conditionLabel(.foggy), "hazy")
        XCTAssertEqual(WeatherService.conditionLabel(.drizzle), "drizzle")
        XCTAssertEqual(WeatherService.conditionLabel(.heavyRain), "rain")
        XCTAssertEqual(WeatherService.conditionLabel(.blizzard), "snow")
        XCTAssertEqual(WeatherService.conditionLabel(.hurricane), "thunderstorm")
        XCTAssertEqual(WeatherService.conditionLabel(.windy), "mild")
    }

    // MARK: - MeditationSceneBackground compatibility
    // MeditationScene.current() routes on these substrings; every wet/snowy
    // condition must keep hitting the right branch.

    func testMeditationRainRouting() {
        let rainScene: (String) -> Bool = { label in
            label.contains("rain") || label.contains("drizzle") || label.contains("thunderstorm")
        }
        for c: WeatherCondition in [.rain, .heavyRain, .drizzle, .freezingRain, .freezingDrizzle,
                                    .sunShowers, .thunderstorms, .strongStorms, .hurricane, .hail] {
            XCTAssertTrue(rainScene(WeatherService.conditionLabel(c)),
                          "\(c) label must route to the rainy meditation scene")
        }
        XCTAssertFalse(rainScene(WeatherService.conditionLabel(.clear)))
        XCTAssertFalse(rainScene(WeatherService.conditionLabel(.snow)))
    }

    func testMeditationSnowRouting() {
        for c: WeatherCondition in [.snow, .heavySnow, .flurries, .sleet, .wintryMix, .blizzard] {
            XCTAssertTrue(WeatherService.conditionLabel(c).contains("snow"),
                          "\(c) label must route to the snow meditation scene")
        }
        XCTAssertFalse(WeatherService.conditionLabel(.rain).contains("snow"))
    }
}
