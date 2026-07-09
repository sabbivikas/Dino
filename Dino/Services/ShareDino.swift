//
//  ShareDino.swift
//  Dino
//
//  Share-dino copy and the once-ever contextual moment logic. Never naggy:
//  the contextual row appears at ONE qualifying moment ever (first breathing
//  completion or lantern claim after install), then never again — whether
//  tapped, dismissed, or simply seen.
//

import Foundation

enum ShareDino {
    // App Store id verified live via itunes lookup (bundleId com.vikassabbi.dino).
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6763940737")!

    static let shareText = "i've been using dino, a tiny gentle companion for heavy days. thought of you 🦕"
    static let profileRowTitle = "share dino with someone who needs it 🦕"
    static let contextualLine = "know someone with heavy days too? dino fits in a pocket 🦕"

    static let contextShownKey = "dino.share.contextShown"

    /// Pure decision — true only before the one-and-only contextual showing.
    static func shouldShowContextual(alreadyShown: Bool) -> Bool {
        !alreadyShown
    }

    static var shareItems: [Any] { [shareText, appStoreURL] }

    @MainActor
    static func shouldShowContextualNow() -> Bool {
        shouldShowContextual(alreadyShown: UserDefaults.standard.bool(forKey: contextShownKey))
    }

    @MainActor
    static func markContextualShown() {
        UserDefaults.standard.set(true, forKey: contextShownKey)
    }
}
