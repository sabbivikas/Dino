//
//  BreathingViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import UIKit
import PostHog

enum BreathingPhase: String {
    case idle
    case inhale
    case hold
    case exhale
    case done

    init(kind: BreathStep.Kind) {
        switch kind {
        case .inhale: self = .inhale
        case .hold:   self = .hold
        case .exhale: self = .exhale
        }
    }

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
    @Published var phaseLabel: String = BreathingPhase.idle.label
    @Published var circleScale: CGFloat = 0.6
    @Published var circleOpacity: Double = 0.85
    @Published var timeRemaining: Int = 0
    @Published var selectedDuration: Int = 120  // 2 min default
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var phaseCountdown: Int = 4
    @Published var totalElapsed: Int = 0
    @Published var currentCycle: Int = 1
    @Published var stepIndex: Int = -1
    @Published var xpEarned: Int = 0

    @Published var selectedPattern: BreathingPattern {
        didSet {
            guard !isRunning else { return }
            phaseCountdown = selectedPattern.steps.first?.seconds ?? 4
            UserDefaults.standard.set(selectedPattern.id, forKey: Self.patternDefaultsKey)
        }
    }

    private static let patternDefaultsKey = "breathingSelectedPattern"

    private var mainTimer: Timer?
    private var phaseTimer: Timer?
    private var sessionStartDate: Date?
    private var pauseAccumulated: TimeInterval = 0
    private var lastPauseDate: Date?

