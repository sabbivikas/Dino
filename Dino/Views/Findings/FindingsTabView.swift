//
//  FindingsTabView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. The destination tab: the FindingsStar at
//  the top (with state captions in dino's lowercase, no-dash voice), and below
//  it the shelf of past findings + the real comfort recs (read-only). Tap the
//  star → "send the star out?" → the server search+pick agent runs → a
//  reveal-style card with a per-outcome action.
//
//  THE HONEST-BOOKING RULE lives here in the UI too: "booked" only shows when
//  BOTH the server booking AND the local calendar write succeeded; otherwise an
//  honest partial line.
//
//  English-only demo (owner decision): plain string literals, no String(localized:).
//

import SwiftUI
import FirebaseAuth

struct FindingsTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Branch-owned deep-link route (the finding push's door). Observed here so
    /// a push tap — cold, backgrounded, or while this tab is already open —
    /// lands on the right task's reveal.
    @ObservedObject private var route = FindingsRoute.shared

    @State private var isVisible = false
    @State private var reconcileTask: Task<Void, Never>?
    @State private var pollTask: Task<Void, Never>?

    @State private var starState: FindingsStarState = .idle
    @State private var findings: [FindingItem] = FindingsStore.items()
    @State private var caption: String = "tap the star to send it out looking"
    @State private var showConfirm = false
    @State private var activeReveal: FindingItem?
    @State private var isBusy = false
    @State private var capReached = false
    /// Branch-owned, UserDefaults-backed source bias (default OFF). Sent to
    /// startFindingTask, which forwards it into the search prompt only — it never
    /// touches the 30-step kill or the 5/day cap.
    @State private var preferBookable = FindingsPrefs.preferBookable()

    private var userName: String { Auth.auth().currentUser?.displayName ?? "" }

    var body: some View {
        ZStack {
            // Full-bleed deep-space backdrop (owner fix #2): the star lives in a
            // real night sky, not a flat navy fill. FindingsSpaceBackdrop is a
            // branch-owned port of the shipping QuietSpaceBackdrop visuals.
            FindingsSpaceBackdrop()

            ScrollView {
                VStack(spacing: 18) {
                    starBlock
                        .padding(.top, 40)

                            Divider().background(Color.white.opacity(0.14)).padding(.horizontal, 40)

                    FindingsShelfView(findings: findings, onOpenFinding: { activeReveal = $0 })
                        .padding(.bottom, 80)
                        .padding(.top, 6)
                }
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("send the star out?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("send it") { sendStar() }
            Button("not now", role: .cancel) {}
        } message: {
            Text("it will go looking for one gentle, free thing for your week")
        }
        .sheet(item: $activeReveal) { item in
            FindingRevealCard(
                initialItem: item,
                userName: userName,
                onClose: { activeReveal = nil },
                // an action inside the card changed the stored truth: re-read the
                // shelf AND the presented item so neither stays stale.
                onChanged: {
                    findings = FindingsStore.items()
                    if let fresh = FindingsStore.item(taskId: item.taskId) { activeReveal = fresh }
                })
        }
        .onAppear {
            isVisible = true
            #if DEBUG
            applyQAStateIfNeeded()
            if applyCardQAIfNeeded() { return }
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
            // Foreground while the tab is up: the star may have come back (or
            // been found) while we were away.
            guard phase == .active, isVisible else { return }
            reconcile()
            consumeDeepLinkIfNeeded()
        }
        .onChange(of: route.pendingTaskId) { _, _ in
            // A push tapped while this tab is ALREADY open still opens its reveal.
            consumeDeepLinkIfNeeded()
        }
    }

    // MARK: - star + caption

    private var starBlock: some View {
        VStack(spacing: 14) {
            FindingsStarHostView(state: starState)
                .frame(height: 300)   // larger hero (owner fix #3); transparent, so glow can overflow
                .overlay {
                    // AWAY (owner fix #6): one faint, slow-drifting mote so the
                    // empty sky still feels alive but lonely.
                    if starState == .away { FindingsLonelyMote() }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard starState == .idle, !isBusy, !capReached else { return }
                    HapticManager.shared.light()
                    showConfirm = true
                }

            Text(caption)
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(Self.creamText)   // light cream on the dark sky (owner fix #4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .transition(.opacity)

            bookableToggle
        }
    }

    /// A small, unobtrusive source-bias control. Biases what the star LOOKS AT,
    /// not what you tap afterwards.
    private var bookableToggle: some View {
        Button {
            preferBookable.toggle()
            FindingsPrefs.setPreferBookable(preferBookable)
            HapticManager.shared.light()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: preferBookable ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                Text("prefer events you can sign up for")
                    .font(DinoTheme.dinoFont(size: 13))
            }
            .foregroundColor(Self.creamText.opacity(preferBookable ? 0.92 : 0.55))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(preferBookable ? 0.10 : 0.05))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("prefer events you can sign up for")
        .accessibilityAddTraits(preferBookable ? [.isSelected] : [])
    }

    /// The paper-family cream (mirrors RecRevealView's cream) for labels on the
    /// dark sky — readable, still soft.
    static let creamText = Color(red: 0.984, green: 0.965, blue: 0.922)

    // MARK: - send the star out

    private func sendStar() {
        isBusy = true
        // Stop any reconcile/poll: this send now owns the choreography.
        stopWatching()
        // "A star is out" marker, written BEFORE the ~2 minute callable returns
        // an id. If the app is killed mid-call there is nothing on the shelf to
        // find, so this is the only thing that tells a cold open to ask the
        // server what happened (the other half of bug 2).
        FindingsStore.markPending()
        setCaption("the star is heading out")
        starState = .sending

        Task {
            // Let the gather + arc-away choreography (~1.35s) finish before the
            // sky goes empty (owner fix #5: total ~1.2–1.6s).
            try? await Task.sleep(nanoseconds: reduceMotion ? 350_000_000 : 1_350_000_000)
            await MainActor.run {
                starState = .away
                setCaption("the star is out looking")
            }
            do {
                let item = try await FindingsService.shared.startFinding(preferBookable: preferBookable)
                // PERSIST THE MOMENT THE ID EXISTS — before any UI work — so a
                // kill between here and the reveal cannot lose the task.
                if !item.taskId.isEmpty {
                    FindingsStore.upsert(item)
                    FindingsStore.clearPending()
                }
                await MainActor.run { landResult(item) }
            } catch {
                await MainActor.run {
                    starState = .back
                    isBusy = false
                    // Gate denial (unauthenticated / permission-denied) is not a
                    // real failure — give it a distinct quiet line (owner fix #8).
                    if FindingsService.isGateDenied(error) {
                        // never left the ground — nothing for a cold open to find.
                        FindingsStore.clearPending()
                        setCaption("the star only flies for its own dino")
                    } else {
                        // the marker STAYS: the server task may well have been
                        // created, and reconcile() will find it.
                        setCaption("the star lost its way for a moment, try again")
                    }
                    #if DEBUG
                    print("[findings] startFinding failed: \(error)")
                    #endif
                    scheduleIdleAfterReturn()
                }
            }
        }
    }

    /// After the return streak settles, hand control back so the star is
    /// tappable again.
    private func scheduleIdleAfterReturn() {
        let delay: TimeInterval = reduceMotion ? 0.7 : 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if starState == .back { starState = .idle }
        }
    }

    // MARK: - reconcile with the server (the reachability fix)

    /// Ask the server what actually happened to the star.
    ///
    /// THE BUG THIS FIXES: the tab rendered local state only — it opened on a
    /// hardcoded idle star and the local shelf — so a task that finished while
    /// the app was backgrounded or killed was simply invisible, even though the
    /// server had a complete finding sitting there. Now every appear and every
    /// foreground asks getFindingTask (no taskId → the caller's latest task).
    private func reconcile() {
        guard !isBusy else { return }   // a live send owns the choreography
        // Cold open with a marker but an empty shelf: show the star as out
        // straight away, rather than a wrong idle star, while the server answers.
        if starState == .idle, FindingsStore.isPendingRecent() {
            starState = .away
            setCaption("the star is out looking")
        }
        reconcileTask?.cancel()
        reconcileTask = Task {
            guard let item = try? await FindingsService.shared.pollLatest() else { return }
            await MainActor.run { applyServerTask(item) }
        }
    }

    /// The decision table: server truth → what the tab shows.
    ///   none                              → plain idle (first ever use)
    ///   searching                         → away + the out-looking line, poll ~10s
    ///   found/empty/booked/handoff/confirmed
    ///     already terminal on the shelf   → nothing replays
    ///     new to this device              → shelve it, play the return, reveal it
    ///   failed / anything else            → quiet idle, shelf untouched
    private func applyServerTask(_ item: FindingItem) {
        guard !isBusy else { return }

        if item.status == "none" {
            FindingsStore.clearPending()
            stopPolling()
            starState = .idle
            setCaption("tap the star to send it out looking")
            return
        }

        if item.status == "searching" {
            if !item.taskId.isEmpty {
                FindingsStore.upsert(item)
                findings = FindingsStore.items()
            }
            starState = .away
            setCaption("the star is out looking")
            startPolling(taskId: item.taskId)
            return
        }

        guard FindingsStore.isTerminal(item.status) else {
            // failed: the star never brought anything back. Stay quiet.
            FindingsStore.clearPending()
            stopPolling()
            if starState == .away { starState = .idle }
            return
        }

        // TERMINAL — the star came back while we weren't looking.
        let alreadyShelved = FindingsStore.hasTerminal(taskId: item.taskId)
        FindingsStore.clearPending()
        stopPolling()
        FindingsStore.upsert(item)
        findings = FindingsStore.items()
        guard !alreadyShelved else {
            // reconciled on an earlier pass — don't replay the return or the card.
            if starState == .away { starState = .idle }
            return
        }
        starState = .back
        scheduleIdleAfterReturn()
        setCaption(item.status == "empty" ? "the star came back"
                                          : "the star came back with something")
        // the notification path wants the finding in front of you, not filed away.
        if item.status == "found" || item.status == "empty" { activeReveal = item }
    }

    /// While the tab is visible and the star is still out, re-ask every ~10s
    /// until the task is terminal. Cancelled on disappear and on a new send.
    private func startPolling(taskId: String) {
        guard !taskId.isEmpty, pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { return }
                guard let item = try? await FindingsService.shared.pollFinding(taskId: taskId)
                else { continue }
                if item.status != "searching" {
                    await MainActor.run { applyServerTask(item) }
                    return
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func stopWatching() {
        reconcileTask?.cancel()
        reconcileTask = nil
        stopPolling()
    }

    // MARK: - deep link (the push's door)

    /// dino://finding/{taskId} → poll THAT task and open its reveal, then clear
    /// the route. Works cold, from the background, and while the tab is open.
    private func consumeDeepLinkIfNeeded() {
        guard let id = route.pendingTaskId, !id.isEmpty else { return }
        route.pendingTaskId = nil
        // Instant: if it is already on the shelf, open it now and refresh after.
        if let local = FindingsStore.item(taskId: id), FindingsStore.isTerminal(local.status) {
            findings = FindingsStore.items()
            activeReveal = local
        }
        Task {
            guard let item = try? await FindingsService.shared.pollFinding(taskId: id) else { return }
            await MainActor.run {
                guard FindingsStore.isTerminal(item.status) else {
                    applyServerTask(item)   // still out → away + keep polling
                    return
                }
                FindingsStore.clearPending()
                stopPolling()
                FindingsStore.upsert(item)
                findings = FindingsStore.items()
                if starState != .back {
                    starState = .back
                    scheduleIdleAfterReturn()
                }
                setCaption(item.status == "empty" ? "the star came back"
                                                  : "the star came back with something")
                activeReveal = item
            }
        }
    }

    #if DEBUG
    /// DEBUG-only QA: `-findingsRecoverQA` drives a fake TERMINAL task through
    /// the REAL reconciliation path (applyServerTask) against an emptied shelf,
    /// so the cold-open recovery — shelve + return choreography + auto reveal —
    /// is capturable with no live server call. Returns true when it fired, so
    /// onAppear skips the real reconcile.
    private func applyRecoverQAIfNeeded() -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("-findingsRecoverQA") else { return false }
        // simulate the cold open: a star was sent out, nothing landed locally.
        UserDefaults.standard.removeObject(forKey: FindingsStore.itemsKey)
        FindingsStore.markPending()
        findings = []
        applyServerTask(FindingItem(
            taskId: "fOBoTl257mhN96RRvEjP",
            status: "found",
            title: "Hatha Yoga Class",
            whenText: "this saturday, 2pm",
            whereText: "SPPL",
            why: "a slow hour where nobody needs anything from you",
            url: "https://sppl.org/events/hatha-yoga",
            outcome: "add_to_calendar"))
        return true
    }

    /// DEBUG-only QA: `-findingsCardQA done|unknown` seeds ONE fixture finding
    /// into the real FindingsStore and opens its reveal, so the two card states
    /// this fix is about are capturable with no server call:
    ///   done    — an already-confirmed finding: the card must show the settled
    ///             "added to your calendar" line, NOT another add button.
    ///   unknown — a finding whose listing stated no time: dateConfidence
    ///             "unknown" and no startISO, so the card must offer "open the
    ///             listing" instead of writing a fabricated event.
    /// Returns true when it fired, so onAppear skips the real reconcile.
    private func applyCardQAIfNeeded() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-findingsCardQA"), i + 1 < args.count else { return false }
        let mode = args[i + 1]
        UserDefaults.standard.removeObject(forKey: FindingsStore.itemsKey)
        FindingsStore.clearPending()
        let fixture: FindingItem
        switch mode {
        case "done":
            fixture = FindingItem(
                taskId: "qaDoneTask0001",
                status: "confirmed",
                title: "Hatha Yoga Class",
                whenText: "this sunday, 2pm",
                whereText: "Rondo Community Library",
                why: "a slow hour where nobody needs anything from you",
                url: "https://sppl.org/events/hatha-yoga",
                outcome: "add_to_calendar",
                startISO: "2026-08-02T14:00:00-05:00",
                endISO: "2026-08-02T15:00:00-05:00",
                dateConfidence: "exact",
                calendarWrittenAt: Date())
        case "unknown":
            fixture = FindingItem(
                taskId: "qaUnknownTask001",
                status: "found",
                title: "Quiet Hours at the Conservatory",
                whenText: "see listing",
                whereText: "Como Park Conservatory",
                why: "warm glass rooms and slow air, whenever you can get there",
                url: "https://stpaul.gov/como/quiet-hours",
                outcome: "add_to_calendar",
                startISO: nil,
                endISO: nil,
                dateConfidence: "unknown")
        default:
            return false
        }
        FindingsStore.upsert(fixture)
        findings = FindingsStore.items()
        starState = .idle
        isBusy = true          // hold off reconcile/poll for the capture
        setCaption("the star came back with something")
        activeReveal = fixture
        return true
    }

    /// DEBUG-only QA: `-findingsStateQA sending|away|back` forces a star state
    /// on launch so each motion state renders for screenshots without a live
    /// server call. Pairs with `-findingsQA -jarTabQA` to open the tab.
    private func applyQAStateIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-findingsStateQA"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "sending":
            isBusy = true; starState = .sending; setCaption("the star is heading out")
        case "away":
            isBusy = true; starState = .away; setCaption("the star is out looking")
        case "back":
            isBusy = true; starState = .back; setCaption("the star came back with something")
            scheduleIdleAfterReturn()
        default:
            break
        }
    }
    #endif

    private func landResult(_ item: FindingItem) {
        isBusy = false
        starState = .back
        scheduleIdleAfterReturn()
        if item.status != "capReached" {
            FindingsStore.upsert(item)
            findings = FindingsStore.items()
        }
        FindingsStore.clearPending()
        switch item.status {
        case "capReached":
            capReached = true
            setCaption("the star has wandered enough today. it will be ready again tomorrow")
        case "found":
            setCaption("the star came back with something")
            activeReveal = item
        case "empty":
            setCaption("the star came back")
            activeReveal = item   // the warm empty-handed card
        default:
            setCaption("the star came back empty pawed tonight")
            activeReveal = item
        }
    }

    private func setCaption(_ text: String) {
        if reduceMotion { caption = text }
        else { withAnimation(.easeInOut(duration: 0.3)) { caption = text } }
    }
}

