//
//  SettingsView.swift
//  Dino
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirm = false
    @State private var showSignOutConfirm = false
    @State private var notifyMorning = true
    @State private var notifyEvening = false
    @State private var notifyStreak = true

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                // Notifications
                Section {
                    SettingsToggle(
                        icon: "sun.max.fill",
                        label: "morning reminder",
                        color: DinoTheme.peach,
                        isOn: $notifyMorning
                    )
                    SettingsToggle(
                        icon: "moon.fill",
                        label: "evening check-in",
                        color: DinoTheme.lavender,
                        isOn: $notifyEvening
                    )
                    SettingsToggle(
                        icon: "flame.fill",
                        label: "streak reminders",
                        color: .orange,
                        isOn: $notifyStreak
                    )
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
                } header: {
                    Text("danger zone")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .listRowBackground(DinoTheme.cardBackground)

                // About
                Section {
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
                    dataManager.signOut()
                    dismiss()
                }
                Button("cancel", role: .cancel) {}
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