    let durationOptions: [(label: String, seconds: Int)] = [
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600)
    ]

    var cycleLength: Int { selectedPattern.cycleLength }
    var totalCycles: Int { selectedPattern.totalCycles(for: selectedDuration) }
    /// Whole breaths only — the session always ends on a completed cycle.
    var plannedDuration: Int { selectedPattern.plannedDuration(for: selectedDuration) }

    var currentStep: BreathStep? {
        let steps = selectedPattern.steps
        guard stepIndex >= 0, stepIndex < steps.count else { return nil }
        return steps[stepIndex]
    }

    /// the big sigh's second inhale — the view gives it a lighter haptic tick
    var isTopUpStep: Bool {
        guard stepIndex > 0, let step = currentStep, step.kind == .inhale else { return false }
        return selectedPattern.steps[stepIndex - 1].kind == .inhale
    }

    /// steady square holds: the countdown ring fills one quarter per count
    var quarterRingProgress: Double? {
        guard isRunning, selectedPattern.quarterTickHolds,
              let step = currentStep, step.kind == .hold, step.seconds > 0 else { return nil }
        return Double(step.seconds - phaseCountdown) / Double(step.seconds)
    }

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
        let saved = UserDefaults.standard.string(forKey: Self.patternDefaultsKey)
        let pattern = BreathingPattern.library.first { $0.id == saved } ?? .steadySquare
        self.selectedPattern = pattern
        self.phaseCountdown = pattern.steps.first?.seconds ?? 4
    }

    func start() {
        timeRemaining = plannedDuration
        totalElapsed = 0
        currentCycle = 1
        stepIndex = -1
        xpEarned = 0
        isPaused = false
        isRunning = true
        sessionStartDate = Date()
        pauseAccumulated = 0
        lastPauseDate = nil
        AnalyticsManager.shared.trackBreathingSessionStarted(
            duration: selectedDuration,
            pattern: analyticsPattern
        )
        startLiveActivity()
        beginCycle()
        startMainTimer()
    }

    private var analyticsPattern: String {
        selectedPattern.id + ":" + selectedPattern.steps.map { String($0.seconds) }.joined(separator: "-")
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
        phaseLabel = BreathingPhase.idle.label
        stepIndex = -1
        BreathingHaptics.shared.stop()
        circleScale = 0.6
        circleOpacity = 0.85
        phaseCountdown = selectedPattern.steps.first?.seconds ?? 4
        endLiveActivity()
        if wasRunning && !wasFinished && elapsedAtStop > 0 {
            AnalyticsManager.shared.trackBreathingSessionAbandoned(atSecond: elapsedAtStop)
        }
    }

    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        lastPauseDate = Date()
        BreathingHaptics.shared.stopCurrent()
        mainTimer?.invalidate()
        phaseTimer?.invalidate()
        mainTimer = nil
        phaseTimer = nil
        updateLiveActivity()
    }

    func resume() {
        guard isRunning && isPaused else { return }
        if let pauseStart = lastPauseDate {
            pauseAccumulated += Date().timeIntervalSince(pauseStart)
        }
        lastPauseDate = nil
        isPaused = false
        startMainTimer()
        if let step = currentStep {
            // land the circle on this step's target without re-animating
            circleScale = step.targetScale
            circleOpacity = step.targetOpacity
            runStep(at: stepIndex, skipAnimation: true)
        } else {
            beginCycle()
        }
    }

    func reset() {
        stop()
        phase = .idle
        totalElapsed = 0
        currentCycle = 1
    }

    private func startMainTimer() {
        // Timestamp-based so the countdown stays accurate across scroll/gesture
        // tracking and backgrounding (especially on iPad multitasking).
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isPaused else { return }
                var rawElapsed = 0
                if let start = self.sessionStartDate {
                    let elapsed = Date().timeIntervalSince(start) - self.pauseAccumulated
                    rawElapsed = Int(elapsed)
                    self.totalElapsed = min(rawElapsed, self.plannedDuration)
                    self.timeRemaining = max(0, self.plannedDuration - self.totalElapsed)
                }
                self.updateLiveActivity()
                // Cycles complete the session; this only catches a stalled
                // phase chain (e.g. a long stretch in the background).
                if rawElapsed >= self.plannedDuration + self.cycleLength {
                    self.finish()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        mainTimer = timer
    }

    /// Recompute the countdown from the start timestamp — call on foreground resume.
    func recalculateFromTimestamp() {
        guard let start = sessionStartDate, isRunning, !isPaused else { return }
        let elapsed = Date().timeIntervalSince(start) - pauseAccumulated
        totalElapsed = min(Int(elapsed), plannedDuration)
        timeRemaining = max(0, plannedDuration - totalElapsed)
        updateLiveActivity()
        if Int(elapsed) >= plannedDuration {
            finish()
        }
    }

    private func beginCycle() {
        runStep(at: 0)
    }

    private func runStep(at index: Int, skipAnimation: Bool = false) {
        let steps = selectedPattern.steps
        if index >= steps.count {
            // cycle complete
            if currentCycle >= totalCycles {
                finish()
                return
            }
            currentCycle += 1
            runStep(at: 0)
            return
        }
        let step = steps[index]
        stepIndex = index
        phase = BreathingPhase(kind: step.kind)
        phaseLabel = step.label
        phaseCountdown = step.seconds

        // The breath you can feel — same transition that drives the circle,
        // so the tide can never drift from the animation.
        BreathingHaptics.shared.play(phase: phase, duration: Double(step.seconds))

        if step.kind == .hold {
            if selectedPattern.shimmersOnHold && !skipAnimation && !UIAccessibility.isReduceMotionEnabled {
                // the hold never freezes — light pulses gently behind closed eyes
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    circleOpacity = step.targetOpacity - 0.05
                }
            }
        } else if !skipAnimation {
            withAnimation(step.curve.animation(seconds: step.seconds)) {
                circleScale = step.targetScale
                circleOpacity = step.targetOpacity
            }
        }

        startPhaseTimer(duration: step.seconds) { [weak self] in
            guard let self = self, self.isRunning, !self.isPaused else { return }
            self.runStep(at: index + 1)
        }
    }

    private func startPhaseTimer(duration: Int, completion: @escaping () -> Void) {
        phaseTimer?.invalidate()
        phaseCountdown = duration
        let startTime = Date()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
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
        RunLoop.main.add(timer, forMode: .common)
        phaseTimer = timer
    }

    private func finish() {
        guard phase != .done else { return }
        mainTimer?.invalidate()
        phaseTimer?.invalidate()
        mainTimer = nil
        phaseTimer = nil
        isRunning = false
        isPaused = false
        phase = .done
        phaseLabel = BreathingPhase.done.label
        BreathingHaptics.shared.stop()
        withAnimation(.easeInOut(duration: 0.5)) {
            circleScale = 0.8
            circleOpacity = 0.9
        }
        endLiveActivity()
        let session = BreathingSession(
            durationSeconds: totalElapsed,
            type: selectedPattern.id
        )
        xpEarned = dataManager.logBreathingSession(session)
        AnalyticsManager.shared.trackBreathingSessionCompleted(
            duration: totalElapsed,
            pattern: analyticsPattern
        )
        HapticManager.shared.success()
    }

    // MARK: - Live Activity Integration

    private func startLiveActivity() {
        if #available(iOS 16.2, *) {
            DinoLiveActivityManager.shared.startBreathingActivity(
                sessionType: selectedPattern.name,
                totalDuration: plannedDuration,
                totalCycles: totalCycles
            )
        }
    }

    private func updateLiveActivity() {
        if #available(iOS 16.2, *) {
            let stepSeconds = currentStep?.seconds ?? 4
            let progress: Double
            if stepSeconds > 0 {
                progress = Double(phaseCountdown) / Double(stepSeconds)
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
