//
//  PresenceHeartbeat.swift
//  Dino
//
//  Rec delivery F2: the smallest viable "the app is open right now" signal.
//  While the app is active, one tiny presence doc gets a server-stamped
//  lastActiveAt roughly every 2 minutes; the delivery sweep reads it so a
//  rec announcement never lands mid-session (it backs off 15-30 min
//  instead). The same doc carries the IANA timezone — the same privacy
//  class as userLocale (a device setting, never a location reading) — so
//  quiet hours (21:30-08:30) are computed in the USER'S local time.
//
//  Privacy: two fields, ever — a timestamp and a zone id. No mood, no
//  usage detail, no screen names. firestore.rules rejects anything else.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
enum PresenceHeartbeat {

    static let intervalSeconds: TimeInterval = 120

    private static var timer: Timer?
    private static var lastWriteAt: Date?

    /// Pure throttle — unit tested. A beat writes only when the last write
    /// is at least a minute old (scene thrash never spams firestore).
    nonisolated static func shouldBeat(lastWriteAt: Date?, now: Date,
                                       minGap: TimeInterval = 60) -> Bool {
        guard let last = lastWriteAt else { return true }
        return now.timeIntervalSince(last) >= minGap
    }

    /// Scene became active: beat now, then keep beating while open.
    static func appBecameActive() {
        beat()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
            Task { @MainActor in beat() }
        }
    }

    /// Scene resigned: stop the timer. The last stamp ages out of the
    /// sweep's 3 minute session window on its own — no farewell write.
    static func appResignedActive() {
        timer?.invalidate()
        timer = nil
    }

    static func beat(now: Date = Date()) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard shouldBeat(lastWriteAt: lastWriteAt, now: now) else { return }
        lastWriteAt = now
        Firestore.firestore().collection("presence").document(uid).setData([
            "lastActiveAt": FieldValue.serverTimestamp(),
            "tz": TimeZone.current.identifier,
        ], merge: true) { _ in }   // silent — a missed beat is a quiet nothing
    }
}
