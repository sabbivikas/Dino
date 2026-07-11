//
//  HomeView.swift
//  Dino
//

import Combine

/// Debounces calls so simultaneous data changes — e.g. a Firestore sync that
/// updates streak, journal, gratitude, and breathing in the same tick —
/// trigger a single refresh instead of 5 back-to-back ones.
private final class RefreshDebouncer: ObservableObject {
    private var cancellable: AnyCancellable?

    func schedule(_ action: @escaping () -> Void) {
        cancellable?.cancel()
        cancellable = Just(())
            .delay(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { _ in action() }
    }
}
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: HomeViewModel = HomeViewModel(dataManager: SharedDataManager.shared)
    @StateObject private var notificationStore = NotificationStore.shared
    @StateObject private var refreshDebouncer = RefreshDebouncer()
    @State private var showNotificationCenter = false
    @AppStorage("dino.showStreak") private var showStreak: Bool = true
    @AppStorage("dino.streakHintSeen") private var streakHintSeen: Bool = false
    @AppStorage("dino.lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion: String = ""
    @State private var showWhatsNew: Bool = false
    @State private var streakBurst: Bool = false
    @State private var resumeBurst: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var navigateToStreak: Bool = false
    @State private var showWorld: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                DinoTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Greeting header with mascot
                        greetingHeader

                        // Action Grid
                        actionGrid

                        // Today's Focus Card
                        focusCard

                        // Gentle note
                        gentleNoteCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DinoTheme.padding)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    headerLeading
                }
                ToolbarItem(placement: .topBarTrailing) {
                    headerTrailing
                }
            }
            .navigationDestination(isPresented: $viewModel.showBreathing) {
                BreathingView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showMeditation) {
                MeditationView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showFocus) {
                FocusView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showAffirmations) {
                AffirmationsView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showGrowth) {
                GrowthView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showAssessment) {
                AssessmentView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showRhythms) {
                RhythmsView(analysis: RhythmsDataAdapter.currentAnalysis(),
                            moodSequence: RhythmsDataAdapter.recentMoodSequence())
            }
            .navigationDestination(isPresented: $viewModel.showResources) {
                ResourcesView().environmentObject(dataManager)
            }
            .onAppear {
                // Dev shortcut for garden-ecosystem simulator verification.
                if GardenDebug.autoOpen { viewModel.showGrowth = true }
                #if DEBUG
                // -breathQA: jump straight to the breathing coach entry.
                if ProcessInfo.processInfo.arguments.contains("-breathQA") {
                    viewModel.showBreathing = true
                }
                // -resourcesQA: jump straight to the support resources screen.
                if ProcessInfo.processInfo.arguments.contains("-resourcesQA") {
                    viewModel.showResources = true
                }
                #endif
                #if DEBUG
                // -healthQA: fire the sleep authorization sheet on launch so the
                // request path is verifiable without navigating to profile.
                if ProcessInfo.processInfo.arguments.contains("-healthQA") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        Task { _ = await HealthService.shared.requestSleepPermission() }
                    }
                }
                #endif
            }
            .onReceive(dataManager.$showBreathingFromDeepLink) { shouldShow in
                guard shouldShow else { return }
                viewModel.showBreathing = true
                dataManager.showBreathingFromDeepLink = false
            }
            .onReceive(dataManager.$showFocusFromDeepLink) { shouldShow in
                guard shouldShow else { return }
                viewModel.showFocus = true
                dataManager.showFocusFromDeepLink = false
            }
            .onReceive(dataManager.$showMeditationFromDeepLink) { shouldShow in
                guard shouldShow else { return }
                viewModel.showMeditation = true
                dataManager.showMeditationFromDeepLink = false
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
            .fullScreenCover(isPresented: $showWorld) {
                WorldView()
            }
            .onAppear {
                #if DEBUG
                // Dev shortcut: jump straight to the world when verifying with
                // the -worldTestAggregate fixture on the simulator.
                if ProcessInfo.processInfo.arguments.contains("-worldTestAggregate") {
                    showWorld = true
                }
                #endif
            }
            .sheet(isPresented: $showWhatsNew, onDismiss: {
                lastSeenWhatsNewVersion = currentAppVersion()
            }) {
                WhatsNewView()
            }
            .onAppear {
                refreshNotifications()
                AnalyticsManager.shared.trackHomeOpened()
                AnalyticsManager.shared.trackScreen("home")
                maybeShowWhatsNew()
            }
            // Coalesce simultaneous data changes (typical during Firestore sync)
            // into a single 150ms-debounced refresh.
            .onChange(of: dataManager.streakData.currentStreak) { _, _ in refreshDebouncer.schedule { refreshNotifications() } }
            .onChange(of: dataManager.journalEntries.count) { _, _ in refreshDebouncer.schedule { refreshNotifications() } }
            .onChange(of: dataManager.gratitudeNotes.count) { _, _ in refreshDebouncer.schedule { refreshNotifications() } }
            .onChange(of: dataManager.breathingSessions.count) { _, _ in refreshDebouncer.schedule { refreshNotifications() } }
            .onChange(of: dataManager.meditationSessions.count) { _, _ in refreshDebouncer.schedule { refreshNotifications() } }
        }
    }

    private func toggleStreakDisplay() {
        HapticManager.shared.medium()
        if showStreak {
            withAnimation(.easeOut(duration: 0.4)) {
                showStreak = false
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showStreak = true
            }
            resumeBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    resumeBurst = false
                }
            }
            streakBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                streakBurst = false
            }
        }
        if !streakHintSeen {
            withAnimation(.easeOut(duration: 0.3)) {
                streakHintSeen = true
            }
        }
    }

    private func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func maybeShowWhatsNew() {
        #if DEBUG
        // -whatsNewQA: force the carousel (normal users see it once per version)
        if ProcessInfo.processInfo.arguments.contains("-whatsNewQA") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showWhatsNew = true }
            return
        }
        #endif
        guard WhatsNewGate.shouldShow(lastSeen: lastSeenWhatsNewVersion,
                                      current: currentAppVersion()) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showWhatsNew = true
        }
    }

    private func refreshNotifications() {
        // Use the most-recent journal date (not the first array element) so we
        // don't depend on whether the array is newest-first or insertion-order.
        let lastJournalDate = dataManager.journalEntries.map { $0.date }.max()
        // Mood painting feature is currently disabled — pass safe defaults
        // so the notification refresh signature is preserved for future re-enable.
        notificationStore.refreshFromData(
            streakDays: dataManager.streakData.currentStreak,
            journalCount: dataManager.journalEntries.count,
            gratitudeCount: dataManager.gratitudeNotes.count,
            lastJournalDate: lastJournalDate,
            hasMonthlyPainting: false,
            paintingMonthKey: "",
            breathingSessionCount: dataManager.breathingSessions.count,
            meditationSessionCount: dataManager.meditationSessions.count
        )
    }

    // MARK: - Header Leading (Avatar)

    private var headerLeading: some View {
        Button {
            dataManager.deepLinkTab = 4
        } label: {
            Image.cached("DinoMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
    }

    // MARK: - Header Trailing (Streak + Settings)

    private var headerTrailing: some View {
        HStack(spacing: 14) {
            // Streak egg — tap to open calendar, long-press to pause/resume
            VStack(spacing: 1) {
                ZStack {
                    if showStreak {
                        Image(systemName: "oval.fill")
                            .font(DinoTheme.dinoFont(size: 22))
                            .foregroundColor(DinoTheme.peach.opacity(0.5))
                        Text("\(dataManager.streakData.currentStreak)")
                            .font(DinoTheme.numericFont(size: 10))
                            .foregroundColor(DinoTheme.textPrimary)
                            .offset(y: 1)
                        if streakBurst {
                            Text("\u{1F525}")
                                .font(.system(size: 18))
                                .scaleEffect(1.4)
                                .opacity(0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: streakBurst)
                        }
                    } else {
                        Circle()
                            .fill(Color(hex: "#E8E4D5"))
                            .frame(width: 24, height: 24)
                        Circle()
                            .strokeBorder(
                                Color(hex: "#A8C5A0").opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                            .frame(width: 24, height: 24)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#A8C5A0"))
                    }
                }
                .frame(width: 28, height: 28)
                .scaleEffect(showStreak ? (resumeBurst ? 1.2 : 1.0) : pulseScale)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.light()
                    navigateToStreak = true
                    if !streakHintSeen {
                        withAnimation(.easeOut(duration: 0.3)) {
                            streakHintSeen = true
                        }
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    toggleStreakDisplay()
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.05
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToStreak) {
                StreakCalendarView().environmentObject(dataManager)
            }

            Button {
                showNotificationCenter = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(DinoTheme.dinoFont(size: 18))
                        .foregroundColor(Color(hex: "#8B7A6A"))
                        .frame(width: 22, height: 22)

                    if notificationStore.unreadCount > 0 {
                        Text("\(min(notificationStore.unreadCount, 9))")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 12, height: 12)
                            .background(Circle().fill(Color(hex: "#E8746A")))
                            .offset(x: 4, y: -4)
                    }
                }
            }

        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayName) 🌿")
                    .font(DinoTheme.dinoLabelFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)

                Text("how are you\nfeeling today?".localized)
                    .font(DinoTheme.dinoDisplayFont(size: 30))
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineSpacing(2)
            }

            Spacer()

            Image.cached("DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
        }
        .padding(.top, DinoDesignSystem.space7)
        .padding(.bottom, DinoDesignSystem.space2)
    }

    // MARK: - Today's Focus Card

    private var focusCard: some View {
        VStack(spacing: 0) {
            // Golden weather scene (130pt) — sun, drifting clouds, parallax hills,
            // ground line, and a walking stickman traveler.
            FocusCardScene()
                .frame(height: 130)

            // Content section
            VStack(alignment: .leading, spacing: 12) {
                Text("today's focus".localized)
                    .font(DinoTheme.dinoLabelFont(size: 15))
                    .foregroundColor(DinoTheme.textSecondary)
                    .tracking(0.3)

                HStack(spacing: 8) {
                    Text(viewModel.todaysFocusEmoji)
                        .font(DinoTheme.dinoFont(size: 24))
                    Text(viewModel.todaysFocus)
                        .font(DinoTheme.dinoDisplayFont(size: 26))
                        .foregroundColor(DinoTheme.textPrimary)
                }
                .padding(.top, -4)

                weeklyTracker
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DinoTheme.surfacePrimary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: "#D1D5DB"), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: DinoDesignSystem.cardShadowRadius,
            y: DinoDesignSystem.cardShadowY
        )
    }

    // MARK: - Weekly Tracker (v9 spec)

    private var weeklyTracker: some View {
        let days = viewModel.weeklyActivity()
        let peach = Color(hex: "#F5C6AA")
        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(DinoTheme.textSecondary)

                    ZStack {
                        if day.isToday {
                            Circle()
                                .fill(peach.opacity(0.25))
                                .frame(width: 40, height: 40)
                        }
                        Circle()
                            .fill((day.isCompleted || day.isToday) ? peach : DinoTheme.surfaceSecondary)
                            .frame(
                                width: day.isToday ? 32 : 28,
                                height: day.isToday ? 32 : 28
                            )
                        if day.isCompleted || day.isToday {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 40)
                    .animation(
                        .spring(
                            response: DinoDesignSystem.interactiveSpringResponse,
                            dampingFraction: DinoDesignSystem.interactiveSpringDamping
                        ),
                        value: day.isCompleted
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 3x3 Action Grid

    private var actionGrid: some View {
        let rows = [
            [
                ActionItem(id: "journal", title: "Journal", icon: "mic.fill", color: DinoTheme.sageGreen, tab: 1),
                ActionItem(id: "mood", title: "Mood", icon: "cloud.sun.fill", color: DinoTheme.skyBlue, tab: 2),
                ActionItem(id: "gratitude", title: "Gratitude", icon: "archivebox.fill", color: DinoTheme.peach, tab: 3),
            ],
            [
                ActionItem(id: "breathing", title: "Breathing", icon: "circle.circle", color: DinoTheme.lavender, tab: nil),
                ActionItem(id: "meditation", title: "Meditation", icon: "leaf.fill", color: DinoTheme.sageGreen.opacity(0.8), tab: nil),
                ActionItem(id: "affirmations", title: "Affirm", icon: "sparkles", color: DinoTheme.warmRose, tab: nil),
            ],
            [
                ActionItem(id: "rhythms", title: "rhythms", icon: "waveform.path", color: DinoTheme.lavender, tab: nil),
                ActionItem(id: "growth", title: "Growth", icon: "tree.fill", color: DinoTheme.sageGreen, tab: nil),
                // world replaced the Help tile (slot 9); Help lives on in
                // Profile → resources. Circle tints toward today's dominant
                // world mood when the aggregate is cached.
                ActionItem(id: "world", title: "world", icon: "globe.americas.fill", color: worldTileColor, tab: nil),
            ]
        ]

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 10) {
                    ForEach(row) { item in
                        actionCard(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(item: ActionItem) -> some View {
        let isPressed = viewModel.tappedCard == item.id

        return Button {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.animateCardTap(item.id)
            }
            handleCardTap(item)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.20))
                        .frame(width: DinoDesignSystem.iconCircleSize, height: DinoDesignSystem.iconCircleSize)

                    Image(systemName: item.icon)
                        .font(DinoTheme.dinoFont(size: 20))
                        .foregroundColor(item.color)
                }

                Text(item.title)
                    .font(DinoTheme.dinoLabelFont(size: 13))
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)   // "Meditation" never truncates in a narrow column
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, DinoDesignSystem.space3)
            .background(DinoTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(item.color.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(
                color: isPressed ? item.color.opacity(0.15) : Color.black.opacity(0.04),
                radius: isPressed ? DinoDesignSystem.pressShadowRadius : 10,
                y: DinoDesignSystem.cardShadowY
            )
            .scaleEffect(isPressed ? DinoDesignSystem.pressScaleDeep : 1.0)
            .animation(.spring(response: DinoDesignSystem.interactiveSpringResponse, dampingFraction: DinoDesignSystem.interactiveSpringDamping), value: isPressed)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gentle Note Card

    private var gentleNoteCard: some View {
        VStack(alignment: .leading, spacing: DinoDesignSystem.space2) {
            Text("a gentle note".localized)
                .font(DinoTheme.dinoLabelFont(size: 13))
                .foregroundColor(DinoTheme.textSecondary)

            Text("you showed up today — and that's already something. 🌱".localized)
                .font(DinoTheme.dinoFont(size: 18))
                .foregroundColor(DinoTheme.textPrimary)
                .lineSpacing(4)
        }
        .padding(DinoTheme.padding)
        .dsCardLarge()
    }

    // MARK: - Card Tap Handler

    private func handleCardTap(_ item: ActionItem) {
        AnalyticsManager.shared.trackActionCardTapped(feature: item.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let tab = item.tab {
                dataManager.deepLinkTab = tab
            } else {
                switch item.id {
                case "breathing":
                    viewModel.showBreathing = true
                case "meditation":
                    viewModel.showMeditation = true
                case "affirmations":
                    viewModel.showAffirmations = true
                case "growth":
                    viewModel.showGrowth = true
                case "assessment":
                    viewModel.showAssessment = true
                case "rhythms":
                    viewModel.showRhythms = true
                case "resources":
                    viewModel.showResources = true
                case "world":
                    showWorld = true
                default:
                    break
                }
            }
        }
    }

    // MARK: - Helpers

    /// Subtle lerp from sage toward today's dominant world mood (cached only).
    private var worldTileColor: Color {
        let base = DinoTheme.sageGreen
        guard let mood = WorldMoodService.cachedTodayBucket?.global.dominantMood else { return base }
        return base.opacity(0.65).blendedWorldTint(DinoWorldPalette.moodSwiftUIColor(mood))
    }

    private var displayName: String {
        let name = dataManager.userName
        if name.isEmpty { return viewModel.greeting }
        return "\(viewModel.greeting), \(name)"
    }

    private var avatarInitial: String {
        let name = dataManager.userName
        if name.isEmpty { return "🦕" }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - Focus Card Golden Scene (v9 spec)
//
// Layout matches preview/focus-card.html: 130pt height, gradient sky
// #FEF0D0 -> #FEF6E8, an animated sun with rays/blink/smile up top,
// two parallax drifting clouds, two layers of rolling hills, a ground
// line with pebbles, and a small walking stickman traveler.

private struct FocusCardScene: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FEF0D0"), Color(hex: "#FEF6E8")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Sun, centered horizontally near the top
                FocusCardSun()
                    .frame(width: 44, height: 44)
                    .position(x: w / 2, y: 32)

                // Two drifting clouds — primary and a smaller dimmer one
                FocusCardCloudLayer(width: w, topOffset: 18, duration: 22, scale: 1.0, opacity: 0.85, phase: 0)
                FocusCardCloudLayer(width: w, topOffset: 32, duration: 32, scale: 0.7, opacity: 0.6, phase: 0.45)

                // Parallax hills + ground sit at the bottom of the scene
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .bottom) {
                        FocusCardHillLayer(
                            color: Color(hex: "#D4C490"),
                            height: 28,
                            opacity: 0.55,
                            duration: 14,
                            backLayer: true
                        )
                        .frame(height: 28)
                        .offset(y: -22)

                        FocusCardHillLayer(
                            color: Color(hex: "#E8D9A8"),
                            height: 22,
                            opacity: 1.0,
                            duration: 8,
                            backLayer: false
                        )
                        .frame(height: 22)
                        .offset(y: -16)

                        // Ground line + pebbles
                        FocusCardGround(width: w)
                    }
                }

                // Walking stickman traveler — sits on the ground line, ~38pt from left
                FocusCardWalker()
                    .frame(width: 44, height: 52)
                    .position(x: 38 + 22, y: geo.size.height - 10 - 26)
            }
            .clipped()
        }
        .onAppear { animate = true }
    }
}

