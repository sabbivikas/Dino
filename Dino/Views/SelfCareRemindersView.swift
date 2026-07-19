//
//  SelfCareRemindersView.swift
//  Dino
//
//  Two daily self-care nudges (water, eat). Toggling a reminder schedules a
//  repeating UNCalendarNotificationTrigger via NotificationManager; toggling
//  off cancels it. Permission-denied surfaces a Settings-deep-link alert and
//  reverts the toggle.
//

import SwiftUI
import UserNotifications
import UIKit

private struct SelfCareReminder: Identifiable {
    let id: String
    let icon: String
    let name: String
    let body: String
    let defaultHour: Int
    let defaultMinute: Int
}

private let selfCareReminders: [SelfCareReminder] = [
    SelfCareReminder(
        id: "selfcare-water",
        icon: "💧",
        name: String(localized: "drink water"),
        body: String(localized: "hey, when did you last have water? 💧 dino thinks you should drink some now"),
        defaultHour: 9, defaultMinute: 0
    ),
    SelfCareReminder(
        id: "selfcare-eat",
        icon: "🍽",
        name: String(localized: "eat something"),
        body: String(localized: "dino noticed it might be lunchtime 🍽 have you eaten something today?"),
        defaultHour: 12, defaultMinute: 30
    ),
    SelfCareReminder(
        id: "breathing_reminder",
        icon: "🌬️",
        name: String(localized: "breathing"),
        body: String(localized: "hey take a breath with dino 🌬️"),
        defaultHour: 8, defaultMinute: 0
    ),
    SelfCareReminder(
        id: "journal_reminder",
        icon: "✍️",
        name: String(localized: "journal"),
        body: String(localized: "your journal is waiting 📝"),
        defaultHour: 19, defaultMinute: 0
    ),
    SelfCareReminder(
        id: "gratitude_reminder",
        icon: "🫙",
        name: String(localized: "gratitude"),
        body: String(localized: "drop one small good thing in the jar today 🫙"),
        defaultHour: 20, defaultMinute: 0
    )
]

struct SelfCareRemindersView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("a few gentle nudges")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(DinoTheme.textSecondary)
                    .padding(.horizontal, 4)

                ForEach(selfCareReminders) { r in
                    SelfCareReminderRow(reminder: r)
                }

                #if DEBUG
                Button {
                    print("🦕 TEST BUTTON TAPPED")
                    let content = UNMutableNotificationContent()
                    content.title = "dino test"
                    content.body = "if you see this in 5 seconds, notifications work"
                    content.sound = .default
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    let request = UNNotificationRequest(identifier: "dino.test.button", content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("🦕 TEST FAILED: \(error)")
                        } else {
                            print("🦕 TEST SCHEDULED for 5s")
                        }
                    }
                    NotificationManager.shared.debugNotificationStatus()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("test notifications")
                            .font(DinoTheme.dinoFont(size: 14))
                    }
                    .foregroundColor(DinoTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
                    )
                }
                .padding(.top, 8)
                #endif
            }
            .padding(20)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("self-care reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SelfCareReminderRow: View {
    let reminder: SelfCareReminder
    @AppStorage private var enabled: Bool
    @AppStorage private var hour: Int
    @AppStorage private var minute: Int
    @State private var showPermissionAlert: Bool = false

    init(reminder: SelfCareReminder) {
        self.reminder = reminder
        _enabled = AppStorage(wrappedValue: false, "\(reminder.id).enabled")
        _hour    = AppStorage(wrappedValue: reminder.defaultHour, "\(reminder.id).hour")
        _minute  = AppStorage(wrappedValue: reminder.defaultMinute, "\(reminder.id).minute")
    }

    private var time: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = hour; c.minute = minute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour = c.hour ?? hour
                minute = c.minute ?? minute
                if enabled {
                    schedule()
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(reminder.icon)
                    .font(.system(size: 26))
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.name)
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(DinoTheme.textPrimary)
                    if enabled {
                        Text(timeString)
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(DinoTheme.textSecondary)
                    } else {
                        Text("off")
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        enabled = newValue
                        AnalyticsManager.shared.trackSelfCareReminderToggled(type: reminder.id, enabled: newValue)
                        if newValue {
                            schedule()
                        } else {
                            cancel()
                        }
                    }
                ))
                .labelsHidden()
                .tint(DinoTheme.accent)
            }

            if enabled {
                DatePicker("time", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DinoTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
        .alert("notifications are off", isPresented: $showPermissionAlert) {
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("to receive self-care reminders, enable notifications for Dino in iPhone Settings → Notifications → Dino")
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: time.wrappedValue).lowercased()
    }

    private func schedule() {
        print("🦕 SCHEDULING: \(reminder.id) at \(hour):\(String(format: "%02d", minute))")
        switch reminder.id {
        case "breathing_reminder":
            NotificationManager.shared.scheduleBreathingReminder(hour: hour, minute: minute)
            completePermissionCheck()
        case "journal_reminder":
            NotificationManager.shared.scheduleJournalReminder(hour: hour, minute: minute)
            completePermissionCheck()
        case "gratitude_reminder":
            NotificationManager.shared.scheduleGratitudeReminder(hour: hour, minute: minute)
            completePermissionCheck()
        default:
            NotificationManager.shared.setSelfCareReminder(
                id: reminder.id,
                body: reminder.body,
                hour: hour,
                minute: minute
            ) { success in
                print("🦕 SCHEDULE RESULT for \(reminder.id): success=\(success)")
                if !success {
                    enabled = false
                    showPermissionAlert = true
                } else {
                    #if DEBUG
                    NotificationManager.shared.debugPendingNotifications()
                    #endif
                }
            }
        }
    }

    private func completePermissionCheck() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status = settings.authorizationStatus
                let ok = status == .authorized || status == .provisional || status == .ephemeral
                if !ok {
                    self.enabled = false
                    self.showPermissionAlert = true
                }
            }
        }
    }

    private func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id])
    }
}
