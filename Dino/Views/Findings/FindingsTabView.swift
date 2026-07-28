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

    @State private var starState: FindingsStarState = .idle
    @State private var findings: [FindingItem] = FindingsStore.items()
    @State private var caption: String = "tap the star to send it out looking"
    @State private var showConfirm = false
    @State private var activeReveal: FindingItem?
    @State private var isBusy = false
    @State private var capReached = false

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
            FindingRevealCard(item: item, userName: userName, onClose: { activeReveal = nil })
        }
        .onAppear {
            #if DEBUG
            applyQAStateIfNeeded()
            #endif
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
        }
    }

    /// The paper-family cream (mirrors RecRevealView's cream) for labels on the
    /// dark sky — readable, still soft.
    static let creamText = Color(red: 0.984, green: 0.965, blue: 0.922)

    // MARK: - send the star out

    private func sendStar() {
        isBusy = true
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
                let item = try await FindingsService.shared.startFinding()
                await MainActor.run { landResult(item) }
            } catch {
                await MainActor.run {
                    starState = .back
                    isBusy = false
                    // Gate denial (unauthenticated / permission-denied) is not a
                    // real failure — give it a distinct quiet line (owner fix #8).
                    if FindingsService.isGateDenied(error) {
                        setCaption("the star only flies for its own dino")
                    } else {
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

    #if DEBUG
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
    let item: FindingItem
    let userName: String
    let onClose: () -> Void

    @State private var note: String?
    @State private var working = false
    @State private var showBookConfirm = false

    private var isEmpty: Bool { item.status == "empty" || item.outcome == "empty_handed" }

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

    @ViewBuilder
    private var actionButton: some View {
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
            primaryButton("add to calendar") { addToCalendar() }
        }
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
        working = true
        Task {
            let ok = await FindingsService.shared.writeCalendar(for: item)
            await MainActor.run {
                working = false
                if ok {
                    FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                    setNote("added to your calendar")
                } else {
                    setNote("couldn't reach your calendar, no worries")
                }
            }
        }
    }

    private func bookIt() {
        working = true
        Task {
            do {
                let (status, url) = try await FindingsService.shared
                    .confirmFinding(taskId: item.taskId, userName: userName)
                let calOK = (status == "booked" || status == "confirmed")
                    ? await FindingsService.shared.writeCalendar(for: item) : false
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
                        setNote(calOK ? "on your calendar" : "couldn't reach your calendar, no worries")
                    default:
                        setNote("couldn't book it this time")
                    }
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
