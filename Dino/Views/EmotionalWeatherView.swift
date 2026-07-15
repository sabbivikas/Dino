//
//  EmotionalWeatherView.swift
//  Dino
//

import SwiftUI
import FirebaseAuth

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
    // Rich rec (2.1): the personalized pick; the classic pool above is the
    // silent fallback. Only one of the two ever shows.
    @State private var pendingRichRec: RichRec?
    @State private var shownRichRec: RichRec?
    // Rec keepsakes (2.1 feature 3): the little shelf, shown only when
    // something rests on it.
    @State private var showRecShelf = false
    @State private var keepsakeCount = 0
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
                                    .foregroundColor(DinoTheme.textSecondary)
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
                                        .font(DinoTheme.dinoFont(size: 13))
                                        .foregroundColor(DinoTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(DinoTheme.textSecondary.opacity(0.85))
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
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(Array(EmotionalWeather.allCases.enumerated()), id: \.element) { index, weather in
                            WeatherCard(
                                weather: weather,
                                isSelected: viewModel.selectedWeather == weather,
                                index: index,
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
                    .padding(.top, 4)   // room for the tape to overhang the top row

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

                    // Sliders — the light metaphor: energy fills warm gold,
                    // intensity fills lavender dusk
                    VStack(spacing: 24) {
                        MoodSlider(
                            title: "energy",
                            value: $viewModel.energyLevel,
                            lowLabel: "drained",
                            highLabel: "energized",
                            color: Color(hex: "#E8B84A")
                        )

                        MoodSlider(
                            title: "intensity",
                            value: $viewModel.intensityLevel,
                            lowLabel: "calm",
                            highLabel: "intense",
                            color: Color(hex: "#9C8FB8")
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
                                    if let rich = await ComfortRecCoordinator.fetchIfMomentIsRight(
                                        dataManager: dataManager, freshHeavyMood: w) {
                                        pendingRichRec = rich
                                    } else {
                                        pendingRec = await GentleRecCoordinator.fetchIfMomentIsRight(
                                            dataManager: dataManager, freshHeavyMood: w)
                                    }
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

                    // Rich comfort rec (2.1) — dino's personalized pick.
                    // Same signals as the slip: tap teaches, ignore teaches.
                    if let rich = shownRichRec {
                        RichRecCard(rec: rich, onOpen: { url in
                            recWasTapped = true
                            GentleRecStore.recordTapped(type: rich.type)
                            AnalyticsManager.shared.trackRecTapped()
                            UIApplication.shared.open(url)
                        }, onNotTonight: {
                            recWasTapped = true   // consumed — no double count on disappear
                            GentleRecStore.recordIgnored(type: rich.type)
                            AnalyticsManager.shared.trackRecIgnored()
                            withAnimation(.easeInOut(duration: 0.35)) { shownRichRec = nil }
                        })
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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

                    // The little shelf (2.1 feature 3) — past picks, kept.
                    if keepsakeCount > 0 {
                        Button {
                            AnalyticsManager.shared.trackScreen("rec_shelf")
                            showRecShelf = true
                        } label: {
                            HStack {
                                Text(ComfortRecVoice.shelfRowLine(keepsakeCount))
                                    .font(DinoTheme.dinoFont(size: 14))
                                    .foregroundColor(Color(hex: "#7A7266"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#A8A29A"))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#FFFDF6"))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DinoTheme.padding)
                    }

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
                // Expedition watcher signal — enum buckets only, once a day.
                await ExpeditionSignals.syncIfNeeded(dataManager: dataManager,
                    sleepHours: sleepData.map { $0.durationHours },
                    steps: stepsToday.map { Int($0) })
                if let agg = await WorldMoodService.fetchAggregate() {
                    worldBucket = agg.bucket(for: WorldMoodService.todayKey())
                }
                // Journal-signal path — support beats the gentle rec here too.
                if stretchSignalFires() {
                    presentSupportRow()
                } else if shownRec == nil, pendingRec == nil,
                          shownRichRec == nil, pendingRichRec == nil {
                    if let rich = await ComfortRecCoordinator.fetchIfMomentIsRight(dataManager: dataManager) {
                        presentRichRec(rich)
                    } else if let rec = await GentleRecCoordinator.fetchIfMomentIsRight(dataManager: dataManager) {
                        presentRec(rec)
                    }
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackMoodScreenOpened()
                AnalyticsManager.shared.trackScreen("mood")
                keepsakeCount = RichRecStore.keepsakes().count
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-richRecQA") {
                    RecOpenMemory.forget()   // deterministic first ask state
                    presentRichRec(.qaSample)
                }
                if ProcessInfo.processInfo.arguments.contains("-richRecQA2") {
                    RecOpenMemory.remember(RecOpenMemory.spotify)   // remembered state
                    presentRichRec(.qaSample)
                }
                if ProcessInfo.processInfo.arguments.contains("-richRecQA3") {
                    RichRecStore.seedQAKeepsakes()   // a full shelf
                    keepsakeCount = RichRecStore.keepsakes().count
                    showRecShelf = true
                }
                if ProcessInfo.processInfo.arguments.contains("-moodStepsQA") {
                    sleepData = HealthService.SleepData(durationHours: 7.2,
                        startTime: Date(), endTime: Date())
                    stepsToday = 4400
                    stepsRead = .high
                    showStepsInsight = true
                }
                #endif
                #if DEBUG
                // -moodQAselect<Mood>: preselect a card for loop screenshots.
                let qaArgs = ProcessInfo.processInfo.arguments
                let qaMoods: [(String, EmotionalWeather)] = [
                    ("-moodQAselectClear", .clear), ("-moodQAselectCloudy", .partlyCloudy),
                    ("-moodQAselectOverwhelmed", .overwhelmed), ("-moodQAselectDrained", .drained),
                ]
                // -ceremonyQA: present the lantern arrival ceremony with a
                // fixture lantern (render check only — no claim, no server).
                if qaArgs.contains("-ceremonyQA") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        ceremonyLantern = ReceivedLantern(
                            text: "someone far away wished you a softer night",
                            countryCode: "JP")
                    }
                }
                if let match = qaMoods.first(where: { qaArgs.contains($0.0) }) {
                    viewModel.selectedWeather = match.1
                    // -moodQAsaved: capture the logged state (light mood — no
                    // heavy post-log flow fires during the sweep)
                    if qaArgs.contains("-moodQAsaved") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            viewModel.saveMood()
                        }
                    }
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
                if let rich = shownRichRec, !recWasTapped {
                    GentleRecStore.recordIgnored(type: rich.type)
                    AnalyticsManager.shared.trackRecIgnored()
                    shownRichRec = nil
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
                } else if let rich = pendingRichRec {
                    pendingRichRec = nil
                    presentRichRec(rich)
                } else if let rec = pendingRec {
                    pendingRec = nil
                    presentRec(rec)
                }
            }) {
                BreakSuggestionCard(mood: breakMood, onDismiss: { showBreakCard = false })
            }
            .sheet(isPresented: $showRecShelf) {
                RecKeepsakesView()
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
        return line.foregroundColor(DinoTheme.textSecondary)
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
        return ProcessInfo.processInfo.arguments.contains("-moodQAscrollBottom")
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

    private func presentRichRec(_ rec: RichRec) {
        GentleRecStore.recordShown()   // same scarcity clock as the classic path
        RichRecStore.recordKeepsake(rec)
        AnalyticsManager.shared.trackRecShown(type: rec.type)
        recWasTapped = false
        withAnimation(.easeInOut(duration: 0.35)) { shownRichRec = rec }
    }
}

// MARK: - Mood Slider — a measure of light
// The fill IS the metaphor: light gathering in the track, glowing brightest
// at the leading edge. The thumb is a small warm disc with a hand-drawn ring
// (a hair squashed and turned — drawn, not lathed). No icons needed.
struct MoodSlider: View {
    let title: String
    @Binding var value: Double
    let lowLabel: String
    let highLabel: String
    let color: Color

    private let tick = UISelectionFeedbackGenerator()

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

            GeometryReader { geo in
                let fraction = CGFloat((value - 1) / 9)
                ZStack(alignment: .leading) {
                    // unlit track — a paper groove
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.13))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color(hex: "#EFE7D2"), lineWidth: 1))
                        .frame(height: 10)

                    // the light gathers — dimmer where it began, bright at the edge
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [color.opacity(0.45), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * fraction), height: 10)
                        .shadow(color: color.opacity(0.45), radius: 5, y: 0)

                    // warm disc, hand-drawn ring
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FFFDF6"))
                            .shadow(color: color.opacity(0.35), radius: 6, y: 2)
                        Ellipse()
                            .stroke(color.opacity(0.9), lineWidth: 2.2)
                            .frame(width: 19.5, height: 20.5)
                            .rotationEffect(.degrees(8))
                    }
                    .frame(width: 28, height: 28)
                    .offset(x: geo.size.width * fraction - 14)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let f = max(0, min(1, drag.location.x / geo.size.width))
                                let stepped = 1 + (f * 9).rounded()
                                if stepped != value { tick.selectionChanged() }
                                value = stepped
                            }
                    )
                }
                .frame(height: 28)
            }
            .frame(height: 28)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(Int(value.rounded())) of 10")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = min(10, value + 1)
                case .decrement: value = max(1, value - 1)
                @unknown default: break
                }
            }

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

