//
//  OnboardingView.swift
//  Dino

import SwiftUI
import UserNotifications

// MARK: - Fixed Onboarding Colors (never themed)
private struct OnboardingColors {
    static let background = Color.white
    static let cardBackground = Color(hex: "F9FAFB")
    static let textPrimary = Color(hex: "2D3142")
    static let textSecondary = Color(hex: "6B7280")
    static let accent = Color(hex: "A8C5A0")
    static let divider = Color(hex: "E5E7EB")
    static let sageGreen = Color(hex: "A8C5A0")
}

// MARK: - Swappable quote constants
private let welcomeQuote = "emotional strength is not the absence of struggle, but the courage to sit with your feelings, understand them, and grow through them."
private let navyQuote = "a peaceful mind is the soil where joy, strength and purpose grows"

// MARK: - Feeling options
private let feelingOptions = [
    "doing great!",
    "ongoing mental health challenges",
    "having a hard time getting over something"
]

// MARK: - Challenge options per path
private let ongoingChallenges = [
    "Depression",
    "Anxiety",
    "Bipolar Disorder",
    "Eating Disorder",
    "OCD",
    "PTSD",
    "Something Else"
]

private let hardTimeChallenges = [
    "Breakup / Relationship / Friendship",
    "Job / Academic Pressure",
    "Health Issues",
    "Loss",
    "Loneliness",
    "Something Else"
]

// MARK: - Referral options
private let referralOptions = [
    "Instagram",
    "TikTok",
    "App Store Search",
    "Family / Friend",
    "Other Social Media / Blog",
    "Other"
]

