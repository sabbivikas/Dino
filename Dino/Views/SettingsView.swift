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

    @State private var showClearConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

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

                        SettingsToggle(
                            icon: "moon.fill",
                            label: "wind-down",
                            color: DinoTheme.lavender,
                            isOn: $notifManager.windDownEnabled
                        )
                    }
                } header: {
                    Text("notifications")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // Appearance
                Section {
                    NavigationLink(destination: ThemeSettingsView()) {
                        SettingsRow(icon: "paintpalette", label: "theme", color: DinoTheme.lavender)
                    }
                } header: {
                    Text("appearance")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // Account
                Section {
                    Button(action: { dataManager.resetOnboarding() }) {
                        SettingsRow(icon: "arrow.clockwise", label: "reset onboarding", color: DinoTheme.skyBlue)
                    }

                    Button(action: { showSignOutConfirm = true }) {
                        SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "sign out", color: DinoTheme.textSecondary)
                    }
                } header: {
                    Text("account")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // Danger zone
                Section {
                    Button(action: { showClearConfirm = true }) {
                        SettingsRow(icon: "trash.fill", label: "clear all data", color: .red)
                    }

                    Button(action: { showDeleteAccountConfirm = true }) {
                        SettingsRow(icon: "person.crop.circle.badge.xmark", label: "delete account", color: .red)
                    }
                } header: {
                    Text("danger zone")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // About
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        SettingsRow(icon: "lock.shield.fill", label: "privacy policy", color: DinoTheme.sageGreen)
                    }

                    HStack {
                        SettingsRow(icon: "info.circle.fill", label: "version", color: DinoTheme.sageGreen)
                        Spacer()
                        Text(appVersion)
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                } header: {
                    Text("about")
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
            .confirmationDialog(
                "clear all data?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("clear everything", role: .destructive) {
                    dataManager.clearAllData()
                    dismiss()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("this will permanently delete all your journal entries, mood logs, gratitude notes, and other data. this cannot be undone.")
            }
            .confirmationDialog(
                "sign out?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("sign out", role: .destructive) {
                    AuthManager.shared.signOut()
                    dataManager.clearForSignOut()
                    UserDefaults.standard.set(false, forKey: "hasPassedAuth")
                    dismiss()
                }
                Button("cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "delete your account?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("delete forever", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("this will permanently delete your account, all your data from the cloud, and sign you out. this cannot be undone. are you sure?")
            }
        }
    }

    private func deleteAccount() async {
        // Delete Firestore data first
        await FirestoreSyncService.shared.deleteAllUserData()

        // Delete Firebase Auth account
        do {
            try await AuthManager.shared.deleteAccount()
        } catch {
            print("[Settings] account deletion error: \(error)")
        }

        // Clear local data
        dataManager.clearForSignOut()
        UserDefaults.standard.set(false, forKey: "hasPassedAuth")
        dismiss()
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
