//
//  OnboardingView.swift
//  Dino
//
//  v6 design-system onboarding over the living 3D world. The star guide
//  in the world is the character presence; pages use the shared
//  WordRevealText / Confetti components.
//

import SwiftUI
import UserNotifications
import PostHog
import StoreKit

// MARK: - v6 Onboarding Colors (fixed, never themed)
private struct OnboardingColors {
    static let textPrimary   = Color(hex: "#2D3142")
    static let textSecondary = Color(hex: "#6B7280")
    static let sage          = Color(hex: "#A8C5A0")
    static let cardWhite     = Color(hex: "#FEFBF3")
    static let peach         = Color(hex: "#F5C6AA")
    static let sky           = Color(hex: "#A8D4E6")
    static let lavender      = Color(hex: "#C4B8D4")
    static let rose          = Color(hex: "#E8B4B8")
    static let moonlight     = Color(hex: "#F5E9C4")
    static let placeholder   = Color(hex: "#A0958A")
    static let navy          = Color(hex: "#1A1A33")
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
    @State private var showSettingsAlert: Bool = false

    private var totalSteps: Int { 12 }

    var body: some View {
        ZStack {
            // Backdrop — one living 3D world; the camera dollies between steps.
            // (The old 2D backdrops — NatureBackdrop, StarfieldBackdrop, and the
            // Metal shader views — remain in the codebase, unused, for instant
            // revert: swap this line back to the previous if/else.)
            OnboardingWorldView(currentStep: currentStep)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .padding(.bottom, 8)

                ZStack {
                    stepContent
                        .id(currentStep)
                        .transition(.opacity.combined(with: .offset(y: 12)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(
                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.52),
                    value: currentStep
                )

                bottomButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }

            // Step 8 confetti sits above the content
            if currentStep == 10 {
                Confetti()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            AudioManager.shared.play(track: "onboarding_ambient", playback: false)
            AudioManager.shared.fadeIn(duration: 2.0)
        }
        .onDisappear {
            AudioManager.shared.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: OnboardingBeginNotifier.name)) { _ in
            advance()
        }
        .onReceive(NotificationCenter.default.publisher(for: OnboardingMaybeLaterNotifier.name)) { _ in
            advance()
        }
        .onReceive(NotificationCenter.default.publisher(for: OnboardingShowSettingsAlertNotifier.name)) { _ in
            showSettingsAlert = true
        }
        .alert("enable notifications", isPresented: $showSettingsAlert) {
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                // Advance past the notifications step regardless
                advance()
            }
            Button("not now", role: .cancel) {
                advance()
            }
        } message: {
            Text("to enable notifications, go to Settings → Dino → Notifications and turn them on")
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(alignment: .center) {
            if currentStep > 0 {
                Button(action: goBack) {
                    Text("back")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(currentStep == 4
                                         ? Color.white.opacity(0.65)
                                         : OnboardingColors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(width: 50, alignment: .leading)
            } else {
                Spacer().frame(width: 50)
            }

            Spacer()

            Text("step \(currentStep + 1) of \(totalSteps)")
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(
                    currentStep == 4
                        ? Color.white.opacity(0.6)
                        : Color(hex: "#2D3142").opacity(0.6)
                )
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            Spacer().frame(width: 50)
        }
    }

    // MARK: - Step dispatcher
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: StepWelcomePage()
        case 1: StepFeelingPage(selectedFeeling: $selectedFeeling)
        case 2: conditionalPage
        case 3: StepEncouragementPage()
        case 4: StepNavyQuotePage()
        case 5: StepReferralPage(selectedReferral: $selectedReferral)
        case 6: StepNotificationsPage()
        case 7: StepNamePage(userName: $dinoNameInput)
        case 8: StepAnxietyUseCasePage()
        case 9: StepRoughDayUseCasePage()
        case 10: StepDisclaimerPage()
        case 11: StepRatingPage(onFinish: finish)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var conditionalPage: some View {
        if selectedFeeling == "doing great!" {
            StepDoingGreatPage()
        } else if selectedFeeling == "ongoing mental health challenges" {
            StepChallengePickerPage(
                options: ongoingChallenges,
                selectedChallenge: $selectedChallenge
            )
        } else {
            StepChallengePickerPage(
                options: hardTimeChallenges,
                selectedChallenge: $selectedChallenge
            )
        }
    }

    // MARK: - Bottom buttons
    @ViewBuilder
    private var bottomButtons: some View {
        if currentStep == 0 {
            // Step 0 has its own inline "begin" button — render nothing here
            EmptyView()
        } else if currentStep == 4 {
            outlinedButton(label: "continue") { advance() }
        } else if currentStep == 6 {
            // Step 6 has inline bell button + "maybe later" — render nothing here
            EmptyView()
        } else if currentStep == 7 {
            VStack(spacing: 12) {
                primarySageButton(label: "next") { advance() }
                Button(action: advance) {
                    Text("skip")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(OnboardingColors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else if currentStep == 10 {
            primarySageButton(label: "let's begin") { advance() }
        } else if currentStep == 11 {
            // Step 11 has its own inline buttons inside the rating card
            EmptyView()
        } else {
            primarySageButton(label: "next") { advance() }
        }
    }

    @ViewBuilder
    private func primarySageButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(OnboardingColors.sage)
                .cornerRadius(16)
                .shadow(color: OnboardingColors.sage.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isNextDisabled)
        .opacity(isNextDisabled ? 0.5 : 1.0)
    }

    @ViewBuilder
    private func outlinedButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(OnboardingColors.moonlight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    Capsule()
                        .stroke(OnboardingColors.moonlight, lineWidth: 1.4)
                )
        }
        .buttonStyle(ScaleButtonStyle())
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
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.52)) {
            currentStep += 1
        }
        AnalyticsManager.shared.trackOnboardingStep(currentStep, total: totalSteps)
    }

    private func goBack() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.52)) {
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
        AnalyticsManager.shared.trackOnboardingComplete()
    }

