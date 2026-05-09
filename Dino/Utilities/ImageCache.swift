//
//  ImageCache.swift
//  Dino
//

import UIKit
import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 50 }
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}

extension Image {
    static func cached(_ name: String) -> Image {
        if let img = ImageCache.shared.image(forKey: name) {
            return Image(uiImage: img)
        }
        if let ui = UIImage(named: name) {
            ImageCache.shared.set(ui, forKey: name)
            return Image(uiImage: ui)
        }
        return Image(name)
    }
}

extension ImageCache {
    func preload(_ names: [String]) {
        Task.detached(priority: .background) {
            for name in names {
                if let ui = UIImage(named: name) {
                    await MainActor.run { self.set(ui, forKey: name) }
                }
            }
        }
    }
}