// MARK: - OnboardingView
struct OnboardingView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    @State private var currentStep: Int = 0
    @State private var selectedFeeling: String = ""
    @State private var selectedChallenge: String = ""
    @State private var selectedReferral: String = ""
    @State private var dinoNameInput: String = ""
    @State private var animateTransition: Bool = false

    // Steps: 0=welcome, 1=feeling, 2=conditional, 3=encouragement, 4=navy quote, 5=referral, 6=notifications, 7=name, 8=disclaimer
    private var totalSteps: Int { 9 }

    var body: some View {
        ZStack {
            // Background — navy for step 4, white otherwise
            if currentStep == 4 {
                Color(red: 0.1, green: 0.1, blue: 0.2).ignoresSafeArea()
            } else {
                OnboardingColors.background.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Top bar: back button + progress dots
                HStack(alignment: .center) {
                    if currentStep > 0 {
                        Button(action: goBack) {
                            Text("back")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(currentStep == 4 ? Color.white.opacity(0.6) : OnboardingColors.textSecondary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .frame(width: 50, alignment: .leading)
                    } else {
                        Spacer().frame(width: 50)
                    }

                    Spacer()

                    // Progress dots
                    HStack(spacing: 7) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle()
                                .fill(progressDotColor(for: i))
                                .frame(
                                    width: i == currentStep ? 9 : 6,
                                    height: i == currentStep ? 9 : 6
                                )
                                .animation(.easeInOut(duration: 0.2), value: currentStep)
                        }
                    }

                    Spacer()

                    // Spacer to balance the back button
                    Spacer().frame(width: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // Page content
                ZStack {
                    switch currentStep {
                    case 0:
                        StepWelcomePage()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 1:
                        StepFeelingPage(selectedFeeling: $selectedFeeling)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 2:
                        conditionalPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 3:
                        StepEncouragementPage()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 4:
                        StepNavyQuotePage()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 5:
                        StepReferralPage(selectedReferral: $selectedReferral)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 6:
                        StepNotificationsPage()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 7:
                        StepNamePage(userName: $dinoNameInput)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 8:
                        StepDisclaimerPage()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom navigation button(s)
                bottomButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            AudioManager.shared.play(track: "onboarding_ambient")
            AudioManager.shared.fadeIn(duration: 2.0)
        }
        .onDisappear {
            AudioManager.shared.stop()
        }
    }

    // MARK: - Conditional page (step 2)
    @ViewBuilder
    private var conditionalPage: some View {
        if selectedFeeling == "doing great!" {
            StepDoingGreatPage()
        } else if selectedFeeling == "ongoing mental health challenges" {
            StepOngoingChallengePage(selectedChallenge: $selectedChallenge)
        } else {
            StepHardTimePage(selectedChallenge: $selectedChallenge)
        }
    }

    // MARK: - Bottom buttons
    @ViewBuilder
    private var bottomButtons: some View {
        if currentStep == 7 {
            // Name page has skip
            VStack(spacing: 12) {
                nextButton(label: "next") { advance() }

                Button(action: advance) {
                    Text("skip")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(OnboardingColors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else if currentStep == 8 {
            nextButton(label: "let's get started!") { finish() }
        } else {
            nextButton(label: "next") { advance() }
        }
    }

    @ViewBuilder
    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(currentStep == 4 ? Color(red: 0.1, green: 0.1, blue: 0.2) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(OnboardingColors.sageGreen)
                .cornerRadius(16)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isNextDisabled)
        .opacity(isNextDisabled ? 0.5 : 1.0)
    }

    private var isNextDisabled: Bool {
        switch currentStep {
        case 1: return selectedFeeling.isEmpty
        case 2:
            if selectedFeeling == "doing great!" { return false }
            return selectedChallenge.isEmpty
        case 5: return selectedReferral.isEmpty
        default: return false
        }
    }

    // MARK: - Navigation
    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep > 0 { currentStep -= 1 }
        }
    }

    private func finish() {
        AudioManager.shared.fadeOut(duration: 1.5)
        dataManager.userFeeling = selectedFeeling
        dataManager.userChallenge = selectedChallenge
        dataManager.referralSource = selectedReferral
        let name = dinoNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.userName = name.isEmpty ? "" : name
        dataManager.dinoName = "Dino"
        dataManager.onboardingComplete = true
    }

    // MARK: - Helpers
    private func progressDotColor(for index: Int) -> Color {
        if currentStep == 4 {
            return index == currentStep ? OnboardingColors.sageGreen : Color.white.opacity(0.3)
        }
        return index == currentStep ? OnboardingColors.sageGreen : OnboardingColors.divider
    }
}

// MARK: - Step 0: Welcome / Intro
private struct StepWelcomePage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(welcomeQuote)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)

            HStack(spacing: 8) {
                Image("DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                Text("🌸")
                    .font(.system(size: 40))
                    .offset(y: -10)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Step 1: How are you feeling?
private struct StepFeelingPage: View {
    @Binding var selectedFeeling: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("how are you feeling lately?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(feelingOptions, id: \.self) { option in
                    FeelingPillButton(
                        label: option,
                        isSelected: selectedFeeling == option,
                        onTap: { selectedFeeling = option }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
    }
}

private struct FeelingPillButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onTap() }
        }) {
            Text(label)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(isSelected ? OnboardingColors.sageGreen : OnboardingColors.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? OnboardingColors.sageGreen : OnboardingColors.divider, lineWidth: 1.5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Step 2a: Doing great path
private struct StepDoingGreatPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("good to hear that! Dino will help you keep things up.")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)

            Image("DinoBalloon")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Step 2b: Ongoing challenges path
private struct StepOngoingChallengePage: View {
    @Binding var selectedChallenge: String

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image("DinoBalloon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("sorry to hear about what has been going on... choose one that has been affecting your mental health the most.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(ongoingChallenges, id: \.self) { option in
                        ChallengePillButton(
                            label: option,
                            isSelected: selectedChallenge == option,
                            onTap: { selectedChallenge = option }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Step 2c: Hard time path
private struct StepHardTimePage: View {
    @Binding var selectedChallenge: String

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image("DinoBalloon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("sorry to hear about what has been going on... choose one that has been affecting your mental health the most.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(hardTimeChallenges, id: \.self) { option in
                        ChallengePillButton(
                            label: option,
                            isSelected: selectedChallenge == option,
                            onTap: { selectedChallenge = option }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct ChallengePillButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onTap() }
        }) {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(isSelected ? OnboardingColors.sageGreen : OnboardingColors.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? OnboardingColors.sageGreen : OnboardingColors.divider, lineWidth: 1.5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Step 3: Encouragement
private struct StepEncouragementPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("while receiving professional care is important, small habits and lifestyle changes can make a stark difference.")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)

            Image("DinoPair")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Step 4: Navy quote page
private struct StepNavyQuotePage: View {
    var body: some View {
        ZStack {
            // Star decorations
            StarfieldView()

            VStack(spacing: 36) {
                Spacer()

                // Quote in oval/speech bubble
                ZStack {
                    Ellipse()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 280, height: 160)

                    Text(navyQuote)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 28)
                        .frame(width: 280)
                }

                // Two dinos together
                Image("DinoFlowers")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)

                Spacer()
                Spacer()
            }
        }
    }
}

private struct StarfieldView: View {
    // Fixed star positions to avoid recalculation
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat)] = {
        var s: [(CGFloat, CGFloat, CGFloat)] = []
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0.1, 0.08, 3), (0.85, 0.12, 2), (0.45, 0.05, 2.5), (0.72, 0.20, 2),
            (0.20, 0.25, 1.5), (0.90, 0.35, 3), (0.05, 0.50, 2), (0.78, 0.55, 1.5),
            (0.35, 0.70, 2.5), (0.60, 0.80, 2), (0.15, 0.85, 3), (0.92, 0.72, 1.5),
            (0.50, 0.92, 2), (0.28, 0.45, 1.5), (0.68, 0.40, 2)
        ]
        return positions.map { ($0.0, $0.1, $0.2) }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: stars[i].size, height: stars[i].size)
                    .position(
                        x: stars[i].x * geo.size.width,
                        y: stars[i].y * geo.size.height
                    )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Step 5: Referral
private struct StepReferralPage: View {
    @Binding var selectedReferral: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("DinoFlower")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)

            Text("how did you hear about us?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(referralOptions, id: \.self) { option in
                    RadioButton(
                        label: option,
                        isSelected: selectedReferral == option,
                        onTap: { selectedReferral = option }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
    }
}

private struct RadioButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onTap() }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? OnboardingColors.sageGreen : OnboardingColors.divider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(OnboardingColors.sageGreen)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(label)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(isSelected ? OnboardingColors.sageGreen.opacity(0.08) : OnboardingColors.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? OnboardingColors.sageGreen : OnboardingColors.divider, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Step 6: Notifications
private struct StepNotificationsPage: View {
    @State private var permissionRequested = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("DinoChecklist")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)

            VStack(spacing: 12) {
                Text("let's set up daily reminders!!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("dino will help you stay on top of your tasks!")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(OnboardingColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if !permissionRequested {
                Button(action: requestNotifications) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                        Text("allow notifications")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(OnboardingColors.sageGreen)
                    .cornerRadius(16)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(OnboardingColors.sageGreen)
                    Text("reminders enabled!")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(OnboardingColors.sageGreen)
                }
            }

            Spacer()
            Spacer()
        }
    }

    private func requestNotifications() {
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            await MainActor.run {
                permissionRequested = true
                if granted {
                    NotificationManager.shared.rescheduleAll()
                    NotificationManager.shared.scheduleReEngagementIfNeeded()
                }
            }
        }
    }
}

// MARK: - Step 7: Name (user's name)
private struct StepNamePage: View {
    @Binding var userName: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)

            Text("what should we call you?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("your name", text: $userName)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(OnboardingColors.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(OnboardingColors.sageGreen.opacity(0.4), lineWidth: 1.5)
                )
                .focused($focused)
                .onAppear { focused = true }
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Step 8: Disclaimer / finish
private struct StepDisclaimerPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("DinoPink")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)

            Text("thank you for being honest/brave. i know it isn't easy to talk about your struggles. let's get started!")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}
