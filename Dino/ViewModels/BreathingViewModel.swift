//
//  BreathingViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import PostHog

enum BreathingPhase: String {
    case idle
    case inhale
    case hold
    case exhale
    case done

    var label: String {
        switch self {
        case .idle: return "ready"
        case .inhale: return "breathe in"
        case .hold: return "hold"
        case .exhale: return "breathe out"
        case .done: return "done"
        }
    }

    var liveActivityLabel: String {
        switch self {
        case .idle: return "Ready"
        case .inhale: return "Inhale"
        case .hold: return "Hold"
        case .exhale: return "Exhale"
        case .done: return "Done"
        }
    }
}

@MainActor
class BreathingViewModel: ObservableObject {
    @Published var phase: BreathingPhase = .idle
    @Published var circleScale: CGFloat = 0.6
    @Published var circleOpacity: Double = 0.6
    @Published var timeRemaining: Int = 0
    @Published var selectedDuration: Int = 120  // 2 min default
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var phaseCountdown: Int = 4
    @Published var totalElapsed: Int = 0
    @Published var currentCycle: Int = 1

    private var mainTimer: Timer?
    private var phaseTimer: Timer?

    let durationOptions: [(label: String, seconds: Int)] = [
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600)
    ]

    private let inhaleSeconds = 4
    private let holdSeconds = 4
    private let exhaleSeconds = 4

    var cycleLength: Int { inhaleSeconds + holdSeconds + exhaleSeconds }

    var totalCycles: Int { selectedDuration / cycleLength }

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    func start() {
        timeRemaining = selectedDuration
        totalElapsed = 0
        currentCycle = 1
        isPaused = false
        isRunning = true
        AnalyticsManager.shared.trackBreathingSessionStarted(
            duration: selectedDuration,
            pattern: "\(inhaleSeconds)-\(holdSeconds)-\(exhaleSeconds)"
        )
        startLiveActivity()
        beginCycle()
        startMainTimer()
    }

    func stop() {
        let elapsedAtStop = totalElapsed
        let wasRunning = isRunning
        let wasFinished = phase == .done
        mainTimer?.invalidate()
        phaseTimer?.invalidate()
        mainTimer = nil
        phaseTimer = nil
        isRunning = false
        isPaused = false
        phase = .idle
        circleScale = 0.6
        circleOpacity = 0.6
        phaseCountdown = 4
        endLiveActivity()
        if wasRunning && !wasFinished && elapsedAtStop > 0 {
            AnalyticsManager.shared.trackBreathingSessionAbandoned(atSecond: elapsedAtStop)
        }
    }

    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        mainTimer?.invalidate()
        phaseTimer?.invalidate()
        mainTimer = nil
        phaseTimer = nil
        updateLiveActivity()
    }

    func resume() {
        guard isRunning && isPaused else { return }
        isPaused = false
        startMainTimer()
        // Resume from current phase
        switch phase {
        case .inhale: startInhale(skipAnimation: true)
        case .hold:   startHold()
        case .exhale: startExhale(skipAnimation: true)
        default:      beginCycle()
        }
    }

    func reset() {
        stop()
        phase = .idle
        totalElapsed = 0
        currentCycle = 1
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

    private func beginCycle() {
        startInhale()
    }

    private func startInhale(skipAnimation: Bool = false) {
        phase = .inhale
        phaseCountdown = inhaleSeconds
        if !skipAnimation {
            withAnimation(.easeInOut(duration: Double(inhaleSeconds))) {
                circleScale = 1.1
                circleOpacity = 1.0
            }
        }
        startPhaseTimer(duration: inhaleSeconds) { [weak self] in
            self?.startHold()
        }
    }

    private func startHold() {
        phase = .hold
        phaseCountdown = holdSeconds
        startPhaseTimer(duration: holdSeconds) { [weak self] in
            self?.startExhale()
        }
    }

    private func startExhale(skipAnimation: Bool = false) {
        phase = .exhale
        phaseCountdown = exhaleSeconds
        if !skipAnimation {
            withAnimation(.easeInOut(duration: Double(exhaleSeconds))) {
                circleScale = 0.6
                circleOpacity = 0.6
            }
        }
        startPhaseTimer(duration: exhaleSeconds) { [weak self] in
            guard let self = self, self.isRunning, !self.isPaused else { return }
            self.currentCycle += 1
            self.beginCycle()
        }
    }

    private func startPhaseTimer(duration: Int, completion: @escaping () -> Void) {
        phaseTimer?.invalidate()
        phaseCountdown = duration
        let startTime = Date()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                guard !self.isPaused else { return }
                let elapsed = Int(Date().timeIntervalSince(startTime))
                self.phaseCountdown = max(0, duration - elapsed)
                if elapsed >= duration {
                    timer.invalidate()
                    completion()
                }
            }
        }
    }

    private func finish() {
        mainTimer?.invalidate()
        phaseTimer?.invalidate()
        mainTimer = nil
        phaseTimer = nil
        isRunning = false
        isPaused = false
        phase = .done
        withAnimation(.easeInOut(duration: 0.5)) {
            circleScale = 0.8
            circleOpacity = 0.8
        }
        endLiveActivity()
        let session = BreathingSession(
            durationSeconds: totalElapsed,
            type: "\(inhaleSeconds)-\(holdSeconds)-\(exhaleSeconds)"
        )
        dataManager.logBreathingSession(session)
        AnalyticsManager.shared.trackBreathingSessionCompleted(duration: totalElapsed)
        HapticManager.shared.success()
    }

    // MARK: - Live Activity Integration

    private func startLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.startBreathingActivity(
                sessionType: "4-4-4",
                totalDuration: selectedDuration,
                totalCycles: totalCycles
            )
        }
    }

    private func updateLiveActivity() {
        if #available(iOS 16.2, *) {
            let progress: Double
            if selectedDuration > 0 {
                progress = Double(phaseCountdown) / Double(currentPhaseDuration)
            } else {
                progress = 0
            }
            DinoLiveActivityManager.shared.updateBreathingActivity(
                phase: phase.liveActivityLabel,
                secondsRemaining: timeRemaining,
                currentCycle: currentCycle,
                totalCycles: totalCycles,
                progress: progress,
                isPaused: isPaused
            )
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.endBreathingActivity()
        }
    }

    private var currentPhaseDuration: Int {
        switch phase {
        case .inhale: return inhaleSeconds
        case .hold:   return holdSeconds
        case .exhale: return exhaleSeconds
        default:      return 4
        }
    }

    // MARK: - Formatting

    var formattedTimeRemaining: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var formattedElapsed: String {
        let mins = totalElapsed / 60
        let secs = totalElapsed % 60
        return String(format: "%d min %02d sec", mins, secs)
    }
}
