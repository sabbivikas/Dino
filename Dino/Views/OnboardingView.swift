//
//  OnboardingView.swift
//  Dino
//
//  v6 design-system onboarding. Uses NatureBackdrop / StarfieldBackdrop
//  and the shared MascotView / WordRevealText / Confetti components.
//

import SwiftUI
import UserNotifications

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
            AudioManager.shared.play(track: "onboarding_ambient")
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
                pill(
                    label: "doing great",
                    bg: OnboardingColors.peach,
                    option: "doing great!",
                    index: 0
                )
                pill(
                    label: "it's a challenge",
                    bg: OnboardingColors.sky,
                    option: "ongoing mental health challenges",
                    index: 1
                )
                pill(
                    label: "somewhere in between",
                    bg: OnboardingColors.lavender,
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
    private func pill(label: String, bg: Color, option: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { selectedFeeling = option }
        }) {
            Text(label)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(bg)
                .cornerRadius(24)
                .shadow(color: OnboardingColors.textPrimary.opacity(0.10), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            selectedFeeling == option
                                ? OnboardingColors.sage
                                : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect(appeared ? 1 : 0.92)
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
                .font(.custom(DinoTheme.customFontName, size: 18))
                .italic()
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
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : OnboardingColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(isSelected ? OnboardingColors.sage : OnboardingColors.cardWhite)
                .cornerRadius(16)
                .shadow(color: OnboardingColors.textPrimary.opacity(0.06), radius: 4, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected
                                ? OnboardingColors.sage
                                : OnboardingColors.sage.opacity(0.15),
                            lineWidth: 1.2
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
                .font(.system(size: 17, design: .rounded))
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

    var body: some View {
        let dur: Double = 1.2
        Image(systemName: "heart.fill")
            .font(.system(size: 22))
            .foregroundColor(Color(hex: "#E8B4B8"))
            .opacity(appeared && !reduceMotion ? 0 : (reduceMotion && appeared ? 0.8 : 0))
            .scaleEffect(appeared ? 1 : 0.6)
            .offset(y: appeared && !reduceMotion ? -80 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.4).delay(delay)
                    : .easeOut(duration: dur).delay(delay),
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
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)
                Spacer()
            }
            .padding(16)
            .background(OnboardingColors.cardWhite)
            .cornerRadius(16)
            .shadow(color: OnboardingColors.textPrimary.opacity(0.06), radius: 4, x: 0, y: 1)
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

            Text("gentle reminders?")
                .font(.custom(DinoTheme.customFontName, size: 24))
                .foregroundColor(OnboardingColors.textPrimary)

            Text("dino will help you stay on top of your tasks.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
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
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(OnboardingColors.placeholder)
                        .padding(.horizontal, 16)
                }
                TextField("", text: $userName)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .padding(.horizontal, 16)
                    .focused($focused)
                    .onAppear { focused = true }
            }
            .frame(height: 56)
            .background(OnboardingColors.cardWhite)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(OnboardingColors.sage, lineWidth: 1.4)
            )
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

            Image("cut-DinoPink")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .shadow(color: Color(hex: "#4A3520").opacity(0.18), radius: 12, x: 0, y: 6)

            Text("thank you for being honest/brave. i know it isn't easy to talk about your struggles. let's get started!")
                .font(.system(size: 15, design: .rounded))
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
    @State private var pulsing: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E8F0E2"), Color(hex: "#D6E5CC")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(0.85)

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(OnboardingColors.sage.opacity(0.18))
                        .frame(width: 200, height: 200)
                        .blur(radius: 18)

                    Circle()
                        .fill(OnboardingColors.sage.opacity(0.6))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulsing && !reduceMotion ? 1.18 : 1.0)
                        .shadow(color: OnboardingColors.sage.opacity(0.45), radius: 20, x: 0, y: 6)
                        .animation(
                            reduceMotion
                                ? .default
                                : .easeInOut(duration: 3).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                }
                .frame(height: 220)

                Text("when anxiety hits")
                    .font(.custom(DinoTheme.customFontName, size: 28))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("4 minutes of breathing activates your body's calm response. dino will guide you through it.")
                    .font(.system(size: 14, design: .rounded))
                    .italic()
                    .foregroundColor(OnboardingColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Text("used by people before meetings, after hard news, during panic moments")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(OnboardingColors.textSecondary.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                Spacer()
            }
        }
        .onAppear {
            if !reduceMotion { pulsing = true }
        }
    }
}

// MARK: - Step 9: Rough day use case
private struct StepRoughDayUseCasePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false

    private let tokenColors: [Color] = [
        Color(hex: "#F5C6AA"),
        Color(hex: "#A8D4E6"),
        Color(hex: "#C4B8D4"),
        Color(hex: "#E8B4B8"),
        Color(hex: "#A8C5A0")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FAF6EC"), Color(hex: "#F5C6AA").opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                jarVisual
                    .frame(width: 180, height: 220)

                Text("one small good thing")
                    .font(.custom(DinoTheme.customFontName, size: 28))
                    .foregroundColor(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("on hard days, dropping one moment into your jar shifts something. it doesn't have to be big.")
                    .font(.system(size: 14, design: .rounded))
                    .italic()
                    .foregroundColor(OnboardingColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Text("people who do this 3x a week report feeling more grounded")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(OnboardingColors.textSecondary.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                Spacer()
            }
        }
        .onAppear { appeared = true }
    }

    private var jarVisual: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<tokenColors.count, id: \.self) { i in
                FallingToken(
                    color: tokenColors[i],
                    index: i,
                    appeared: appeared,
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

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(hex: "#FEFBF3").opacity(0.75))
                        .frame(width: 130, height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(OnboardingColors.sage.opacity(0.45), lineWidth: 1.4)
                        )
                        .shadow(color: OnboardingColors.textPrimary.opacity(0.10), radius: 8, x: 0, y: 4)

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(tokenColors[i].opacity(0.8))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

private struct FallingToken: View {
    @State private var dropped: Bool = false
    let color: Color
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    var body: some View {
        let xOffsets: [CGFloat] = [-30, -10, 10, 30, 0]
        let startX = xOffsets[index % xOffsets.count]
        let delay = Double(index) * 0.6

        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 1)
            .offset(x: startX, y: dropped ? 90 : -120)
            .opacity(dropped ? 0 : (appeared ? 1 : 0))
            .rotationEffect(.degrees(dropped ? 180 : 0))
            .onAppear {
                guard appeared else { return }
                if reduceMotion {
                    dropped = false
                    return
                }
                withAnimation(
                    .easeIn(duration: 1.4)
                        .delay(delay)
                        .repeatForever(autoreverses: false)
                ) {
                    dropped = true
                }
            }
    }
}
