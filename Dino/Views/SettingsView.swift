//
//  SettingsView.swift
//  Dino
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var notifManager = NotificationManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Notifications
                Section {
                    SettingsToggle(
                        icon: "bell.fill",
                        label: "notifications",
                        color: DinoTheme.sageGreen,
                        isOn: $notifManager.notificationsEnabled
                    )

                    if notifManager.notificationsEnabled {
                        SettingsToggle(
                            icon: "sun.max.fill",
                            label: "daily check-in",
                            color: DinoTheme.peach,
                            isOn: $notifManager.dailyCheckInEnabled
                        )

                        // Check-in time picker
                        if notifManager.dailyCheckInEnabled {
                            HStack(spacing: 14) {
                                Image(systemName: "clock")
                                    .font(DinoTheme.dinoFont(size: 16))
                                    .foregroundColor(DinoTheme.skyBlue)
                                    .frame(width: 32, height: 32)
                                    .background(DinoTheme.skyBlue.opacity(0.12))
                                    .cornerRadius(8)

                                Text("check-in time")
                                    .font(DinoTheme.bodyFont())
                                    .foregroundColor(DinoTheme.textPrimary)

                                Spacer()

                                DatePicker("", selection: Binding(
                                    get: {
                                        var components = DateComponents()
                                        components.hour = notifManager.checkInHour
                                        components.minute = notifManager.checkInMinute
                                        return Calendar.current.date(from: components) ?? Date()
                                    },
                                    set: { date in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        notifManager.checkInHour = components.hour ?? 19
                                        notifManager.checkInMinute = components.minute ?? 0
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                        }

                        SettingsToggle(
                            icon: "flame.fill",
                            label: "streak reminders",
                            color: .orange,
                            isOn: $notifManager.streakReminderEnabled
                        )

                        NavigationLink {
                            WindDownView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "moon.fill")
                                    .font(DinoTheme.dinoFont(size: 16))
                                    .foregroundColor(DinoTheme.lavender)
                                    .frame(width: 32, height: 32)
                                    .background(DinoTheme.lavender.opacity(0.12))
                                    .cornerRadius(8)
                                Text("wind-down")
                                    .font(DinoTheme.bodyFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            }
                        }
                    }
                } header: {
                    Text("notifications")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // Self-care reminders
                Section {
                    NavigationLink {
                        SelfCareRemindersView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.text.square.fill")
                                .font(DinoTheme.dinoFont(size: 16))
                                .foregroundColor(DinoTheme.warmRose)
                                .frame(width: 32, height: 32)
                                .background(DinoTheme.warmRose.opacity(0.12))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("self-care reminders")
                                    .font(DinoTheme.bodyFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                                Text("water, food")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("self-care")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)
            }
            .listStyle(.insetGrouped)
            .background(DinoTheme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DinoTheme.sageGreen)
                }
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)

            Text(label)
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textPrimary)
        }
    }
}

// MARK: - Settings Toggle
struct SettingsToggle: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)

            Text(label)
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(DinoTheme.sageGreen)
        }
    }
}
