//
//  GardenSnapshotBridge.swift
//  Dino
//
//  A weak hand-off of the live garden SCNView so the share flow can capture
//  the real 3D garden via SceneKit's GPU snapshot (ImageRenderer returns black
//  for SceneKit on device). Set when the garden scene appears, cleared when it
//  goes away — a single live garden panel, no retain, no leak.
//

import SceneKit

@MainActor
enum GardenSnapshotBridge {
    static weak var scnView: SCNView?
}