    private func progressDotColor(for index: Int) -> Color {
        if currentStep == 4 {
            return index == currentStep ? OnboardingColors.sage : Color.white.opacity(0.3)
        }
        return index == currentStep ? OnboardingColors.sage : Color(hex: "#E5E7EB")
    }
}

// MARK: - Step 0: Welcome
private struct StepWelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            WordRevealText(
                welcomeQuote,
                font: .custom(DinoTheme.customFontName, size: 22),
                color: OnboardingColors.textPrimary
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)

            Button(action: {
                // Hop up one step via parent environment. We rely on the
                // parent's next-button mechanism by sending a notification
                // is overkill — instead, use a custom preference/coordinator.
                OnboardingBeginNotifier.fire()
            }) {
                Text("begin")
                    .font(.custom(DinoTheme.customFontName, size: 18))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 36)
                    .background(OnboardingColors.sage, in: Capsule())
                    .shadow(color: OnboardingColors.sage.opacity(0.40), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }
}

// A tiny in-process pub/sub to let Step 0's "begin" button tell the parent
// view to advance without tightly coupling the page structs.
private enum OnboardingBeginNotifier {
    static let name = Notification.Name("DinoOnboardingBeginTap")
    static func fire() {
        NotificationCenter.default.post(name: Self.name, object: nil)
    }
}

// MARK: - Step 1: Feeling
private struct StepFeelingPage: View {
    @Binding var selectedFeeling: String
    @State private var appeared: Bool = false
    @State private var tappedIndex: Int? = nil
    @State private var tapPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            Text("how are you feeling lately?")
                .font(.custom(DinoTheme.customFontName, size: 26))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                pill(
                    label: "doing great",
                    option: "doing great!",
                    index: 0
                )
                pill(
                    label: "it's a challenge",
                    option: "ongoing mental health challenges",
                    index: 1
                )
                pill(
                    label: "somewhere in between",
                    option: "having a hard time getting over something",
                    index: 2
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func pill(label: String, option: String, index: Int) -> some View {
        let isSelected = selectedFeeling == option
        Button(action: {
            withAnimation(.spring(response: 0.3)) { selectedFeeling = option }
            tappedIndex = index
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                tapPulse = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    tapPulse = 1.0
                }
            }
        }) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 19))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 28)
                .background(isSelected ? OnboardingColors.sage : Color(hex: "#F9FAFB"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color(hex: "#7BA872") : Color(hex: "#D1D5DB"),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect((tappedIndex == index ? tapPulse : 1.0) * (appeared ? 1 : 0.92))
        .opacity(appeared ? 1 : 0)
        .animation(
            .timingCurve(0.22, 1, 0.36, 1, duration: 0.48)
                .delay(Double(index) * 0.12),
            value: appeared
        )
    }
}

