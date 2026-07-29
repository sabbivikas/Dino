//
//  FindingsCardView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — the redesigned finding card (Tolan
//  layout), shown ABOVE the free-floating star. Branch-owned SwiftUI.
//
//  LAYOUT (top → bottom): a rounded-rect event PHOTO filling the upper portion
//  (async-loaded, with a generated-gradient fallback in the SAME shape — never
//  a broken slot, never an invented photo); TWO small white circular buttons
//  overlapping the photo's top-right (share + an up-chevron that COLLAPSES the
//  card); a bold white single-line title (ellipsis); a small white pill with
//  the SOURCE DOMAIN in dark text. ~78% screen width, corner radius 26,
//  translucent gradient pale-mint → green → muted warm brown.
//
//  ACTION PATH (owner course-correction): the card body is NOT a tap target. An
//  EXPLICIT per-outcome button sits below the source pill — add_to_calendar
//  “add it to my day”, book_it “save me a spot”, finish_signup “open the signup
//  page” (no confirmed time falls back to “open the listing”, never a guessed
//  date). Beneath it a quiet “not this time” dismisses the card to the idle sky,
//  leaving the finding UNACTED and recoverable. An already-acted finding shows
//  only the quiet acted line. Every honest guard is intact.
//
//  REVEAL CHOREOGRAPHY: light first, card second (the card is MADE OF the
//  light). A vertical seed cracks open → six rays fan out rotating as they
//  expand → a ring pops through them → eight sparks fly out and fade → the card
//  materializes on a Y-axis flip from nearly edge-on with a slight overshoot →
//  one diagonal holographic sweep across it → then a slow warm rim pulse. ~1.5s.
//  It is one deterministic `keyframeAnimator` timeline: SwiftUI drives it, so a
//  re-mount during the appear transition simply REPLAYS it (an earlier
//  @State/asyncAfter driver could get stranded mid-reveal). Reduce Motion: the
//  light + flip collapse to a plain fade, the holo sweep is skipped.
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI

struct FindingsCardView: View {
    let initialItem: FindingItem
    let userName: String
    var onCollapse: () -> Void = {}
    var onShare: (FindingItem) -> Void = { _ in }
    var onChanged: () -> Void = {}
    /// "not this time" — dismiss the card back to the idle sky. The finding stays
    /// UNACTED (no keepsake, no status change) and remains recoverable via the
    /// reconcile / latest-task path.
    var onDismiss: () -> Void = {}
    /// DEBUG QA: freeze the reveal at the rays/ring moment (card not yet in) so
    /// the mid-reveal frame is screenshot-able. Never set in real use.
    var qaFreezeReveal: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var live: FindingItem?
    private var item: FindingItem { live ?? initialItem }

    @State private var note: String?
    @State private var working = false
    @State private var showBookConfirm = false
    @State private var rimHot = false
    /// Light burst driver: false = collapsed+bright (pre-burst), true = expanded
    /// +faded. Flipped true on appear; each element eases via .animation(value:).
    @State private var burst = false
    /// Removes the light overlay once the burst has played, so nothing lingers.
    @State private var lightShown = true
    /// Holo sweep X (× width); animates across once after the card materializes.
    @State private var holoX: CGFloat = -1.4
    /// Latched true on appear so the card INSERTS (triggering the flip
    /// transition). A transition always settles at the present state, so a
    /// re-mount just replays the flip — it can never strand the card invisible
    /// the way an opacity/@State driver could.
    @State private var cardPlaced = false

