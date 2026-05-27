//
//  AppUpdateService.swift
//  Dino
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    private init() {}

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var appStoreURL: URL? = nil
    @Published var bannerDismissed: Bool = false

    private let bundleId = "com.vikassabbi.dino"

    func checkForUpdate() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let appStoreVersion = first["version"] as? String else { return }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            latestVersion = appStoreVersion

            if let urlString = first["trackViewUrl"] as? String {
                appStoreURL = URL(string: urlString)
            }

            let isNewer = appStoreVersion.compare(currentVersion, options: .numeric) == .orderedDescending
            #if DEBUG
            print("[Update] current=\(currentVersion) latest=\(appStoreVersion) updateAvailable=\(isNewer)")
            #endif
            updateAvailable = isNewer
        } catch {
            #if DEBUG
            print("[Update] check failed: \(error)")
            #endif
        }
    }

    func dismissBanner() {
        bannerDismissed = true
    }
}