// MARK: - Step 2a: Doing great
private struct StepDoingGreatPage: View {
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            // Soft aura + rising hearts — gentle motion where the mascot stood.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OnboardingColors.sage.opacity(0.30), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                ForEach(0..<3, id: \.self) { i in
                    RisingHeart(
                        appeared: appeared,
                        delay: Double(i) * 0.3,
                        size: [14, 20, 16][i],
                        wobble: [-5, 8, -8][i]
                    )
                    .offset(x: CGFloat([-40, 0, 40][i]), y: 30)
                }
            }
            .frame(height: 160)

            Text("good to hear that! Dino will help you keep things up.")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Step 2b/c: Challenge picker
private struct StepChallengePickerPage: View {
    let options: [String]
    @Binding var selectedChallenge: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            Text("sorry to hear what's going on. what's been weighing on you most?")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
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
                .font(DinoTheme.dinoFont(size: 18))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 16)
                .background(isSelected ? OnboardingColors.sage : Color(hex: "#F9FAFB"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color(hex: "#7BA872") : Color(hex: "#D1D5DB"),
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Step 3: Encouragement
private struct StepEncouragementPage: View {
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            ZStack {
                // Aura behind pair
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OnboardingColors.sage.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)

                // Rising hearts — custom circle accents with wobble
                ForEach(0..<3, id: \.self) { i in
                    RisingHeart(
                        appeared: appeared,
                        delay: Double(i) * 0.3,
                        size: [14, 20, 16][i],
                        wobble: [-5, 8, -8][i]
                    )
                    .offset(x: CGFloat([-40, 0, 40][i]))
                }
            }

            Text("you're not alone")
                .font(.custom(DinoTheme.customFontName, size: 26))
                .foregroundColor(OnboardingColors.textPrimary)

            Text("while receiving professional care is important, small habits and lifestyle changes can make a stark difference.")
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(OnboardingColors.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

private struct RisingHeart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let appeared: Bool
    let delay: Double
    let size: CGFloat
    let wobble: Double

    var body: some View {
        let dur: Double = 1.2
        Circle()
            .fill(Color(hex: "#E8B4B8"))
            .frame(width: size, height: size)
            .opacity(appeared && !reduceMotion ? 0 : (reduceMotion && appeared ? 0.8 : 0))
            .scaleEffect(reduceMotion ? 1.0 : (appeared ? 1 : 0.6))
            .rotationEffect(.degrees(appeared && !reduceMotion ? wobble : 0))
            .offset(y: appeared && !reduceMotion ? -80 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.4).delay(delay)
                    : .easeInOut(duration: dur).delay(delay),
                value: appeared
            )
    }
}

// MARK: - Step 4: Navy quote
private struct StepNavyQuotePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 20)

            ZStack {
                Ellipse()
                    .fill(Color(hex: "#FEFBF3").opacity(0.10))
                    .background(.ultraThinMaterial, in: Ellipse())
                    .overlay(
                        Ellipse()
                            .stroke(Color(hex: "#FEFBF3").opacity(0.22), lineWidth: 1)
                    )
                    .frame(width: 320, height: 180)

                Text(navyQuote)
                    .font(DinoTheme.dinoFont(size: 20))
                    .foregroundColor(OnboardingColors.moonlight)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                    .frame(width: 300)
            }

            Spacer()
        }
    }
}

