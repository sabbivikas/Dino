import Combine
//
//  DinoLiveActivityManager.swift
//  Dino
//
//  Singleton manager that handles starting, updating, and ending Live Activities
//  for breathing, meditation, and focus sessions.
//

import ActivityKit
import Foundation

@MainActor
class DinoLiveActivityManager: ObservableObject {

    static let shared = DinoLiveActivityManager()

    // MARK: - Current Activities

    @Published var breathingActivity: Activity<BreathingActivityAttributes>?
    @Published var meditationActivity: Activity<MeditationActivityAttributes>?
    @Published var focusActivity: Activity<FocusActivityAttributes>?
    @Published var recParcelActivity: Activity<RecParcelActivityAttributes>?

    // MARK: - Message Banks

    static let calmingMessages: [String] = [
        String(localized: "breathe and let go"),
        String(localized: "you are at peace"),
        String(localized: "this moment is yours"),
        String(localized: "just be"),
        String(localized: "nothing to do, nowhere to go"),
        String(localized: "gentle awareness"),
        String(localized: "stillness within")
    ]

    static let focusMessages: [String] = [
        String(localized: "stay focused"),
        String(localized: "you're doing great"),
        String(localized: "one thing at a time"),
        String(localized: "deep work mode"),
        String(localized: "almost there"),
        String(localized: "keep going")
    ]

    private init() {}

    // MARK: - Availability Check

    @available(iOS 16.2, *)
    private var activitiesEnabled: Bool {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("[Dino] Activities enabled: \(enabled)")
        return enabled
    }

    // MARK: - Breathing

    @available(iOS 16.2, *)
    func startBreathingActivity(sessionType: String, totalDuration: Int, totalCycles: Int) {
        guard activitiesEnabled else { return }

        print("[Dino] Starting breathing Live Activity...")

        let attributes = BreathingActivityAttributes(
            sessionType: sessionType,
            totalDurationSeconds: totalDuration
        )

        let initialState = BreathingActivityAttributes.ContentState(
            phase: "Inhale",
            secondsRemaining: totalDuration,
            currentCycle: 1,
            totalCycles: totalCycles,
            progress: 0.0,
            isPaused: false
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            breathingActivity = activity
            #if DEBUG
            print("[Dino] Breathing Live Activity started: \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[Dino] Failed to start breathing Live Activity")
            #endif
        }
    }

