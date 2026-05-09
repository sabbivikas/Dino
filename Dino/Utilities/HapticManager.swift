//
//  HapticManager.swift
//  Dino
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    private init() {}
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
