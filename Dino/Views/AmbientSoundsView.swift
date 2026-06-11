//
//  AmbientSoundsView.swift
//  Dino
//
//  Full-screen ambient sounds experience. The visual backdrop is the
//  Ambient3D world — an illustrated gradient forest background with a 3D
//  waterfall, lily pad and star companion (see Views/Ambient3D/). This
//  file keeps the UI overlays: close button, wave bars, the lily-pad tap
//  zone, and the forest-letter envelope flow.
//

import SwiftUI

// MARK: - Palette tokens (day / night) — UI overlay colors only

private struct AmbientPalette {
    let uiCream: Color
    let closeBg: Color
    let sage: Color

    static let day = AmbientPalette(
        uiCream: Color(hex: "#FFF7E8"),
        closeBg: Color(red: 255/255, green: 250/255, blue: 238/255),
        sage: Color(hex: "#A8C5A0")
    )

    static let night = AmbientPalette(
        uiCream: Color(hex: "#EAF1F6"),
        closeBg: Color(red: 228/255, green: 238/255, blue: 246/255),
        sage: Color(hex: "#A8C5A0")
    )
}

// MARK: - UI Overlay (label, close, wave bars)

private struct AmbientUIOverlay: View {
    let palette: AmbientPalette
    let isPlaying: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Top center label
            Text("ambient sounds")
                .font(DinoTheme.dinoFont(size: 13))
                .tracking(2)
                .foregroundColor(palette.uiCream.opacity(0.4))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 62)

            // Close button (top right)
            HStack {
                Spacer()
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(palette.closeBg.opacity(0.16))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.uiCream)
                    }
                }
                .padding(.trailing, 22)
                .padding(.top, 58)
            }

            // Wave equalizer bars (bottom center, only when playing)
            if isPlaying {
                WaveBars(color: palette.sage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 34)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
    }
}

private struct WaveBars: View {
    let color: Color
    private let bars: [(height: Double, delay: Double)] = [
        (12, -0.9), (26, -0.3), (16, -0.6), (22, -0.45), (14, -0.75)
    ]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<bars.count, id: \.self) { i in
                    let b = bars[i]
                    let phase = ((t + b.delay).truncatingRemainder(dividingBy: 1.5)) / 1.5
                    let s = 0.4 + 0.6 * (0.5 - 0.5 * cos(phase * 2 * .pi))
                    Capsule()
                        .fill(color)
                        .frame(width: 5, height: b.height)
                        .scaleEffect(y: s, anchor: .center)
                        .shadow(color: color.opacity(0.5), radius: 3, y: 1)
                }
            }
            .frame(height: 30)
        }
    }
}

// MARK: - Day-scene wrapper (backdrop for ForestLetterView)

/// Thin wrapper that always renders the daytime world — used by
/// `ForestLetterView` as a hauntingly dim background.
struct WaterfallDayScene: View {
    var body: some View {
        AmbientWorldView(isNight: false)
    }
}

// MARK: - ForestLetterView (aged-parchment airmail letter)

/// Full-screen letter shown before AmbientSoundsView. The waterfall scene
/// sits behind, dimmed and blurred. The letter itself is a parchment page
/// with airmail border, postage stamp, postmark, and a hand-drawn signature.
struct ForestLetterView: View {
    let onEnter: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed: Bool = false
    @State private var fadingOut: Bool = false

