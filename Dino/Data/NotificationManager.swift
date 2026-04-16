//
//  NotificationManager.swift
//  Dino
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    // User preferences — persisted via UserDefaults
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notif_enabled"); rescheduleAll() }
    }
    @Published var dailyCheckInEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyCheckInEnabled, forKey: "notif_dailyCheckIn"); rescheduleAll() }
    }
    @Published var streakReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(streakReminderEnabled, forKey: "notif_streakReminder"); rescheduleAll() }
    }
    @Published var windDownEnabled: Bool {
        didSet { UserDefaults.standard.set(windDownEnabled, forKey: "notif_windDown"); rescheduleAll() }
    }
    @Published var checkInHour: Int {
        didSet { UserDefaults.standard.set(checkInHour, forKey: "notif_checkInHour"); rescheduleAll() }
    }
    @Published var checkInMinute: Int {
        didSet { UserDefaults.standard.set(checkInMinute, forKey: "notif_checkInMinute"); rescheduleAll() }
    }
    @Published var hasPermission: Bool = false

    private init() {
        let ud = UserDefaults.standard
        self.notificationsEnabled = ud.object(forKey: "notif_enabled") as? Bool ?? true
        self.dailyCheckInEnabled = ud.object(forKey: "notif_dailyCheckIn") as? Bool ?? true
        self.streakReminderEnabled = ud.object(forKey: "notif_streakReminder") as? Bool ?? true
        self.windDownEnabled = ud.object(forKey: "notif_windDown") as? Bool ?? true
        self.checkInHour = ud.object(forKey: "notif_checkInHour") as? Int ?? 19 // 7pm default
        self.checkInMinute = ud.object(forKey: "notif_checkInMinute") as? Int ?? 0

        checkPermissionStatus()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            hasPermission = granted
            print("[Notifications] permission: \(granted)")
            if granted { rescheduleAll() }
            return granted
        } catch {
            print("[Notifications] permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.hasPermission = settings.authorizationStatus == .authorized
                print("[Notifications] current permission: \(self.hasPermission)")
            }
        }
    }

    // MARK: - Scheduling

    func rescheduleAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[Notifications] cleared all pending")

        guard notificationsEnabled && hasPermission else {
            print("[Notifications] disabled or no permission — skipping schedule")
            return
        }

        if dailyCheckInEnabled { scheduleDailyCheckIn() }
        if streakReminderEnabled { scheduleStreakReminder() }
        if windDownEnabled { scheduleWindDown() }
    }

    // MARK: - Daily Check-in

    private let checkInMessages = [
        ("how are you feeling today?", "take a moment to check in with yourself"),
        ("pause for a second", "your feelings matter. let's check in."),
        ("hey, how's your day going?", "a quick reflection can make all the difference"),
        ("a gentle reminder", "you deserve a moment of stillness today"),
        ("checking in on you", "how's your emotional weather right now?"),
    ]

    private func scheduleDailyCheckIn() {
        let message = checkInMessages.randomElement() ?? checkInMessages[0]

        var dateComponents = DateComponents()
        dateComponents.hour = checkInHour
        dateComponents.minute = checkInMinute

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default
        content.categoryIdentifier = "DAILY_CHECKIN"
        content.userInfo = ["action": "mood"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_checkin", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] daily check-in schedule ERROR: \(error)")
            } else {
                print("[Notifications] daily check-in scheduled at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
        }
    }

    // MARK: - Streak Reminder

    private let streakMessages = [
        ("keep your streak alive", "one small check-in is all it takes"),
        ("don't break the chain", "your streak is worth protecting"),
        ("you've been showing up", "keep the momentum going today"),
        ("just one moment today", "your future self will thank you"),
    ]

    private func scheduleStreakReminder() {
        let message = streakMessages.randomElement() ?? streakMessages[0]

        // Schedule for 2 hours after check-in time as a fallback
        var dateComponents = DateComponents()
        dateComponents.hour = min(23, checkInHour + 2)
        dateComponents.minute = checkInMinute

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"
        content.userInfo = ["action": "mood"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] streak reminder schedule ERROR: \(error)")
            } else {
                print("[Notifications] streak reminder scheduled at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
        }
    }

    // MARK: - Wind-down

    private let windDownMessages = [
        ("time to slow down", "how was your day? let's reflect."),
        ("the day is winding down", "take a breath before sleep"),
        ("evening check-in", "what's one thing you're grateful for today?"),
        ("settling in for the night", "a moment of calm before rest"),
    ]

    private func scheduleWindDown() {
        let message = windDownMessages.randomElement() ?? windDownMessages[0]

        var dateComponents = DateComponents()
        dateComponents.hour = 21 // 9pm
        dateComponents.minute = 30

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default
        content.categoryIdentifier = "WIND_DOWN"
        content.userInfo = ["action": "journal"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "wind_down", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] wind-down schedule ERROR: \(error)")
            } else {
                print("[Notifications] wind-down scheduled at 21:30")
            }
        }
    }

    // MARK: - Smart Skip Logic

    /// Call this when user logs a mood. Removes today's pending streak reminder.
    func userDidLogMood() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])
        print("[Notifications] streak reminder removed — user already logged mood today")
    }

    /// Call this when user opens the app. Checks if we should suppress notifications.
    func userDidOpenApp() {
        checkPermissionStatus()
        print("[Notifications] app opened — checking status")
    }

    // MARK: - Re-engagement

    /// Schedule a gentle re-engagement notification for users inactive for 3+ days.
    /// Call this on app launch or background.
    func scheduleReEngagementIfNeeded() {
        guard notificationsEnabled && hasPermission else { return }

        let reEngagementMessages = [
            ("we miss you", "even a small moment of reflection helps"),
            ("hey, it's been a while", "your dino misses you. come say hi."),
            ("no pressure", "whenever you're ready, we're here"),
        ]

        let message = reEngagementMessages.randomElement() ?? reEngagementMessages[0]

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default
        content.userInfo = ["action": "home"]

        // Fire 3 days from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "re_engagement", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] re-engagement schedule ERROR: \(error)")
            } else {
                print("[Notifications] re-engagement scheduled for 3 days from now")
            }
        }
    }
}
