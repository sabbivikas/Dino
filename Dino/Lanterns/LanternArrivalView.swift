//
//  LanternArrivalView.swift
//  Dino
//
//  The lantern ARRIVAL ceremony (distinct from the send-release scene in
//  World/LanternCeremonyView) — full-screen experience layer over the
//  mood screen after a heavy log. beat → hush → drift → hover → open →
//  keep → kept → lift → after, exact handoff timings. Claim, moderation,
//  and report mechanics are untouched — this view only renders.
//
//  Fully skippable: tap anywhere advances. Reduce Motion: the same machine
//  and timings, crossfades between stage end-states only (no drift/sway).
//

import SwiftUI

struct LanternArrivalView: View {
    let lantern: ReceivedLantern
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var machine = LanternCeremonyMachine()
    @State private var phaseStartedAt = Date()
    @State private var timerTask: Task<Void, Never>?
    @State private var showReportConfirm = false

    private var countryName: String? {
        lantern.countryCode == "elsewhere" ? nil : LanternService.countryName(lantern.countryCode)
    }

    private var distanceLine: String {
        let user = WorldMoodService.countryCode(from: Locale.current.region?.identifier)
        let km = user == "elsewhere" || lantern.countryCode == "elsewhere"
            ? nil : CeremonyDistance.kilometers(from: user, to: lantern.countryCode)
        let metric = Locale.current.measurementSystem == .metric
        return CeremonyStrings.distanceLine(kilometers: km, metric: metric)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: reduceMotion || !needsClock)) { timeline in
                let dt = timeline.date.timeIntervalSince(phaseStartedAt) * 1000
                let frame = reduceMotion
                    ? CeremonyLayout.frame(phase: machine.phase, dt: .greatestFiniteMagnitude)
                    : CeremonyLayout.frame(phase: machine.phase, dt: max(dt, 0))
                content(frame: frame, size: geo.size)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { advanceByTap() }
        .onAppear { scheduleTimer() }
        .onDisappear { timerTask?.cancel() }
        .alert("report this lantern", isPresented: $showReportConfirm) {
            Button("report", role: .destructive) {
                Task { await LanternService.report(lantern) }
                advanceByTap()
            }
            Button("keep reading", role: .cancel) {}
        }
        .accessibilityAction(named: Text("continue")) { advanceByTap() }
    }

    private var needsClock: Bool {
        machine.phase != .after
    }

    @ViewBuilder
    private func content(frame: CeremonyLanternFrame, size: CGSize) -> some View {
        let sx = size.width / 390.0
        let sy = size.height / 844.0
        ZStack {
            // the mood screen shows through during beat/after; night fades in
            CeremonySkyView(night: frame.night,
                            glowCenter: CGPoint(x: frame.x, y: frame.y + 34),
                            glowAlpha: frame.glowAlpha,
                            glowRadius: frame.glowRadius,
                            jarGlow: frame.jarGlow,
                            reduceMotion: reduceMotion)
                .opacity(machine.phase == .beat ? 0 : 1)
                .animation(.easeInOut(duration: reduceMotion ? 0.8 : 0.3), value: machine.phase)

            // beat: the pause is the design — dim + one quiet word, nothing else
            if machine.phase == .beat {
                Color(hex: "#FAF6EC").opacity(0.45).ignoresSafeArea()
                Text(CeremonyStrings.loggedLine)
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(Color(hex: "#7A7266"))
                    .accessibilityAddTraits(.updatesFrequently)
            }

            // the lantern itself
            if frame.visible {
                LanternGlyphView(seed: abs(lantern.id.hashValue), width: 72 * sx)
                    .rotationEffect(.degrees(reduceMotion ? 0 : frame.rotationDegrees))
                    .scaleEffect(frame.scale)
                    .position(x: frame.x * sx, y: (frame.y + 34) * sy)
                    .animation(reduceMotion ? .easeInOut(duration: 0.8) : nil, value: machine.phase)
                    .accessibilityHidden(true)
            }

            // hover invitation
            if machine.phase == .hover {
                VStack(spacing: 8) {
                    Text(CeremonyStrings.hoverTitle)
                        .font(DinoTheme.dinoFont(size: 20))
                        .foregroundColor(Color(hex: "#FFF9E8"))
                    Text(CeremonyStrings.hoverSub)
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(Color(hex: "#FFF9E8").opacity(0.55))
                    Text(CeremonyStrings.tapToOpen)
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(Color(hex: "#FFF9E8"))
                        .padding(.horizontal, 26).padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "#FFF9E8").opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(hex: "#FFF9E8").opacity(0.22), lineWidth: 1))
                        )
                        .padding(.top, 12)
                }
                .position(x: size.width / 2, y: 500 * sy)
                .transition(.opacity)
            }

            // the message card (open)
            if machine.phase == .open {
                messageCard
                    .padding(.horizontal, 26)
                    .position(x: size.width / 2, y: 360 * sy)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1, anchor: .top).combined(with: .opacity),
                        removal: .opacity))

                Button { showReportConfirm = true } label: {
                    Text(CeremonyStrings.reportLink)
                        .font(DinoTheme.dinoFont(size: 12.5))
                        .foregroundColor(Color(hex: "#FFF9E8").opacity(0.32))
                        .underline()
                }
                .buttonStyle(.plain)
                .position(x: size.width / 2, y: size.height - 44)
                .accessibilitySortPriority(-1)
            }

            // jar (keep/kept/lift)
            if machine.phase == .keep || machine.phase == .kept || machine.phase == .lift {
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180 * sx)
                    .position(x: size.width / 2, y: 615 * sy)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            if machine.phase == .kept {
                Text(CeremonyStrings.keptCaption)
                    .font(DinoTheme.dinoFont(size: 18))
                    .foregroundColor(Color(hex: "#FFF9E8"))
                    .position(x: size.width / 2, y: 740 * sy)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: machine.phase)
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(CeremonyStrings.kicker(countryName: countryName))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "#A8A29A"))
            Text("\u{201C}\(lantern.text)\u{201D}")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .lineSpacing(6)
                .foregroundColor(Color(hex: "#3D3A35"))
                .padding(.top, 14)
            HStack(spacing: 10) {
                Text("🌍")
                Text(distanceLine)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#7A7266"))
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                DashedDivider().padding(.top, -8)
            }
            Button {
                machine.keepTapped()
                phaseStartedAt = Date()
                scheduleTimer()
            } label: {
                Text(CeremonyStrings.keepButton)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#7BA872")))
                    .shadow(color: Color(hex: "#7BA872").opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 26, leading: 26, bottom: 24, trailing: 26))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(hex: "#FEFBF3"))
            .shadow(color: Color(red: 10/255, green: 10/255, blue: 25/255).opacity(0.45), radius: 30, y: 24)
            .shadow(color: Color(red: 1, green: 196/255, blue: 120/255).opacity(0.14), radius: 30))
        .rotationEffect(.degrees(-0.8))
        .onTapGesture { /* the card absorbs taps — reading space */ }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
    }

    // MARK: - Advancement

    private func advanceByTap() {
        let before = machine.phase
        machine.tapped()
        guard machine.phase != before else {
            if machine.phase == .after { finish() }
            return
        }
        phaseStartedAt = Date()
        announcePhase()
        if machine.phase == .after { finish() } else { scheduleTimer() }
    }

    private func scheduleTimer() {
        timerTask?.cancel()
        guard let duration = LanternCeremonyMachine.timerDuration(for: machine.phase) else { return }
        timerTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            machine.timerFired()
            phaseStartedAt = Date()
            announcePhase()
            if machine.phase == .after { finish() } else { scheduleTimer() }
        }
    }

    private func announcePhase() {
        switch machine.phase {
        case .hush: UIAccessibility.post(notification: .announcement, argument: CeremonyStrings.voHush)
        case .drift: UIAccessibility.post(notification: .announcement, argument: CeremonyStrings.voDrift)
        default: break
        }
    }

    private func finish() {
        timerTask?.cancel()
        onFinished()
    }
}

private struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(Color(hex: "#3D3A35").opacity(0.16),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: 0.5))
            p.addLine(to: CGPoint(x: rect.width, y: 0.5))
            return p
        }
    }
}