// MARK: - Sun (Canvas) — rays spin slowly, body pulses, eyes blink occasionally

private struct FocusCardSun: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // All motion derived from wall-clock time — replaces an unmanaged
            // repeating Timer that accumulated on every Home appearance and was
            // never invalidated. Rays: one revolution / 14s. Pulse: 1.0↔1.08
            // over a 3s round trip. Blink: snap shut ~0.28s every 4s.
            let rayAngle = (t / 14.0).truncatingRemainder(dividingBy: 1.0) * 360.0
            let pulse: CGFloat = 1.04 + 0.04 * CGFloat(sin(t * 2 * .pi / 3.0))
            let cyc = t.truncatingRemainder(dividingBy: 4.0)
            let blink: CGFloat = cyc < 0.08 ? (1.0 - 0.9 * CGFloat(cyc / 0.08))
                : (cyc < 0.18 ? 0.1
                : (cyc < 0.28 ? (0.1 + 0.9 * CGFloat((cyc - 0.18) / 0.1)) : 1.0))
            sunCanvas(rayAngle: rayAngle, pulse: pulse, blink: blink)
        }
    }

    private func sunCanvas(rayAngle: Double, pulse: CGFloat, blink: CGFloat) -> some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let strokeColor = Color(hex: "#D4920A")
            let bodyFill = Color(hex: "#FFD89B")
            let eyeColor = Color(hex: "#8B5530")
            let blushColor = Color(hex: "#F5B4B8")

            // Rays
            context.translateBy(x: cx, y: cy)
            context.rotate(by: .degrees(rayAngle))
            let rayInner: CGFloat = 13
            let rayOuter: CGFloat = 19
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                var ray = Path()
                ray.move(to: CGPoint(x: rayInner * cos(a), y: rayInner * sin(a)))
                ray.addLine(to: CGPoint(x: rayOuter * cos(a), y: rayOuter * sin(a)))
                context.stroke(ray, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
            context.rotate(by: .degrees(-rayAngle))

            // Body (pulsing)
            let r: CGFloat = 10 * pulse
            let bodyRect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            let body = Path(ellipseIn: bodyRect)
            context.fill(body, with: .color(bodyFill))
            context.stroke(body, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.8))

            // Eyes — scaleY-blink
            let eyeH: CGFloat = 2 * blink
            let leftEye = Path(ellipseIn: CGRect(x: -3 - 0.5, y: -2 - eyeH / 2, width: 1.6, height: eyeH))
            let rightEye = Path(ellipseIn: CGRect(x: 3 - 1.1, y: -2 - eyeH / 2, width: 1.6, height: eyeH))
            context.fill(leftEye, with: .color(eyeColor))
            context.fill(rightEye, with: .color(eyeColor))

            // Smile
            var smile = Path()
            smile.move(to: CGPoint(x: -3, y: 2))
            smile.addQuadCurve(to: CGPoint(x: 3, y: 2), control: CGPoint(x: 0, y: 5))
            context.stroke(smile, with: .color(eyeColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            // Blush cheeks
            let leftBlush = Path(ellipseIn: CGRect(x: -5 - 1.3, y: 2, width: 2.6, height: 2.6))
            let rightBlush = Path(ellipseIn: CGRect(x: 3 + 0, y: 2, width: 2.6, height: 2.6))
            context.fill(leftBlush, with: .color(blushColor.opacity(0.6)))
            context.fill(rightBlush, with: .color(blushColor.opacity(0.6)))
        }
    }
}