    private var isEmpty: Bool { item.status == "empty" || item.outcome == "empty_handed" }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width * 0.78
            let reach = cardWidth * 0.62
            ZStack {
                if lightShown && !reduceMotion {
                    lightLayer(reach: reach)   // light first; the card is made of it
                }
                if cardPlaced {
                    card(width: cardWidth, holoX: holoX)
                        .transition(reduceMotion ? .opacity : .findingsCardReveal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .confirmationDialog("book it?", isPresented: $showBookConfirm, titleVisibility: .visible) {
            Button("yes, book it") { bookIt() }
            Button("not now", role: .cancel) {}
        } message: {
            Text("dino will sign you up with just your name and email")
        }
        .onAppear { onAppearReveal() }
    }

    private func onAppearReveal() {
        refresh()
        if qaFreezeReveal { return }   // card stays absent; hold the pre-burst light
        if reduceMotion {
            cardPlaced = true
            FindingsHaptics.shared.cardLock()
            if isEmpty { FindingsHaptics.shared.emptyHanded() }
            return
        }
        // insert the card so its flip transition plays; settles fully present.
        withAnimation { cardPlaced = true }
        // fire the light burst (each element eases off `burst` with its own delay)
        burst = true
        FindingsHaptics.shared.rayBurst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            FindingsHaptics.shared.cardLock()
            if isEmpty { FindingsHaptics.shared.emptyHanded() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) { lightShown = false }
        }
        // one diagonal holo sweep after the card locks
        withAnimation(.easeInOut(duration: 0.55).delay(1.25)) { holoX = 1.4 }
        // slow warm rim pulse while the card is on screen
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(1.0)) {
            rimHot = true
        }
    }

    // MARK: - the card

    private func card(width: CGFloat, holoX: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            photo(width: width)
                .overlay(alignment: .topTrailing) { circleButtons.padding(12) }

            VStack(alignment: .leading, spacing: 10) {
                Text(item.title.isEmpty ? "a gentle outing" : item.title)
                    .font(DinoTheme.dinoFont(size: 20))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let domain = FindingsDomain.source(from: item.url) {
                    Text(domain)
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(Color(hex: "#3A2E20"))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                }

                actionArea
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#CDE8CF").opacity(0.95),
                             Color(hex: "#7FB185").opacity(0.94),
                             Color(hex: "#6B5238").opacity(0.95)],
                    startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: "#FFE9B8").opacity(rimHot ? 0.85 : 0.35),
                        lineWidth: rimHot ? 2.0 : 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { holoSweep(width: width, x: holoX) }
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: - photo (async, gradient fallback in the same shape)