// MARK: - Step 5: Referral
private struct StepReferralPage: View {
    @Binding var selectedReferral: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            Text("how did you hear about us?")
                .font(.custom(DinoTheme.customFontName, size: 24))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(referralOptions, id: \.self) { option in
                        RadioRow(
                            label: option,
                            isSelected: selectedReferral == option,
                            onTap: { selectedReferral = option }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct RadioRow: View {
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
                        .stroke(OnboardingColors.sage, lineWidth: 1.8)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(OnboardingColors.sage)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(label)
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(OnboardingColors.textPrimary)
                Spacer()
            }
            .padding(16)
            .background(Color(hex: "#F9FAFB"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#D1D5DB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Step 6: Notifications
private struct StepNotificationsPage: View {
    @State private var permissionRequested = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("gentle reminders?")
                    .font(.custom(DinoTheme.customFontName, size: 24))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("dino will help you stay on top of your tasks.")
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(OnboardingColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#F9FAFB"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#D1D5DB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 24)

            if !permissionRequested {
                Button(action: requestNotifications) {
                    ZStack {
                        Circle()
                            .fill(OnboardingColors.sage)
                            .frame(width: 64, height: 64)
                            .shadow(color: OnboardingColors.sage.opacity(0.40), radius: 12, x: 0, y: 4)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(OnboardingColors.sage)
                    Text("reminders enabled!")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(OnboardingColors.sage)
                }
            }

            Button(action: {
                OnboardingMaybeLaterNotifier.fire()
            }) {
                Text("maybe later")
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(OnboardingColors.textSecondary)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    private func requestNotifications() {
        Task {
            let result = await NotificationManager.shared.requestPermissionDetailed()
            await MainActor.run {
                permissionRequested = true

                if result.granted {
                    NotificationManager.shared.rescheduleAll()
                    NotificationManager.shared.scheduleReEngagementIfNeeded()
                    // Advance shortly after so the "reminders enabled!" state is visible
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        OnboardingMaybeLaterNotifier.fire()
                    }
                } else if result.shouldShowSettingsAlert {
                    // Previously denied — iOS won't re-prompt. Surface the Settings alert
                    // on the parent OnboardingView. The alert's buttons advance the flow.
                    OnboardingShowSettingsAlertNotifier.fire()
                } else {
                    // Fresh denial — treat as "maybe later" and advance.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        OnboardingMaybeLaterNotifier.fire()
                    }
                }
            }
        }
    }
}

private enum OnboardingMaybeLaterNotifier {
    static let name = Notification.Name("DinoOnboardingMaybeLaterTap")
    static func fire() {
        NotificationCenter.default.post(name: Self.name, object: nil)
    }
}

private enum OnboardingShowSettingsAlertNotifier {
    static let name = Notification.Name("DinoOnboardingShowSettingsAlert")
    static func fire() {
        NotificationCenter.default.post(name: Self.name, object: nil)
    }
}

// MARK: - Step 7: Name
private struct StepNamePage: View {
    @Binding var userName: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            Text("what should we call you?")
                .font(.custom(DinoTheme.customFontName, size: 26))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ZStack(alignment: .leading) {
                if userName.isEmpty {
                    Text("your name")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(OnboardingColors.placeholder)
                        .padding(.horizontal, 16)
                }
                TextField("", text: $userName)
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .padding(.horizontal, 16)
                    .focused($focused)
                    .onAppear { focused = true }
            }
            .frame(height: 56)
            .background(Color(hex: "#F9FAFB"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        focused ? OnboardingColors.sage : Color(hex: "#D1D5DB"),
                        lineWidth: focused ? 2 : 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.2), value: focused)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Step 8: Disclaimer + Confetti
private struct StepDisclaimerPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            // Confetti (rendered by the parent on this step) carries the
            // celebration — the copy stands on its own over the world.
            Text("thank you for being honest/brave. i know it isn't easy to talk about your struggles. let's get started!")
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 280)

            Spacer()
        }
    }
}


// MARK: - Step 8: Anxiety use case
private struct StepAnxietyUseCasePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var outerScale: CGFloat = 1.0
    @State private var midScale: CGFloat = 1.0
    @State private var innerScale: CGFloat = 1.0
    @State private var dimmed: Bool = false
    @State private var breathPhase: String = "breathe in"
    @State private var phaseTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            ZStack {
                // Layer 1 — outer glow ring
                Circle()
                    .fill(OnboardingColors.sage.opacity(0.25))
                    .frame(width: 200, height: 200)
                    .blur(radius: 6)
                    .scaleEffect(reduceMotion ? 1.0 : outerScale)
                    .opacity(reduceMotion && dimmed ? 0.7 : 1.0)

                // Layer 2 — mid ring
                Circle()
                    .stroke(OnboardingColors.sage.opacity(0.45), lineWidth: 2)
                    .frame(width: 160, height: 160)
                    .scaleEffect(reduceMotion ? 1.0 : midScale)
                    .opacity(reduceMotion && dimmed ? 0.7 : 1.0)

                // Layer 3 — inner core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [OnboardingColors.sage, Color(hex: "#C8E6F5")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(reduceMotion ? 1.0 : innerScale)
                    .opacity(reduceMotion && dimmed ? 0.7 : 1.0)
            }
            .frame(height: 220)

            Text(breathPhase)
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(OnboardingColors.sage)
                .id(breathPhase)
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))

            Text("when anxiety hits")
                .font(.custom(DinoTheme.customFontName, size: 28))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("4 minutes of breathing activates your body's calm response. dino will guide you through it.")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Text("used by people before meetings, after hard news, during panic moments")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(OnboardingColors.textSecondary.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            Spacer()
        }
        .onAppear {
            if reduceMotion {
                // Opacity-only pulse — no scale changes
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            } else {
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    outerScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                        midScale = 1.08
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                        innerScale = 1.05
                    }
                }
            }

            phaseTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    breathPhase = (breathPhase == "breathe in") ? "breathe out" : "breathe in"
                }
            }
        }
        .onDisappear {
            phaseTimer?.invalidate()
            phaseTimer = nil
        }
    }
}

