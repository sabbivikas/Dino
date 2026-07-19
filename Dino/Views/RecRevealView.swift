//
//  RecRevealView.swift
//  Dino
//
//  Rec delivery F4 — the reveal: a full-screen gift moment. Dusk world
//  backdrop (the app's own evening sky + hill palette), dino at the bottom
//  presenting, the paper parcel center-screen. A tap unwraps (~1s of paper
//  folding away), then the rec card blooms in — image-led when artwork
//  arrives (tmdb poster / open library cover / itunes art via RecArtwork),
//  paper-only otherwise, never a broken frame.
//
//  card revealed = 'opened' (announced → opened, the rules' one client
//  write) + the live activity ends + the keepsake/ledger write exactly as
//  the old display flow did. swipe-down before the card shows dismisses
//  and leaves everything announced — the parcel stays for later (F5).
//
//  Reduce Motion: no unwrap animation — the card fades in. Dark mode safe
//  by construction (fixed dusk palette + the house paper card).
//

import SwiftUI

struct RecRevealView: View {
    let deliveryId: String
    let onDismiss: () -> Void

    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var phase: RecRevealPhase = .wrapped
    @State private var delivery: RecRevealService.Delivery?
    @State private var artwork: UIImage?
    @State private var unwrapProgress: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var didRecord = false

    // paper palette — mirrors RecParcelView (private there by design)
    private let cream      = Color(red: 0.984, green: 0.965, blue: 0.922)
    private let creamShade = Color(red: 0.937, green: 0.906, blue: 0.839)
    private let paperEdge  = Color(red: 0.816, green: 0.769, blue: 0.667)