    var body: some View {
        ZStack {
            // Hauntingly dim, blurred waterfall in the background.
            // Audio is NOT started until "enter the forest" is tapped.
            ZStack {
                WaterfallDayScene()
                Color.black.opacity(0.35)
            }
            .blur(radius: 3)
            .ignoresSafeArea()

            // Letter + CTAs centered vertically.
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                LetterPaper()
                    .padding(.horizontal, 20)
                    .rotationEffect(.degrees(restRotation), anchor: .center)
                    .offset(y: yOffset)
                    .scaleEffect(scaleAmount)
                    .opacity(landed ? (fadingOut ? 0 : 1) : 0)

                Spacer(minLength: 12)

                // CTAs sit outside the letter, glowing softly against the dark scene.
                Button(action: enterForest) {
                    Text("enter the forest →")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(Color(hex: "#FEFBF3"))
                        .shadow(color: Color(hex: "#A8C5A0").opacity(0.6), radius: 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(fadingOut ? 0 : 1)

                Button(action: onDismiss) {
                    Text("maybe later")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .opacity(fadingOut ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .onAppear { startEntrance() }
    }

    // MARK: Entrance / exit

    private var restRotation: Double {
        if reduceMotion { return -1 }
        return landed ? -1 : -8
    }
    private var yOffset: Double {
        if reduceMotion { return 0 }
        return landed ? 0 : -60
    }
    private var scaleAmount: Double {
        if reduceMotion { return 1.0 }
        return landed ? 1.0 : 0.94
    }

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.4)
                    : .spring(response: 0.65, dampingFraction: 0.72)
            ) {
                landed = true
            }
        }
    }

    private func enterForest() {
        let audio = AudioManager.shared
        audio.setVolume(0.7)
        audio.play(track: "rain", playback: true)
        audio.fadeIn(duration: 2.0)

        withAnimation(.easeOut(duration: 0.4)) { fadingOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onEnter()
        }
    }
}

// MARK: - Letter paper (parchment + airmail border + stamp + postmark + content)

private struct LetterPaper: View {
    private let letterBody: String = """
find a quiet spot.
close your eyes.

you're standing at the edge of a still forest.
somewhere nearby, a waterfall breathes.

there is nothing to do here.
no goals. no rush. no noise.

just let the sounds find you.
breathe slowly.
stay as long as you like.

the forest will be here,
whenever you need it.
"""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Parchment background + subtle grain lines
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#FBF4E4"),
                        Color(hex: "#F5EDD8"),
                        Color(hex: "#EFE4CA")
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                Canvas { ctx, size in
                    for i in 0..<4 {
                        var p = Path()
                        let y = Double(i + 1) * size.height / 5.0
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y + 24))
                        ctx.stroke(p, with: .color(Color(hex: "#8B7355").opacity(0.03)), lineWidth: 0.5)
                    }
                }
            }

            // Letter content (header + body + footer + fold line)
            VStack(alignment: .leading, spacing: 0) {
                Text("dear friend,")
                    .font(DinoTheme.dinoFont(size: 15))
                    .italic()
                    .foregroundColor(Color(hex: "#6B5B3E"))
                    .padding(.top, 20)
                    .padding(.leading, 20)

                Text(letterBody)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(Color(hex: "#4A3520"))
                    .lineSpacing(7)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("with love,")
                        .font(DinoTheme.dinoFont(size: 15))
                        .italic()
                        .foregroundColor(Color(hex: "#6B5B3E"))
                    Text("the forest")
                        .font(DinoTheme.dinoFont(size: 18))
                        .foregroundColor(Color(hex: "#3D6B3A"))
                    ForestLeafShape()
                        .fill(Color(hex: "#A8C5A0"))
                        .frame(width: 12, height: 14)
                        .padding(.top, 2)
                }
                .padding(.leading, 20)
                .padding(.top, 18)

                Rectangle()
                    .fill(Color(hex: "#D4C4A0").opacity(0.6))
                    .frame(height: 0.5)
                    .padding(.top, 16)

                Color.clear.frame(height: 14)
            }
            .padding(.bottom, 4)

            // Airmail border sits over the parchment but BELOW the stamp.
            AirmailStripes(thickness: 8)
                .padding(6)
                .allowsHitTesting(false)

            // Postage stamp + postmark in top-right — drawn on top of the border.
            ZStack(alignment: .topTrailing) {
                PostageStamp()
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                PostmarkCircle()
                    .offset(x: -8, y: 30)
            }
        }
        .background(Color(hex: "#FBF4E4"))
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Airmail stripes

/// 45° alternating red/blue stripes filling a ring around the parent rect.
/// Uses Canvas + `.destinationOut` to punch the inner area transparent.
private struct AirmailStripes: View {
    let thickness: Double

