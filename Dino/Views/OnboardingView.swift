//
//  OnboardingView.swift
//  Dino
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @State private var currentPage: Int = 0
    @State private var userName: String = ""
    @State private var selectedIntentions: Set<String> = []
    @State private var notificationRequested: Bool = false
    @State private var showResources: Bool = false

    let intentions = [
        "reduce stress", "feel calmer", "build habits",
        "sleep better", "be more present", "manage anxiety"
    ]

    var totalPages: Int { 5 }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? DinoTheme.sageGreen : DinoTheme.divider)
                            .frame(width: i == currentPage ? 10 : 7, height: i == currentPage ? 10 : 7)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 8)

                TabView(selection: $currentPage) {
                    // Page 0: Welcome
                    OnboardingPage(
                        icon: "❤️",
                        title: "dino is your safe space",
                        subtitle: "a private, calm place just for you — no feeds, no followers, just peace."
                    )
                    .tag(0)

                    // Page 1: Name
                    NamePage(userName: $userName)
                        .tag(1)

                    // Page 2: Intentions
                    IntentionsPage(
                        intentions: intentions,
                        selected: $selectedIntentions
                    )
                    .tag(2)

                    // Page 3: Notifications
                    NotificationsPage(requested: $notificationRequested)
                        .tag(3)

                    // Page 4: Disclaimer
                    DisclaimerPage(showResources: $showResources)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .font(DinoTheme.bodyFont())
                        .foregroundColor(DinoTheme.textSecondary)
                        .frame(width: 80)
                    }

                    Spacer()

                    Button(action: advance) {
                        Text(currentPage == totalPages - 1 ? "let's begin" : "next")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(.white)
                            .frame(width: 140)
                            .padding(.vertical, 16)
                            .background(DinoTheme.sageGreen)
                            .cornerRadius(DinoTheme.cornerRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, DinoTheme.largePadding)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showResources) {
            ResourcesView()
        }
    }

    private func advance() {
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        if !userName.isEmpty {
            dataManager.userName = userName
        }
        dataManager.userIntentions = Array(selectedIntentions)
        dataManager.onboardingComplete = true
    }
}

// MARK: - Onboarding Page
struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(icon)
                .font(.system(size: 80))
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                Text(title)
                    .font(DinoTheme.largeFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DinoTheme.largePadding)
    }
}

// MARK: - Name Page
struct NamePage: View {
    @Binding var userName: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("👋")
                .font(.system(size: 70))

            VStack(spacing: 12) {
                Text("what should we call you?")
                    .font(DinoTheme.largeFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("dino will use this to greet you each day.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("your first name", text: $userName)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(DinoTheme.cardBackground)
                .cornerRadius(DinoTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                        .stroke(DinoTheme.sageGreen.opacity(0.5), lineWidth: 1.5)
                )
                .focused($focused)
                .onAppear { focused = true }
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DinoTheme.largePadding)
    }
}

// MARK: - Intentions Page
struct IntentionsPage: View {
    let intentions: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🌱")
                .font(.system(size: 70))

            VStack(spacing: 10) {
                Text("what brings you here?")
                    .font(DinoTheme.largeFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("pick everything that resonates.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }

            // Grid of chips
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(intentions, id: \.self) { intention in
                    IntentionChip(
                        label: intention,
                        isSelected: selected.contains(intention),
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                if selected.contains(intention) {
                                    selected.remove(intention)
                                } else {
                                    selected.insert(intention)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DinoTheme.largePadding)
    }
}

struct IntentionChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(DinoTheme.captionFont())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : DinoTheme.textPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? DinoTheme.sageGreen : DinoTheme.cardBackground)
                .cornerRadius(DinoTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                        .stroke(isSelected ? DinoTheme.sageGreen : DinoTheme.divider, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Notifications Page
struct NotificationsPage: View {
    @Binding var requested: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("🔔")
                .font(.system(size: 70))

            VStack(spacing: 12) {
                Text("stay in the loop")
                    .font(DinoTheme.largeFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("gentle reminders to check in with yourself. totally optional.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: { requested = true }) {
                HStack(spacing: 10) {
                    Image(systemName: requested ? "checkmark.circle.fill" : "bell")
                        .font(.system(size: 18))
                    Text(requested ? "reminders enabled" : "enable reminders")
                        .font(DinoTheme.headlineFont())
                }
                .foregroundColor(requested ? DinoTheme.sageGreen : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(requested ? DinoTheme.sageGreen.opacity(0.15) : DinoTheme.sageGreen)
                .cornerRadius(DinoTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                        .stroke(DinoTheme.sageGreen, lineWidth: requested ? 1.5 : 0)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 32)

            Text("you can change this in settings anytime.")
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DinoTheme.largePadding)
    }
}

// MARK: - Disclaimer Page
struct DisclaimerPage: View {
    @Binding var showResources: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🌿")
                .font(.system(size: 70))

            VStack(spacing: 12) {
                Text("one thing to know")
                    .font(DinoTheme.largeFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Text("dino is not a medical tool or a replacement for professional support. it's a space for reflection and self-care.")
                    .font(DinoTheme.bodyFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 10) {
                Text("if you're struggling and need help now:")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)

                Button(action: { showResources = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                        Text("need help now?")
                    }
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(DinoTheme.warmRose)
                    .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DinoTheme.largePadding)
    }
}
