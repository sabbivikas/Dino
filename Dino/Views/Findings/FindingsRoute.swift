//
//  FindingsRoute.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — the branch-owned deep-link route.
//
//  The finding push now carries dino://finding/{taskId} in its data payload.
//  AppDelegate already forwards userInfo["deepLink"], and ContentView's one
//  additive case parses it here and publishes the id; FindingsTabView observes
//  pendingTaskId, polls that task, opens its reveal, and clears the route.
//
//  WHY NOT SharedDataManager: that is a shipping file this branch may not
//  touch, so the published route state lives here instead. ContentView only
//  sets the already-existing deepLinkTab plus this branch-owned publisher.
//
//  English-only demo (owner decision): plain string literals only.
//

import Foundation
import Combine

final class FindingsRoute: ObservableObject {
    static let shared = FindingsRoute()
    private init() {}

    /// Set by the deep link, consumed (and cleared) by FindingsTabView.
    @Published var pendingTaskId: String?

    /// Strict parse of dino://finding/{taskId} — anything malformed is nil
    /// (silence, never a broken door). Mirrors RecRevealLink.from(url:).
    static func taskId(from url: URL) -> String? {
        guard url.scheme == "dino", url.host == "finding" else { return nil }
        let id = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
        guard !id.isEmpty, id != "/" else { return nil }
        return id
    }
}