    var body: some View {
        Canvas { ctx, size in
            let red  = Color(hex: "#E85444")
            let blue = Color(hex: "#4A7FC1")
            let stripeW: Double = 8
            let cycle: Double = 16   // red(8) + blue(8)
            let span = size.width + size.height

            var x: Double = -span
            while x < span {
                var r = Path()
                r.move(to: CGPoint(x: x, y: 0))
                r.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(r, with: .color(red), lineWidth: stripeW)
                var b = Path()
                b.move(to: CGPoint(x: x + 8, y: 0))
                b.addLine(to: CGPoint(x: x + 8 + size.height, y: size.height))
                ctx.stroke(b, with: .color(blue), lineWidth: stripeW)
                x += cycle
            }

            // Punch out the inner area so only the border ring remains visible.
            ctx.blendMode = .destinationOut
            let inner = CGRect(
                x: thickness,
                y: thickness,
                width: max(0, size.width  - 2 * thickness),
                height: max(0, size.height - 2 * thickness)
            )
            ctx.fill(Path(inner), with: .color(.black))
        }
    }
}

// MARK: - Postage stamp

private struct PostageStamp: View {
    var body: some View {
        ZStack {
            // Cream outer frame
            Rectangle()
                .fill(Color(hex: "#FEFBF3"))
                .frame(width: 56, height: 68)
            // Sage interior
            Rectangle()
                .fill(Color(hex: "#A8C5A0"))
                .frame(width: 52, height: 64)
            // Inner sage-deep hairline for the classic stamp look
            Rectangle()
                .stroke(Color(hex: "#7BA872"), lineWidth: 0.6)
                .frame(width: 46, height: 58)
            // Leaf + label
            VStack(spacing: 2) {
                ForestLeafShape()
                    .fill(Color.white)
                    .frame(width: 18, height: 22)
                Text("dino")
                    .font(DinoTheme.dinoFont(size: 8))
                    .foregroundColor(.white)
                    .tracking(0.6)
            }
            .offset(y: -2)
        }
        // Faint scalloped "perforation" suggestion via repeated white dots
        .overlay(PerforationDots(width: 56, height: 68))
        .rotationEffect(.degrees(4))
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

/// Small white circles arrayed around the edge to suggest postage perforations.
private struct PerforationDots: View {
    let width: Double
    let height: Double
    var body: some View {
        Canvas { ctx, size in
            let r: Double = 1.4
            let step: Double = 5.0
            func dot(_ x: Double, _ y: Double) {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(hex: "#FEFBF3"))
                )
            }
            // Top + bottom edges
            var x = step
            while x < size.width {
                dot(x, 0)
                dot(x, size.height)
                x += step
            }
            // Left + right edges
            var y = step
            while y < size.height {
                dot(0, y)
                dot(size.width, y)
                y += step
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Postmark

private struct PostmarkCircle: View {
    var body: some View {
        ZStack {
            // Outer dashed circle
            Circle()
                .stroke(
                    Color(hex: "#8B7355").opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
                .frame(width: 44, height: 44)

            // Two horizontal lines around the center text
            VStack(spacing: 1.5) {
                Rectangle()
                    .fill(Color(hex: "#8B7355").opacity(0.5))
                    .frame(width: 22, height: 0.5)
                Text("forest post")
                    .font(DinoTheme.dinoFont(size: 7))
                    .foregroundColor(Color(hex: "#8B7355").opacity(0.7))
                    .tracking(0.4)
                Rectangle()
                    .fill(Color(hex: "#8B7355").opacity(0.5))
                    .frame(width: 22, height: 0.5)
            }
        }
        .rotationEffect(.degrees(-12))
    }
}

// MARK: - Forest leaf shape (used by seal, footer signature, and stamp)

private struct ForestLeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let top = CGPoint(x: r.midX, y: r.minY)
        let bottom = CGPoint(x: r.midX, y: r.maxY)
        p.move(to: top)
        p.addQuadCurve(to: bottom, control: CGPoint(x: r.maxX, y: r.midY))
        p.addQuadCurve(to: top,    control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        p.move(to: top)
        p.addLine(to: bottom)
        return p
    }
}

// MARK: - AmbientSoundsView (composition root)

struct AmbientSoundsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var audio = AudioManager.shared
    @State private var isClosing: Bool = false
    @State private var letterOpen: Bool = false
    @State private var dailyLetter: ForestDailyLetter?
    @State private var letterLoading: Bool = false
    @State private var savedToJar: Bool = false
    @State private var lilyPadGlow: Bool = false
    @State private var lilyPadScreenPos: CGPoint? = nil

    private let isNight: Bool = {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 20 || h < 6
    }()
    private var palette: AmbientPalette { isNight ? .night : .day }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // LAYER 1: the 3D world.
                AmbientWorldView(
                    isNight: isNight,
                    onLilyPadPosition: { pos in
                        lilyPadScreenPos = pos
                    }
                )
                .ignoresSafeArea()

                // LAYER 2: lily-pad tap zone, sitting over the 3D pad.
                LilyPadTapZone(
                    glow: lilyPadGlow && !letterOpen,
                    reduceMotion: reduceMotion,
                    onTap: { openLetter() }
                )
                .position(
                    lilyPadScreenPos
                        ?? CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.7)
                )
                .opacity(letterOpen ? 0 : 1)

                AmbientUIOverlay(
                    palette: palette,
                    isPlaying: audio.isPlaying,
                    onClose: close
                )
                .ignoresSafeArea()
                .opacity(letterOpen ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: letterOpen)

                // Daily forest-letter overlay rendered on top of everything.
                if letterOpen {
                    ForestLetterOverlay(
                        letter: dailyLetter,
                        loading: letterLoading,
                        savedToJar: savedToJar,
                        reduceMotion: reduceMotion,
                        onSave: handleSaveToJar,
                        onClose: { closeLetter() }
                    )
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(isNight ? .dark : .light)
        .onAppear {
            // Keep the screen lit so the ambient scene runs uninterrupted.
            UIApplication.shared.isIdleTimerDisabled = true

            // Only start the track if it isn't already playing — e.g. when
            // the user came in via ForestLetterView, audio is already fading in.
            if !AudioManager.shared.isPlaying {
                AudioManager.shared.play(track: "rain", playback: true)
                AudioManager.shared.setVolume(0.7)
                AudioManager.shared.fadeIn(duration: 1.5)
            }

            AnalyticsManager.shared.trackScreenViewed("ambient_sounds")
            AnalyticsManager.shared.trackScreen("ambient_sounds")

            // Begin the lily-pad pulse after a 3s pause so the scene has
            // time to land before pointing at the tap target.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { lilyPadGlow = true }
            }

            // Preload today's letter so the overlay reads instantly. Skip if
            // we already have today's letter cached — SwiftUI fires .onAppear
            // every time the view comes back from a sheet / nav transition.
            if dailyLetter == nil {
                Task { await loadLetter() }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // Defensive: also reset the idle timer when the app loses active state.
        // Protects against a crash mid-session leaving the screen permanently lit.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Letter loading + tap handlers

    private func openLetter() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) {
            letterOpen = true
        }
        // Refresh in case it wasn't loaded yet on appear.
        if dailyLetter == nil { Task { await loadLetter() } }
    }

    private func closeLetter() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            letterOpen = false
        }
    }