    private func photo(width: CGFloat) -> some View {
        let height = width * 0.62
        return ZStack {
            if let raw = item.imageURL, let url = URL(string: raw) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.3))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        gradientFallback   // loading + failure both fall back, never a blank slot
                    }
                }
            } else {
                gradientFallback
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.18)],
                           startPoint: .center, endPoint: .bottom)
        }
    }

    /// A deterministic gradient in the card's palette, seeded from the title so
    /// it is stable and never an invented/borrowed photo.
    private var gradientFallback: some View {
        let seed = abs(item.title.hashValue)
        let palette: [(String, String)] = [
            ("#A9D3B0", "#6E9C86"), ("#C8BEE6", "#8A7CB6"),
            ("#BBD9E8", "#7C9DB8"), ("#E6CBB6", "#B08E6E"),
        ]
        let pair = palette[seed % palette.count]
        return ZStack {
            LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: - the two white circular controls

    private var circleButtons: some View {
        HStack(spacing: 10) {
            circleButton(system: "square.and.arrow.up") { onShare(item) }
            circleButton(system: "chevron.up") {
                FindingsHaptics.shared.tapStar()
                onCollapse()
            }
        }
    }

    private func circleButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#3A2E20"))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.95)))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - action area (explicit button + "not this time", no body tap)

    @ViewBuilder
    private var actionArea: some View {
        if isEmpty {
            Text("the star came back with open paws tonight. nothing gentle turned up this time.")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(.white.opacity(0.92))
        } else {
            switch item.status {
            case "confirmed": actedLine("added to your calendar")
            case "booked":    actedLine("booked")
            case "handoff":   actedLine("handed off to you — finish signing up")
            default:
                VStack(alignment: .leading, spacing: 10) {
                    primaryButton
                    if let note {
                        Text(note)
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .transition(.opacity)
                    }
                    Button(action: { onDismiss() }) {
                        Text("not this time")
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The single explicit action, labelled by outcome so the button itself says
    /// WHICH of the four this card is. Cream fill + dark text stays legible on
    /// the mint→green→brown gradient.
    private var primaryButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: 8) {
                if working { ProgressView().tint(Color(hex: "#3A2E20")).scaleEffect(0.8) }
                Text(working ? "one moment" : primaryLabel)
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(Color(hex: "#3A2E20"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color(hex: "#FBF4E2")))
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    private var primaryLabel: String {
        switch item.outcome {
        case "book_it":       return "save me a spot"
        case "finish_signup": return "open the signup page"
        default:
            return item.hasConfirmedTime ? "add it to my day" : "open the listing"
        }
    }

    private func primaryAction() {
        guard !working else { return }
        switch item.outcome {
        case "book_it":
            showBookConfirm = true
        case "finish_signup":
            if let url = URL(string: item.url) { UIApplication.shared.open(url) }
            FindingsKeepsake.recordAccepted(item)   // opening the signup page = accepted
            FindingsStore.markStatus(taskId: item.taskId, status: "handoff")
            setNote("opened the signup page for you")
            refresh(); onChanged()
        default: // add_to_calendar
            if item.hasConfirmedTime { addToCalendar() }
            else {
                // HONEST: no confirmed time → open the listing rather than invent a
                // date. Not an acceptance, so no keepsake and no status change.
                if let url = URL(string: item.url) { UIApplication.shared.open(url) }
                setNote("no confirmed time on the listing, so dino opened it instead of guessing")
            }
        }
    }

    private func actedLine(_ label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
            Text(label).font(DinoTheme.dinoFont(size: 14)).foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    // MARK: - reveal light (seed → rays → ring → sparks, eased off `burst`)

    private func lightLayer(reach: CGFloat) -> some View {
        let frozen = qaFreezeReveal
        // per-element start (pre-burst) → end (expanded + faded)
        let seedH: CGFloat = frozen ? 0.6 : (burst ? 1 : 0.05)
        let seedOp: Double = frozen ? 0.95 : (burst ? 0 : 0.95)
        let raysRot: Double = frozen ? 16 : (burst ? 26 : 0)
        let raysScale: CGFloat = frozen ? 0.85 : (burst ? 1.1 : 0.1)
        let raysOp: Double = frozen ? 0.8 : (burst ? 0 : 0.8)
        let ringScale: CGFloat = frozen ? 0.95 : (burst ? 1.2 : 0.1)
        let ringOp: Double = frozen ? 0.7 : (burst ? 0 : 0.7)
        let sparksSpread: CGFloat = frozen ? reach * 0.5 : (burst ? reach * 0.95 : 4)
        let sparksOp: Double = frozen ? 0.85 : (burst ? 0 : 0.9)
        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "#FFF3D6"), Color(hex: "#FFE08A")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 7, height: reach)
                .scaleEffect(x: 1, y: seedH, anchor: .center)
                .opacity(seedOp)
                .blur(radius: 1)
                .animation(frozen ? nil : .easeOut(duration: 0.35), value: burst)

            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(Color(hex: "#FFE9B8"))
                        .frame(width: 3, height: reach * 1.25)
                        .offset(y: -reach * 0.62)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
            }
            .rotationEffect(.degrees(raysRot))
            .scaleEffect(raysScale)
            .opacity(raysOp)
            .animation(frozen ? nil : .easeOut(duration: 0.5).delay(0.08), value: burst)

            Circle()
                .stroke(Color(hex: "#FFF3D6"), lineWidth: 2.5)
                .frame(width: reach * 1.5, height: reach * 1.5)
                .scaleEffect(ringScale)
                .opacity(ringOp)
                .animation(frozen ? nil : .easeOut(duration: 0.55).delay(0.12), value: burst)

            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#FFEFC6"))
                    .frame(width: 6, height: 6)
                    .offset(sparkOffset(i, spread: sparksSpread))
                    .opacity(sparksOp)
                    .animation(frozen ? nil : .easeOut(duration: 0.5).delay(0.12), value: burst)
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkOffset(_ i: Int, spread: CGFloat) -> CGSize {
        let a = Double(i) / 8.0 * 2 * .pi + 0.3
        return CGSize(width: cos(a) * spread, height: sin(a) * spread)
    }

    @ViewBuilder
    private func holoSweep(width: CGFloat, x: Double) -> some View {
        if !reduceMotion {
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.35), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: width * 0.5)
            .rotationEffect(.degrees(18))
            .offset(x: CGFloat(x) * width)
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }

    // MARK: - live state

    private func refresh() {
        if let stored = FindingsStore.item(taskId: initialItem.taskId) { live = stored }
    }

    private func setNote(_ text: String) {
        withAnimation(.easeInOut(duration: 0.25)) { note = text }
    }

    // MARK: - actions

    private func addToCalendar() {
        let current = FindingsStore.item(taskId: item.taskId) ?? item
        guard !FindingsStore.hasCalendarWrite(current) else {
            refresh(); setNote("already on your calendar"); return
        }
        working = true
        Task {
            let result = await FindingsService.shared.writeCalendar(for: item)
            await MainActor.run {
                working = false
                switch result {
                case .written, .alreadyWritten:
                    FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                    FindingsKeepsake.recordAccepted(item)   // calendar write = accepted
                    setNote("added to your calendar")
                case .noConfirmedTime:
                    setNote("no confirmed time on the listing, so nothing was scheduled")
                case .failed:
                    setNote("couldn't reach your calendar, no worries")
                }
                refresh(); onChanged()
            }
        }
    }

    private func bookIt() {
        let currentItem = FindingsStore.item(taskId: item.taskId) ?? item
        guard !FindingsStore.isActed(currentItem.status) else { refresh(); return }
        working = true
        Task {
            do {
                let (status, url) = try await FindingsService.shared
                    .confirmFinding(taskId: item.taskId, userName: userName)
                let write: FindingsService.CalendarWrite
                if status == "booked" || status == "confirmed" {
                    write = await FindingsService.shared.writeCalendar(for: item)
                } else { write = .failed }
                let calOK = (write == .written || write == .alreadyWritten)
                await MainActor.run {
                    working = false
                    switch status {
                    case "booked":
                        FindingsStore.markStatus(taskId: item.taskId, status: "booked", bookedAt: Date())
                        FindingsKeepsake.recordAccepted(item)
                        setNote(calOK ? "booked" : "booked, but the calendar write failed")
                    case "handoff":
                        FindingsStore.markStatus(taskId: item.taskId, status: "handoff")
                        if let u = URL(string: url.isEmpty ? item.url : url) { UIApplication.shared.open(u) }
                        FindingsKeepsake.recordAccepted(item)
                        setNote(calOK ? "calendar saved, registration handed off to you"
                                      : "registration handed off to you at the page")
                    case "confirmed":
                        FindingsStore.markStatus(taskId: item.taskId, status: "confirmed")
                        FindingsKeepsake.recordAccepted(item)
                        setNote(calOK ? "on your calendar"
                                      : (write == .noConfirmedTime
                                         ? "no confirmed time on the listing, so nothing was scheduled"
                                         : "couldn't reach your calendar, no worries"))
                    default:
                        setNote("couldn't book it this time")
                    }
                    refresh(); onChanged()
                }
            } catch {
                await MainActor.run { working = false; setNote("couldn't book it this time") }
            }
        }
    }
}

// MARK: - the card materialize transition (Y-flip from nearly edge-on)

private struct FindingsCardFlip: ViewModifier {
    var progress: Double   // 0 = edge-on + invisible, 1 = fully present
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.92 + 0.08 * progress)
            .rotation3DEffect(.degrees((1 - progress) * 82),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }
}

extension AnyTransition {
    /// The card is MADE OF the light: it flips in from nearly edge-on with a
    /// slight overshoot. A transition (not @State) so it always settles present.
    static var findingsCardReveal: AnyTransition {
        .modifier(active: FindingsCardFlip(progress: 0),
                  identity: FindingsCardFlip(progress: 1))
        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.42))
    }
}
