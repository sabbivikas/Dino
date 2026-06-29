//
//  HealthService.swift
//  Dino
//
//  Read-only Apple Health access for last night's sleep. The ONLY Health data
//  read is sleepAnalysis; nothing is ever written, and nothing leaves the
//  device — sleep is used purely to contextualize the local UI and patterns.
//  Every entry point degrades gracefully when Health is unavailable or denied.
//

import Foundation
import Combine
import HealthKit

@MainActor
final class HealthService: ObservableObject {
    static let shared = HealthService()
    private init() {}

    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    /// Whether Health data is available on this device at all (false on iPad / unsupported).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Current read-authorization status for sleep. Note: for privacy, HealthKit
    /// reports `.sharingDenied` even when undetermined for read scopes in some
    /// cases — callers should treat this as a hint, not a guarantee of data.
    var sleepAuthStatus: HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: sleepType)
    }

    // MARK: - Permission

    /// Requests read access to sleepAnalysis. Returns true if the request
    /// completed without error (HealthKit never reveals read-grant for privacy,
    /// so this reflects "the user finished the sheet", not necessarily "granted").
    /// Returns false if Health is unavailable or the request throws.
    func requestSleepPermission() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
            return true
        } catch {
            #if DEBUG
            print("🛏️ health auth error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Read last night's sleep

    /// Reads sleep samples from yesterday 8pm → today 10am and aggregates all
    /// "asleep" stages into total hours. Returns nil if Health is unavailable,
    /// not authorized, or there's no sleep data in the window.
    func lastNightSleep(now: Date = Date(), calendar: Calendar = .current) async -> SleepData? {
        guard isAvailable else { return nil }

        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .hour, value: -4, to: today),  // yesterday 8pm
              let windowEnd = calendar.date(byAdding: .hour, value: 10, to: today)      // today 10am
        else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        // Keep only "asleep" stages (exclude inBed / awake) and merge overlapping
        // intervals so overlapping samples from multiple sources aren't double-counted.
        let asleep = samples.filter { Self.isAsleep($0.value) }
        guard !asleep.isEmpty else { return nil }

        let intervals = Self.mergeIntervals(asleep.map { ($0.startDate, $0.endDate) })
        let totalSeconds = intervals.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        guard totalSeconds > 0,
              let earliest = intervals.map({ $0.0 }).min(),
              let latest = intervals.map({ $0.1 }).max() else { return nil }

        return SleepData(durationHours: totalSeconds / 3600.0, startTime: earliest, endTime: latest)
    }

    /// True for any "asleep" category value across iOS versions (core, deep, REM,
    /// and the legacy unspecified `asleep`). Excludes inBed and awake.
    private static func isAsleep(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            switch value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                 HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                 HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                return true
            default:
                return false
            }
        } else {
            return value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    /// Merges overlapping/adjacent [start,end] intervals so total asleep time is
    /// not double-counted when multiple sources or stages overlap.
    private static func mergeIntervals(_ raw: [(Date, Date)]) -> [(Date, Date)] {
        let sorted = raw.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        guard var current = sorted.first else { return [] }
        var merged: [(Date, Date)] = []
        for iv in sorted.dropFirst() {
            if iv.0 <= current.1 {
                current.1 = max(current.1, iv.1)
            } else {
                merged.append(current)
                current = iv
            }
        }
        merged.append(current)
        return merged
    }

    // MARK: - SleepData

    struct SleepData {
        let durationHours: Double
        let startTime: Date
        let endTime: Date

        var isShort: Bool { durationHours < 6 }
        var isVeryShort: Bool { durationHours < 5 }

        /// "6h 30min" / "6h" format.
        var displayString: String {
            let hours = Int(durationHours)
            let mins = Int((durationHours - Double(hours)) * 60)
            return mins > 0 ? "\(hours)h \(mins)min" : "\(hours)h"
        }

        var dinoObservation: String {
            switch durationHours {
            case ..<5:
                return "that's a short night — be gentle with yourself today 🌿".localized
            case 5..<6:
                return "lighter sleep than usual — today might feel a little heavier".localized
            case 6..<7:
                return "decent rest last night 🌿".localized
            default:
                return "you slept well — good foundation for today 🌱".localized
            }
        }
    }
}