    private func handleSaveToJar() {
        guard let letter = dailyLetter, !savedToJar else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        savedToJar = true
        Task { await ForestLetterService.shared.saveToGratitudeJar(letter) }
    }

    @MainActor
    private func loadLetter() async {
        letterLoading = true
        let letter = await ForestLetterService.shared.getTodaysLetter()
        dailyLetter = letter
        savedToJar = letter.savedToJar
        letterLoading = false
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        AudioManager.shared.fadeOut(duration: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioManager.shared.stop()
            dismiss()
        }
    }
}

// MARK: - Lily pad tap zone

private struct LilyPadTapZone: View {
    let glow: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            if glow {
                if reduceMotion {
                    Circle()
                        .fill(Color(hex: "#A8C5A0").opacity(0.3))
                        .frame(width: 80, height: 80)
                        .blur(radius: 6)
                } else {
                    TimelineView(.animation(minimumInterval: 1/30)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let phase = (t.truncatingRemainder(dividingBy: 2.0)) / 2.0
                        let f = 0.5 - 0.5 * cos(phase * 2 * .pi)
                        let scale = 1.0 + 0.08 * f
                        let op = 0.2 + 0.2 * f
                        Circle()
                            .fill(Color(hex: "#A8C5A0").opacity(op))
                            .frame(width: 80, height: 80)
                            .scaleEffect(scale)
                            .blur(radius: 6)
                    }
                }
            }
            Color.clear
                .frame(width: 80, height: 40)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        }
    }
}

// MARK: - Forest letter overlay (envelope opens to reveal letter)

