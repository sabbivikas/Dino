//
//  OnboardingView.swift
//  Dino
//
//  v6 design-system onboarding. Uses NatureBackdrop / StarfieldBackdrop
//  and the shared MascotView / WordRevealText / Confetti components.
//

import SwiftUI
import UserNotifications
import PostHog

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
    static let surface1      = Color(hex: "#F9FAFB")
    static let cardBorder    = Color(hex: "#D1D5DB")
    static let sageDeep      = Color(hex: "#7BA872")
}

// MARK: - Shared onboarding surfaces

private struct OnboardingCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(OnboardingColors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(OnboardingColors.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

private extension View {
    func onboardingCardSurface(cornerRadius: CGFloat = 16, padding: CGFloat = 0) -> some View {
        modifier(OnboardingCardSurface(cornerRadius: cornerRadius, padding: padding))
    }
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

    private var totalSteps: Int { 11 }

    var body: some View {
        ZStack {
            // Backdrop
            if currentStep == 4 {
                StarfieldBackdrop()
                    .transition(.opacity)
            } else {
                NatureBackdrop()
                    .transition(.opacity)
            }

            if currentStep == 1 {
                OnboardingFeelingColorWash(selectedFeeling: selectedFeeling)
                    .transition(.opacity)
            }

            if currentStep == 3 {
                OnboardingEncouragementHeartsAmbient()
                    .transition(.opacity)
            }

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

            if currentStep == 10 {
                OnboardingCelebrationAmbient()
                    .transition(.opacity)
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
                        .font(.system(size: 15, design: .rounded))
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
                        ? OnboardingColors.moonlight.opacity(0.85)
                        : DinoTheme.textSecondary.opacity(0.7)
                )
                .id(currentStep)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))

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
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(OnboardingColors.textSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        } else if currentStep == 10 {
            primarySageButton(label: "let's begin") { finish() }
        } else {
            primarySageButton(label: "next") { advance() }
        }
    }

    @ViewBuilder
    private func primarySageButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                .font(.system(size: 17, weight: .semibold, design: .rounded))
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

}

// MARK: - Step 0: Welcome
private struct StepWelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            MascotView(imageName: "cut-DinoMascot", size: 200)

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

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            Text("how are you feeling lately?")
                .font(.custom(DinoTheme.customFontName, size: 26))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                FeelingPillButton(
                    label: "doing great",
                    option: "doing great!",
                    isSelected: selectedFeeling == "doing great!",
                    index: 0,
                    appeared: appeared,
                    onSelect: { selectedFeeling = $0 }
                )
                FeelingPillButton(
                    label: "it's a challenge",
                    option: "ongoing mental health challenges",
                    isSelected: selectedFeeling == "ongoing mental health challenges",
                    index: 1,
                    appeared: appeared,
                    onSelect: { selectedFeeling = $0 }
                )
                FeelingPillButton(
                    label: "somewhere in between",
                    option: "having a hard time getting over something",
                    isSelected: selectedFeeling == "having a hard time getting over something",
                    index: 2,
                    appeared: appeared,
                    onSelect: { selectedFeeling = $0 }
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

private struct FeelingPillButton: View {
    let label: String
    let option: String
    let isSelected: Bool
    let index: Int
    let appeared: Bool
    let onSelect: (String) -> Void

    @State private var bounceScale: CGFloat = 1

    var body: some View {
        Button(action: select) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(isSelected ? OnboardingColors.sage : OnboardingColors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? OnboardingColors.sageDeep : OnboardingColors.cardBorder,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect((appeared ? 1 : 0.92) * bounceScale)
        .opacity(appeared ? 1 : 0)
        .animation(
            .timingCurve(0.22, 1, 0.36, 1, duration: 0.48)
                .delay(Double(index) * 0.12),
            value: appeared
        )
    }

    private func select() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            onSelect(option)
            bounceScale = 1.04
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1
            }
        }
    }
}

// MARK: - Step 2a: Doing great
private struct StepDoingGreatPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            MascotView(imageName: "cut-DinoBalloon", size: 200)

            Text("good to hear that! Dino will help you keep things up.")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .italic()
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Step 2b/c: Challenge picker
private struct StepChallengePickerPage: View {
    let options: [String]
    @Binding var selectedChallenge: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            MascotView(imageName: "cut-DinoMascot", size: 140)

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
                .onboardingCardSurface(cornerRadius: 20, padding: 20)
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

    @State private var bounceScale: CGFloat = 1

