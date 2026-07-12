//
//  EmotionalWeatherView.swift
//  Dino
//

import SwiftUI

struct EmotionalWeatherView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: MoodViewModel = MoodViewModel(dataManager: SharedDataManager.shared)
    @State private var showBreakCard = false
    @State private var breakMood: EmotionalWeather = .drained
    @State private var sleepData: HealthService.SleepData?
    // Steps: honest number + dino's read, always relative to their own baseline.
    @State private var stepsToday: Double?
    @State private var stepsRead: StepsRead?
    @State private var showStepsInsight = false
    @State private var showStepsInvite = false
    @AppStorage("dino.health.stepsInviteDismissed") private var stepsInviteDismissed = false
    // Dino World: the post-log moment (always the final beat) + world card.
    @State private var worldBucket: WorldDayBucket?
    @State private var worldMomentLine: String?
    @State private var worldMomentMood: EmotionalWeather = .clear
    @State private var worldMomentPending: (line: String, mood: EmotionalWeather)?
    @State private var showWorld = false
    // Lanterns: invite after bright logs; after heavy ones the arrival
    // CEREMONY replaces the old popup (claim mechanics untouched).
    @State private var showLanternInvite = false
    @State private var showLanternCompose = false
    @State private var ceremonyLantern: ReceivedLantern?
    @State private var showJarLine = false
    // Gentle recommendation: ONE real thing, one warm line, only when the
    // moment engine says so (see GentleRecEngine — scarcity is the feature).
    @State private var pendingRec: GentleRec?
    @State private var shownRec: GentleRec?
    @State private var recWasTapped = false
    // Tiered support: quiet glyph always; the row only on a heavy stretch
    // (StretchSignal). Support beats the gentle rec when both are eligible.
    @State private var showResources = false
    @State private var pendingSupportRow = false
    @State private var showSupportRow = false
    // Share dino — the once-ever contextual moment (after a lantern lands).
    @State private var showShareRow = false
    // Siri return moment: one quiet line after a voice-logged mood, once.
    @State private var siriReturnLine: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Header
                    VStack(spacing: 6) {
                        Text("how's your\ninner weather?".localized)
                            .font(DinoTheme.dinoDisplayFont(size: 28))
                            .foregroundColor(DinoTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, DinoTheme.padding)

                    // One quiet body card — sleep + steps merged into a single
                    // top line and ONE combined read (priority: today's body
                    // state, then last night, then insight, then neutral).
                    // Hidden entirely when Health has nothing to say.
                    if sleepData != nil || stepsToday != nil {
                        VStack(spacing: 2) {
                            bodyTopLine
                            if let line = StepsSignal.combinedRead(sleepHours: sleepData?.durationHours,
                                                                   stepsRead: stepsRead,
                                                                   showInsight: showStepsInsight) {
                                Text(line)
                                    .font(DinoTheme.dinoFont(size: 11))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    if showStepsInvite {
                        // One-time in-place ask for existing users who already
                        // connected sleep — gone forever once tapped or dismissed.
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    showStepsInvite = false
                                    _ = await HealthService.shared.requestStepsPermission()
                                    await loadSteps()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("🌿")
                                        .font(.system(size: 11))
                                    Text("dino can notice your movement too".localized)
                                        .font(DinoTheme.dinoFont(size: 12))
                                        .foregroundColor(DinoTheme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                stepsInviteDismissed = true
                                showStepsInvite = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // Weather cards
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(EmotionalWeather.allCases, id: \.self) { weather in
                            WeatherCard(
                                weather: weather,
                                isSelected: viewModel.selectedWeather == weather,
                                onTap: {
                                    HapticManager.shared.light()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.selectedWeather = weather
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)

                    // Suggestion text
                    if viewModel.selectedWeather != nil {
                        Text(viewModel.suggestion)
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DinoTheme.largePadding)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(DinoTheme.accent.opacity(0.10))
                            )
                            .padding(.horizontal, DinoTheme.padding)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    // Sliders
                    VStack(spacing: 24) {
                        MoodSlider(
                            title: "energy",
                            value: $viewModel.energyLevel,
                            lowLabel: "drained",
                            highLabel: "energized",
                            color: DinoTheme.skyBlue
                        )

                        MoodSlider(
                            title: "intensity",
                            value: $viewModel.intensityLevel,
                            lowLabel: "calm",
                            highLabel: "intense",
                            color: DinoTheme.lavender
                        )
                    }
                    .padding(DinoTheme.padding)
                    .dsCardLarge()
                    .padding(.horizontal, DinoTheme.padding)

                    // Save button
                    Button(action: {
                        HapticManager.shared.success()
                        let logged = viewModel.selectedWeather
                        viewModel.saveMood()
                        // Break-finder hook: show the card on every low mood.
                        if let w = logged, w == .overwhelmed || w == .drained {
                            breakMood = w
                            // World moment waits for the break card to finish —
                            // it is always the final beat, never an interruption.
                            if let line = WorldMoodService.worldMomentLine(mood: w, bucket: worldBucket ?? WorldMoodService.cachedTodayBucket) {
                                worldMomentPending = (line, w)
                            }
                            // Support row on a heavy stretch — it takes the
                            // slot; the gentle rec stays quiet that day.
                            if stretchSignalFires() {
                                pendingSupportRow = true
                            } else {
                                // And — rarely — a gentle recommendation for
                                // after the break card. Gates run locally first.
                                Task {
                                    pendingRec = await GentleRecCoordinator.fetchIfMomentIsRight(
                                        dataManager: dataManager, freshHeavyMood: w)
                                }
                            }
                            // The ceremony is the headliner when a lantern is
                            // available: claim races a short window; nil or
                            // slow → today's exact flow (break card first).
                            Task {
                                let lantern: ReceivedLantern? = await withTaskGroup(of: ReceivedLantern?.self) { group in
                                    group.addTask { await LanternService.claimLantern() }
                                    group.addTask { try? await Task.sleep(for: .seconds(2.5)); return nil }
                                    let first = await group.next() ?? nil
                                    group.cancelAll()
                                    return first
                                }
                                if let lantern {
                                    ceremonyLantern = lantern
                                } else {
                                    showBreakCard = true
                                }
                            }
                        } else if let w = logged {
                            // clear / partlyCloudy → the moment shows right away,
                            // plus a gentle invitation to send a lantern onward.
                            if let line = WorldMoodService.worldMomentLine(mood: w, bucket: worldBucket ?? WorldMoodService.cachedTodayBucket) {
                                worldMomentMood = w
                                withAnimation(.easeInOut(duration: 0.35)) { worldMomentLine = line }
                            }
                            withAnimation(.easeInOut(duration: 0.35)) { showLanternInvite = true }
                        }
                    }) {
                        MoodLogButtonLabel(selected: viewModel.selectedWeather,
                                           saved: viewModel.saved)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.selectedWeather == nil)
                    .padding(.horizontal, DinoTheme.padding)

                    // one handwritten line once a mood is chosen — softer for
                    // the heavy skies, lighter for the kind ones
                    if let chosen = viewModel.selectedWeather, !viewModel.saved {
                        Text(MoodButtonVoice.line(for: chosen))
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, -8)
                            .padding(.horizontal, DinoTheme.padding)
                            .transition(.opacity)
                    }

                    // Dino World post-log moment — one soft line, tap to visit.
                    if let line = worldMomentLine {
                        Button {
                            AnalyticsManager.shared.trackWorldPostLogTapped()
                            showWorld = true
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(DinoWorldPalette.moodSwiftUIColor(worldMomentMood))
                                    .frame(width: 10, height: 10)
                                    .shadow(color: DinoWorldPalette.moodSwiftUIColor(worldMomentMood).opacity(0.8), radius: 5)
                                Text(line)
                                    .font(DinoTheme.dinoFont(size: 14))
                                    .foregroundColor(DinoWorldPalette.moodSwiftUIColor(worldMomentMood))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(DinoWorldPalette.moodSwiftUIColor(worldMomentMood).opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Support row — only on a heavy stretch, never a single
                    // tired tuesday (StretchSignal), max once per 7 days.
                    if showSupportRow {
                        Button {
                            showResources = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lifepreserver")
                                    .font(.system(size: 15))
                                    .foregroundColor(DinoTheme.sageGreen)
                                Text(StretchSignal.supportLine)
                                    .font(DinoTheme.dinoFont(size: 14))
                                    .foregroundColor(DinoTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(DinoTheme.sageGreen.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Share dino — the once-ever contextual moment.
                    if showShareRow {
                        HStack(spacing: 10) {
                            ShareLink(item: ShareDino.appStoreURL,
                                      message: Text(ShareDino.shareText)) {
                                HStack(spacing: 8) {
                                    Text("🦕")
                                    Text(ShareDino.contextualLine)
                                        .font(DinoTheme.dinoFont(size: 13))
                                        .foregroundColor(DinoTheme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            Spacer(minLength: 0)
                            Button {
                                withAnimation { showShareRow = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity)
                    }

                    // Tonight's lantern — the ceremony's quiet coda.
                    if showJarLine {
                        HStack(spacing: 8) {
                            Text("🏮").font(.system(size: 12))
                            Text(CeremonyStrings.jarStackLine)
                                .font(DinoTheme.dinoFont(size: 13))
                                .foregroundColor(DinoTheme.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity)
                    }

                    // While you were away — one quiet line after a siri-logged
                    // mood (consumed on show; x just hides it).
                    if let line = siriReturnLine {
                        HStack(spacing: 8) {
                            Text("🦕").font(.system(size: 12))
                            Text(line)
                                .font(DinoTheme.dinoFont(size: 13))
                                .foregroundColor(DinoTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Button {
                                withAnimation { siriReturnLine = nil }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity)
                    }

                    // Comfort slip (concept 3a) — the gentle rec's new body.
                    // "not tonight" feeds the exact ignore signal leaving did;
                    // every GentleRecEngine gate is unchanged.
                    if let rec = shownRec {
                        ComfortSlipView(rec: rec, onTake: {
                            recWasTapped = true
                            GentleRecStore.recordTapped(type: rec.type)
                            AnalyticsManager.shared.trackRecTapped()
                            if let url = URL(string: rec.link) {
                                UIApplication.shared.open(url)
                            }
                        }, onNotTonight: {
                            recWasTapped = true   // consumed — no double count on disappear
                            GentleRecStore.recordIgnored(type: rec.type)
                            AnalyticsManager.shared.trackRecIgnored()
                            withAnimation(.easeInOut(duration: 0.35)) { shownRec = nil }
                        })
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Lantern invite — after a bright log, pass the light on.
                    if showLanternInvite {
                        Button {
                            showLanternCompose = true
                        } label: {
                            HStack(spacing: 10) {
                                Text("🏮")
                                Text("send a lantern to someone having a hard day")
                                    .font(DinoTheme.dinoFont(size: 14))
                                    .foregroundColor(DinoTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(Color(hex: "#F5C6AA").opacity(0.22))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DinoTheme.padding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Weekly trend
                    WeeklyMoodTrend(viewModel: viewModel)
                        .padding(.horizontal, DinoTheme.padding)

                    // Dino World card — a glowing glimpse of everyone's weather.
                    WorldMoodCard(bucket: worldBucket) {
                        AnalyticsManager.shared.trackWorldCardTapped()
                        showWorld = true
                    }
                    .padding(.horizontal, DinoTheme.padding)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(moodQAScrollBottom ? .bottom : .top)
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                if siriReturnLine == nil, let line = SiriReturnMoment.consume() {
                    siriReturnLine = line
                }
                if let s = await HealthService.shared.lastNightSleep() { sleepData = s }
                await loadSteps()
                if let agg = await WorldMoodService.fetchAggregate() {
                    worldBucket = agg.bucket(for: WorldMoodService.todayKey())
                }
                // Journal-signal path — support beats the gentle rec here too.
                if stretchSignalFires() {
                    presentSupportRow()
                } else if shownRec == nil, pendingRec == nil,
                          let rec = await GentleRecCoordinator.fetchIfMomentIsRight(dataManager: dataManager) {
                    presentRec(rec)
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackMoodScreenOpened()
                AnalyticsManager.shared.trackScreen("mood")
                #if DEBUG
                // -moodQAselect<Mood>: preselect a card for loop screenshots.
                let qaArgs = ProcessInfo.processInfo.arguments
                let qaMoods: [(String, EmotionalWeather)] = [
                    ("-moodQAselectClear", .clear), ("-moodQAselectCloudy", .partlyCloudy),
                    ("-moodQAselectOverwhelmed", .overwhelmed), ("-moodQAselectDrained", .drained),
                ]
                if let match = qaMoods.first(where: { qaArgs.contains($0.0) }) {
                    viewModel.selectedWeather = match.1
                }
                #endif
            }
            .onDisappear {
                // Shown but never tapped → an ignore for the learning loop
                // (3 ignores of a type and that type goes quiet).
                if let rec = shownRec, !recWasTapped {
                    GentleRecStore.recordIgnored(type: rec.type)
                    AnalyticsManager.shared.trackRecIgnored()
                    shownRec = nil
                }
            }
            .sheet(isPresented: $showBreakCard, onDismiss: {
                // The break card finished (confirmed or dismissed) — the world
                // moment line appears as the final beat below.
                if let pending = worldMomentPending {
                    worldMomentPending = nil
                    worldMomentMood = pending.mood
                    withAnimation(.easeInOut(duration: 0.35)) { worldMomentLine = pending.line }
                }
                if pendingSupportRow {
                    pendingSupportRow = false
                    presentSupportRow()
                } else if let rec = pendingRec {
                    pendingRec = nil
                    presentRec(rec)
                }
            }) {
                BreakSuggestionCard(mood: breakMood, onDismiss: { showBreakCard = false })
            }
            .fullScreenCover(isPresented: $showWorld) {
                WorldView()
            }
            .fullScreenCover(isPresented: $showLanternCompose) {
                LanternComposeView(onDismiss: { showLanternCompose = false })
            }
            .fullScreenCover(item: $ceremonyLantern) { lantern in
                LanternArrivalView(lantern: lantern, onFinished: {
                    ceremonyLantern = nil
                    withAnimation(.easeInOut(duration: 0.5)) { showJarLine = true }
                    // a lantern just landed — the one contextual share moment
                    if ShareDino.shouldShowContextualNow() {
                        ShareDino.markContextualShown()
                        withAnimation(.easeInOut(duration: 0.35)) { showShareRow = true }
                    }
                    // ceremony before break card — the stack follows as today
                    showBreakCard = true
                })
                .presentationBackground(.clear)
            }
            .overlay(alignment: .topTrailing) {
                // Quiet persistent support affordance — always present, never
                // animated, never badged. Availability without diagnosis.
                Button {
                    showResources = true
                } label: {
                    Image(systemName: "lifepreserver")
                        .font(.system(size: 17))
                        .foregroundColor(DinoTheme.textSecondary.opacity(0.55))
                        .padding(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("support resources")
                .padding(.trailing, 8)
                .padding(.top, 4)
            }
            .sheet(isPresented: $showResources) {
                ResourcesView()
            }
        }
    }

    /// "🌙 7h 12m  ·  🚶 4,400 steps" — digits in numericFont, the rest in
    /// dinoFont. Sleep-only shows just the moon; steps-only says "steps today".
    private var bodyTopLine: some View {
        var line = Text("")
        var stepsOnly = true
        if let sleep = sleepData {
            line = line + Text("🌙 ").font(DinoTheme.dinoFont(size: 12))
                + Text(StepsSignal.compactSleep(hours: sleep.durationHours))
                    .font(DinoTheme.numericFont(size: 12))
            stepsOnly = false
        }
        if let steps = stepsToday {
            if !stepsOnly {
                line = line + Text("  ·  ").font(DinoTheme.dinoFont(size: 12))
            }
            line = line + Text("🚶 ").font(DinoTheme.dinoFont(size: 12))
                + Text(StepsSignal.formattedCount(steps)).font(DinoTheme.numericFont(size: 12))
                + Text(" " + (stepsOnly ? "steps today".localized : "steps".localized))
                    .font(DinoTheme.dinoFont(size: 12))
        }
        return line.foregroundColor(.secondary)
    }

    /// Loads the steps card (or the one-time invite for sleep-connected users).
    /// 90 days: the last 31 feed the card's own-baseline read, the full window
    /// feeds the movement-mood correlation. All local — no network, no logging.
    private func loadSteps() async {
        let service = HealthService.shared
        guard service.isAvailable else { return }
        if service.hasRequestedSteps {
            guard let totals = await service.dailyStepTotals(days: 90) else { return }
            let today = totals.last?.steps ?? 0
            let recentHistory = Array(totals.suffix(31).dropLast().map { $0.steps })
            let read = StepsSignal.read(today: today, history: recentHistory)
            stepsToday = today
            stepsRead = read
            let engine = RhythmsDataAdapter.makeEngine(
                stepsSamples: totals.map { StepsSample(date: $0.date, steps: $0.steps) })
            showStepsInsight = StepsSignal.shouldShowInsight(read: read,
                                                             correlation: engine.movementCorrelation())
        } else if service.hasRequestedSleep, !stepsInviteDismissed {
            showStepsInvite = true
        }
    }

    /// QA screenshots of the log button need the fold moved — DEBUG only.
    private var moodQAScrollBottom: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-moodQAselect") }
        #else
        return false
        #endif
    }

    private func stretchSignalFires(now: Date = Date()) -> Bool {
        StretchSignal.shouldOffer(
            moodEntries: dataManager.moodEntries.map { ($0.date, $0.weatherType) },
            journalToggleOn: dataManager.journalThemeLearningEnabled,
            journalThemesToday: dataManager.themeTags
                .filter { $0.source == ThemeTag.sourceJournal && Calendar.current.isDate($0.date, inSameDayAs: now) }
                .map { $0.theme },
            lastShownAt: SupportRowStore.lastShownAt(),
            now: now,
            calendar: .current)
    }

    private func presentSupportRow() {
        SupportRowStore.recordShown()
        withAnimation(.easeInOut(duration: 0.35)) { showSupportRow = true }
    }

    private func presentRec(_ rec: GentleRec) {
        GentleRecStore.recordShown()   // the scarcity clock starts at display, not fetch
        AnalyticsManager.shared.trackRecShown(type: rec.type)
        recWasTapped = false
        withAnimation(.easeInOut(duration: 0.35)) { shownRec = rec }
    }
}

// MARK: - Mood Slider
struct MoodSlider: View {
    let title: String
    @Binding var value: Double
    let lowLabel: String
    let highLabel: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text("\(Int(value.rounded()))/10")
                    .font(DinoTheme.numericFont(size: 16))
                    .foregroundColor(color)
            }

            // Custom thick slider track with large thumb
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    // Track fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat((value - 1) / 9), height: 6)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: color.opacity(0.30), radius: 6, y: 2)
                        .overlay(
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: geo.size.width * CGFloat((value - 1) / 9) - 13)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let fraction = max(0, min(1, drag.location.x / geo.size.width))
                                    value = 1 + (fraction * 9).rounded()
                                }
                        )
                }
                .frame(height: 26)
            }
            .frame(height: 26)

            HStack {
                Text(lowLabel)
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
                Spacer()
                Text(highLabel)
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
    }
}

// MARK: - Weekly Trend
struct WeeklyMoodTrend: View {
    @ObservedObject var viewModel: MoodViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("this week")
                .font(DinoTheme.dinoLabelFont(size: 14))
                .foregroundColor(DinoTheme.textSecondary)

            HStack(spacing: 0) {
                ForEach(viewModel.last7Days, id: \.self) { date in
                    let mood = viewModel.moodForDay(date)
                    VStack(spacing: 8) {
                        Text(mood?.emoji ?? "·")
                            .font(.system(size: mood != nil ? 28 : 16))

                        Text(dayLabel(date))
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .dsCardLarge()
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
}