private struct ForestLetterOverlay: View {
    let letter: ForestDailyLetter?
    let loading: Bool
    let savedToJar: Bool
    let reduceMotion: Bool
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var landed: Bool = false
    @State private var envelopeOpen: Bool = false
    @State private var letterEmerged: Bool = false
    @State private var dismissing: Bool = false
    @State private var animateLoading: Bool = false
    @State private var hintOpacity: Double = 0.3
    @State private var saveAppeared: Bool = false
    @State private var letterHeight: CGFloat = 240

    var body: some View {
        GeometryReader { geo in
            let envW: CGFloat = max(0, geo.size.width - 48)
            let envH: CGFloat = envW * 0.65
            let flapH: CGFloat = envH * 0.45
            let centerX: CGFloat = geo.size.width / 2
            let centerY: CGFloat = geo.size.height / 2
            let restRot: Double = landed ? -1 : (reduceMotion ? -1 : -8)
            let yEntry: CGFloat = landed ? 0 : (reduceMotion ? 0 : -400)
            let letterOffset: CGFloat = letterEmerged
                ? -(envH / 2 + letterHeight / 2 + 16)
                : 0

            ZStack {
                // Tap-to-dismiss backdrop
                Color.black.opacity(0.50)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }

                // Envelope cluster
                ZStack {
                    // LETTER (behind body — slides up out of the envelope)
                    LetterCard(
                        letter: letter,
                        loading: loading,
                        savedToJar: savedToJar,
                        animateLoading: animateLoading,
                        saveAppeared: saveAppeared,
                        width: envW,
                        onSave: onSave,
                        onClose: { close() }
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: LetterHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                    .offset(y: letterOffset)
                    .opacity(letterEmerged ? 1 : 0)

                    // ENVELOPE BODY
                    EnvelopeBody(width: envW, height: envH)
                        .onTapGesture { openEnvelope() }

                    // FLAP (with wax seal) — occupies top 45% of envelope,
                    // rotates -180° around its bottom edge (fold line) to open.
                    EnvelopeFlap(width: envW, height: flapH)
                        .frame(width: envW, height: flapH)
                        .position(x: envW / 2, y: flapH / 2)
                        .rotation3DEffect(
                            .degrees(envelopeOpen ? -180 : 0),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom,
                            perspective: 0.6
                        )
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.35)
                                : .easeInOut(duration: 0.5),
                            value: envelopeOpen
                        )
                        .onTapGesture { openEnvelope() }
                }
                .frame(width: envW, height: envH)
                .rotationEffect(.degrees(restRot))
                .position(x: centerX, y: centerY)
                .offset(y: yEntry)
                .opacity(landed ? 1 : 0)

                // "tap to open" hint below the envelope
                if !envelopeOpen && !dismissing {
                    Text("tap to open")
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(Color(hex: "#6B5B3E").opacity(hintOpacity))
                        .position(x: centerX, y: centerY + envH / 2 + 28)
                        .opacity(landed ? 1 : 0)
                }
            }
            .onPreferenceChange(LetterHeightKey.self) { h in
                if h > 0 { letterHeight = h }
            }
        }
        .onAppear { startEntrance() }
    }

    // MARK: Animation

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.4)
                    : .spring(response: 0.7, dampingFraction: 0.72)
            ) {
                landed = true
            }
        }
        if reduceMotion {
            hintOpacity = 0.55
        } else {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animateLoading = true
                hintOpacity = 0.8
            }
        }
    }

    private func openEnvelope() {
        guard !envelopeOpen, !dismissing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.35)
                : .spring(response: 0.6, dampingFraction: 0.7)
        ) {
            envelopeOpen = true
        }
        // Letter slides up after the flap finishes swinging open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard !dismissing else { return }
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.35)
                    : .spring(response: 0.6, dampingFraction: 0.75)
            ) {
                letterEmerged = true
            }
            // The "saved to jar" confirmation fades in next time the user taps save.
            if savedToJar {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    saveAppeared = true
                }
            }
        }
    }

    private func close() {
        guard !dismissing else { return }
        dismissing = true
        let wasOpen = envelopeOpen

        if wasOpen {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                letterEmerged = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard dismissing else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    envelopeOpen = false
                }
            }
        }

        let flyAwayDelay: Double = wasOpen ? 0.55 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + flyAwayDelay) {
            guard dismissing else { return }
            withAnimation(.easeIn(duration: 0.35)) {
                landed = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard dismissing else { return }
                onClose()
            }
        }
    }
}

