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

    private var isInitializing = true

    private static func isPermissionGranted(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private init() {
        let ud = UserDefaults.standard
        self.notificationsEnabled = ud.object(forKey: "notif_enabled") as? Bool ?? true
        self.dailyCheckInEnabled = ud.object(forKey: "notif_dailyCheckIn") as? Bool ?? true
        self.streakReminderEnabled = ud.object(forKey: "notif_streakReminder") as? Bool ?? true
        self.windDownEnabled = ud.object(forKey: "notif_windDown") as? Bool ?? true
        self.checkInHour = ud.object(forKey: "notif_checkInHour") as? Int ?? 19 // 7pm default
        self.checkInMinute = ud.object(forKey: "notif_checkInMinute") as? Int ?? 0
        self.isInitializing = false

        checkPermissionStatus()
    }

    // MARK: - Permission

    /// Result of a permission request. `shouldShowSettingsAlert` is true when
    /// the user previously denied — iOS will NOT re-prompt, so the caller
    /// should surface a "go to Settings" alert instead.
    struct PermissionResult {
        let granted: Bool
        let shouldShowSettingsAlert: Bool
    }

    /// Preferred permission request — distinguishes "freshly denied" from
    /// "previously denied" so callers can route the latter to Settings.
    func requestPermissionDetailed() async -> PermissionResult {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                hasPermission = granted
                print("[Notifications] permission (fresh prompt): \(granted)")
                if granted { rescheduleAll() }
                return PermissionResult(granted: granted, shouldShowSettingsAlert: false)
            } catch {
                #if DEBUG
                print("[Notifications] permission error")
                #endif
                return PermissionResult(granted: false, shouldShowSettingsAlert: false)
            }
        case .denied:
            // iOS will NOT re-prompt — caller should show a Settings alert.
            hasPermission = false
            print("[Notifications] permission previously denied — need Settings alert")
            return PermissionResult(granted: false, shouldShowSettingsAlert: true)
        case .authorized, .provisional, .ephemeral:
            hasPermission = true
            rescheduleAll()
            return PermissionResult(granted: true, shouldShowSettingsAlert: false)
        @unknown default:
            return PermissionResult(granted: false, shouldShowSettingsAlert: false)
        }
    }

    /// Back-compat wrapper for existing call sites that only care about granted/not.
    func requestPermission() async -> Bool {
        await requestPermissionDetailed().granted
    }

    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                let wasGranted = self.hasPermission
                self.hasPermission = Self.isPermissionGranted(settings.authorizationStatus)
                print("[Notifications] current permission: \(self.hasPermission)")
                // If permission just became available, schedule notifications
                if self.hasPermission && !wasGranted {
                    self.rescheduleAll()
                }
            }
        }
    }

    // MARK: - Scheduling

    func rescheduleAll() {
        guard !isInitializing else { return }

        guard notificationsEnabled && hasPermission else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            print("[Notifications] disabled or no permission — cleared all pending")
            return
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[Notifications] cleared all pending, rescheduling...")

        if dailyCheckInEnabled { scheduleDailyCheckIn() }
        if streakReminderEnabled { scheduleStreakReminder() }
        if windDownEnabled { scheduleWindDown() }
    }

    // MARK: - Wind-down (configurable — routines + custom time)

    /// Called from WindDownView when user changes wind-down settings.
    func rescheduleWindDown() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["winddown.daily"])

        guard hasPermission && notificationsEnabled else { return }

        let ud = UserDefaults.standard
        let enabled = ud.bool(forKey: "wind_down_enabled")
        guard enabled else {
            print("[Notifications] wind-down (configurable) disabled — cleared")
            return
        }

        let interval = ud.double(forKey: "wind_down_time")
        var hour = 21
        var minute = 30
        if interval != 0 {
            let date = Date(timeIntervalSinceReferenceDate: interval)
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            hour = comps.hour ?? 21
            minute = comps.minute ?? 30
        }

        var routines: [String] = []
        let breathing = ud.object(forKey: "wind_down_breathing") as? Bool ?? true
        let journal   = ud.object(forKey: "wind_down_journal") as? Bool ?? true
        let gratitude = ud.object(forKey: "wind_down_gratitude") as? Bool ?? true
        if breathing { routines.append("breathing") }
        if journal { routines.append("journal") }
        if gratitude { routines.append("gratitude") }

        let messages = [
            "time to wind down gently",
            "the day is softening, so can you",
            "a quiet moment is waiting for you",
            "close the day kindly",
            "rest is a practice too",
        ]

        let content = UNMutableNotificationContent()
        content.title = messages[Calendar.current.component(.dayOfYear, from: Date()) % messages.count]
        if !routines.isEmpty {
            content.body = "tonight: " + routines.joined(separator: " · ")
        }
        content.sound = .default
        content.categoryIdentifier = "WIND_DOWN"
        content.userInfo = ["action": "journal"]

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: "winddown.daily",
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("[Notifications] wind-down (configurable) schedule ERROR: \(error)")
            } else {
                print("[Notifications] wind-down (configurable) scheduled at \(hour):\(String(format: "%02d", minute))")
            }
            #endif
        }
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
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let message = checkInMessages[dayOfYear % checkInMessages.count]

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
            #if DEBUG
            if let error = error {
                print("[Notifications] daily check-in schedule ERROR: \(error)")
            } else {
                print("[Notifications] daily check-in scheduled at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
            #endif
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
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let message = streakMessages[dayOfYear % streakMessages.count]

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
            #if DEBUG
            if let error = error {
                print("[Notifications] streak reminder schedule ERROR: \(error)")
            } else {
                print("[Notifications] streak reminder scheduled at \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
            }
            #endif
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
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let message = windDownMessages[dayOfYear % windDownMessages.count]

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
            #if DEBUG
            if let error = error {
                print("[Notifications] wind-down schedule ERROR: \(error)")
            } else {
                print("[Notifications] wind-down scheduled at 21:30")
            }
            #endif
        }
    }

    // MARK: - Smart Skip Logic

    /// Call this when user logs a mood. Removes today's pending streak reminder.
    func userDidLogMood() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])
        print("[Notifications] streak reminder removed — user already logged mood today")
    }

    /// Call this when user opens the app. Re-checks permission and reschedules if needed.
    func userDidOpenApp() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.hasPermission = Self.isPermissionGranted(settings.authorizationStatus)
                print("[Notifications] app opened — permission: \(self.hasPermission)")
                if self.hasPermission && self.notificationsEnabled {
                    self.rescheduleAll()
                    self.scheduleReEngagementIfNeeded()
                }
                self.debugPrintPending()
            }
        }
    }

    // MARK: - Test Notification

    /// Send a test notification in 5 seconds to verify the system works.
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "dino is here"
        content.body = "notifications are working perfectly"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("[Notifications] test ERROR: \(error)")
            } else {
                print("[Notifications] test notification scheduled in 5s")
            }
            #endif
        }
    }

    /// Debug: print all pending notifications
    func debugPrintPending() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("[Notifications] \(requests.count) pending:")
            for r in requests {
                print("  - \(r.identifier): \(r.content.title) | trigger: \(String(describing: r.trigger))")
            }
        }
    }

    /// Debug helper — dumps pending notification requests. Logs only in DEBUG.
    func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            #if DEBUG
            print("[Reminders] Pending: \(requests.count)")
            for r in requests {
                print("[Reminders] - \(r.identifier): \(String(describing: r.trigger))")
            }
            #endif
        }
    }

    // MARK: - Self-care reminders

    /// Schedule a single repeating self-care reminder. Calls completion on
    /// the main queue with `true` on success, `false` if permission is
    /// denied or scheduling failed. Self-care reminders are an explicit
    /// per-reminder opt-in by the user (they tap a toggle), so this
    /// intentionally bypasses the master `notificationsEnabled` flag —
    /// system-level authorization is the only gate.
    func setSelfCareReminder(id: String, body: String, hour: Int, minute: Int, completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard Self.isPermissionGranted(settings.authorizationStatus) else {
                    #if DEBUG
                    print("[SelfCare] permission gate failed status=\(settings.authorizationStatus.rawValue)")
                    #endif
                    completion(false)
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "dino"
                content.body = body
                content.sound = .default

                var dc = DateComponents()
                dc.hour = hour
                dc.minute = minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [id])
                center.add(request) { error in
                    #if DEBUG
                    if let error = error {
                        print("[SelfCare] add failed for \(id): \(error)")
                    } else {
                        print("[SelfCare] add succeeded for \(id) at \(hour):\(String(format: "%02d", minute))")
                        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                            print("[SelfCare] pending count: \(reqs.count)")
                            for r in reqs where r.identifier.hasPrefix("selfcare-") {
                                print("[SelfCare]   \(r.identifier) trigger=\(String(describing: r.trigger))")
                            }
                        }
                    }
                    #endif
                    DispatchQueue.main.async {
                        completion(error == nil)
                    }
                }
            }
        }
    }

    func cancelSelfCareReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
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
            #if DEBUG
            if let error = error {
                print("[Notifications] re-engagement schedule ERROR: \(error)")
            } else {
                print("[Notifications] re-engagement scheduled for 3 days from now")
            }
            #endif
        }
    }
}