    var body: some View {
        Button(action: select) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(isSelected ? OnboardingColors.sage : OnboardingColors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? OnboardingColors.sageDeep : OnboardingColors.cardBorder,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect(bounceScale)
    }

    private func select() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            onTap()
            bounceScale = 1.04
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1
            }
        }
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
                            colors: [Color(hex: "#A8C5A0").opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)

                Image("cut-DinoPair")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 180)
                    .shadow(color: Color(hex: "#4A3520").opacity(0.18), radius: 12, x: 0, y: 6)

                // Rising hearts
                ForEach(0..<3, id: \.self) { i in
                    RisingHeart(appeared: appeared, delay: Double(i) * 0.3)
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

private struct RoseHeartShape: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(OnboardingColors.rose)
                .frame(width: size * 0.52, height: size * 0.52)
                .offset(x: -size * 0.18, y: size * 0.04)
            Circle()
                .fill(OnboardingColors.rose)
                .frame(width: size * 0.52, height: size * 0.52)
                .offset(x: size * 0.18, y: size * 0.04)
            Ellipse()
                .fill(OnboardingColors.rose)
                .frame(width: size * 0.55, height: size * 0.42)
                .offset(y: size * 0.14)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#4A3520").opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

private struct RisingHeart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let appeared: Bool
    let delay: Double

    @State private var wobble: Double = -8

    var body: some View {
        let dur: Double = 1.2
        RoseHeartShape(size: 20)
            .opacity(appeared && !reduceMotion ? 0 : (reduceMotion && appeared ? 0.8 : 0))
            .scaleEffect(appeared ? 1 : 0.6)
            .rotationEffect(.degrees(reduceMotion ? 0 : wobble))
            .offset(y: appeared && !reduceMotion ? -80 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.4).delay(delay)
                    : .easeOut(duration: dur).delay(delay),
                value: appeared
            )
            .onChange(of: appeared) { _, isUp in
                guard isUp, !reduceMotion else { return }
                wobble = -8
                withAnimation(.easeInOut(duration: dur).delay(delay)) {
                    wobble = 8
                }
            }
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
                    .font(.custom(DinoTheme.customFontName, size: 20))
                    .italic()
                    .foregroundColor(OnboardingColors.moonlight)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                    .frame(width: 300)
            }

            Image("cut-DinoFlowers")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)

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

            MascotView(imageName: "cut-DinoFlower", size: 160)

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
            .onboardingCardSurface(cornerRadius: 16, padding: 16)
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

            MascotView(imageName: "cut-DinoChecklist", size: 200)

            VStack(spacing: 10) {
                Text("gentle reminders?")
                    .font(.custom(DinoTheme.customFontName, size: 24))
                    .foregroundColor(OnboardingColors.textPrimary)

                Text("dino will help you stay on top of your tasks.")
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(OnboardingColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .onboardingCardSurface(cornerRadius: 16, padding: 20)
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
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(OnboardingColors.sage)
                    Text("reminders enabled!")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(OnboardingColors.sage)
                }
            }

            Button(action: {
                OnboardingMaybeLaterNotifier.fire()
            }) {
                Text("maybe later")
                    .font(.system(size: 15, design: .rounded))
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

            MascotView(imageName: "cut-DinoMascot", size: 160)

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
            .background(OnboardingColors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        focused ? OnboardingColors.sage : OnboardingColors.cardBorder,
                        lineWidth: focused ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Step 10: Thank you + celebration
private struct StepDisclaimerPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mascotScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            MascotView(imageName: "cut-DinoPink", size: 180)
                .scaleEffect(mascotScale)
                .shadow(color: Color(hex: "#4A3520").opacity(0.18), radius: 12, x: 0, y: 6)

            Text("thank you for being honest/brave. i know it isn't easy to talk about your struggles. let's get started!")
                .font(DinoTheme.dinoFont(size: 17))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 280)

            Spacer()
        }
        .onAppear {
            if reduceMotion {
                mascotScale = 1
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                    mascotScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                        mascotScale = 1
                    }
                }
            }
        }
    }
}


// MARK: - Step 8: Anxiety use case (breathing preview)
private struct StepAnxietyUseCasePage: View {
    var body: some View {
        ZStack {
            OnboardingBreathingAmbient()

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                BreathingCircleComposition()
                    .frame(height: 240)

                Text("when anxiety hits")
                    .font(.custom(DinoTheme.customFontName, size: 28))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                (Text("")
                    + Text("4").font(DinoTheme.numericFont(size: 16))
                    + Text(" minutes of breathing activates your body's calm response. dino will guide you through it.")
                        .font(DinoTheme.dinoFont(size: 16)))
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
        }
    }
}