    @available(iOS 16.2, *)
    func updateBreathingActivity(
        phase: String,
        secondsRemaining: Int,
        currentCycle: Int,
        totalCycles: Int,
        progress: Double,
        isPaused: Bool
    ) {
        guard let activity = breathingActivity else { return }

        print("[Dino] Updating breathing Live Activity — phase: \(phase), remaining: \(secondsRemaining)s")

        let state = BreathingActivityAttributes.ContentState(
            phase: phase,
            secondsRemaining: secondsRemaining,
            currentCycle: currentCycle,
            totalCycles: totalCycles,
            progress: progress,
            isPaused: isPaused
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    @available(iOS 16.2, *)
    func endBreathingActivity() {
        guard let activity = breathingActivity else { return }

        print("[Dino] Ending breathing Live Activity")

        Task {
            await activity.end(dismissalPolicy: .immediate)
            breathingActivity = nil
        }
    }

    // MARK: - Meditation

    @available(iOS 16.2, *)
    func startMeditationActivity(totalDuration: Int) {
        guard activitiesEnabled else { return }

        let attributes = MeditationActivityAttributes(totalDurationSeconds: totalDuration)

        let initialState = MeditationActivityAttributes.ContentState(
            secondsRemaining: totalDuration,
            calmMessage: DinoLiveActivityManager.calmingMessages.first ?? String(localized: "breathe and let go"),
            isPaused: false,
            progress: 0.0
        )

        print("[Dino] Starting meditation Live Activity...")

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            meditationActivity = activity
            #if DEBUG
            print("[Dino] Meditation Live Activity started: \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[Dino] Failed to start meditation Live Activity")
            #endif
        }
    }

    @available(iOS 16.2, *)
    func updateMeditationActivity(secondsRemaining: Int, message: String, progress: Double, isPaused: Bool) {
        guard let activity = meditationActivity else { return }

        print("[Dino] Updating meditation Live Activity — remaining: \(secondsRemaining)s")

        let state = MeditationActivityAttributes.ContentState(
            secondsRemaining: secondsRemaining,
            calmMessage: message,
            isPaused: isPaused,
            progress: progress
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    @available(iOS 16.2, *)
    func endMeditationActivity() {
        guard let activity = meditationActivity else { return }

        print("[Dino] Ending meditation Live Activity")

        Task {
            await activity.end(dismissalPolicy: .immediate)
            meditationActivity = nil
        }
    }

    // MARK: - Focus

    @available(iOS 16.2, *)
    func startFocusActivity(totalDuration: Int) {
        guard activitiesEnabled else { return }

        let attributes = FocusActivityAttributes(totalDurationSeconds: totalDuration)

        let initialState = FocusActivityAttributes.ContentState(
            secondsRemaining: totalDuration,
            progress: 0.0,
            isPaused: false,
            motivationMessage: DinoLiveActivityManager.focusMessages.first ?? String(localized: "stay focused")
        )

        print("[Dino] Starting focus Live Activity...")

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            focusActivity = activity
            #if DEBUG
            print("[Dino] Focus Live Activity started: \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[Dino] Failed to start focus Live Activity")
            #endif
        }
    }

    @available(iOS 16.2, *)
    func updateFocusActivity(secondsRemaining: Int, progress: Double, isPaused: Bool, message: String) {
        guard let activity = focusActivity else { return }

        print("[Dino] Updating focus Live Activity — remaining: \(secondsRemaining)s")

        let state = FocusActivityAttributes.ContentState(
            secondsRemaining: secondsRemaining,
            progress: progress,
            isPaused: isPaused,
            motivationMessage: message
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    @available(iOS 16.2, *)
    func endFocusActivity() {
        guard let activity = focusActivity else { return }

        print("[Dino] Ending focus Live Activity")

        Task {
            await activity.end(dismissalPolicy: .immediate)
            focusActivity = nil
        }
    }

    // MARK: - Rec Parcel (rec delivery F3)

    /// Raise the paper parcel for an announced delivery. Idempotent — one
    /// delivery gets at most one parcel — and never raised past the 6h life.
    /// staleDate marks the system's "this is old" point; the true end is the
    /// foreground sweep below or the reveal opening (client-side start is
    /// the honest limit without provisioned push-to-start — see F3 verdict).
    @available(iOS 16.2, *)
    func startRecParcelActivity(deliveryId: String, announcedAt: Date, now: Date = Date()) {
        guard activitiesEnabled else { return }
        guard !Activity<RecParcelActivityAttributes>.activities
            .contains(where: { $0.attributes.deliveryId == deliveryId }) else { return }
        let staleDate = announcedAt.addingTimeInterval(RecParcelActivityAttributes.lifetime)
        guard staleDate > now else { return }   // announced too long ago — stay quiet

        let attributes = RecParcelActivityAttributes(deliveryId: deliveryId, announcedAt: announcedAt)
        do {
            let content = ActivityContent(
                state: RecParcelActivityAttributes.ContentState(),
                staleDate: staleDate
            )
            let activity = try Activity.request(attributes: attributes, content: content)
            recParcelActivity = activity
            print("[Dino] Rec parcel Live Activity started: \(activity.id)")
        } catch {
            #if DEBUG
            print("[Dino] Failed to start rec parcel Live Activity: \(error)")
            #endif
        }
    }

    /// The parcel was opened (deep link landed) — every parcel ends now.
    @available(iOS 16.2, *)
    func endRecParcelActivities() {
        recParcelActivity = nil
        Task {
            for activity in Activity<RecParcelActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    /// 6h expiry — ActivityKit cannot end an activity while the app is
    /// closed, so each foreground pass ends any parcel past its life
    /// (between hour 6 and the next open, the system's staleDate dims it).
    @available(iOS 16.2, *)
    func sweepStaleRecParcels(now: Date = Date()) {
        Task {
            for activity in Activity<RecParcelActivityAttributes>.activities
            where activity.attributes.announcedAt.addingTimeInterval(RecParcelActivityAttributes.lifetime) <= now {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
