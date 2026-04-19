import Combine
//
//  MeditationView.swift
//  Dino
//
//  Calming meditation screen with Live Activity integration.
//

import SwiftUI

struct MeditationView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: MeditationViewModel = MeditationViewModel(dataManager: SharedDataManager.shared)
    @StateObject private var audio = AudioManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NatureSceneBackground()

                if viewModel.isDone {
                    MeditationDoneScreen(viewModel: viewModel, onDismiss: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 6) {
                            Text("meditate")
                                .font(DinoTheme.dinoDisplayFont(size: 28))
                                .foregroundColor(DinoTheme.textPrimary)
                            Text(viewModel.isRunning ? viewModel.currentMessage : "be still. be here.")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary)
                                .italic()
                                .animation(.easeInOut, value: viewModel.currentMessage)
                        }
                        .padding(.top, 16)

                        // Pulsing visual
                        MeditationPulseView(isRunning: viewModel.isRunning, isPaused: viewModel.isPaused)

                        // Timer (when running)
                        if viewModel.isRunning {
                            Text(viewModel.formattedTimeRemaining)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(DinoTheme.textPrimary)
                                .monospacedDigit()
                                .transition(.opacity)
                        }

                        // Sound indicator
                        if viewModel.isRunning {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.lavender)
                                Text("ambient sounds")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                            }
                        }

                        // Duration selector (before start)
                        if !viewModel.isRunning {
                            VStack(spacing: 12) {
                                Text("session length")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)

                                HStack(spacing: 8) {
                                    ForEach(viewModel.durationOptions, id: \.seconds) { option in
                                        Button(action: {
                                            viewModel.selectedDuration = option.seconds
                                        }) {
                                            Text(option.label)
                                                .font(DinoTheme.captionFont())
                                                .fontWeight(.semibold)
                                                .foregroundColor(viewModel.selectedDuration == option.seconds ? .white : DinoTheme.textPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    viewModel.selectedDuration == option.seconds
                                                        ? DinoTheme.lavender
                                                        : DinoTheme.cardBackground
                                                )
                                                .cornerRadius(DinoTheme.cornerRadius)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                                        .stroke(
                                                            viewModel.selectedDuration == option.seconds
                                                                ? DinoTheme.lavender
                                                                : DinoTheme.divider,
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Controls
                        VStack(spacing: 12) {
                            Button(action: {
                                withAnimation {
                                    if viewModel.isRunning {
                                        viewModel.stop()
                                    } else {
                                        viewModel.start()
                                    }
                                }
                            }) {
                                Text(viewModel.isRunning ? "end session" : "begin")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(viewModel.isRunning ? Color.red.opacity(0.7) : DinoTheme.lavender)
                                    .cornerRadius(DinoTheme.largeCornerRadius)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            if viewModel.isRunning {
                                Button(action: {
                                    withAnimation {
                                        if viewModel.isPaused {
                                            viewModel.resume()
                                        } else {
                                            viewModel.pause()
                                        }
                                    }
                                }) {
                                    Text(viewModel.isPaused ? "resume" : "pause")
                                        .font(DinoTheme.headlineFont())
                                        .foregroundColor(DinoTheme.lavender)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(DinoTheme.lavender.opacity(0.1))
                                        .cornerRadius(DinoTheme.largeCornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                                                .stroke(DinoTheme.lavender.opacity(0.4), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isRunning {
                        Button(action: {
                            if audio.isPlaying {
                                audio.pause()
                            } else {
                                audio.resume()
                            }
                        }) {
                            Image(systemName: audio.isPlaying ? "speaker.wave.2" : "speaker.slash")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("[Meditation] app going to background")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("[Meditation] app returned to foreground")
            if viewModel.isRunning {
                viewModel.recalculateFromTimestamp()
            }
        }
    }
}

// MARK: - Pulsing Visual

struct MeditationPulseView: View {
    let isRunning: Bool
    let isPaused: Bool

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Outer pulse rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(DinoTheme.lavender.opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                    .frame(width: 160 + CGFloat(i * 30), height: 160 + CGFloat(i * 30))
                    .scaleEffect(pulse && isRunning && !isPaused ? 1.15 : 1.0)
                    .animation(
                        isRunning && !isPaused
                            ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(Double(i) * 0.4)
                            : .default,
                        value: pulse
                    )
            }

            // Core circle
            Circle()
                .fill(DinoTheme.lavender.opacity(0.2))
                .frame(width: 140, height: 140)
                .scaleEffect(pulse && isRunning && !isPaused ? 1.08 : 1.0)
                .animation(
                    isRunning && !isPaused
                        ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            // Emoji
            Text(isPaused ? "⏸" : "🧘")
                .font(.system(size: isRunning ? 42 : 52))
                .animation(.easeInOut(duration: 0.3), value: isRunning)
        }
        .frame(height: 220)
        .onAppear {
            pulse = true
        }
        .onChange(of: isRunning) { running in
            pulse = running
        }
    }
}

// MARK: - Done Screen

struct MeditationDoneScreen: View {
    @ObservedObject var viewModel: MeditationViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🧘")
                .font(.system(size: 70))

            VStack(spacing: 10) {
                Text("well done")
                    .font(DinoTheme.dinoDisplayFont(size: 28))
                    .foregroundColor(DinoTheme.textPrimary)

                Text("stillness found.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .italic()
            }

            HStack(spacing: 20) {
                StatPill(label: "meditated", value: viewModel.formattedElapsed, color: DinoTheme.lavender)
                StatPill(label: "xp earned", value: "+20", color: DinoTheme.peach)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: { viewModel.reset() }) {
                    Text("meditate again")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(DinoTheme.lavender)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.lavender.opacity(0.1))
                        .cornerRadius(DinoTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                .stroke(DinoTheme.lavender.opacity(0.4), lineWidth: 1.5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onDismiss) {
                    Text("done")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.lavender)
                        .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DinoTheme.padding)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - MeditationViewModel

@MainActor
class MeditationViewModel: ObservableObject {
    @Published var timeRemaining: Int = 300
    @Published var selectedDuration: Int = 300
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isDone: Bool = false
    @Published var totalElapsed: Int = 0
    @Published var currentMessage: String = "breathe and let go"

    private var mainTimer: Timer?
    private var messageTimer: Timer?
    private var messageIndex: Int = 0
    private var trackIndex: Int = 0

    // Timestamp-based tracking for background accuracy
    private var sessionStartDate: Date?
    private var pauseAccumulated: TimeInterval = 0
    private var lastPauseDate: Date?

    private let meditationTracks = ["meditation_ambient", "meditation_ambient_2"]

    let durationOptions: [(label: String, seconds: Int)] = [
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
        ("20 min", 1200)
    ]

    private let messages = DinoLiveActivityManager.calmingMessages
    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    var sessionProgress: Double {
        guard selectedDuration > 0 else { return 0 }
        let elapsed = selectedDuration - timeRemaining
        return min(1.0, Double(elapsed) / Double(selectedDuration))
    }

    var formattedTimeRemaining: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedElapsed: String {
        let m = totalElapsed / 60
        let s = totalElapsed % 60
        return String(format: "%d min %02d sec", m, s)
    }

    func start() {
        timeRemaining = selectedDuration
        totalElapsed = 0
        messageIndex = 0
        currentMessage = messages.first ?? "breathe and let go"
        isPaused = false
        isDone = false
        isRunning = true
        sessionStartDate = Date()
        pauseAccumulated = 0
        lastPauseDate = nil
        print("[Meditation] session started — duration: \(selectedDuration)s")
        startLiveActivity()
        startMainTimer()
        startMessageTimer()
        let track = meditationTracks[trackIndex % meditationTracks.count]
        trackIndex += 1
        AudioManager.shared.play(track: track)
        AudioManager.shared.fadeIn(duration: 2.0)
        print("[Meditation] audio started: \(track)")
    }

    func stop() {
        stopTimers()
        isRunning = false
        isPaused = false
        sessionStartDate = nil
        endLiveActivity()
        AudioManager.shared.stop()
        print("[Meditation] session stopped")
    }

    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        lastPauseDate = Date()
        stopTimers()
        updateLiveActivity()
        AudioManager.shared.pause()
        print("[Meditation] session paused")
    }

    func resume() {
        guard isRunning && isPaused else { return }
        if let pauseStart = lastPauseDate {
            pauseAccumulated += Date().timeIntervalSince(pauseStart)
        }
        lastPauseDate = nil
        isPaused = false
        startMainTimer()
        startMessageTimer()
        AudioManager.shared.resume()
        print("[Meditation] session resumed")
    }

    /// Recalculate time from timestamps when returning from background
    func recalculateFromTimestamp() {
        guard let start = sessionStartDate, !isPaused else { return }
        let elapsed = Date().timeIntervalSince(start) - pauseAccumulated
        let elapsedInt = Int(elapsed)
        totalElapsed = min(elapsedInt, selectedDuration)
        timeRemaining = max(0, selectedDuration - elapsedInt)
        print("[Meditation] recalculated from timestamp — elapsed: \(elapsedInt)s, remaining: \(timeRemaining)s")
        updateLiveActivity()
        if timeRemaining <= 0 {
            finish()
        }
    }

    func reset() {
        stop()
        isDone = false
        timeRemaining = selectedDuration
        totalElapsed = 0
    }

    private func startMainTimer() {
        mainTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isPaused else { return }
                // Use timestamp-based calculation for accuracy
                if let start = self.sessionStartDate {
                    let elapsed = Date().timeIntervalSince(start) - self.pauseAccumulated
                    self.totalElapsed = min(Int(elapsed), self.selectedDuration)
                    self.timeRemaining = max(0, self.selectedDuration - self.totalElapsed)
                }
                self.updateLiveActivity()
                if self.timeRemaining <= 0 {
                    self.finish()
                }
            }
        }
    }

    private func startMessageTimer() {
        messageTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isPaused else { return }
                self.messageIndex = (self.messageIndex + 1) % self.messages.count
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.currentMessage = self.messages[self.messageIndex]
                }
            }
        }
    }

    private func stopTimers() {
        mainTimer?.invalidate()
        messageTimer?.invalidate()
        mainTimer = nil
        messageTimer = nil
    }

    private func finish() {
        stopTimers()
        isRunning = false
        isPaused = false
        isDone = true
        endLiveActivity()
        dataManager.logMeditationSession(MeditationSession(durationSeconds: totalElapsed, completed: true))
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.startMeditationActivity(totalDuration: selectedDuration)
        }
    }

    private func updateLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.updateMeditationActivity(
                secondsRemaining: timeRemaining,
                message: currentMessage,
                progress: sessionProgress,
                isPaused: isPaused
            )
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.endMeditationActivity()
        }
    }
}

// MARK: - Nature Scene Background

/// Illustrated forest/garden scene used as the meditation screen backdrop.
/// Built from SwiftUI shapes — no asset required. Sits behind the
/// meditation UI and is decorative only (no interaction).
struct NatureSceneBackground: View {
    // Color palette tuned for a soft, hand-drawn feel
    private let skyWhite       = Color(red: 1.00, green: 1.00, blue: 1.00)
    private let cloudGrey      = Color(red: 0.87, green: 0.88, blue: 0.90)
    private let trunkBrown     = Color(red: 0.56, green: 0.43, blue: 0.38)
    private let foliageGreen   = Color(red: 0.50, green: 0.74, blue: 0.50)
    private let bushGreen      = Color(red: 0.62, green: 0.84, blue: 0.50)
    private let windBlue       = Color(red: 0.62, green: 0.80, blue: 0.93)
    private let flowerColors: [Color] = [
        Color(red: 0.95, green: 0.40, blue: 0.45), // red
        Color(red: 1.00, green: 0.85, blue: 0.30), // yellow
        Color(red: 0.55, green: 0.75, blue: 0.95), // sky blue
        Color(red: 0.78, green: 0.55, blue: 0.88), // purple
        Color(red: 0.96, green: 0.62, blue: 0.72)  // pink
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                skyWhite

                // Clouds
                cloud(w: w * 0.55, h: h * 0.09)
                    .position(x: w * 0.25, y: h * 0.10)
                cloud(w: w * 0.42, h: h * 0.08)
                    .position(x: w * 0.82, y: h * 0.13)

                // Wind swirls — distributed in mid sky
                windSwirl()
                    .frame(width: 56, height: 12)
                    .position(x: w * 0.30, y: h * 0.22)
                windSwirl()
                    .frame(width: 62, height: 12)
                    .position(x: w * 0.58, y: h * 0.27)
                windSwirl()
                    .frame(width: 50, height: 12)
                    .position(x: w * 0.74, y: h * 0.20)
                windSwirl()
                    .frame(width: 60, height: 12)
                    .position(x: w * 0.42, y: h * 0.45)
                windSwirl()
                    .frame(width: 54, height: 12)
                    .position(x: w * 0.66, y: h * 0.50)

                // Trees
                tree(width: w * 0.34, height: h * 0.46)
                    .position(x: w * 0.10, y: h * 0.42)
                tree(width: w * 0.36, height: h * 0.50)
                    .position(x: w * 0.90, y: h * 0.38)

                // Bushes at bottom corners
                Ellipse()
                    .fill(bushGreen)
                    .frame(width: w * 0.55, height: h * 0.10)
                    .position(x: w * 0.16, y: h * 0.94)
                Ellipse()
                    .fill(bushGreen)
                    .frame(width: w * 0.55, height: h * 0.10)
                    .position(x: w * 0.84, y: h * 0.95)

                // Flowers scattered in the bushes
                flowerCluster(w: w, h: h)

                // Dino sitting peacefully — lower third, centered
                Image("DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.26)
                    .position(x: w * 0.50, y: h * 0.78)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func cloud(w: CGFloat, h: CGFloat) -> some View {
        Ellipse()
            .fill(cloudGrey)
            .frame(width: w, height: h)
    }

    private func windSwirl() -> some View {
        WindSwirlShape()
            .stroke(windBlue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func tree(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Trunk
            RoundedRectangle(cornerRadius: 8)
                .fill(trunkBrown)
                .frame(width: width * 0.18, height: height * 0.65)

            // Foliage crown
            Circle()
                .fill(foliageGreen)
                .frame(width: width, height: width)
                .offset(y: -height * 0.42)
        }
        .frame(width: width, height: height)
    }

    private func flowerCluster(w: CGFloat, h: CGFloat) -> some View {
        // Hand-placed positions matching the reference (left + right corners)
        let dots: [(x: CGFloat, y: CGFloat, color: Int, size: CGFloat)] = [
            (0.05, 0.91, 0, 9), (0.10, 0.93, 1, 8), (0.18, 0.92, 3, 9),
            (0.22, 0.95, 0, 8), (0.78, 0.93, 0, 9), (0.84, 0.91, 4, 8),
            (0.90, 0.94, 1, 9), (0.95, 0.92, 2, 8)
        ]
        return ZStack {
            ForEach(0..<dots.count, id: \.self) { i in
                let d = dots[i]
                Circle()
                    .fill(flowerColors[d.color % flowerColors.count])
                    .frame(width: d.size, height: d.size)
                    .position(x: w * d.x, y: h * d.y)
            }
        }
    }
}

/// A gentle tilde-like wave used to suggest wind/breath in the air.
struct WindSwirlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.15, y: rect.midY - rect.height * 0.5),
            control2: CGPoint(x: rect.width * 0.35, y: rect.midY + rect.height * 0.5)
        )
        p.addCurve(
            to: CGPoint(x: rect.width, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.65, y: rect.midY - rect.height * 0.5),
            control2: CGPoint(x: rect.width * 0.85, y: rect.midY + rect.height * 0.5)
        )
        return p
    }
}
