//
//  BreathingCoachService.swift
//  Dino
//
//  The network half of the breathing coach. Called ONLY when free text is
//  present — chip-only input resolves locally with no API call. Every
//  response field is re-validated client-side, the call races a hard 4s
//  timeout, results are cached per day by a HASH of the normalized input
//  (raw feeling text never touches disk), and any failure falls back to the
//  deterministic local matcher — the user never sees an error.
//
//  Concern combination: final = clientNet OR serverNet OR modelConcern.
//  This service can only raise concern on top of what the server returns;
//  nothing here (cache included) can lower it.
//

import Foundation
import FirebaseFunctions

@MainActor
final class BreathingCoachService {
    static let shared = BreathingCoachService()
    private init() {}

    private let cacheKey = "dino.breathCoach.cache"
    private static let timeoutSeconds: Double = 4

    struct TimeoutError: Error {}

    func recommend(chips: [BreathingFeeling], text: String) async -> BreathingRecommendation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // detector #1: on-device, before any network — works fully offline
        let clientConcern = BreathingCrisisNet.isConcerning(trimmed)

        // chip-only → deterministic, free, instant
        guard !trimmed.isEmpty else {
            return BreathingCoach.localRecommendation(chips: chips, text: trimmed)
        }

        let dayKey = GardenLetterGate.dayKey(for: Date())
        let hash = BreathingCoach.cacheKeyHash(chips: chips, text: trimmed, dayKey: dayKey)
        if let cached = loadCached(hash: hash, dayKey: dayKey) {
            return cached.raisingConcern(clientConcern)
        }

        do {
            let result = try await withTimeout(Self.timeoutSeconds) {
                try await self.callFunction(chips: chips, text: String(trimmed.prefix(300)))
            }
            let rec = result.raisingConcern(clientConcern)
            saveCached(rec, hash: hash, dayKey: dayKey)
            return rec
        } catch {
            #if DEBUG
            print("🌿 breathing coach fell back: \(error)")
            #endif
            return BreathingCoach.localRecommendation(chips: chips, text: trimmed)
        }
    }

    // MARK: - Cloud call + client-side re-validation

    private func callFunction(chips: [BreathingFeeling], text: String) async throws -> BreathingRecommendation {
        let functions = Functions.functions(region: "us-central1")
        let callable = functions.httpsCallable("suggestBreathingSession")
        let result = try await callable.call([
            "feelings": chips.map(\.rawValue),
            "text": text,
            "userLocale": Locale.current.language.languageCode?.identifier ?? "en",
        ])
        guard let data = result.data as? [String: Any] else { throw TimeoutError() }

        // never trust the wire, even our own validated server
        let pattern = BreathingCoach.pattern(forCoachID: data["pattern"] as? String ?? "") ?? .bigSigh
        let minutes = BreathingCoach.clampMinutes(data["minutes"] as? Int ?? 5)
        var reason = (data["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if reason.isEmpty || reason.split(separator: " ").count > 14
            || reason.contains("-") || reason.contains("—") {
            reason = BreathingCoach.fallbackReason
        }
        let concern = data["concern"] as? Bool ?? false
        return BreathingRecommendation(patternID: pattern.id, minutes: minutes,
                                       reason: reason.lowercased(), concern: concern, fromAI: true)
    }

    private func withTimeout<T: Sendable>(_ seconds: Double,
                                          _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            guard let first = try await group.next() else { throw TimeoutError() }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Per-day cache (hash → result; no raw text, pruned daily)

    private struct CacheBox: Codable {
        let dayKey: String
        var entries: [String: BreathingRecommendation]
    }

    private func loadCached(hash: String, dayKey: String) -> BreathingRecommendation? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let box = try? JSONDecoder().decode(CacheBox.self, from: data),
              box.dayKey == dayKey else { return nil }
        return box.entries[hash]
    }

    private func saveCached(_ rec: BreathingRecommendation, hash: String, dayKey: String) {
        var box: CacheBox
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let existing = try? JSONDecoder().decode(CacheBox.self, from: data),
           existing.dayKey == dayKey {
            box = existing
        } else {
            box = CacheBox(dayKey: dayKey, entries: [:])   // new day → old entries pruned
        }
        box.entries[hash] = rec
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