// MARK: - Envelope components

private struct EnvelopeBody: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F5EDD8"),
                            Color(hex: "#EFE4CA")
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            // Two diagonal fold lines from bottom corners meeting at center bottom.
            Canvas { ctx, size in
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height))
                p.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2))
                p.move(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2))
                ctx.stroke(
                    p,
                    with: .color(Color(hex: "#C4A882").opacity(0.30)),
                    lineWidth: 1
                )
            }
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.20), radius: 16, x: 0, y: 8)
    }
}

private struct EnvelopeFlap: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            FlapTriangleShape()
                .fill(Color(hex: "#EDE0C4"))
                .frame(width: width, height: height)

            // Subtle crease along the fold line.
            Path { p in
                p.move(to: CGPoint(x: 0, y: height))
                p.addLine(to: CGPoint(x: width, y: height))
            }
            .stroke(Color(hex: "#C4A882").opacity(0.40), lineWidth: 0.5)
            .frame(width: width, height: height)

            // Wax seal centered on the flap.
            ZStack {
                Circle()
                    .fill(Color(hex: "#A8C5A0").opacity(0.20))
                    .frame(width: 64, height: 64)
                    .blur(radius: 12)
                Circle()
                    .fill(Color(hex: "#A8C5A0"))
                    .frame(width: 44, height: 44)
                VStack(spacing: 1) {
                    ForestLeafShape()
                        .fill(Color.white.opacity(0.70))
                        .frame(width: 12, height: 14)
                    Text("D")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(width: width, height: height)
        }
    }
}

private struct FlapTriangleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Wide base along the top of the envelope, point at the fold line
        // (bottom-center of the flap rect).
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Letter card (slides out of the envelope)

private struct LetterCard: View {
    let letter: ForestDailyLetter?
    let loading: Bool
    let savedToJar: Bool
    let animateLoading: Bool
    let saveAppeared: Bool
    let width: CGFloat
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Opened wax seal imprint (outline + faint leaf)
            ZStack {
                Circle()
                    .stroke(Color(hex: "#C4A882").opacity(0.30), lineWidth: 1)
                    .frame(width: 24, height: 24)
                ForestLeafShape()
                    .fill(Color(hex: "#C4A882").opacity(0.30))
                    .frame(width: 8, height: 10)
            }

            Text("a note from the forest")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#6B5B3E").opacity(0.65))
                .tracking(1.5)

            Rectangle()
                .fill(Color(hex: "#C4A882").opacity(0.40))
                .frame(height: 0.5)
                .padding(.horizontal, 60)

            if loading {
                Text("the forest is writing\u{2026}")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B5B3E").opacity(0.45))
                    .opacity(animateLoading ? 1.0 : 0.3)
            } else {
                Text(letter?.content ?? "")
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(Color(hex: "#3D2B1F"))
                    .lineSpacing(7)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Color(hex: "#C4A882").opacity(0.40))
                .frame(height: 0.5)
                .padding(.horizontal, 60)

            if !savedToJar && letter != nil && !loading {
                Button(action: onSave) {
                    Text("save to jar \u{1FAD9}")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundColor(Color(hex: "#3D6B3A"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if savedToJar {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#3D6B3A"))
                    Text("saved to your jar")
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(Color(hex: "#3D6B3A"))
                }
                .opacity(saveAppeared ? 1 : 0)
                .scaleEffect(saveAppeared ? 1 : 0.85)
            }

            Button(action: onClose) {
                Text("close")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(Color(hex: "#6B5B3E").opacity(0.40))
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: width)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#FBF4E4"),
                        Color(hex: "#F5EDD8")
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Subtle diagonal grain lines (3 strokes at 2% opacity)
                Canvas { ctx, size in
                    for i in 0..<3 {
                        let y0 = size.height * Double(i + 1) / 4.0
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y0))
                        p.addLine(to: CGPoint(x: size.width, y: y0 + 18))
                        ctx.stroke(
                            p,
                            with: .color(Color(hex: "#8B7355").opacity(0.02)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
        )
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        .rotationEffect(.degrees(-0.5))
    }
}

// MARK: - Preference key for measuring the letter card height

private struct LetterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
