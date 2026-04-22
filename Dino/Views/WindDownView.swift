//
//  WindDownView.swift
//  Dino
//

import SwiftUI

struct WindDownView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("wind_down_enabled")   private var enabled: Bool = false
    @AppStorage("wind_down_time")      private var windDownTimeInterval: Double = 0
    @AppStorage("wind_down_breathing") private var includeBreathing: Bool = true
    @AppStorage("wind_down_journal")   private var includeJournal: Bool = true
    @AppStorage("wind_down_gratitude") private var includeGratitude: Bool = true

    @State private var showSavedToast = false

    // Palette
    private let paperCream   = Color(hex: "#FBF5E4")
    private let paperWhite   = Color(hex: "#FFFDF5")
    private let sage         = Color(hex: "#7BA872")
    private let sageSoft     = Color(hex: "#A8C5A0")
    private let nearBlack    = Color(hex: "#2D3A2B")
    private let washiLavender = Color(hex: "#C4B8D4")
    private let washiPeach    = Color(hex: "#F5C5A3")
    private let washiSage     = Color(hex: "#B8D4B0")
    private let mutedText     = Color(hex: "#9E9E9E")
    private let cardBorder    = Color(hex: "#E8E0D0")

    // Date <-> TimeInterval helpers (stored as Date().timeIntervalSinceReferenceDate)
    private var windDownDate: Binding<Date> {
        Binding(
            get: {
                if windDownTimeInterval == 0 {
                    // default 9:30pm today
                    var comps = DateComponents()
                    comps.hour = 21
                    comps.minute = 30
                    return Calendar.current.date(from: comps) ?? Date()
                }
                return Date(timeIntervalSinceReferenceDate: windDownTimeInterval)
            },
            set: { newDate in
                windDownTimeInterval = newDate.timeIntervalSinceReferenceDate
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paperCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 22) {
                        headerCard
                            .rotationEffect(.degrees(-1.2))

                        masterToggleCard
                            .rotationEffect(.degrees(-0.8))

                        timeCard
                            .rotationEffect(.degrees(1.1))
                            .opacity(enabled ? 1.0 : 0.5)

                        routinesCard
                            .rotationEffect(.degrees(-0.5))
                            .opacity(enabled ? 1.0 : 0.5)

                        saveButton
                            .rotationEffect(.degrees(1.3))
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("wind down")
                        .font(DinoTheme.dinoFont(size: 18))
                        .foregroundStyle(nearBlack)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close") { dismiss() }
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundStyle(sage)
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    savedToast
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        scrapbookCard(tapeColor: washiLavender) {
            HStack(spacing: 16) {
                Image("DinoSleeping")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text("wind down")
                        .font(DinoTheme.dinoFont(size: 26))
                        .foregroundStyle(nearBlack)
                    Text("end your day with kindness")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundStyle(sage)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var masterToggleCard: some View {
        scrapbookCard(tapeColor: washiPeach) {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(washiLavender))

                VStack(alignment: .leading, spacing: 2) {
                    Text("enable wind down")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundStyle(nearBlack)
                    Text("a soft reminder each evening")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundStyle(mutedText)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .tint(sage)
            }
        }
    }

    private var timeCard: some View {
        scrapbookCard(tapeColor: washiSage) {
            VStack(alignment: .leading, spacing: 10) {
                Text("time")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundStyle(mutedText)

                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(sage)

                    Text("nudge me at")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundStyle(nearBlack)

                    Spacer(minLength: 0)

                    DatePicker("", selection: windDownDate,
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!enabled)
                }
            }
        }
    }

    private var routinesCard: some View {
        scrapbookCard(tapeColor: washiLavender) {
            VStack(alignment: .leading, spacing: 14) {
                Text("include routines")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundStyle(mutedText)

                routineRow(
                    icon: "wind",
                    iconColor: Color(hex: "#A8D4E6"),
                    label: "breathing",
                    isOn: $includeBreathing
                )

                routineRow(
                    icon: "book.closed.fill",
                    iconColor: Color(hex: "#E8B4B8"),
                    label: "journal",
                    isOn: $includeJournal
                )

                routineRow(
                    icon: "sparkles",
                    iconColor: Color(hex: "#F5C5A3"),
                    label: "gratitude",
                    isOn: $includeGratitude
                )
            }
        }
    }

    private func routineRow(icon: String, iconColor: Color,
                            label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(iconColor))

            Text(label)
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundStyle(nearBlack)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(sage)
                .disabled(!enabled)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("save")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(sage))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private var savedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(sage)
            Text("saved")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundStyle(nearBlack)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(paperWhite)
                .overlay(Capsule().stroke(sage, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .rotationEffect(.degrees(1))
    }

    // MARK: - Scrapbook card helper

    @ViewBuilder
    private func scrapbookCard<Content: View>(
        tapeColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(paperWhite)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorder, lineWidth: 1)
                )

            content()
                .padding(18)
                .padding(.top, 6)

            // Washi tape accent
            RoundedRectangle(cornerRadius: 2)
                .fill(tapeColor.opacity(0.8))
                .frame(width: 70, height: 18)
                .rotationEffect(.degrees(-4))
                .offset(y: -6)
        }
    }

    // MARK: - Save

    private func save() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        NotificationManager.shared.rescheduleWindDown()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    WindDownView()
}
