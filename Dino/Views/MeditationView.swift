import Combine
import PostHog
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
                // Storybook scene background (sunny/rainy/night/snow)
                MeditationSceneBackground(scene: .current())
                    .ignoresSafeArea(.all)

                // Subtle dark overlay for text readability
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                if viewModel.isDone {
                    MeditationDoneScreen(viewModel: viewModel, onDismiss: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    GeometryReader { geo in
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 6) {
                            Text("meditate")
                                .font(DinoTheme.dinoDisplayFont(size: 28))
                                .foregroundColor(.white)
                            Text(viewModel.isRunning ? viewModel.currentMessage : "be still. be here.")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(.white.opacity(0.8))
                                .italic()
                                .animation(.easeInOut, value: viewModel.currentMessage)
                        }
                        .padding(.top, 16)

                        Spacer()

                        // Timer display
                        if viewModel.isRunning {
                            Text(viewModel.formattedTimeRemaining)
                                .font(.custom(DinoTheme.customFontName, size: 36))
                                .foregroundColor(.white)
                                .transition(.opacity)
                        }

                        // Sound indicator
                        if viewModel.isRunning {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(.white.opacity(0.7))
                                Text("ambient sounds")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }

                        // Duration selector (before start)
                        if !viewModel.isRunning {
                            VStack(spacing: 12) {
                                Text("session length")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(.white.opacity(0.7))

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
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
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
        AnalyticsManager.shared.trackMeditationSessionStarted(scene: "default", duration: selectedDuration)
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
        let elapsedAtStop = totalElapsed
        stopTimers()
        isRunning = false
        isPaused = false
        sessionStartDate = nil
        endLiveActivity()
        AudioManager.shared.stop()
        if elapsedAtStop > 0 {
            AnalyticsManager.shared.trackMeditationSessionAbandoned(atSecond: elapsedAtStop)
        }
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
        AnalyticsManager.shared.trackMeditationSessionCompleted(duration: totalElapsed)
        HapticManager.shared.success()
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