    private var reduceMotion: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-recRevealQAReduceMotion") { return true }
        #endif
        return systemReduceMotion
    }

    private var rec: RichRec? { delivery?.recs.first }

    private var isQA: Bool {
        #if DEBUG
        return deliveryId.hasPrefix("qa-")
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            RecDuskBackdrop(reduceMotion: reduceMotion)

            // the parcel beat — wrapped + unwrapping
            if phase != .revealed {
                parcelBlock
                    .transition(.opacity)
            }

            // the paper folding away
            if phase == .unwrapping {
                unwrapFlaps
            }

            // the card — blooms 0.92 → 1 (spring), or fades under reduce motion
            if let rec {
                cardView(rec)
                    .scaleEffect(phase == .revealed ? 1.0 : (reduceMotion ? 1.0 : 0.92))
                    .opacity(phase == .revealed ? 1.0 : 0.0)
                    .allowsHitTesting(phase == .revealed)
            }
        }
        .offset(y: max(0, dragOffset))
        .contentShape(Rectangle())
        .onTapGesture { parcelTapped() }
        .gesture(dismissDrag)
        .onAppear { load() }
    }

    // MARK: - the parcel beat

    private var parcelBlock: some View {
        VStack(spacing: 26) {
            Spacer()
            RecParcelView(size: 158, glowing: true)
                .scaleEffect(1.0 + 0.12 * unwrapProgress)
                .opacity(1.0 - Double(unwrapProgress))
            // existing catalog line — zero new copy for the presenting beat
            Text(ComfortRecVoice.header(hour: Calendar.current.component(.hour, from: Date())))
                .font(DinoTheme.dinoFont(size: 24))
                .foregroundColor(cream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                .opacity(1.0 - Double(unwrapProgress))
            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Four cream paper quarters that fly outward as the string comes off —
    /// scale/rotate/opacity only, no physics, 60fps-friendly.
    private var unwrapFlaps: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let dx: CGFloat = (i % 2 == 0 ? -1 : 1)
                let dy: CGFloat = (i < 2 ? -1 : 1)
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [cream, creamShade],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(paperEdge, lineWidth: 1.2))
                    .frame(width: 84, height: 74)
                    .rotationEffect(.degrees(Double(dx * dy) * 42 * Double(unwrapProgress)))
                    .offset(x: dx * 130 * unwrapProgress,
                            y: dy * 150 * unwrapProgress - 40 * unwrapProgress)
                    .opacity(Double(1.0 - unwrapProgress) * 0.95)
            }
        }
        .offset(y: -46)   // over the parcel's spot
        .allowsHitTesting(false)
    }

    // MARK: - the card

    private func cardView(_ rec: RichRec) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // artwork — washi-taped onto the paper; simply absent when no
            // image arrived (the paper-only design, never an empty frame)
            if let artwork {
                HStack {
                    Spacer()
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: rec.type == "music" ? 168 : 150,
                               height: rec.type == "music" ? 168 : 216)
                        .clipped()
                        .cornerRadius(4)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
                        .rotationEffect(.degrees(1.4))
                        .overlay(alignment: .top) { washiTapes }
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 16)
                .transition(.opacity)
            }

            // the title NEVER truncates — long titles wrap (house rule)
            Text(rec.title)
                .font(DinoTheme.dinoFont(size: 23))
                .lineSpacing(4)
                .foregroundColor(Color(hex: "#3D3A35"))
                .fixedSize(horizontal: false, vertical: true)
            Text(ComfortRecVoice.metaLine(rec))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color(hex: "#A8A29A"))
                .padding(.top, 4)

            // why — dino speaking to this person about this day
            HStack(alignment: .top, spacing: 10) {
                Image("jar-dino")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 26)
                Text(rec.why)
                    .font(DinoTheme.dinoFont(size: 16))
                    .lineSpacing(5)
                    .foregroundColor(Color(hex: "#7A7266"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)

            // content flags — wellness critical, always visible
            Text(rec.flags.map(\.localized).joined(separator: ComfortRecVoice.flagSeparator))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(Color(hex: "#7BA872"))
                .padding(.top, 10)

            HStack(spacing: 8) {
                // source pill — watch-provider or source
                Text(RecRevealVoice.sourcePill(for: rec, rememberedMusicApp: RecOpenMemory.remembered()))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#7A7266"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#F0E7D3")))
                Text(ComfortRecVoice.feelLine(rec))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Color(hex: "#A8A29A"))
                    .lineLimit(1)
            }
            .padding(.top, 10)

            VStack(spacing: 10) {
                Button(action: openIt) {
                    Text(ComfortRecVoice.openIt)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#7BA872")))
                        .shadow(color: Color(hex: "#7BA872").opacity(0.30), radius: 7, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())

                if let url = RecRevealShare.url(for: rec) {
                    ShareLink(item: url, message: Text(RecRevealShare.message(for: rec))) {
                        Text(String(localized: "share"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#7A7266"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "#3D3A35").opacity(0.14), lineWidth: 1.5))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.top, 16)
        }
        .padding(EdgeInsets(top: 22, leading: 22, bottom: 20, trailing: 22))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#FFFDF6"))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                .shadow(color: .black.opacity(0.30), radius: 18, y: 12)
        )
        .rotationEffect(.degrees(-1.1))
        .padding(.horizontal, 26)
    }

    private var washiTapes: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#EAD9A8").opacity(0.85))
                .frame(width: 46, height: 15)
                .rotationEffect(.degrees(-38))
                .offset(x: -14, y: -7)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#EAD9A8").opacity(0.85))
                .frame(width: 46, height: 15)
                .rotationEffect(.degrees(34))
                .offset(x: 14, y: -7)
        }
    }

    // MARK: - gestures + flow

    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    // wrapped/unwrapping → delivery stays announced, parcel
                    // stays for later (RecRevealMachine.parcelStaysForLater)
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func load() {
        Task {
            let fetched = await RecRevealService.fetch(deliveryId: deliveryId)
            delivery = fetched
            guard let first = fetched?.recs.first else { return }
            // pre-warm during the wrapped beat; a late arrival fades in
            let image = await RecArtwork.loadImage(for: first)
            withAnimation(.easeInOut(duration: 0.35)) { artwork = image }
        }
    }

    private func parcelTapped() {
        let next = RecRevealMachine.afterParcelTap(
            phase: phase, payloadReady: rec != nil, reduceMotion: reduceMotion)
        guard next != phase else { return }
        HapticManager.shared.light()
        if next == .revealed {
            // reduce motion — the card fades in, nothing folds
            withAnimation(.easeInOut(duration: 0.3)) { phase = .revealed }
            recordRevealIfNeeded()
        } else {
            phase = .unwrapping
            withAnimation(.easeOut(duration: 0.75)) { unwrapProgress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + RecRevealMachine.unwrapDuration) {
                guard phase == .unwrapping else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    phase = RecRevealMachine.afterUnwrapAnimation(phase: phase)
                }
                recordRevealIfNeeded()
            }
        }
    }

    /// The reveal happened — runs once: end the parcel activity, flip the
    /// delivery to opened, and write the keepsake + ledger exactly as the
    /// old display flow did (shelf compatibility — F5 relies on it).
    private func recordRevealIfNeeded() {
        guard !didRecord, let delivery, let rec else { return }
        didRecord = true
        DinoLiveActivityManager.shared.endRecParcelActivities()
        AnalyticsManager.shared.trackScreen("rec_reveal")
        guard RecRevealMachine.shouldMarkOpened(phase: .revealed,
                                                deliveryStatus: delivery.status) else { return }
        RecRevealService.markOpened(deliveryId: deliveryId)
        guard !isQA else { return }   // fixtures never write the shelf/ledger
        // F5 — remember this delivery as opened on-device so the shelf catch
        // drops its wrapped parcel at once (the markOpened flip is async).
        RichRecStore.markDeliveryOpened(deliveryId)
        // exactly the old presentRichRec flow: scarcity clock, ledger 'shown',
        // the shelf keepsake (one event, two faces), analytics
        GentleRecStore.recordShown()
        let ledgerId = OutcomeLedger.recordShown(kind: "rec", itemType: rec.type,
                                                 moodEntries: dataManager.moodEntries)
        RichRecStore.recordKeepsake(rec, ledgerId: ledgerId)
        AnalyticsManager.shared.trackRecShown(type: rec.type)
        // the two companions wait in the local cache for future cleared
        // moments — the same batch behavior the old network fetch had
        let rest = Array(delivery.recs.dropFirst())
        if !rest.isEmpty { RichRecStore.save(RichRecBatch(recs: rest, fetchedAt: Date())) }
    }

    private func openIt() {
        guard let rec, let link = rec.reopenLink() else { return }
        GentleRecStore.recordTapped(type: rec.type)
        if !isQA { OutcomeLedger.recordAction(kind: "rec", action: "opened") }
        AnalyticsManager.shared.trackRecTapped()
        UIApplication.shared.open(link.url)
    }
}

