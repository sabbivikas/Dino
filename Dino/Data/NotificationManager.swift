//
//  NotificationManager.swift
//  Dino
//

import Foundation
import UserNotifications
import Combine

extension Notification.Name {
    static let dinoOpenURL = Notification.Name("dinoOpenURL")
}

/// Holds a deep-link URL set by AppDelegate when a notification is tapped
/// before ContentView is subscribed. ContentView clears it after handling.
/// Touched only on the main thread (delegate callback + view lifecycle).
enum DinoPendingDeepLink {
    static var url: URL?
}

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
            // When master OFF or no permission, remove ONLY what this function manages
            // (NOT winddown.daily, NOT self-care, NOT plant nudges, NOT re_engagement)
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["daily_checkin", "streak_reminder", "selfcare-water", "selfcare-eat"]
            )
            return
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_checkin", "streak_reminder"]
        )

        if dailyCheckInEnabled { scheduleDailyCheckIn() }
        if streakReminderEnabled { scheduleStreakReminder() }

        scheduleDefaultRemindersIfNeeded()

        #if DEBUG
        printPendingNotifications()
        #endif
    }

    /// First-launch only — pre-populate routine + self-care reminders with sensible defaults
    /// and flip the matching @AppStorage toggles so SelfCareRemindersView reflects the state.
    private func scheduleDefaultRemindersIfNeeded() {
        let ud = UserDefaults.standard
        let key = "dino.defaultRemindersScheduled"
        guard !ud.bool(forKey: key) else { return }

        print("[Notifications] first launch — scheduling default routine + self-care reminders")
        scheduleBreathingReminder(hour: 8, minute: 0)
        scheduleJournalReminder(hour: 19, minute: 0)
        scheduleGratitudeReminder(hour: 20, minute: 0)
        setSelfCareReminder(id: "selfcare-water", body: "hey, when did you last have water? 💧", hour: 10, minute: 0) { _ in }
        setSelfCareReminder(id: "selfcare-eat",   body: "dino noticed it might be lunchtime 🍽", hour: 12, minute: 30) { _ in }

        ud.set(true, forKey: "selfcare-water.enabled")
        ud.set(10, forKey: "selfcare-water.hour"); ud.set(0, forKey: "selfcare-water.minute")
        ud.set(true, forKey: "selfcare-eat.enabled")
        ud.set(12, forKey: "selfcare-eat.hour"); ud.set(30, forKey: "selfcare-eat.minute")
        ud.set(true, forKey: "breathing_reminder.enabled")
        ud.set(8, forKey: "breathing_reminder.hour"); ud.set(0, forKey: "breathing_reminder.minute")
        ud.set(true, forKey: "journal_reminder.enabled")
        ud.set(19, forKey: "journal_reminder.hour"); ud.set(0, forKey: "journal_reminder.minute")
        ud.set(true, forKey: "gratitude_reminder.enabled")
        ud.set(20, forKey: "gratitude_reminder.hour"); ud.set(0, forKey: "gratitude_reminder.minute")

        ud.set(true, forKey: key)
    }

    // MARK: - Routine Reminders (breathing / journal / gratitude)

    func scheduleBreathingReminder(hour: Int, minute: Int) {
        var components = DateComponents()
        components.timeZone = .current
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let body = NudgeLibrary.random(from: NudgeLibrary.breathingReminder)
        scheduleNotification(id: "breathing_reminder", body: body, trigger: trigger)
    }

    func scheduleJournalReminder(hour: Int, minute: Int) {
        var components = DateComponents()
        components.timeZone = .current
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let body = NudgeLibrary.random(from: NudgeLibrary.journalReminder)
        scheduleNotification(id: "journal_reminder", body: body, trigger: trigger)
    }

    func scheduleGratitudeReminder(hour: Int, minute: Int) {
        var components = DateComponents()
        components.timeZone = .current
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let body = NudgeLibrary.random(from: NudgeLibrary.gratitudeReminder)
        scheduleNotification(id: "gratitude_reminder", body: body, trigger: trigger)
    }

    func cancelRoutineReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func scheduleNotification(id: String, body: String, trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "dino 🦕"
        content.body = body

        switch id {
        case "daily_checkin":
            content.categoryIdentifier = "DAILY_CHECKIN"
            content.userInfo = ["action": "mood"]
        case "streak_reminder":
            content.categoryIdentifier = "STREAK_REMINDER"
            content.userInfo = ["action": "mood"]
        case "breathing_reminder":
            content.categoryIdentifier = "WIND_DOWN"
            content.userInfo = ["action": "breathe"]
        case "journal_reminder":
            content.categoryIdentifier = "DAILY_CHECKIN"
            content.userInfo = ["action": "journal"]
        case "gratitude_reminder":
            content.userInfo = ["action": "gratitude"]
        default:
            break
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("[Notifications] \(id) schedule ERROR: \(error)")
            } else {
                print("[Notifications] \(id) scheduled with trigger: \(String(describing: trigger))")
            }
            #endif
        }
    }

    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            #if DEBUG
            print("🦕 PENDING NOTIFICATIONS (\(requests.count)):")
            requests.forEach { print("  - \($0.identifier): \($0.trigger.map { String(describing: $0) } ?? "no trigger")") }
            #endif
        }
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

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

        let title = NudgeLibrary.random(from: NudgeLibrary.windDown)
        let content = UNMutableNotificationContent()
        content.title = title
        if !routines.isEmpty {
            content.body = "tonight: " + routines.joined(separator: " · ")
        }
        content.sound = .default
        content.categoryIdentifier = "WIND_DOWN"
        content.userInfo = ["action": "journal"]

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

    private func scheduleDailyCheckIn() {
        var components = DateComponents()
        components.hour = checkInHour
        components.minute = checkInMinute

        let alreadyOpenedToday: Bool
        if let lastOpen = UserDefaults.standard.object(forKey: "dino.lastAppOpenDate") as? Date {
            alreadyOpenedToday = Calendar.current.isDateInToday(lastOpen)
        } else {
            alreadyOpenedToday = false
        }

        let trigger: UNCalendarNotificationTrigger
        if alreadyOpenedToday, let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            let cal = Calendar.current
            components.year = cal.component(.year, from: tomorrow)
            components.month = cal.component(.month, from: tomorrow)
            components.day = cal.component(.day, from: tomorrow)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let body = NudgeLibrary.random(from: NudgeLibrary.dailyCheckIn)
        scheduleNotification(id: "daily_checkin", body: body, trigger: trigger)
    }

    // MARK: - Streak Reminder

    private func scheduleStreakReminder() {
        var components = DateComponents()
        components.hour = min(23, checkInHour + 2)
        components.minute = checkInMinute

        let activityToday: Bool
        if let lastActivity = UserDefaults.standard.object(forKey: "dino.lastActivityDate") as? Date {
            activityToday = Calendar.current.isDateInToday(lastActivity)
        } else {
            activityToday = false
        }

        let trigger: UNCalendarNotificationTrigger
        if activityToday, let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            let cal = Calendar.current
            components.year = cal.component(.year, from: tomorrow)
            components.month = cal.component(.month, from: tomorrow)
            components.day = cal.component(.day, from: tomorrow)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let body = NudgeLibrary.random(from: NudgeLibrary.streakReminder)
        scheduleNotification(id: "streak_reminder", body: body, trigger: trigger)
    }

    // MARK: - Smart Skip Logic

    func userDidLogMood() {
        UserDefaults.standard.set(Date(), forKey: "dino.lastActivityDate")
        print("[Notifications] activity stamped (mood)")
    }

    func userDidLogActivity() {
        UserDefaults.standard.set(Date(), forKey: "dino.lastActivityDate")
        print("[Notifications] activity stamped")
    }

    /// Call this when user opens the app. Re-checks permission and reschedules if needed.
    func userDidOpenApp() {
        UserDefaults.standard.set(Date(), forKey: "dino.lastAppOpenDate")
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

    // MARK: - Plant Nudges (driven by growth events)

    private static let plantNudgesKey = "dino.plantNudgesEnabled"
    private static let lastSeenBloomKey = "dino.lastSeenBloomCount"
    private static let previousStreakKey = "dino.previousStreak"

    var plantNudgesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.plantNudgesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.plantNudgesKey) }
    }

    func schedulePlantDyingNudge() {
        #if DEBUG
        let dyingDelay: TimeInterval = 10
        #else
        let dyingDelay: TimeInterval = 3 * 60 * 60
        #endif
        print("🌱 SCHEDULING PLANT DYING NUDGE — fires in \(Int(dyingDelay))s")
        schedulePlantNudge(
            identifier: "plant_dying_nudge",
            body: NudgeLibrary.random(from: NudgeLibrary.plantDying),
            delaySeconds: dyingDelay
        )
    }

    func schedulePlantProgressNudge() {
        print("🌱 SCHEDULING PLANT PROGRESS NUDGE")
        schedulePlantNudge(
            identifier: "plant_progress_nudge",
            body: NudgeLibrary.random(from: NudgeLibrary.plantProgressing),
            delaySeconds: 60
        )
    }

    func schedulePlantBloomingNudge() {
        print("🌱 SCHEDULING PLANT BLOOMING NUDGE — level up!")
        schedulePlantNudge(
            identifier: "plant_blooming_nudge",
            body: NudgeLibrary.random(from: NudgeLibrary.plantBlooming),
            delaySeconds: 60
        )
    }

    private func schedulePlantNudge(identifier: String, body: String, delaySeconds: TimeInterval) {
        guard notificationsEnabled, plantNudgesEnabled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard self != nil else { return }
            DispatchQueue.main.async {
                guard Self.isPermissionGranted(settings.authorizationStatus) else { return }
                let content = UNMutableNotificationContent()
                content.title = "dino"
                content.body = body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                center.add(request) { error in
                    #if DEBUG
                    if let error = error {
                        print("[Nudge] plant schedule failed for \(identifier): \(error)")
                    } else {
                        print("[Nudge] plant scheduled \(identifier) in \(Int(delaySeconds))s")
                    }
                    #endif
                }
            }
        }
    }

    /// Inspect growth state and fire the right plant nudge (if any).
    /// Priority: bloom celebration > progress milestone > dying.
    /// Bloom proxy = GrowthStats.level (we have no separate bloomCount field).
    func checkAndSchedulePlantNudge(streakData: StreakData, growthStats: GrowthStats) {
        let ud = UserDefaults.standard
        let currentBloom = growthStats.level
        let lastSeenBloom = ud.integer(forKey: Self.lastSeenBloomKey)
        if currentBloom > lastSeenBloom {
            print("🌱 BLOOM TRIGGERED: bloom \(lastSeenBloom) → \(currentBloom)")
            schedulePlantBloomingNudge()
            ud.set(currentBloom, forKey: Self.lastSeenBloomKey)
            ud.set(streakData.currentStreak, forKey: Self.previousStreakKey)
            return
        }
        if [7, 14, 21].contains(streakData.currentStreak) {
            let previous = ud.integer(forKey: Self.previousStreakKey)
            if previous != streakData.currentStreak {
                print("🌱 PROGRESS TRIGGERED: streak hit \(streakData.currentStreak)")
                schedulePlantProgressNudge()
            } else {
                print("🌱 PLANT CHECK no action")
            }
            ud.set(streakData.currentStreak, forKey: Self.previousStreakKey)
            return
        }
        let previous = ud.integer(forKey: Self.previousStreakKey)
        if streakData.currentStreak == 0 && previous > 0 {
            print("🌱 DYING TRIGGERED: streak dropped from \(previous) → 0")
            schedulePlantDyingNudge()
        } else {
            print("🌱 PLANT CHECK no action")
        }
        ud.set(streakData.currentStreak, forKey: Self.previousStreakKey)
    }

    // MARK: - Test Notification

    /// Send a test notification in 5 seconds to verify the system works.
    /// Schedules the rhythms "letter from the forest" for a specific date — the
    /// night before a day the pattern engine confidently predicts will be hard.
    /// Tapping opens the letter envelope via the "rhythmsletter" deep link.
    func scheduleRhythmsLetter(at fireDate: Date) {
        guard notificationsEnabled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard Self.isPermissionGranted(settings.authorizationStatus) else { return }
            let content = UNMutableNotificationContent()
            content.title = "a letter from the forest 🌲"
            content.body = "something arrived for tomorrow. tap to read it."
            content.sound = .default
            content.userInfo = ["action": "rhythmsletter"]

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "rhythms_letter", content: content, trigger: trigger)
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["rhythms_letter"])
            center.add(request) { error in
                #if DEBUG
                if let error = error { print("[Rhythms] letter schedule ERROR: \(error)") }
                #endif
            }
        }
    }

    #if DEBUG
    /// Manual QA helper: fire the rhythms letter notification in ~5s (no
    /// network). Pair with RhythmsLetterScheduler.scheduleTestLetter().
    func scheduleRhythmsLetterTest() {
        let content = UNMutableNotificationContent()
        content.title = "a letter from the forest 🌲"
        content.body = "something arrived for tomorrow. tap to read it."
        content.sound = .default
        content.userInfo = ["action": "rhythmsletter"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rhythms_letter_test", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    #endif

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

    /// Always-on debug — prints permission state and all pending requests.
    /// Intentionally not gated by #if DEBUG so it shows on TestFlight too.
    func debugNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🦕 NOTIF PERMISSION: \(settings.authorizationStatus.rawValue)")
            print("🦕 ALERT: \(settings.alertSetting.rawValue)")
            print("🦕 SOUND: \(settings.soundSetting.rawValue)")
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("🦕 PENDING COUNT: \(requests.count)")
            requests.forEach { r in
                print("🦕 PENDING: \(r.identifier) | \(r.content.body) | trigger: \(String(describing: r.trigger))")
            }
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
