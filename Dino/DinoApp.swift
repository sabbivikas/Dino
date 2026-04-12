//
//  DinoApp.swift
//  Dino
//

import SwiftUI

@main
struct DinoApp: App {
    @StateObject private var dataManager = SharedDataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
