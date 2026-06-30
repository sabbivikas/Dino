//
//  IdentityLifecycle.swift
//  Dino
//
//  PostHog identity lifecycle for cold launch, foreground returns, late-auth
//  recovery, and logout. Swift/PostHog-iOS port of the cross-platform identity
//  spec. All dependencies are injected behind protocols so the logic is unit
//  testable without Firebase or a live PostHog instance.
//
//  PRIVACY: identify() only ever receives a Firebase UID as the distinct id and
//  a small, non-sensitive `safeProperties` dictionary. No journal, gratitude,
//  mood, or other wellness content is ever sent as a person property, and the
//  DEBUG logs below carry only high-level lifecycle messages — never tokens or
//  user content.
//

import Foundation
import FirebaseAuth
import PostHog

// MARK: - Seams (injectable for tests)

/// Schedules a one-shot timer; returns a cancel closure. Real impl uses the
/// main run loop; tests inject a controllable fake ("fake timers").
protocol IdentityScheduler {
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> () -> Void
}

/// The PostHog surface the lifecycle needs. Real impl forwards to PostHogSDK.
protocol IdentityClient {
    func identify(_ distinctId: String, properties: [String: Any])
    func capture(_ event: String, properties: [String: Any])
    func reset()
}

/// Resolves the currently-authenticated Firebase UID (or nil), timeout-safe.
@MainActor
protocol AuthUserResolving {
    func resolve() async -> String?
}

/// Subscribe to auth changes; the callback gets the UID (nil = signed out).
/// Returns an unsubscribe closure.
typealias AuthSubscribe = (@escaping (String?) -> Void) -> (() -> Void)

// MARK: - Real scheduler

final class MainRunLoopScheduler: IdentityScheduler {
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        return { item.cancel() }
    }
}

// MARK: - Timeout-safe auth resolver

/// Waits up to `timeout` for the first auth callback, then settles exactly once.
/// Proceeds with nil on timeout, clears the timer + listener on completion, and
/// is safe even if the subscription fires synchronously before it is assigned.
@MainActor
final class TimeoutAuthResolver: AuthUserResolving {
    private let subscribe: AuthSubscribe
    private let scheduler: IdentityScheduler
    private let timeout: TimeInterval
    private let log: (String) -> Void

    init(timeout: TimeInterval = 5,
         scheduler: IdentityScheduler,
         log: @escaping (String) -> Void = { _ in },
         subscribe: @escaping AuthSubscribe) {
        self.timeout = timeout
        self.scheduler = scheduler
        self.log = log
        self.subscribe = subscribe
    }

    /// Completion form — fully synchronous registration, used directly by tests.
    func resolve(completion: @escaping (String?) -> Void) {
        var settled = false
        var unsubscribe: (() -> Void)?
        var cancelTimeout: (() -> Void)?

        func finish(_ uid: String?) {
            if settled { return }
            settled = true
            cancelTimeout?()
            unsubscribe?()
            completion(uid)
        }

        cancelTimeout = scheduler.schedule(after: timeout) { [log] in
            log("Firebase timeout reached, proceeding anonymously")
            finish(nil)
        }

        unsubscribe = subscribe { uid in finish(uid) }
        // If the subscription fired synchronously before `unsubscribe` was
        // assigned, finish() already settled — tear the listener down now.
        if settled { unsubscribe?(); unsubscribe = nil }
    }

    func resolve() async -> String? {
        await withCheckedContinuation { continuation in
            resolve { continuation.resume(returning: $0) }
        }
    }
}

// MARK: - Identity lifecycle manager

@MainActor
final class IdentityLifecycleManager {
    enum OpenType: String {
        case coldStart = "cold_start"
        case foreground
    }

    private let client: IdentityClient
    private let resolver: AuthUserResolving
    private let lateSubscribe: AuthSubscribe
    private let log: (String) -> Void
    private let isFirstOpenProvider: () -> Bool

    private(set) var coldStartComplete = false
    private(set) var lateIdentityRecoveryComplete = false
    private var lateUnsubscribe: (() -> Void)?

    init(client: IdentityClient,
         resolver: AuthUserResolving,
         lateSubscribe: @escaping AuthSubscribe,
         isFirstOpenProvider: @escaping () -> Bool,
         log: @escaping (String) -> Void = { _ in }) {
        self.client = client
        self.resolver = resolver
        self.lateSubscribe = lateSubscribe
        self.isFirstOpenProvider = isFirstOpenProvider
        self.log = log
    }

    /// Non-sensitive person properties only. NEVER journal / gratitude / mood /
    /// private reflection content, and never the email as a distinct id.
    static func safeProperties() -> [String: Any] {
        ["platform": "iOS"]
    }

