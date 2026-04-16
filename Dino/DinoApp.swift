//
//  DinoApp.swift
//  Dino
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("[App] Firebase configured")
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.notification.request.content.userInfo["action"] as? String ?? "home"
        Task { @MainActor in
            switch action {
            case "mood":       SharedDataManager.shared.deepLinkTab = 2
            case "journal":    SharedDataManager.shared.deepLinkTab = 1
            case "gratitude":  SharedDataManager.shared.deepLinkTab = 3
            default:           SharedDataManager.shared.deepLinkTab = 0
            }
        }
        completionHandler()
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct DinoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var dataManager = SharedDataManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncService = FirestoreSyncService.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(themeManager)
                .environmentObject(authManager)
                .environmentObject(syncService)
                .environmentObject(notificationManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
