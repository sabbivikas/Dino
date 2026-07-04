//
//  LanternLathe.swift
//  Dino
//
//  Pure lathe (surface-of-revolution) generator for the paper sky-lantern:
//  narrow mouth → full belly → rounded crown. SceneKit has no lathe primitive,
//  so we revolve a 2D (y, radius) profile ourselves. The mesh math is pure and
//  unit-tested; only the SCNGeometry wrapper touches SceneKit.
//

import Foundation
import simd

enum LanternLathe {

    /// The locked sky-lantern silhouette (y up, height 1): narrow open mouth
    /// at the bottom, full belly, gently rounded crown.
    static let skyLanternProfile: [(y: Float, r: Float)] = [
        (0.00, 0.16),   // mouth rim (open)
        (0.06, 0.22),
        (0.18, 0.30),
        (0.38, 0.34),   // belly
        (0.60, 0.32),
        (0.78, 0.26),
        (0.92, 0.16),
        (1.00, 0.05),   // rounded crown, nearly closed
    ]

    struct Mesh {
        let positions: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        let uvs: [SIMD2<Float>]
        let indices: [UInt32]
    }

    /// Revolves `profile` around the Y axis. `segments` ≥ 3. Columns are
    /// segments+1 (seam duplicated for clean UV wrap); triangles wind outward.
    static func mesh(profile: [(y: Float, r: Float)] = skyLanternProfile,
                     segments: Int = 24) -> Mesh {
        let rings = profile.count
        guard rings >= 2, segments >= 3 else {
            return Mesh(positions: [], normals: [], uvs: [], indices: [])
        }
        let cols = segments + 1
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity(rings * cols)

        for i in 0..<rings {
            let (y, r) = profile[i]
            // Profile tangent from neighbors → outward surface normal (dy, -dr).
            let prev = profile[max(0, i - 1)]
            let next = profile[min(rings - 1, i + 1)]
            let dy = next.y - prev.y
            let dr = next.r - prev.r
            let len = max(sqrt(dy * dy + dr * dr), 1e-6)
            let nRadial = dy / len
            let nY = -dr / len

            for s in 0..<cols {
                let a = Float(s) / Float(segments) * 2 * .pi
                let ca = cos(a), sa = sin(a)
                positions.append(SIMD3(r * ca, y, r * sa))
                normals.append(simd_normalize(SIMD3(nRadial * ca, nY, nRadial * sa)))
                uvs.append(SIMD2(Float(s) / Float(segments), 1 - profile[i].y))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity((rings - 1) * segments * 6)
        for i in 0..<(rings - 1) {
            for s in 0..<segments {
                let a = UInt32(i * cols + s)
                let b = UInt32((i + 1) * cols + s)
                let c = UInt32(i * cols + s + 1)
                let d = UInt32((i + 1) * cols + s + 1)
                indices.append(contentsOf: [a, b, c, c, b, d])
            }
        }
        return Mesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }
}

#if canImport(SceneKit)
import SceneKit

extension LanternLathe {
    /// Thin SceneKit wrapper around the pure mesh.
    static func geometry(profile: [(y: Float, r: Float)] = skyLanternProfile,
                         segments: Int = 24) -> SCNGeometry {
        let m = mesh(profile: profile, segments: segments)
        let positions = m.positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let normals = m.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let uvs = m.uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        var idx = m.indices
        let element = SCNGeometryElement(data: Data(bytes: &idx, count: idx.count * 4),
                                         primitiveType: .triangles,
                                         primitiveCount: idx.count / 3,
                                         bytesPerIndex: 4)
        return SCNGeometry(sources: [SCNGeometrySource(vertices: positions),
                                     SCNGeometrySource(normals: normals),
                                     SCNGeometrySource(textureCoordinates: uvs)],
                           elements: [element])
    }
}
#endif
