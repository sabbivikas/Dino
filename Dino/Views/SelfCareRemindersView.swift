//
//  SelfCareRemindersView.swift
//  Dino
//
//  Four daily self-care nudges (water, eat, wind down, check-in). Toggling
//  a reminder schedules a repeating UNCalendarNotificationTrigger via
//  NotificationManager; toggling off cancels it. Permission-denied surfaces
//  a Settings-deep-link alert and reverts the toggle.
//

import SwiftUI
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
        name: "drink water",
        body: "hey, when did you last have water? 💧 dino thinks you should drink some now",
        defaultHour: 9, defaultMinute: 0
    ),
    SelfCareReminder(
        id: "selfcare-eat",
        icon: "🍽",
        name: "eat something",
        body: "dino noticed it might be lunchtime 🍽 have you eaten something today?",
        defaultHour: 12, defaultMinute: 30
    ),
    SelfCareReminder(
        id: "selfcare-rest",
        icon: "😴",
        name: "wind down",
        body: "time to slow down 🌙 dino is winding down too",
        defaultHour: 21, defaultMinute: 30
    ),
    SelfCareReminder(
        id: "selfcare-checkin",
        icon: "🌿",
        name: "check in with yourself",
        body: "how are you really doing today? 🌿 take a moment for yourself",
        defaultHour: 19, defaultMinute: 0
    )
]

struct SelfCareRemindersView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("a few gentle nudges")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(DinoTheme.textSecondary)
                    .padding(.horizontal, 4)

                ForEach(selfCareReminders) { r in
                    SelfCareReminderRow(reminder: r)
                }
            }
            .padding(20)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("self-care reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            _ = await NotificationManager.shared.requestPermissionDetailed()
        }
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
                        .font(.custom(DinoTheme.customFontName, size: 16))
                        .foregroundColor(DinoTheme.textPrimary)
                    if enabled {
                        Text(timeString)
                            .font(.custom(DinoTheme.customFontName, size: 11))
                            .foregroundColor(DinoTheme.textSecondary)
                    } else {
                        Text("off")
                            .font(.custom(DinoTheme.customFontName, size: 11))
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        enabled = newValue
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
        NotificationManager.shared.setSelfCareReminder(
            id: reminder.id,
            body: reminder.body,
            hour: hour,
            minute: minute
        ) { success in
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

    private func cancel() {
        NotificationManager.shared.cancelSelfCareReminder(id: reminder.id)
    }
}
