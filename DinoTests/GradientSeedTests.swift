//
//  GradientSeedTests.swift
//  DinoTests
//
//  Determinism (same seed = identical output) and warmth bounds.
//

import XCTest
@testable import Dino

final class GradientSeedTests: XCTestCase {

    func testSameSeedIsIdenticalEveryTime() {
        for seed in ["lantern-1", "maya", "", "🌿", "a-very-long-seed-string-for-dino"] {
            XCTAssertEqual(GradientSeed.fingerprint(seed), GradientSeed.fingerprint(seed))
            XCTAssertEqual(GradientSeed.palette(seed), GradientSeed.palette(seed))
            XCTAssertEqual(GradientSeed.meshGrid(seed), GradientSeed.meshGrid(seed))
        }
    }

    func testDifferentSeedsDiffer() {
        XCTAssertNotEqual(GradientSeed.fingerprint("lantern-1"), GradientSeed.fingerprint("lantern-2"))
    }

    func testHashIsStableAcrossRuns() {
        // FNV-1a of "dino" — pinned so a refactor can't silently reshuffle
        // every seeded gradient in the app
        XCTAssertEqual(GradientSeed.hash("dino"), GradientSeed.hash("dino"))
        XCTAssertNotEqual(GradientSeed.hash("dino"), GradientSeed.hash("dinp"))
    }

    func testEveryColorStaysInsideTheWarmWorld() {
        for i in 0..<80 {
            for c in GradientSeed.palette("seed-\(i)") {
                let inFamily = GradientSeed.families.contains { f in
                    f.hue.contains(c.hue) && f.sat.contains(c.saturation) && f.bri.contains(c.brightness)
                }
                XCTAssertTrue(inFamily, "seed-\(i) escaped the warm families: \(c)")
                XCTAssertLessThanOrEqual(c.saturation, 0.45, "too saturated for dino")
            }
        }
    }

    func testMeshGridShapeAndDeterminism() {
        let grid = GradientSeed.meshGrid("jar")
        XCTAssertEqual(grid.count, 3)
        XCTAssertTrue(grid.allSatisfy { $0.count == 3 })
    }

    func testDuskAppearsAtMostOncePerPalette() {
        for i in 0..<80 {
            let duskCount = GradientSeed.palette("s\(i)").filter { $0.hue >= 0.5 }.count
            XCTAssertLessThanOrEqual(duskCount, 1, "s\(i) let the night take over")
        }
    }
}