// MARK: - Step 9: Rough day use case
private struct GratitudeSlipSpec {
    let label: String
    let color: Color
    let rotation: Double
}

private let gratitudeSlips: [GratitudeSlipSpec] = [
    GratitudeSlipSpec(label: "quiet morning", color: Color(hex: "#FDDCB5"), rotation: -10),
    GratitudeSlipSpec(label: "good tea",      color: Color(hex: "#E8E0F5"), rotation: 6),
    GratitudeSlipSpec(label: "kind words",    color: Color(hex: "#C8E6F5"), rotation: -4),
    GratitudeSlipSpec(label: "sunshine",      color: Color(hex: "#C8E0C4"), rotation: 8),
    GratitudeSlipSpec(label: "deep breath",   color: Color(hex: "#F5D0D0"), rotation: -7)
]

private struct StepRoughDayUseCasePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cycle: Int = 0
    @State private var cycleTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            jarStage
                .padding(.horizontal, 24)

            Text("one small good thing")
                .font(.custom(DinoTheme.customFontName, size: 28))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("on hard days, dropping one moment into your jar shifts something. it doesn't have to be big.")
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Text("people who do this 3x a week report feeling more grounded")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(OnboardingColors.textSecondary.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            Spacer()
        }
        .onAppear {
            cycleTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
                cycle += 1
            }
        }
        .onDisappear {
            cycleTimer?.invalidate()
            cycleTimer = nil
        }
    }

    private var jarStage: some View {
        // No backing card — the jar (already translucent) floats over the
        // world so the scene stays visible behind it.
        jarVisual
            .frame(width: 180, height: 220)
    }

    private var jarVisual: some View {
        ZStack(alignment: .bottom) {
            // Falling gratitude slips drop into the jar
            ForEach(gratitudeSlips.indices, id: \.self) { i in
                GratitudeSlip(
                    spec: gratitudeSlips[i],
                    index: i,
                    cycle: cycle,
                    reduceMotion: reduceMotion
                )
            }

            VStack(spacing: 0) {
                Capsule()
                    .fill(OnboardingColors.sage.opacity(0.85))
                    .frame(width: 90, height: 16)
                    .shadow(color: OnboardingColors.textPrimary.opacity(0.10), radius: 2, x: 0, y: 1)

                Rectangle()
                    .fill(Color(hex: "#FEFBF3").opacity(0.9))
                    .frame(width: 70, height: 10)
                    .overlay(
                        Rectangle()
                            .stroke(OnboardingColors.sage.opacity(0.35), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(hex: "#FEFBF3").opacity(0.75))
                    .frame(width: 130, height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(OnboardingColors.sage.opacity(0.45), lineWidth: 1.4)
                    )
                    .shadow(color: OnboardingColors.textPrimary.opacity(0.10), radius: 8, x: 0, y: 4)
            }
        }
    }
}

private struct GratitudeSlip: View {
    let spec: GratitudeSlipSpec
    let index: Int
    let cycle: Int
    let reduceMotion: Bool

    @State private var landed: Bool = false
    @State private var squished: Bool = false

    var body: some View {
        let delay = 0.2 + Double(index) * 0.5

        RoundedRectangle(cornerRadius: 6)
            .fill(spec.color)
            .frame(width: 80, height: 28)
            .overlay(
                Text(spec.label)
                    .font(DinoTheme.dinoFont(size: 9))
                    .foregroundColor(Color.black.opacity(0.5))
            )
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 2)
            .rotationEffect(.degrees(spec.rotation))
            .scaleEffect(x: 1.0, y: squished ? 0.85 : 1.0)
            .opacity(landed ? 0.85 : 0)
            .offset(y: reduceMotion ? 0 : (landed ? 0 : -180))
            .padding(.bottom, 16)
            .onAppear {
                scheduleFall(delay: delay)
            }
            .onChange(of: cycle) { _, _ in
                landed = false
                squished = false
                scheduleFall(delay: delay)
            }
    }

    private func scheduleFall(delay: Double) {
        if reduceMotion {
            // Fade-in only — no movement, no squish
            withAnimation(.easeIn(duration: 0.6).delay(delay)) {
                landed = true
            }
        } else {
            withAnimation(.easeIn(duration: 0.6).delay(delay)) {
                landed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.6) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    squished = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        squished = false
                    }
                }
            }
        }
    }
}