// MARK: - Weekly Trend — seven skies

/// pure seed + tone rules for the week strip (tested)
enum WeekSky {
    /// stable per user · day · mood — the same sky every time you look back
    static func seed(userId: String, dayKey: String, mood: EmotionalWeather) -> String {
        userId + "|" + dayKey + "|" + mood.rawValue
    }

    static func isHeavy(_ mood: EmotionalWeather) -> Bool {
        mood == .overwhelmed || mood == .drained
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct WeeklyMoodTrend: View {
    @ObservedObject var viewModel: MoodViewModel

    private var userId: String { Auth.auth().currentUser?.uid ?? "dino" }

    #if DEBUG
    /// -moodQAweek: fixture week for screenshots — view-local, writes nothing
    private static let qaMoods: [EmotionalWeather?] = [
        .clear, .partlyCloudy, nil, .drained, .overwhelmed, .clear, nil,
    ]
    private var qaWeek: Bool { ProcessInfo.processInfo.arguments.contains("-moodQAweek") }
    #endif

    private func moodFor(_ date: Date, index: Int) -> EmotionalWeather? {
        #if DEBUG
        if qaWeek { return Self.qaMoods[index % Self.qaMoods.count] }
        #endif
        return viewModel.moodForDay(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("this week")
                .font(DinoTheme.dinoLabelFont(size: 14))
                .foregroundColor(DinoTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(Array(viewModel.last7Days.enumerated()), id: \.element) { index, date in
                    let mood = moodFor(date, index: index)
                    VStack(spacing: 8) {
                        DaySky(mood: mood,
                               seed: mood.map {
                                   WeekSky.seed(userId: userId,
                                                dayKey: WeekSky.dayKey(date),
                                                mood: $0)
                               })
                        Text(dayLabel(date))
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(fullDayLabel(date)), \(mood?.label ?? "no log")")
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .dsCardLarge()
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }

    private func fullDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

/// one day's sky: a seeded gradient square — dusk-toned when the day was
/// heavy, warm when it was kind, faint empty paper when nothing was logged
private struct DaySky: View {
    let mood: EmotionalWeather?
    let seed: String?

    var body: some View {
        ZStack {
            if let seed, let mood {
                SeededMeshGradient(seed: seed, radius: 34)
                // the day's tone: dusk settles over heavy skies, warmth over kind ones
                Rectangle()
                    .fill(WeekSky.isHeavy(mood)
                        ? Color(hue: 0.63, saturation: 0.38, brightness: 0.32).opacity(0.42)
                        : Color(hex: "#F5C87A").opacity(0.14))
                // soft inner light
                RadialGradient(gradient: Gradient(colors: [.white.opacity(0.22), .clear]),
                               center: .init(x: 0.35, y: 0.30), startRadius: 0, endRadius: 34)
                // soft scrim so the ink glyph reads on any sky (stronger on dark heavy days)
                Circle()
                    .fill(Color.white.opacity(WeekSky.isHeavy(mood) ? 0.55 : 0.28))
                    .frame(width: 30, height: 30)
                    .blur(radius: 4)
                // the day, instantly readable as its mood — static hand-drawn glyph
                DinoWeatherGlyph(weather: mood, size: 22, paused: true)
            } else {
                // faint empty paper — a page not written on
                Color(hex: "#FFFDF6").opacity(0.75)
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color(hex: "#EFE7D2"), lineWidth: 1))
        .accessibilityHidden(true)
    }
}