// MARK: - the reveal card (per-outcome action)

private struct FindingRevealCard: View {
    /// The snapshot the sheet was PRESENTED with. Never rendered directly — see
    /// `item` below.
    let initialItem: FindingItem
    let userName: String
    let onClose: () -> Void
    /// Tells the tab to re-read the shelf after an action, so the slips update too.
    var onChanged: () -> Void = {}

    /// THE BUG THIS FIXES: the card used to render the snapshot it was handed,
    /// so a finding acted on in an earlier session (or a moment ago) still
    /// showed a live "add to calendar" button. The card now renders whatever
    /// FindingsStore currently holds for this taskId, refreshed on appear and
    /// after every action.
    @State private var live: FindingItem?
    private var item: FindingItem { live ?? initialItem }

    @State private var note: String?
    @State private var working = false
    @State private var showBookConfirm = false

    private var isEmpty: Bool { item.status == "empty" || item.outcome == "empty_handed" }

    /// Re-read the stored truth for this task. Called on appear (so reopening
    /// from the shelf shows the acted state) and after every action.
    private func refresh() {
        if let stored = FindingsStore.item(taskId: initialItem.taskId) { live = stored }
    }

    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#7A6F5F"))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(hex: "#F5F0E8")))
                    }
                    .buttonStyle(.plain)
                }

                if isEmpty {
                    emptyHanded
                } else {
                    filledCard
                }
                Spacer()
            }
            .padding(24)
        }
        .onAppear(perform: refresh)
    }

    private var emptyHanded: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⭐️").font(.system(size: 40))
            Text("the star came back with open paws tonight")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(Color(hex: "#4A3520"))
            Text("nothing gentle turned up this time. it will try again another day, no rush at all.")
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(Color(hex: "#7A6F5F"))
        }
        .padding(.top, 10)
    }

    private var filledCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(DinoTheme.dinoFont(size: 24))
                .foregroundColor(Color(hex: "#2E2A24"))
            if !item.whenText.isEmpty || !item.whereText.isEmpty {
                Text([item.whenText, item.whereText].filter { !$0.isEmpty }.joined(separator: "  ·  "))
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#7A6F5F"))
            }
            if !item.why.isEmpty {
                Text(item.why)
                    .font(DinoTheme.dinoFont(size: 15))
                    .italic()
                    .foregroundColor(Color(hex: "#4A3520"))
                    .padding(.top, 4)
            }

            Spacer().frame(height: 8)
            actionButton

            if let note {
                Text(note)
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(Color(hex: "#7A6F5F"))
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .padding(.top, 6)
    }

    /// STATUS FIRST, outcome second.
    ///
    /// A finding that has already been acted on (confirmed / booked / handoff)
    /// gets a plain DONE line, never another action — offering "add to calendar"
    /// on something already on the calendar was how the second, duplicate event
    /// got written. Only a not-yet-acted finding falls through to the per-outcome
    /// action, and a finding with no confirmed time never gets a calendar button
    /// at all.
    @ViewBuilder
    private var actionButton: some View {
        switch item.status {
        case "confirmed":
            doneState("added to your calendar")
        case "booked":
            doneState("booked")
        case "handoff":
            VStack(alignment: .leading, spacing: 10) {
                doneState("handed off to you — finish signing up")
                secondaryButton("open the page again") {
                    if let url = URL(string: item.url) { UIApplication.shared.open(url) }
                }
            }
        default:
            unactedAction
        }
    }

    @ViewBuilder
    private var unactedAction: some View {
        switch item.outcome {
        case "book_it":
            primaryButton("book it") { showBookConfirm = true }
                .confirmationDialog("book it?", isPresented: $showBookConfirm, titleVisibility: .visible) {
                    Button("yes, book it") { bookIt() }
                    Button("not now", role: .cancel) {}
                } message: {
                    Text("dino will sign you up with just your name and email")
                }
        case "finish_signup":
            primaryButton("finish signing up") {
                if let url = URL(string: item.url) { UIApplication.shared.open(url) }
                setNote("opened the page for you to finish")
            }
        default: // add_to_calendar
            // HONEST: with no confirmed time on the listing there is nothing to
            // put on a calendar, so we open the listing instead of inventing a
            // date the way the old placeholder did.
            if item.hasConfirmedTime {
                primaryButton("add to calendar") { addToCalendar() }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    primaryButton("open the listing") {
                        if let url = URL(string: item.url) { UIApplication.shared.open(url) }
                        setNote("opened the listing for you")
                    }
                    Text("no confirmed time on the listing, so dino will not guess one")
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(Color(hex: "#7A6F5F"))
                }
            }
        }
    }

    /// A settled, non-tappable state. Deliberately not a Button: there is
    /// nothing left to do here.
    private func doneState(_ label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#4A3520").opacity(0.55))
            Text(label)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(Color(hex: "#4A3520"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color(hex: "#EDE4D4")))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private func secondaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(Color(hex: "#4A3520"))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().stroke(Color(hex: "#4A3520").opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if working { ProgressView().tint(.white).padding(.trailing, 4) }
                Text(working ? "one moment" : label)
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color(hex: "#4A3520")))
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    // MARK: - actions

    private func addToCalendar() {
        // BELT: never write twice. The card should not even be offering this on
        // an acted finding, but a stale tap must still be a no-op, not a second
        // event on someone's calendar.
        let current = FindingsStore.item(taskId: item.taskId) ?? item
        guard !FindingsStore.hasCalendarWrite(current) else {
            refresh()
            setNote("already on your calendar")
            return
        }
        working = true
        Task {
            let result = await FindingsService.shared.writeCalendar(for: item)
            await MainActor.run {
                working = false
                switch result {
                case .written:
                    FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                    setNote("added to your calendar")
                case .alreadyWritten:
                    FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                    setNote("already on your calendar")
                case .noConfirmedTime:
                    setNote("no confirmed time on the listing, so nothing was scheduled")
                case .failed:
                    setNote("couldn't reach your calendar, no worries")
                }
                refresh()
                onChanged()
            }
        }
    }

    private func bookIt() {
        // Same guard on the booking path: an already-acted finding is done.
        let currentItem = FindingsStore.item(taskId: item.taskId) ?? item
        guard !FindingsStore.isActed(currentItem.status) else {
            refresh()
            return
        }
        working = true
        Task {
            do {
                let (status, url) = try await FindingsService.shared
                    .confirmFinding(taskId: item.taskId, userName: userName)
                // The calendar write here goes through the SAME duplicate guard
                // and the same real-date rule as the plain add-to-calendar path.
                let write: FindingsService.CalendarWrite
                if status == "booked" || status == "confirmed" {
                    write = await FindingsService.shared.writeCalendar(for: item)
                } else {
                    write = .failed
                }
                let calOK = (write == .written || write == .alreadyWritten)
                await MainActor.run {
                    working = false
                    switch status {
                    case "booked":
                        FindingsStore.markStatus(taskId: item.taskId, status: "booked", bookedAt: Date())
                        setNote(calOK ? "booked" : "booked, but the calendar write failed")
                    case "handoff":
                        FindingsStore.markStatus(taskId: item.taskId, status: "handoff")
                        if let u = URL(string: url.isEmpty ? item.url : url) { UIApplication.shared.open(u) }
                        setNote(calOK ? "calendar saved, registration handed off to you"
                                      : "registration handed off to you at the page")
                    case "confirmed":
                        FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                        setNote(calOK ? "on your calendar"
                                      : (write == .noConfirmedTime
                                         ? "no confirmed time on the listing, so nothing was scheduled"
                                         : "couldn't reach your calendar, no worries"))
                    default:
                        setNote("couldn't book it this time")
                    }
                    refresh()
                    onChanged()
                }
            } catch {
                await MainActor.run { working = false; setNote("couldn't book it this time") }
            }
        }
    }

    private func setNote(_ text: String) {
        withAnimation(.easeInOut(duration: 0.25)) { note = text }
    }
}