// MARK: - Step 11: Rating

private struct TestimonialData {
    let quote: String
    let name: String
    let tag: String
}

private let ratingTestimonials: [TestimonialData] = [
    TestimonialData(
        quote: "your little dino has saved my day many times.",
        name: "patricia b.",
        tag: "rn, icu nurse \u{00B7} finland"
    ),
    TestimonialData(
        quote: "it feels so friendly and natural, not like i'm being pressured to keep up with my good habits.",
        name: "mikhale m.",
        tag: "dino user"
    ),
    TestimonialData(
        quote: "the app helps me remember the good parts of life.",
        name: "luan",
        tag: "dino community"
    )
]

private struct StepRatingPage: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardAppeared: [Bool] = [false, false, false]
    @State private var starBounce: [CGFloat] = [1, 1, 1, 1, 1]
    @State private var selectedStars: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // TOP SECTION — headlines
                VStack(spacing: 8) {
                    Text("enjoying dino?")
                        .font(DinoTheme.dinoFont(size: 28))
                        .foregroundColor(Color(hex: "#2D3142"))
                        .padding(.top, 8)

                    Text("you're already part of something beautiful \u{1F331}")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(Color(hex: "#2D3142").opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // TESTIMONIAL SECTION — label + 3 vertical cards
                VStack(spacing: 12) {
                    Text("what others are saying")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(Color(hex: "#2D3142").opacity(0.45))
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .center)

                    ForEach(0..<ratingTestimonials.count, id: \.self) { i in
                        TestimonialCard(data: ratingTestimonials[i])
                            .opacity(cardAppeared[i] ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (cardAppeared[i] ? 0 : 16))
                    }
                }

                // RATING SECTION — label + stars
                VStack(spacing: 12) {
                    Text("tap to rate")
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(Color(hex: "#2D3142").opacity(0.5))

                    HStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { i in
                            Button(action: { tapStar(i) }) {
                                Image(systemName: i < selectedStars ? "star.fill" : "star")
                                    .font(.system(size: 34))
                                    .foregroundColor(
                                        i < selectedStars
                                            ? Color(hex: "#F9C784")
                                            : Color(hex: "#D1D5DB")
                                    )
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(reduceMotion ? 1.0 : starBounce[i])
                        }
                    }
                }
                .padding(.top, 4)

                // BUTTONS
                VStack(spacing: 8) {
                    if selectedStars > 0 {
                        Button(action: rateAction) {
                            Text("rate on the app store")
                                .font(DinoTheme.dinoFont(size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(OnboardingColors.sage)
                                .cornerRadius(16)
                                .shadow(color: OnboardingColors.sage.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.opacity)
                    }

                    Button(action: {
                        AnalyticsManager.shared.trackRatingSkipped()
                        onFinish()
                    }) {
                        Text("maybe later")
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(Color(hex: "#2D3142").opacity(0.55))
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.3), value: selectedStars > 0)
        .onAppear {
            AnalyticsManager.shared.trackRatingScreenShown()
            startEntranceAnimations()
        }
    }

    private func startEntranceAnimations() {
        for i in 0..<ratingTestimonials.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.1) {
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.35)
                        : .spring(response: 0.5, dampingFraction: 0.75)
                ) {
                    cardAppeared[i] = true
                }
            }
        }
    }

    private func tapStar(_ index: Int) {
        let stars = index + 1
        AnalyticsManager.shared.trackRatingStarTapped(stars: stars)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3)) {
            selectedStars = stars
        }
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            starBounce[index] = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                starBounce[index] = 1.0
            }
        }
    }

    private func rateAction() {
        AnalyticsManager.shared.trackRatingSubmitted(stars: selectedStars)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onFinish()
        }
    }
}

private struct TestimonialCard: View {
    let data: TestimonialData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#F9C784"))
                }
            }

            Text(data.quote)
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(Color(hex: "#4A3520"))
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(data.name)
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(OnboardingColors.sage)
                Text("\u{00B7}")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(Color(hex: "#9E8E7E").opacity(0.5))
                Text(data.tag)
                    .font(DinoTheme.dinoFont(size: 11))
                    .foregroundColor(Color(hex: "#9E8E7E").opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#FEFBF3"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E8DDD0"), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#C4A882").opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
