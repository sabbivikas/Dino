//
//  FindingsTabView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — REDESIGNED screen. Deep space; the star
//  floats free (full-bleed SceneKit scene, star + Earth, no box); when a finding
//  lands a large Tolan card appears ABOVE the star, the star still visible
//  beneath with a clear gap. NOTHING ELSE on the screen — no shelf, no header,
//  no list. Past findings rest on the EXISTING profile shelf as keepsakes
//  (FindingsKeepsake), written the moment a finding is ACCEPTED in the card.
//
//  States: IDLE (star + one caption + trips-remaining count) → SENDING (gather +
//  arc off) → AWAY (star removed, faint motes) → LANDING (slow decelerating
//  streak in) → REVEAL (the card, made of light) → or EMPTY-HANDED (same
//  landing, warm caption, no card).
//
//  The honest server-reachability logic (reconcile / poll / deep-link) is kept
//  from the prior build; only the presentation changed — an in-scene card, not a
//  sheet, and no local shelf.
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI
import FirebaseAuth

struct FindingsTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var route = FindingsRoute.shared

    @State private var isVisible = false
    @State private var reconcileTask: Task<Void, Never>?
    @State private var pollTask: Task<Void, Never>?

    @State private var starState: FindingsStarState = .idle
    @State private var caption: String = "tap the star to send it out looking"
    @State private var showConfirm = false
    /// The finding whose card is up (nil = star-only sky).
    @State private var activeFinding: FindingItem?
    /// The card was collapsed by its up-chevron: star-only sky + a re-expand chip.
    @State private var collapsed = false
    @State private var isBusy = false
    @State private var capReached = false
    @State private var tripsRemaining: Int?
    @State private var preferBookable = FindingsPrefs.preferBookable()
    @State private var qaFreezeReveal = false

    private var userName: String { Auth.auth().currentUser?.displayName ?? "" }
    private var cardPresented: Bool { activeFinding != nil && !collapsed }

    var body: some View {
        ZStack {
            FindingsSpaceBackdrop()

            // The full-bleed star + Earth scene. Transparent, no box; the star
            // drops lower + smaller when the card is up.
            FindingsStarHostView(state: starState, cardPresented: cardPresented)

            // AWAY: one or two faint drifting motes so the empty sky feels alive.
            if starState == .away && activeFinding == nil {
                ZStack {
                    FindingsLonelyMote(phase: 0).offset(x: -30, y: -20)
                    FindingsLonelyMote(phase: 7).offset(x: 44, y: 26)
                }
            }

            // The star's tap region (idle only) — over the hero star's area.
            if starState == .idle && activeFinding == nil && !isBusy && !capReached {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width, height: geo.size.height * 0.34)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
                        .onTapGesture {
                            FindingsHaptics.shared.tapStar()
                            showConfirm = true
                        }
                }
            }

            content
        }
        .confirmationDialog("send the star out?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("send it") { sendStar() }
            Button("not now", role: .cancel) {}
        } message: {
            Text("it will go looking for one gentle, free thing for your week")
        }
        .onAppear {
            isVisible = true
            #if DEBUG
            if applyCardQAIfNeeded() { return }
            if applyStateQAIfNeeded() { return }
            if applyRecoverQAIfNeeded() { return }
            #endif
            reconcile()
            consumeDeepLinkIfNeeded()
        }
        .onDisappear {
            isVisible = false
            stopWatching()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isVisible else { return }
            reconcile()
            consumeDeepLinkIfNeeded()
        }
        .onChange(of: route.pendingTaskId) { _, _ in consumeDeepLinkIfNeeded() }
    }

    // MARK: - content overlay (card on top, or idle caption at the bottom)

    @ViewBuilder
    private var content: some View {
        if let finding = activeFinding, !collapsed {
            VStack {
                FindingsCardView(
                    initialItem: finding,
                    userName: userName,
                    onCollapse: { withAnimation(.easeInOut(duration: 0.35)) { collapsed = true } },
                    onShare: { presentShare($0) },
                    onChanged: { if let fresh = FindingsStore.item(taskId: finding.taskId) { activeFinding = fresh } },
                    onDismiss: {
                        // "not this time": back to the idle sky, finding unacted
                        // and still recoverable via reconcile / latest-task.
                        withAnimation(.easeInOut(duration: 0.3)) { activeFinding = nil }
                        collapsed = false
                    },
                    qaFreezeReveal: qaFreezeReveal)
                .id(finding.taskId)   // a new finding re-runs the reveal choreography
                .padding(.top, 60)
                Spacer()
            }
            .transition(.opacity)
        } else if collapsed, activeFinding != nil {
            // COLLAPSED: star-only sky + a small unobtrusive re-expand chip.
            VStack {
                Button {
                    FindingsHaptics.shared.tapStar()
                    withAnimation(.easeInOut(duration: 0.35)) { collapsed = false }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        Text("a finding is waiting").font(DinoTheme.dinoFont(size: 13))
                    }
                    .foregroundColor(Self.creamText)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .padding(.top, 60)
                Spacer()
            }
            .transition(.opacity)
        } else {
            // IDLE / SENDING / AWAY / LANDING / EMPTY: one quiet caption + count.
            VStack {
                Spacer()
                Text(caption)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(Self.creamText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .transition(.opacity)
                if starState == .idle && !capReached, let trips = tripsRemaining {
                    Text(trips == 1 ? "1 trip left today" : "\(trips) trips left today")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(Self.creamText.opacity(0.6))
                        .padding(.top, 6)
                }
                Spacer().frame(height: 90)
            }
        }
    }

    /// The paper-family cream for labels on the dark sky.
    static let creamText = Color(red: 0.984, green: 0.965, blue: 0.922)

    // MARK: - send the star out

    private func sendStar() {
        isBusy = true
        stopWatching()
        FindingsStore.markPending()
        setCaption("the star is heading out")
        FindingsHaptics.shared.gather()
        starState = .sending
        FindingsHaptics.shared.launch()

        Task {
            // Let the gather + arc-away (~1.7s) finish before the sky goes empty.
            try? await Task.sleep(nanoseconds: reduceMotion ? 350_000_000 : 1_700_000_000)
            await MainActor.run {
                starState = .away
                setCaption("the star is out looking")
            }
            do {
                let item = try await FindingsService.shared.startFinding(preferBookable: preferBookable)
                if !item.taskId.isEmpty {
                    FindingsStore.upsert(item)
                    FindingsStore.clearPending()
                }
                await MainActor.run {
                    tripsRemaining = FindingsService.shared.lastRemainingToday
                    landResult(item)
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    if FindingsService.isGateDenied(error) {
                        FindingsStore.clearPending()
                        starState = .landing
                        setCaption("the star only flies for its own dino")
                    } else {
                        starState = .landing
                        setCaption("the star lost its way for a moment, try again")
                    }
                    scheduleIdleAfterLanding()
                }
            }
        }
    }

    /// After the landing streak settles, hand control back so the star is
    /// tappable again. Returns when the star is idle.
    private func scheduleIdleAfterLanding(then: (() -> Void)? = nil) {
        let delay: TimeInterval = reduceMotion ? 0.5 : 3.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if starState == .landing { starState = .idle }
            then?()
        }
    }

    private func landResult(_ item: FindingItem) {
        FindingsStore.clearPending()
        if item.status != "capReached" {
            FindingsStore.upsert(item)
        }
        switch item.status {
        case "capReached":
            isBusy = false
            capReached = true
            starState = .idle
            setCaption("the star has wandered enough today. it will be ready again tomorrow")
        case "found":
            starState = .landing
            FindingsHaptics.shared.landingSettle()
            setCaption("the star is coming back with something")
            scheduleIdleAfterLanding {
                isBusy = false
                presentFinding(item)
            }
        case "empty":
            // EMPTY-HANDED: same landing, NO card, warm copy, zero error styling.
            starState = .landing
            FindingsHaptics.shared.landingSettle()
            scheduleIdleAfterLanding {
                isBusy = false
                FindingsHaptics.shared.emptyHanded()
                setCaption("the star came back with open paws tonight. nothing gentle turned up, it will try again another day")
            }
        case "alreadyRunning":
            // The server's in-flight guard: a star is already out and billing.
            // Show the away sky and WATCH that task — never launch a second one.
            isBusy = false
            starState = .away
            setCaption(FindingsCopy.alreadyRunningLine)
            if !item.taskId.isEmpty { startPolling(taskId: item.taskId) }
        default:
            // FAILED (step cap / timeout / error). NOT the warm empty-handed
            // line: nothing was "not found", the trip was cut short and it was
            // billed. Honest, quiet, and no nudge to send again immediately.
            isBusy = false
            starState = .landing
            logFailure(item)
            setCaption(FindingsCopy.failedLine(outcome: item.outcome))
            scheduleIdleAfterLanding()
        }
    }

    /// Surface the real outcome for the owner without putting it on screen.
    private func logFailure(_ item: FindingItem) {
        #if DEBUG
        print("[findings] task=\(item.taskId) status=\(item.status) outcome=\(item.outcome)")
        #endif
    }

    private func presentFinding(_ item: FindingItem) {
        collapsed = false
        withAnimation(.easeInOut(duration: 0.3)) { activeFinding = item }
    }

    // MARK: - reconcile with the server (unchanged reachability logic)

    private func reconcile() {
        guard !isBusy else { return }
        if starState == .idle, activeFinding == nil, FindingsStore.isPendingRecent() {
            starState = .away
            setCaption("the star is out looking")
        }
        reconcileTask?.cancel()
        reconcileTask = Task {
            guard let item = try? await FindingsService.shared.pollLatest() else { return }
            await MainActor.run {
                tripsRemaining = FindingsService.shared.lastRemainingToday
                applyServerTask(item)
            }
        }
    }

    private func applyServerTask(_ item: FindingItem) {
        guard !isBusy else { return }

        if item.status == "none" {
            FindingsStore.clearPending(); stopPolling()
            starState = .idle
            setCaption("tap the star to send it out looking")
            return
        }
        if item.status == "searching" {
            if !item.taskId.isEmpty { FindingsStore.upsert(item) }
            starState = .away
            setCaption("the star is out looking")
            startPolling(taskId: item.taskId)
            return
        }
        // FAILED reconciles honestly too — the same non-alarming line as a live
        // landing, never the warm empty-handed copy and never silence.
        if item.status == "failed" {
            // ...once. A reconcile fires on every appear + foreground, so a
            // failure already on the shelf must not replay its landing.
            let alreadySeen = FindingsStore.item(taskId: item.taskId)?.status == "failed"
            FindingsStore.clearPending(); stopPolling()
            if !item.taskId.isEmpty { FindingsStore.upsert(item) }
            guard !alreadySeen else {
                if starState == .away { starState = .idle }
                return
            }
            logFailure(item)
            starState = .landing
            let line = FindingsCopy.failedLine(outcome: item.outcome)
            scheduleIdleAfterLanding { setCaption(line) }
            return
        }
        guard FindingsStore.isTerminal(item.status) else {
            FindingsStore.clearPending(); stopPolling()
            if starState == .away { starState = .idle }
            return
        }

        let alreadyShelved = FindingsStore.hasTerminal(taskId: item.taskId)
        FindingsStore.clearPending(); stopPolling()
        FindingsStore.upsert(item)
        guard !alreadyShelved else {
            if starState == .away { starState = .idle }
            return
        }
        starState = .landing
        if item.status == "found" {
            setCaption("the star is coming back with something")
            scheduleIdleAfterLanding { presentFinding(item) }
        } else if item.status == "empty" {
            scheduleIdleAfterLanding {
                setCaption("the star came back with open paws tonight")
            }
        } else {
            scheduleIdleAfterLanding()
        }
    }

    private func startPolling(taskId: String) {
        guard !taskId.isEmpty, pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { return }
                guard let item = try? await FindingsService.shared.pollFinding(taskId: taskId) else { continue }
                if item.status != "searching" {
                    await MainActor.run { applyServerTask(item) }
                    return
                }
            }
        }
    }

    private func stopPolling() { pollTask?.cancel(); pollTask = nil }
    private func stopWatching() { reconcileTask?.cancel(); reconcileTask = nil; stopPolling() }

    // MARK: - deep link (the push's door)

    private func consumeDeepLinkIfNeeded() {
        guard let id = route.pendingTaskId, !id.isEmpty else { return }
        route.pendingTaskId = nil
        if let local = FindingsStore.item(taskId: id), FindingsStore.isTerminal(local.status) {
            presentFinding(local)
        }
        Task {
            guard let item = try? await FindingsService.shared.pollFinding(taskId: id) else { return }
            await MainActor.run {
                guard FindingsStore.isTerminal(item.status) else { applyServerTask(item); return }
                FindingsStore.clearPending(); stopPolling()
                FindingsStore.upsert(item)
                if item.status == "found" { presentFinding(item) }
                else { setCaption("the star came back") }
            }
        }
    }

    // MARK: - share

    private func presentShare(_ item: FindingItem) {
        var items: [Any] = []
        if !item.title.isEmpty { items.append(item.title) }
        if let url = URL(string: item.url) { items.append(url) }
        guard !items.isEmpty,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        var top = root
        while let presented = top.presentedViewController { top = presented }
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }

    private func setCaption(_ text: String) {
        if reduceMotion { caption = text }
        else { withAnimation(.easeInOut(duration: 0.3)) { caption = text } }
    }

    // MARK: - DEBUG QA (drive every state by launch arg; sim tapping unavailable)

    #if DEBUG
    /// `-findingsStateQA idle|sending|away|landing|empty` forces a star state on
    /// launch so each motion state renders for screenshots with no live call.
    private func applyStateQAIfNeeded() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-findingsStateQA"), i + 1 < args.count else { return false }
        isBusy = true
        tripsRemaining = 4
        switch args[i + 1] {
        case "idle":    starState = .idle; isBusy = false; setCaption("tap the star to send it out looking")
        case "sending": starState = .sending; setCaption("the star is heading out")
        case "away":    starState = .away; setCaption("the star is out looking")
        case "landing": starState = .landing; setCaption("the star is coming back with something")
        case "empty":
            starState = .idle
            setCaption("the star came back with open paws tonight. nothing gentle turned up, it will try again another day")
        default: return false
        }
        return true
    }

    /// `-findingsCardQA settled|done|unknown|photo|midreveal` seeds ONE fixture
    /// finding and shows its card so every card state is capturable with no call.
    private func applyCardQAIfNeeded() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-findingsCardQA"), i + 1 < args.count else { return false }
        let mode = args[i + 1]
        UserDefaults.standard.removeObject(forKey: FindingsStore.itemsKey)
        FindingsStore.clearPending()
        isBusy = true
        starState = .idle
        let base = FindingItem(
            taskId: "qaCard-\(mode)",
            status: mode == "done" ? "confirmed" : "found",
            title: mode == "unknown" ? "Quiet Hours at the Conservatory" : "Hatha Yoga in the Reading Room",
            whenText: mode == "unknown" ? "see listing" : "this saturday, 2pm",
            whereText: mode == "unknown" ? "Como Park Conservatory" : "Rondo Community Library",
            why: "a slow hour where nobody needs anything from you",
            url: "https://sppl.org/events/hatha-yoga",
            outcome: "add_to_calendar",
            createdAt: Date(),
            startISO: mode == "unknown" ? nil : "2026-08-02T14:00:00-05:00",
            endISO: mode == "unknown" ? nil : "2026-08-02T15:00:00-05:00",
            dateConfidence: mode == "unknown" ? "unknown" : "exact",
            calendarWrittenAt: mode == "done" ? Date() : nil,
            imageURL: nil)   // no network on sim → the generated-gradient fallback
        FindingsStore.upsert(base)
        qaFreezeReveal = (mode == "midreveal")
        activeFinding = base
        collapsed = false
        setCaption("the star came back with something")
        return true
    }

    /// `-findingsRecoverQA` drives a fake TERMINAL task through the REAL
    /// reconciliation path against an emptied shelf (cold-open recovery).
    private func applyRecoverQAIfNeeded() -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("-findingsRecoverQA") else { return false }
        UserDefaults.standard.removeObject(forKey: FindingsStore.itemsKey)
        FindingsStore.markPending()
        applyServerTask(FindingItem(
            taskId: "fOBoTl257mhN96RRvEjP", status: "found",
            title: "Hatha Yoga Class", whenText: "this saturday, 2pm", whereText: "SPPL",
            why: "a slow hour where nobody needs anything from you",
            url: "https://sppl.org/events/hatha-yoga", outcome: "add_to_calendar"))
        return true
    }
    #endif
}
