//
//  WorldToyMaskTests.swift
//  DinoTests
//
//  Deterministic tests for the toy-planet mask math.
//

import XCTest
import simd
@testable import Dino

final class WorldToyMaskTests: XCTestCase {
    private let tol: Float = 1e-5

    // 1) Blur preserves a constant field exactly (normalized window).
    func testBlurPreservesConstant() {
        let field = [Float](repeating: 0.7, count: 8 * 4)
        let out = WorldToyMask.boxBlur(field, width: 8, height: 4, radius: 2)
        for v in out { XCTAssertEqual(v, 0.7, accuracy: tol) }
    }

    // 2) Blur smooths a hard step into intermediate values.
    func testBlurSmoothsStep() {
        let w = 16, h = 1
        var field = [Float](repeating: 0, count: w)
        for x in 8..<16 { field[x] = 1 }
        let out = WorldToyMask.boxBlur(field, width: w, height: h, radius: 1)
        XCTAssertEqual(out[7], 1.0 / 3.0, accuracy: 1e-4)   // sees 0,0,1 window? → (0+0+1)/3
        XCTAssertEqual(out[8], 2.0 / 3.0, accuracy: 1e-4)
    }

    // 3) Blur wraps horizontally (globe seam) — an impulse at x=0 leaks to x=w-1.
    func testBlurWrapsHorizontally() {
        let w = 8, h = 1
        var field = [Float](repeating: 0, count: w)
        field[0] = 1
        let out = WorldToyMask.boxBlur(field, width: w, height: h, radius: 1)
        XCTAssertGreaterThan(out[w - 1], 0)                 // wrapped
        XCTAssertEqual(out[w - 1], 1.0 / 3.0, accuracy: 1e-4)
        XCTAssertEqual(out[4], 0, accuracy: tol)            // far away untouched
    }

    // 4) Threshold is strictly binary.
    func testThreshold() {
        let out = WorldToyMask.threshold([0.0, 0.49, 0.5, 0.51, 1.0], cutoff: 0.5)
        XCTAssertEqual(out, [0, 0, 1, 1, 1])
    }

    // 5) Flat height field → straight-up normals.
    func testNormalMapFlat() {
        let n = WorldToyMask.normalMap(heights: [Float](repeating: 0.5, count: 6 * 4),
                                       width: 6, height: 4, strength: 3)
        for v in n {
            XCTAssertEqual(v.x, 0, accuracy: tol)
            XCTAssertEqual(v.y, 0, accuracy: tol)
            XCTAssertEqual(v.z, 1, accuracy: tol)
        }
    }

    // 6) A rising slope in +x tilts normals toward -x; all normals unit length.
    func testNormalMapSlopeAndLength() {
        let w = 8, h = 4
        var heights = [Float](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { heights[y * w + x] = Float(x) / Float(w) } }
        let n = WorldToyMask.normalMap(heights: heights, width: w, height: h, strength: 2)
        // interior pixel on the slope
        let v = n[1 * w + 3]
        XCTAssertLessThan(v.x, 0)
        for vec in n { XCTAssertEqual(Double(simd_length(vec)), 1.0, accuracy: 1e-4) }
    }
}
