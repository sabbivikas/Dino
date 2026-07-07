//
//  WorldPulse.swift
//  Dino
//
//  Live pulse model + Firestore listener for DINO WORLD. Pulses are the
//  anonymous real-time blooms written by the onWorldMoodCreated trigger:
//  {countryCode (already privacy-folded server-side), mood, createdAt}.
//  The listener lives exactly as long as the globe is on screen — started
//  in makeUIView, removed in dismantleUIView, no leaks.
//

import Foundation
import FirebaseFirestore

struct WorldPulse: Equatable {
    let countryCode: String
    let mood: EmotionalWeather
    let createdAt: Date

    /// Pulses older than this never bloom, even if the TTL hasn't collected
    /// them yet.
    static let maxAge: TimeInterval = 5 * 60

    /// Pure parse — malformed docs are dropped, never crash.
    static func parse(_ data: [String: Any]) -> WorldPulse? {
        guard let moodRaw = data["mood"] as? String,
              let mood = EmotionalWeather(rawValue: moodRaw),
              let ts = data["createdAt"] as? Timestamp else { return nil }
        let country = (data["countryCode"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "elsewhere"
        return WorldPulse(countryCode: country, mood: mood, createdAt: ts.dateValue())
    }

    /// Pure expiry filter: only genuinely fresh pulses (and none from the
    /// future beyond small clock skew).
    static func fresh(_ pulses: [WorldPulse], now: Date = Date()) -> [WorldPulse] {
        pulses.filter {
            now.timeIntervalSince($0.createdAt) < maxAge
                && $0.createdAt.timeIntervalSince(now) < 60
        }
    }
}

@MainActor
final class WorldPulseListener {
    private(set) var registration: ListenerRegistration?
    var isActive: Bool { registration != nil }

    /// Starts listening for fresh pulses. Any previous registration is
    /// removed first — at most one live listener per instance.
    func start(onPulse: @escaping @MainActor (WorldPulse) -> Void) {
        stop()
        let cutoff = Timestamp(date: Date().addingTimeInterval(-WorldPulse.maxAge))
        registration = Firestore.firestore().collection("worldPulses")
            .whereField("createdAt", isGreaterThan: cutoff)
            .order(by: "createdAt")
            .limit(toLast: 50)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot, !snapshot.metadata.isFromCache else { return }
                let fresh = WorldPulse.fresh(
                    snapshot.documentChanges
                        .filter { $0.type == .added }
                        .compactMap { WorldPulse.parse($0.document.data()) }
                )
                guard !fresh.isEmpty else { return }
                Task { @MainActor in fresh.forEach(onPulse) }
            }
    }

    func stop() {
        registration?.remove()
        registration = nil
    }

    /// Test hook — lets unit tests verify the detach contract without a
    /// live Firestore.
    func attachForTesting(_ r: ListenerRegistration) {
        registration = r
    }
}