// MARK: - the dusk world backdrop

/// Dusk gradient + two soft hills + dino presenting — every color from the
/// app's own evening sky palette (DinoSkyBackground), the dino from the
/// existing mascot art. Fixed palette = identical (and safe) in dark mode.
private struct RecDuskBackdrop: View {
    let reduceMotion: Bool
    @State private var breathing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // the app's evening sky family (SkyPalette .evening/.dusk)
                LinearGradient(
                    colors: [Color(hex: "#2D2B6B"), Color(hex: "#4A4080"), Color(hex: "#6B4FA0")],
                    startPoint: .top, endPoint: .bottom)

                // a warm horizon breath behind the hills (the parcel's glow family)
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.0, green: 0.914, blue: 0.722).opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: w * 0.7))
                    .frame(width: w * 1.6, height: h * 0.5)
                    .position(x: w * 0.5, y: h * 0.86)

                // two soft hill silhouettes (the app's evening hill palette)
                Ellipse()
                    .fill(Color(hex: "#4A6741").opacity(0.9))
                    .frame(width: w * 1.7, height: h * 0.30)
                    .position(x: w * 0.22, y: h * 1.00)
                Ellipse()
                    .fill(Color(hex: "#364F31"))
                    .frame(width: w * 1.7, height: h * 0.26)
                    .position(x: w * 0.86, y: h * 1.04)

                // dino, presenting — the existing mascot art, gently breathing
                Image("cut-DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .scaleEffect(reduceMotion ? 1.0 : (breathing ? 1.025 : 0.985))
                    .position(x: w * 0.26, y: h * 0.885)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}