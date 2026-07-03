//
//  LanternLatheTests.swift
//  DinoTests
//
//  Deterministic tests for the pure lantern lathe mesh generator.
//

import XCTest
import simd
@testable import Dino

final class LanternLatheTests: XCTestCase {

    // 1) Vertex/index counts for a known profile.
    func testMeshCounts() {
        let profile: [(y: Float, r: Float)] = [(0, 0.2), (0.5, 0.35), (1, 0.05)]
        let m = LanternLathe.mesh(profile: profile, segments: 8)
        XCTAssertEqual(m.positions.count, 3 * 9)                 // rings × (segments+1)
        XCTAssertEqual(m.normals.count, m.positions.count)
        XCTAssertEqual(m.uvs.count, m.positions.count)
        XCTAssertEqual(m.indices.count, 2 * 8 * 6)               // (rings-1) × segs × 6
    }

    // 2) Every ring's vertices sit at the profile radius and height.
    func testRadiiAndHeights() {
        let profile: [(y: Float, r: Float)] = [(0, 0.16), (0.38, 0.34), (1, 0.05)]
        let m = LanternLathe.mesh(profile: profile, segments: 12)
        let cols = 13
        for (ring, spec) in profile.enumerated() {
            for s in 0..<cols {
                let p = m.positions[ring * cols + s]
                XCTAssertEqual(p.y, spec.y, accuracy: 1e-5)
                let radius = sqrt(p.x * p.x + p.z * p.z)
                XCTAssertEqual(radius, spec.r, accuracy: 1e-4)
            }
        }
    }

    // 3) All indices are in range; triangle count matches.
    func testIndicesValid() {
        let m = LanternLathe.mesh(segments: 24)   // locked sky-lantern profile
        XCTAssertFalse(m.indices.isEmpty)
        XCTAssertEqual(m.indices.count % 3, 0)
        let maxIndex = m.indices.max() ?? 0
        XCTAssertLessThan(Int(maxIndex), m.positions.count)
    }

    // 4) Normals are unit length and point outward at the belly.
    func testNormals() {
        let m = LanternLathe.mesh(segments: 16)
        for n in m.normals {
            XCTAssertEqual(Double(simd_length(n)), 1.0, accuracy: 1e-4)
        }
        // Belly ring (index 3 in the locked profile) → normal mostly radial.
        let cols = 17
        let belly = m.normals[3 * cols]      // angle 0 → +X direction
        XCTAssertGreaterThan(belly.x, 0.7)
    }

    // 5) Seam column duplicates position but wraps UV to 1.
    func testSeamWrap() {
        let m = LanternLathe.mesh(segments: 8)
        let cols = 9
        let first = m.positions[0]
        let seam = m.positions[cols - 1]
        XCTAssertEqual(first.x, seam.x, accuracy: 1e-4)
        XCTAssertEqual(first.z, seam.z, accuracy: 1e-4)
        XCTAssertEqual(m.uvs[0].x, 0, accuracy: 1e-5)
        XCTAssertEqual(m.uvs[cols - 1].x, 1, accuracy: 1e-5)
    }

    // 6) Degenerate inputs return empty, never crash.
    func testDegenerateInputs() {
        XCTAssertTrue(LanternLathe.mesh(profile: [(0, 0.1)], segments: 8).positions.isEmpty)
        XCTAssertTrue(LanternLathe.mesh(segments: 2).positions.isEmpty)
    }
}