// MARK: - Drifting cloud layer

private struct FocusCardCloudLayer: View {
    let width: CGFloat
    let topOffset: CGFloat
    let duration: Double
    let scale: CGFloat
    let opacity: Double
    let phase: Double

    @State private var x: CGFloat = -1

    var body: some View {
        FocusCardCloud()
            .frame(width: 60, height: 22)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: x, y: topOffset + 11)
            .onAppear {
                let span = width + 100
                x = -50 + span * CGFloat(phase)
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    x = width + 50
                }
            }
    }
}

private struct FocusCardCloud: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var cloud = Path()
            cloud.move(to: CGPoint(x: 12/60 * w, y: 8/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 6/60 * w, y: 13/22 * h),
                               control: CGPoint(x: 6/60 * w, y: 8/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 2/60 * w, y: 18/22 * h),
                               control: CGPoint(x: 2/60 * w, y: 13/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 6/60 * w, y: 21/22 * h),
                               control: CGPoint(x: 2/60 * w, y: 21/22 * h))
            cloud.addLine(to: CGPoint(x: 52/60 * w, y: 21/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 58/60 * w, y: 15/22 * h),
                               control: CGPoint(x: 58/60 * w, y: 21/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 52/60 * w, y: 10/22 * h),
                               control: CGPoint(x: 58/60 * w, y: 10/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 42/60 * w, y: 3/22 * h),
                               control: CGPoint(x: 51/60 * w, y: 3/22 * h))
            cloud.addQuadCurve(to: CGPoint(x: 28/60 * w, y: 5/22 * h),
                               control: CGPoint(x: 34/60 * w, y: 0))
            cloud.addQuadCurve(to: CGPoint(x: 12/60 * w, y: 8/22 * h),
                               control: CGPoint(x: 20/60 * w, y: 2/22 * h))
            cloud.closeSubpath()
            context.fill(cloud, with: .color(.white.opacity(0.95)))
            context.stroke(cloud, with: .color(Color(hex: "#B8C4D0")),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Parallax hill layer (scrolling tiled wave)

private struct FocusCardHillLayer: View {
    let color: Color
    let height: CGFloat
    let opacity: Double
    let duration: Double
    let backLayer: Bool

    @State private var offsetX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let tileW: CGFloat = 420
            HStack(spacing: 0) {
                hillTile(width: tileW, height: height)
                hillTile(width: tileW, height: height)
            }
            .frame(width: tileW * 2, height: height)
            .offset(x: offsetX)
            .frame(width: geo.size.width, height: height, alignment: .leading)
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    offsetX = -tileW
                }
            }
        }
        .frame(height: height)
        .opacity(opacity)
    }

    private func hillTile(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var p = Path()
            if backLayer {
                p.move(to: CGPoint(x: 0, y: h))
                p.addQuadCurve(to: CGPoint(x: w * (140.0/420.0), y: h * (18.0/28.0)),
                               control: CGPoint(x: w * (70.0/420.0), y: h * (8.0/28.0)))
                p.addQuadCurve(to: CGPoint(x: w * (280.0/420.0), y: h * (14.0/28.0)),
                               control: CGPoint(x: w * (210.0/420.0), y: h))
                p.addQuadCurve(to: CGPoint(x: w, y: h * (18.0/28.0)),
                               control: CGPoint(x: w * (350.0/420.0), y: h * (6.0/28.0)))
            } else {
                p.move(to: CGPoint(x: 0, y: h))
                p.addQuadCurve(to: CGPoint(x: w * (160.0/420.0), y: h * (14.0/22.0)),
                               control: CGPoint(x: w * (80.0/420.0), y: h * (6.0/22.0)))
                p.addQuadCurve(to: CGPoint(x: w * (320.0/420.0), y: h * (10.0/22.0)),
                               control: CGPoint(x: w * (240.0/420.0), y: h))
                p.addQuadCurve(to: CGPoint(x: w, y: h * (14.0/22.0)),
                               control: CGPoint(x: w * (400.0/420.0), y: h * (6.0/22.0)))
            }
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            context.fill(p, with: .color(color))
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Ground line + pebbles

private struct FocusCardGround: View {
    let width: CGFloat
    @State private var pebbleOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            // Ground line — fades at the edges
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(hex: "#A88A4A"), location: 0.06),
                    .init(color: Color(hex: "#A88A4A"), location: 0.94),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
            .opacity(0.5)
            .offset(y: -4)

            // Pebbles — tile of 60pt, scrolls slowly leftward
            HStack(spacing: 0) {
                ForEach(0..<(Int(width / 60) + 3), id: \.self) { _ in
                    PebbleTile()
                        .frame(width: 60, height: 4)
                }
            }
            .offset(x: pebbleOffset)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    pebbleOffset = -60
                }
            }
        }
        .frame(height: 4)
        .offset(y: -10)
        .frame(maxWidth: .infinity)
    }
}

