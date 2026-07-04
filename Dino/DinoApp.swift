//
//  DinoApp.swift
//  Dino
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UserNotifications
import PostHog

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("[App] Firebase configured")
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        return true
    }

    private func registerNotificationCategories() {
        let logMoodAction = UNNotificationAction(
            identifier: "LOG_MOOD",
            title: "log mood 🌿",
            options: [.foreground]
        )
        let openJournalAction = UNNotificationAction(
            identifier: "OPEN_JOURNAL",
            title: "open journal ✍️",
            options: [.foreground]
        )
        let logActivityAction = UNNotificationAction(
            identifier: "LOG_ACTIVITY",
            title: "log something 🌱",
            options: [.foreground]
        )
        let startBreathingAction = UNNotificationAction(
            identifier: "START_BREATHING",
            title: "breathe with dino 🌬️",
            options: [.foreground]
        )

        let checkInCategory = UNNotificationCategory(
            identifier: "DAILY_CHECKIN",
            actions: [logMoodAction, openJournalAction],
            intentIdentifiers: []
        )
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [logActivityAction],
            intentIdentifiers: []
        )
        let windDownCategory = UNNotificationCategory(
            identifier: "WIND_DOWN",
            actions: [startBreathingAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories(
            [checkInCategory, streakCategory, windDownCategory]
        )
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // Handle notification taps and action buttons
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier

        let path: String?
        switch identifier {
        case "LOG_MOOD":
            path = "dino://mood"
        case "OPEN_JOURNAL":
            path = "dino://journal"
        case "LOG_ACTIVITY":
            path = "dino://mood"
        case "START_BREATHING":
            path = "dino://breathe"
        case UNNotificationDefaultActionIdentifier:
            switch category {
            case "DAILY_CHECKIN":   path = "dino://mood"
            case "STREAK_REMINDER": path = "dino://mood"
            case "WIND_DOWN":       path = "dino://breathe"
            default:
                let action = response.notification.request.content.userInfo["action"] as? String ?? "home"
                switch action {
                case "mood":          path = "dino://mood"
                case "journal":       path = "dino://journal"
                case "gratitude":     path = "dino://gratitude"
                case "rhythmsletter": path = "dino://rhythmsletter"
                case "meditation":    path = "dino://meditation"
                case "breathe":       path = "dino://breathe"
                default:              path = nil
                }
            }
        default:
            path = nil
        }

        if let path = path, let url = URL(string: path) {
            DinoPendingDeepLink.url = url
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dinoOpenURL, object: url)
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionStartTime: Date = Date()

    init() {
        let config = PostHogConfig(
            projectToken: "phc_sjfNi7Wc5A9EKLuAcDN8LPUaCGcXnywCmryM6aWz2obb",
            host: "https://us.i.posthog.com"
        )
        // Manual app_opened / app_backgrounded / session_* events are richer
        // and already firing; autocapture would duplicate them.
        config.captureApplicationLifecycleEvents = false
        PostHogSDK.shared.setup(config)

        PostHogSDK.shared.register([
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "platform": "iOS"
        ])

        // One-time migration: gestures swapped (tap now opens calendar, long-press pauses).
        // Re-show the hint so existing users discover the new behavior.
        let ud = UserDefaults.standard
        let hintVersionKey = "dino.streakHintVersion"
        let currentHintVersion = 2
        if ud.integer(forKey: hintVersionKey) < currentHintVersion {
            ud.set(false, forKey: "dino.streakHintSeen")
            ud.set(currentHintVersion, forKey: hintVersionKey)
        }
    }
    @StateObject private var dataManager = SharedDataManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncService = FirestoreSyncService.shared
    @StateObject private var notificationManager = NotificationManager.shared

    // Observing this @AppStorage value causes the entire view tree to re-render
    // when the user adjusts text size — propagating the new scale into every
    // DinoTheme.dinoFont / numericFont call downstream.
    @AppStorage("text_size_scale") private var textSizeScale: Double = 1.0

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
                .task {
                    notificationManager.userDidOpenApp()

                    // Request permission if not yet decided
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    if settings.authorizationStatus == .notDetermined {
                        _ = await notificationManager.requestPermissionDetailed()
                    } else if settings.authorizationStatus == .authorized
                              || settings.authorizationStatus == .provisional {
                        notificationManager.rescheduleAll()
                    }

                    #if DEBUG
                    notificationManager.debugNotificationStatus()
                    #endif

                    await IdentityLifecycleManager.shared.handleColdStart()
                    ImageCache.shared.preload(["DinoMascot", "dino-meditation", "DinoFlower-cut", "cut-DinoChecklist", "dino-only"])
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        sessionStartTime = Date()
                        AnalyticsManager.shared.trackSessionStarted()
                        // Foreground return → app_opened(open_type: foreground).
                        // (onChange does not fire for the initial active at mount,
                        // so the cold-launch active is never misclassified here.)
                        IdentityLifecycleManager.shared.handleForegroundReturn()
                        // Evening check: schedule a night-before rhythms letter
                        // if tomorrow is confidently predicted to be hard.
                        Task { await RhythmsLetterScheduler.shared.evaluateAndScheduleIfNeeded() }
                        // DinoMind: generate today's smart check-in nudge (once/day).
                        Task { await DailyNudgeScheduler.generateIfNeeded() }
                    case .inactive, .background:
                        let duration = Date().timeIntervalSince(sessionStartTime)
                        if duration > 0 {
                            AnalyticsManager.shared.trackAppBackgrounded(sessionDuration: duration)
                            AnalyticsManager.shared.trackSessionEnded(durationSeconds: Int(duration))
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
}
