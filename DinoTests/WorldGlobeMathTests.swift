//
//  WorldGlobeMathTests.swift
//  DinoTests
//
//  Deterministic tests for the globe's pure math.
//

import XCTest
import simd
@testable import Dino

final class WorldGlobeMathTests: XCTestCase {
    private let tol = 1e-4

    // 1) Fibonacci sphere: count, unit length, hemisphere balance.
    func testFibonacciSphere() {
        let pts = WorldGlobeMath.fibonacciSphere(count: 1000)
        XCTAssertEqual(pts.count, 1000)
        for p in pts { XCTAssertEqual(Double(simd_length(p)), 1.0, accuracy: 1e-5) }
        let north = pts.filter { $0.y > 0 }.count
        XCTAssertEqual(north, 500)   // symmetric by construction
        XCTAssertTrue(WorldGlobeMath.fibonacciSphere(count: 0).isEmpty)
    }

    // 2) lat/lon ↔ vector roundtrip.
    func testLatLonRoundtrip() {
        for (lat, lon) in [(0.0, 0.0), (45.0, 90.0), (-33.9, 151.2), (89.0, -179.0), (-89.0, 179.0)] {
            let v = WorldGlobeMath.unitVector(latitude: lat, longitude: lon)
            XCTAssertEqual(Double(simd_length(v)), 1.0, accuracy: 1e-5)
            let back = WorldGlobeMath.latLon(from: v)
            XCTAssertEqual(back.lat, lat, accuracy: tol)
            XCTAssertEqual(back.lon, lon, accuracy: tol)
        }
    }

    // 3) Known anchors: north pole up, lon 0 faces +Z.
    func testConventions() {
        let pole = WorldGlobeMath.unitVector(latitude: 90, longitude: 0)
        XCTAssertEqual(Double(pole.y), 1.0, accuracy: tol)
        let greenwich = WorldGlobeMath.unitVector(latitude: 0, longitude: 0)
        XCTAssertEqual(Double(greenwich.z), 1.0, accuracy: tol)
        let east90 = WorldGlobeMath.unitVector(latitude: 0, longitude: 90)
        XCTAssertEqual(Double(east90.x), 1.0, accuracy: tol)
    }

    // 4) Equirectangular UV corners + center.
    func testEquirectangularUV() {
        let c = WorldGlobeMath.equirectangularUV(latitude: 0, longitude: 0)
        XCTAssertEqual(c.u, 0.5, accuracy: tol)
        XCTAssertEqual(c.v, 0.5, accuracy: tol)
        let nw = WorldGlobeMath.equirectangularUV(latitude: 90, longitude: -180)
        XCTAssertEqual(nw.u, 0.0, accuracy: tol)
        XCTAssertEqual(nw.v, 0.0, accuracy: tol)
        let se = WorldGlobeMath.equirectangularUV(latitude: -90, longitude: 180)
        XCTAssertEqual(se.u, 1.0, accuracy: tol)
        XCTAssertEqual(se.v, 1.0, accuracy: tol)
    }

    // 5) Terminator fade: day 0, night 1, midpoint 0.5, monotonic.
    func testNightFade() {
        let sun = SIMD3<Float>(0, 0, 1)
        XCTAssertEqual(Double(WorldGlobeMath.nightFade(normal: SIMD3(0, 0, 1), sunDirection: sun)), 0, accuracy: tol)
        XCTAssertEqual(Double(WorldGlobeMath.nightFade(normal: SIMD3(0, 0, -1), sunDirection: sun)), 1, accuracy: tol)
        XCTAssertEqual(Double(WorldGlobeMath.nightFade(normal: SIMD3(1, 0, 0), sunDirection: sun)), 0.5, accuracy: tol)
        // strictly increasing as the point rotates from noon to midnight
        var last: Float = -1
        for deg in stride(from: 0.0, through: 180.0, by: 15.0) {
            let r = Float(deg * .pi / 180)
            let n = SIMD3<Float>(sin(r), 0, cos(r))
            let f = WorldGlobeMath.nightFade(normal: n, sunDirection: sun)
            XCTAssertGreaterThanOrEqual(f + 1e-6, last)
            last = f
        }
    }

    // 6a) Mood tint: snap when one mood clearly leads.
    func testMoodTintSnapsToDominant() {
        // 60/20/10/10 — lead margin 0.40 ≥ 0.15 → pure gold
        let t = WorldMoodTint.tint(clear: 60, partlyCloudy: 20, overwhelmed: 10, drained: 10)
        XCTAssertEqual(t, WorldMoodTint.gold)
    }

    // 6b) Mood tint: proportional blend when moods are close.
    func testMoodTintBlendsWhenClose() {
        // 40/35/25 — lead margin 0.05 < 0.15 → weighted blend, not any pure color
        let t = WorldMoodTint.tint(clear: 40, partlyCloudy: 35, overwhelmed: 25, drained: 0)
        XCTAssertNotEqual(t, WorldMoodTint.gold)
        XCTAssertNotEqual(t, WorldMoodTint.sage)
        let expected = WorldMoodTint.gold * 0.40 + WorldMoodTint.sage * 0.35 + WorldMoodTint.lavender * 0.25
        XCTAssertEqual(Double(t.x), Double(expected.x), accuracy: 1e-5)
        XCTAssertEqual(Double(t.y), Double(expected.y), accuracy: 1e-5)
        XCTAssertEqual(Double(t.z), Double(expected.z), accuracy: 1e-5)
    }

    // 6c) Mood tint: quiet world → neutral peach; exact boundary snaps.
    func testMoodTintNeutralAndBoundary() {
        XCTAssertEqual(WorldMoodTint.tint(clear: 0, partlyCloudy: 0, overwhelmed: 0, drained: 0),
                       WorldMoodTint.neutral)
        // 50/35/15/0: margin exactly 0.15 → snaps
        let t = WorldMoodTint.tint(clear: 50, partlyCloudy: 35, overwhelmed: 15, drained: 0)
        XCTAssertEqual(t, WorldMoodTint.gold)
    }

    // 6d) Earth warming: desaturates, lifts toward cream, stays in range.
    func testEarthWarming() {
        // deep ocean blue → warmer, less saturated, channels in 0...1
        let ocean = WorldEarthToning.warmed(r: 0.08, g: 0.16, b: 0.45)
        XCTAssertLessThan(ocean.b - ocean.r, 0.45 - 0.08)      // blue dominance reduced
        for v in [ocean.r, ocean.g, ocean.b] {
            XCTAssertGreaterThanOrEqual(v, 0); XCTAssertLessThanOrEqual(v, 1)
        }
        // pure white stays near-white (never blows out or inverts)
        let white = WorldEarthToning.warmed(r: 1, g: 1, b: 1)
        XCTAssertGreaterThan(white.r, 0.95)
        XCTAssertGreaterThan(white.g, 0.9)
        // warm cast: red channel ≥ blue channel for neutral input
        XCTAssertGreaterThanOrEqual(white.r, white.b)
    }

    // 6) Water-pixel classification (ocean blue vs land vs ice).
    func testWaterPixelClassification() {
        XCTAssertTrue(LandMask.isWaterPixel(r: 20, g: 40, b: 110))    // deep ocean
        XCTAssertFalse(LandMask.isWaterPixel(r: 90, g: 120, b: 60))   // forest
        XCTAssertFalse(LandMask.isWaterPixel(r: 180, g: 160, b: 120)) // desert
        XCTAssertFalse(LandMask.isWaterPixel(r: 240, g: 244, b: 246)) // ice cap → land
    }
}