    /// Redacted UID indicator for DEBUG logs — shows only the last 4 chars so the
    /// console never carries the full Firebase UID.
    static func redactedUID(_ uid: String) -> String {
        let tail = uid.suffix(4)
        return tail.isEmpty ? "uid:****" : "uid:…\(tail)"
    }

    // MARK: Cold launch

    /// Runs once per process. Restores the Firebase session (timeout-safe),
    /// identifies with the UID when present, otherwise starts late recovery,
    /// then captures a single `app_opened` with open_type = cold_start.
    func handleColdStart() async {
        guard !coldStartComplete else {
            log("duplicate lifecycle call blocked (cold start)")
            return
        }
        coldStartComplete = true
        log("session restoration started")

        let uid = await resolver.resolve()
        if let uid, !uid.isEmpty {
            log("authenticated user found")
            log("identify called (\(Self.redactedUID(uid)))")
            client.identify(uid, properties: Self.safeProperties())
            log("PostHog identify completed")
        } else {
            log("no authenticated user found, starting late identity recovery")
            startLateIdentityRecovery()
        }

        client.capture("app_opened", properties: [
            "open_type": OpenType.coldStart.rawValue,
            "is_first_open": isFirstOpenProvider()
        ])
        log("app_opened captured: cold_start")
    }

    // MARK: Foreground return

    /// A foreground return (background → active). Captures one `app_opened` with
    /// open_type = foreground. Never fires before cold start has begun, and in
    /// SwiftUI `onChange(of: scenePhase)` does not fire for the initial active
    /// state at mount — so the cold-launch active is never misclassified here.
    func handleForegroundReturn() {
        guard coldStartComplete else { return }
        client.capture("app_opened", properties: ["open_type": OpenType.foreground.rawValue])
        log("app_opened captured: foreground")
    }

    // MARK: Late identity recovery

    /// Started only when cold start timed out or found no user. Listens for the
    /// Firebase session to become available, identifies exactly once with the
    /// UID (merging the earlier anonymous cold-start events into the identified
    /// person), then removes its listener. Never fires another `app_opened`.
    private func startLateIdentityRecovery() {
        guard !lateIdentityRecoveryComplete, lateUnsubscribe == nil else { return }
        log("late recovery listener started")
        lateUnsubscribe = lateSubscribe { [weak self] uid in
            guard let self else { return }
            guard let uid, !uid.isEmpty, !self.lateIdentityRecoveryComplete else { return }
            self.lateIdentityRecoveryComplete = true
            self.log("authenticated user recovered (\(Self.redactedUID(uid)))")
            self.client.identify(uid, properties: Self.safeProperties())
            self.log("identify completed (late recovery); no additional app_opened captured")
            self.lateUnsubscribe?()
            self.lateUnsubscribe = nil
        }
    }

    // MARK: Logout

    /// Captures `user_signed_out` while still identified, then resets PostHog so
    /// subsequent events route to a fresh anonymous distinct id. The caller
    /// clears the Firebase/local session afterward. reset() takes no argument
    /// (iOS SDK) so a second account on the device is not aliased to this one.
    func handleLogout(properties: [String: Any] = [:]) {
        client.capture("user_signed_out", properties: properties)
        log("user_signed_out captured")
        client.reset()
        log("PostHog reset completed")
    }
}

// MARK: - Production wiring

func identityLifecycleLog(_ message: String) {
    #if DEBUG
    print("[Identity] \(message)")
    #endif
}

/// Forwards to PostHogSDK, honoring the analytics opt-out for captures/identify.
struct PostHogIdentityClient: IdentityClient {
    func identify(_ distinctId: String, properties: [String: Any]) {
        guard AnalyticsManager.shared.isEnabled else { return }
        PostHogSDK.shared.identify(distinctId, userProperties: properties)
    }
    func capture(_ event: String, properties: [String: Any]) {
        guard AnalyticsManager.shared.isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }
    func reset() {
        PostHogSDK.shared.reset()
    }
}

extension IdentityLifecycleManager {
    /// Production singleton wired to Firebase auth + PostHog.
    static let shared: IdentityLifecycleManager = {
        let firebaseSubscribe: AuthSubscribe = { callback in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                callback(user?.uid)
            }
            return { Auth.auth().removeStateDidChangeListener(handle) }
        }
        let resolver = TimeoutAuthResolver(
            timeout: 5,
            scheduler: MainRunLoopScheduler(),
            log: identityLifecycleLog,
            subscribe: firebaseSubscribe
        )
        return IdentityLifecycleManager(
            client: PostHogIdentityClient(),
            resolver: resolver,
            lateSubscribe: firebaseSubscribe,
            isFirstOpenProvider: {
                let key = "dino.hasOpenedBefore"
                let isFirst = !UserDefaults.standard.bool(forKey: key)
                if isFirst { UserDefaults.standard.set(true, forKey: key) }
                return isFirst
            },
            log: identityLifecycleLog
        )
    }()
}