private struct BreathingCircleComposition: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sage = Color(hex: "#A8C5A0")
    private let sky = Color(hex: "#C8E6F5")
    private let period: Double = 10.0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let norm = (t.truncatingRemainder(dividingBy: period)) / period
            let inhale = norm < 0.5

            VStack(spacing: 14) {
                ZStack {
                    breathingLayer(
                        norm: norm,
                        delay: 0,
                        maxScale: 1.12,
                        style: .outerGlow
                    )
                    breathingLayer(
                        norm: norm,
                        delay: 0.05,
                        maxScale: 1.08,
                        style: .midRing
                    )
                    breathingLayer(
                        norm: norm,
                        delay: 0.1,
                        maxScale: 1.05,
                        style: .innerCore
                    )
                }
                .frame(width: 200, height: 200)

                Text(inhale ? "breathe in" : "breathe out")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(OnboardingColors.sage)
                    .id(inhale)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: inhale)
            }
        }
    }

    private enum LayerStyle { case outerGlow, midRing, innerCore }

    @ViewBuilder
    private func breathingLayer(
        norm: Double,
        delay: Double,
        maxScale: CGFloat,
        style: LayerStyle
    ) -> some View {
        let shifted = norm - delay
        let pulse = 0.5 - 0.5 * cos(shifted * 2 * .pi)
        let wave = reduceMotion
            ? 1.0
            : 1.0 + (maxScale - 1.0) * CGFloat(pulse)
        let opacityPulse = reduceMotion
            ? (0.55 + 0.15 * sin(norm * 2 * .pi))
            : 1.0

        Group {
            switch style {
            case .outerGlow:
                Circle()
                    .fill(sage.opacity(0.25 * opacityPulse))
                    .frame(width: 200, height: 200)
                    .blur(radius: 6)
            case .midRing:
                Circle()
                    .stroke(sage.opacity(0.45 * opacityPulse), lineWidth: 2)
                    .frame(width: 168, height: 168)
            case .innerCore:
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [sage, sky],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: sage.opacity(0.45), radius: 20, x: 0, y: 6)
            }
        }
        .scaleEffect(wave)
    }
}

// MARK: - Step 9: Rough day use case (gratitude jar)
private struct StepRoughDayUseCasePage: View {
    var body: some View {
        ZStack {
            OnboardingGratitudeJarAmbient()

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                GratitudeJarStage()
                    .frame(maxWidth: 280)

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

                (Text("people who do this ")
                    + Text("3").font(DinoTheme.numericFont(size: 11))
                    + Text("x a week report feeling more grounded")
                        .font(DinoTheme.dinoFont(size: 11)))
                    .foregroundColor(OnboardingColors.textSecondary.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                Spacer()
            }
        }
    }
}

private struct GratitudeSlipSpec {
    let text: String
    let color: Color
    let rotation: Double
    let xOffset: CGFloat
}

private struct GratitudeJarStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cycle: Int = 0

    private static let slips: [GratitudeSlipSpec] = [
        GratitudeSlipSpec(text: "quiet morning", color: OnboardingColors.peach, rotation: -10, xOffset: -28),
        GratitudeSlipSpec(text: "good tea", color: OnboardingColors.lavender, rotation: 8, xOffset: 22),
        GratitudeSlipSpec(text: "kind words", color: OnboardingColors.sky, rotation: -6, xOffset: -8),
        GratitudeSlipSpec(text: "sunshine", color: OnboardingColors.sage, rotation: 12, xOffset: 30),
        GratitudeSlipSpec(text: "deep breath", color: OnboardingColors.rose, rotation: -12, xOffset: 0)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<Self.slips.count, id: \.self) { i in
                GratitudeSlipView(
                    spec: Self.slips[i],
                    index: i,
                    cycle: cycle,
                    reduceMotion: reduceMotion
                )
            }
            gratitudeJar
        }
        .frame(width: 220, height: 260)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FEFBF3"), Color(hex: "#F4F0E4")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .onAppear {
            guard !reduceMotion else { return }
            scheduleNextCycle()
        }
    }

    private var gratitudeJar: some View {
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

            ZStack(alignment: .bottom) {
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

    private func scheduleNextCycle() {
        let lastDelay = Double(Self.slips.count - 1) * 0.45 + 1.1
        let repeatAfter = lastDelay + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + repeatAfter) {
            cycle += 1
            scheduleNextCycle()
        }
    }
}

private struct GratitudeSlipView: View {
    let spec: GratitudeSlipSpec
    let index: Int
    let cycle: Int
    let reduceMotion: Bool

    @State private var dropY: CGFloat = -130
    @State private var landed: Bool = false
    @State private var squishY: CGFloat = 1

    private let landY: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(spec.color.opacity(0.6))
                .frame(width: 80, height: 28)
            Text(spec.text)
                .font(DinoTheme.dinoFont(size: 9))
                .foregroundColor(OnboardingColors.textPrimary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .rotationEffect(.degrees(spec.rotation))
        .offset(x: spec.xOffset, y: dropY)
        .scaleEffect(x: 1, y: squishY, anchor: .bottom)
        .opacity(reduceMotion && landed ? 0.9 : 1)
        .onAppear { runDrop() }
        .onChange(of: cycle) { _, _ in resetAndDrop() }
    }

    private func runDrop() {
        resetAndDrop()
    }

    private func resetAndDrop() {
        dropY = -130
        landed = false
        squishY = 1
        let delay = Double(index) * 0.45

        if reduceMotion {
            dropY = landY
            landed = true
            return
        }

        withAnimation(.easeIn(duration: 1.0).delay(delay)) {
            dropY = landY
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.0) {
            landed = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                squishY = 0.85
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    squishY = 1
                }
            }
        }
    }
}