private struct PebbleTile: View {
    var body: some View {
        Canvas { context, _ in
            let stone = Color(hex: "#A88A4A")
            let pebbles: [(CGFloat, CGFloat, CGFloat, Double)] = [
                (4, 2, 0.8, 0.55),
                (22, 3, 0.6, 0.45),
                (38, 2, 0.7, 0.5),
                (52, 3, 0.5, 0.4)
            ]
            for (x, y, r, o) in pebbles {
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(stone.opacity(o)))
            }
        }
        .frame(width: 60, height: 4)
    }
}

// MARK: - Walking stickman traveler

private struct FocusCardWalker: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            // The old unmanaged Timer advanced `phase` by 0.22 per 1/30s tick
            // (6.6 rad/s) and was never invalidated — it accumulated on every
            // Home appearance. Deriving from wall-clock time leaks nothing.
            let phase = timeline.date.timeIntervalSinceReferenceDate * 6.6
            let bob = CGFloat(sin(phase) * 0.75 - 0.75)
            walkerCanvas(phase: phase)
                .offset(y: bob)
        }
    }

    private func walkerCanvas(phase: Double) -> some View {
        Canvas { context, size in
            // viewBox 0..60 mapped into size
            let sx = size.width / 60
            let sy = size.height / 60
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: CGFloat(x) * sx, y: CGFloat(y) * sy)
            }

            let ink = Color(hex: "#2D3142")
            let skin = Color(hex: "#FDE6CB")
            let pack = Color(hex: "#A8C5A0")
            let hatColor = Color(hex: "#8B6E4E")

            // Ground shadow
            let shadow = Path(ellipseIn: CGRect(
                x: (30 - 13) * sx, y: (58 - 1.6) * sy,
                width: 26 * sx, height: 3.2 * sy))
            context.fill(shadow, with: .color(.black.opacity(0.10)))

            // Backpack
            let packRect = CGRect(x: 16 * sx, y: 22 * sy, width: 11 * sx, height: 16 * sy)
            let packPath = Path(roundedRect: packRect, cornerRadius: 2.6 * sx)
            context.fill(packPath, with: .color(pack))
            context.stroke(packPath, with: .color(ink), style: StrokeStyle(lineWidth: 1.8))

            // Hat brim + crown
            let brim = Path(ellipseIn: CGRect(
                x: (30 - 9) * sx, y: (16 - 2) * sy,
                width: 18 * sx, height: 4 * sy))
            context.fill(brim, with: .color(hatColor))
            context.stroke(brim, with: .color(ink), style: StrokeStyle(lineWidth: 1.8))

            var crown = Path()
            crown.move(to: pt(25, 15))
            crown.addQuadCurve(to: pt(35, 15), control: pt(30, 8))
            crown.closeSubpath()
            context.fill(crown, with: .color(hatColor))
            context.stroke(crown, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

            // Head
            let head = Path(ellipseIn: CGRect(
                x: (30 - 4.2) * sx, y: (20 - 4.2) * sy,
                width: 8.4 * sx, height: 8.4 * sy))
            context.fill(head, with: .color(skin))
            context.stroke(head, with: .color(ink), style: StrokeStyle(lineWidth: 1.8))

            // Torso
            var torso = Path()
            torso.move(to: pt(30, 24))
            torso.addLine(to: pt(30, 42))
            context.stroke(torso, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            // Limbs swing around pivots at shoulder (30,22) and hip (30,42)
            let swing = sin(phase) * (24.0 * .pi / 180.0)

            func rotated(from origin: CGPoint, to end: CGPoint, by angle: Double) -> CGPoint {
                let dx = end.x - origin.x
                let dy = end.y - origin.y
                let ca = CGFloat(cos(angle))
                let sa = CGFloat(sin(angle))
                return CGPoint(x: origin.x + dx * ca - dy * sa,
                               y: origin.y + dx * sa + dy * ca)
            }

            let shoulder = pt(30, 22)
            let hip = pt(30, 42)

            // Arm L (swing A), Arm R (swing B = -swing)
            let armLEnd = rotated(from: shoulder, to: pt(24, 34), by: swing)
            var armL = Path(); armL.move(to: shoulder); armL.addLine(to: armLEnd)
            context.stroke(armL, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            let handLRect = CGRect(x: armLEnd.x - 1.4 * sx, y: armLEnd.y - 1.4 * sy, width: 2.8 * sx, height: 2.8 * sy)
            context.fill(Path(ellipseIn: handLRect), with: .color(skin))
            context.stroke(Path(ellipseIn: handLRect), with: .color(ink), style: StrokeStyle(lineWidth: 1))

            let armREnd = rotated(from: shoulder, to: pt(36, 34), by: -swing)
            var armR = Path(); armR.move(to: shoulder); armR.addLine(to: armREnd)
            context.stroke(armR, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            let handRRect = CGRect(x: armREnd.x - 1.4 * sx, y: armREnd.y - 1.4 * sy, width: 2.8 * sx, height: 2.8 * sy)
            context.fill(Path(ellipseIn: handRRect), with: .color(skin))
            context.stroke(Path(ellipseIn: handRRect), with: .color(ink), style: StrokeStyle(lineWidth: 1))

            // Leg L (paired with arm R: -swing), Leg R (paired with arm L: +swing)
            let legLEnd = rotated(from: hip, to: pt(24, 56), by: -swing)
            var legL = Path(); legL.move(to: hip); legL.addLine(to: legLEnd)
            context.stroke(legL, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            var footL = Path()
            footL.move(to: CGPoint(x: legLEnd.x - 2 * sx, y: legLEnd.y))
            footL.addLine(to: CGPoint(x: legLEnd.x + 2 * sx, y: legLEnd.y))
            context.stroke(footL, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            let legREnd = rotated(from: hip, to: pt(36, 56), by: swing)
            var legR = Path(); legR.move(to: hip); legR.addLine(to: legREnd)
            context.stroke(legR, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            var footR = Path()
            footR.move(to: CGPoint(x: legREnd.x - 2 * sx, y: legREnd.y))
            footR.addLine(to: CGPoint(x: legREnd.x + 2 * sx, y: legREnd.y))
            context.stroke(footR, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
}

// MARK: - ActionItem Model

private struct ActionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let tab: Int? // if set, switches tab instead of navigation push
}
