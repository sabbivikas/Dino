import Combine
//
//  FocusView.swift
//  Dino
//
//  Focus / Pomodoro timer with Live Activity integration.
//

import SwiftUI

struct FocusView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: FocusViewModel = FocusViewModel(dataManager: SharedDataManager.shared)
    @StateObject private var audio = AudioManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DinoTheme.background.ignoresSafeArea()

                if viewModel.isDone {
                    FocusDoneScreen(viewModel: viewModel, onDismiss: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 6) {
                            Text("focus")
                                .font(DinoTheme.dinoDisplayFont(size: 28))
                                .foregroundColor(DinoTheme.textPrimary)
                            Text(viewModel.isRunning ? viewModel.currentMessage : "single-task. breathe. flow.")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary)
                                .animation(.easeInOut, value: viewModel.currentMessage)
                        }
                        .padding(.top, 16)

                        // Progress ring
                        FocusProgressRing(
                            progress: viewModel.sessionProgress,
                            timeText: viewModel.formattedTimeRemaining,
                            isPaused: viewModel.isPaused,
                            isRunning: viewModel.isRunning
                        )

                        // Duration selector (before start)
                        if !viewModel.isRunning {
                            VStack(spacing: 12) {
                                Text("session length")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)

                                HStack(spacing: 10) {
                                    ForEach(viewModel.durationOptions, id: \.seconds) { option in
                                        Button(action: {
                                            viewModel.selectedDuration = option.seconds
                                        }) {
                                            Text(option.label)
                                                .font(DinoTheme.captionFont())
                                                .fontWeight(.semibold)
                                                .foregroundColor(viewModel.selectedDuration == option.seconds ? .white : DinoTheme.textPrimary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    viewModel.selectedDuration == option.seconds
                                                        ? DinoTheme.skyBlue
                                                        : DinoTheme.cardBackground
                                                )
                                                .cornerRadius(DinoTheme.cornerRadius)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                                        .stroke(
                                                            viewModel.selectedDuration == option.seconds
                                                                ? DinoTheme.skyBlue
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
                                Text(viewModel.isRunning ? "end session" : "start focus")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(viewModel.isRunning ? Color.red.opacity(0.7) : DinoTheme.skyBlue)
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
                                        .foregroundColor(DinoTheme.skyBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(DinoTheme.skyBlue.opacity(0.1))
                                        .cornerRadius(DinoTheme.largeCornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                                                .stroke(DinoTheme.skyBlue.opacity(0.4), lineWidth: 1.5)
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
                                .font(.system(size: 14))
                                .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .onDisappear {
            viewModel.stop()
            AudioManager.shared.stop()
        }
        .onChange(of: viewModel.isRunning) { running in
            if running {
                AudioManager.shared.play(track: "focus_ambient")
                AudioManager.shared.fadeIn(duration: 2.0)
            } else {
                AudioManager.shared.stop()
            }
        }
        .onChange(of: viewModel.isPaused) { paused in
            if paused {
                AudioManager.shared.pause()
            } else if viewModel.isRunning {
                AudioManager.shared.resume()
            }
        }
    }
}

// MARK: - Progress Ring

struct FocusProgressRing: View {
    let progress: Double
    let timeText: String
    let isPaused: Bool
    let isRunning: Bool

    private let skyBlue = DinoTheme.skyBlue
    private let ringSize: CGFloat = 220

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(skyBlue.opacity(0.15), lineWidth: 12)
                .frame(width: ringSize, height: ringSize)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    skyBlue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Center content
            VStack(spacing: 6) {
                if isRunning {
                    Text(isPaused ? "⏸" : "🎯")
                        .font(.system(size: 28))
                    Text(timeText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DinoTheme.textPrimary)
                        .monospacedDigit()
                } else {
                    Text("🎯")
                        .font(.system(size: 36))
                    Text("ready")
                        .font(DinoTheme.dinoFont(size: 20))
                        .foregroundColor(DinoTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Done Screen

struct FocusDoneScreen: View {
    @ObservedObject var viewModel: FocusViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🎯")
                .font(.system(size: 70))

            VStack(spacing: 10) {
                Text("session complete")
                    .font(DinoTheme.dinoDisplayFont(size: 28))
                    .foregroundColor(DinoTheme.textPrimary)

                Text("deep work done. take a breath.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }

            HStack(spacing: 20) {
                StatPill(label: "focused", value: viewModel.formattedElapsed, color: DinoTheme.skyBlue)
                StatPill(label: "xp earned", value: "+25", color: DinoTheme.peach)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: { viewModel.reset() }) {
                    Text("focus again")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(DinoTheme.skyBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.skyBlue.opacity(0.1))
                        .cornerRadius(DinoTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                .stroke(DinoTheme.skyBlue.opacity(0.4), lineWidth: 1.5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onDismiss) {
                    Text("done")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.skyBlue)
                        .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DinoTheme.padding)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - FocusViewModel

@MainActor
class FocusViewModel: ObservableObject {
    @Published var timeRemaining: Int = 1500
    @Published var selectedDuration: Int = 1500
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isDone: Bool = false
    @Published var totalElapsed: Int = 0
    @Published var currentMessage: String = "stay focused"

    private var mainTimer: Timer?
    private var messageTimer: Timer?
    private var messageIndex: Int = 0

    let durationOptions: [(label: String, seconds: Int)] = [
        ("15 min", 900),
        ("25 min", 1500),
        ("45 min", 2700),
        ("60 min", 3600)
    ]

    private let messages = DinoLiveActivityManager.focusMessages
    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
        self.timeRemaining = 1500
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
        currentMessage = messages.first ?? "stay focused"
        isPaused = false
        isDone = false
        isRunning = true
        startLiveActivity()
        startMainTimer()
        startMessageTimer()
    }

    func stop() {
        stopTimers()
        isRunning = false
        isPaused = false
        endLiveActivity()
    }

    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        stopTimers()
        updateLiveActivity()
    }

    func resume() {
        guard isRunning && isPaused else { return }
        isPaused = false
        startMainTimer()
        startMessageTimer()
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
                self.timeRemaining -= 1
                self.totalElapsed += 1
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
                withAnimation(.easeInOut(duration: 0.5)) {
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
        dataManager.logFocusSession(FocusSession(durationSeconds: totalElapsed, completed: true))
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.startFocusActivity(totalDuration: selectedDuration)
        }
    }

    private func updateLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.updateFocusActivity(
                secondsRemaining: timeRemaining,
                progress: sessionProgress,
                isPaused: isPaused,
                message: currentMessage
            )
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.endFocusActivity()
        }
    }
}
