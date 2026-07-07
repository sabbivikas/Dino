//
//  HealthService.swift
//  Dino
//
//  Read-only Apple Health access. The ONLY Health data read is sleepAnalysis
//  and stepCount; nothing is ever written, and nothing leaves the device —
//  both are used purely to contextualize the local UI and patterns (raw step
//  values are never logged to analytics or sent anywhere).
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
    private let stepsType = HKQuantityType(.stepCount)

    /// Whether Health data is available on this device at all (false on iPad / unsupported).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether we've ever completed a sleep authorization request. HealthKit
    /// never reveals read grants (and `authorizationStatus(for:)` only reports
    /// WRITE status — permanently `.sharingDenied` for a read-only app), so
    /// "have we asked" is tracked here and "do we have data" is probed by
    /// actually reading. Those two are the only honest signals available.
    private static let sleepRequestedKey = "dino.health.sleepRequested"
    var hasRequestedSleep: Bool {
        UserDefaults.standard.bool(forKey: Self.sleepRequestedKey)
    }

    /// Steps has its OWN ask-flag — never inferred from sleep's grant. An
    /// existing user who connected sleep in an earlier version has never been
    /// asked about steps, and these two facts must stay independent.
    private static let stepsRequestedKey = "dino.health.stepsRequested"
    var hasRequestedSteps: Bool {
        UserDefaults.standard.bool(forKey: Self.stepsRequestedKey)
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
            UserDefaults.standard.set(true, forKey: Self.sleepRequestedKey)
            return true
        } catch {
            #if DEBUG
            print("🛏️ health auth error: \(error)")
            #endif
            return false
        }
    }

    /// Requests read access to stepCount alone — the in-place ask for existing
    /// users who already went through the sleep flow.
    func requestStepsPermission() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [stepsType])
            UserDefaults.standard.set(true, forKey: Self.stepsRequestedKey)
            return true
        } catch {
            #if DEBUG
            print("👣 health auth error: \(error)")
            #endif
            return false
        }
    }

    /// Requests sleep + steps in a single sheet — the fresh-install ask
    /// (onboarding and the profile connect row).
    func requestHealthPermissions() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType, stepsType])
            UserDefaults.standard.set(true, forKey: Self.sleepRequestedKey)
            UserDefaults.standard.set(true, forKey: Self.stepsRequestedKey)
            return true
        } catch {
            #if DEBUG
            print("🌿 health auth error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Read daily steps

    /// Daily step totals for the trailing `days` local days, oldest → newest,
    /// with today as the LAST element (partial, midnight → now). Returns nil
    /// when Health is unavailable or the whole window is empty — a denied read
    /// and no-data are indistinguishable by design, and both mean stay quiet.
    func dailyStepTotals(days: Int = 30,
                         now: Date = Date(),
                         calendar: Calendar = .current) async -> [(date: Date, steps: Double)]? {
        guard isAvailable, days > 0 else { return nil }
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: now, options: .strictStartDate)
        var dayInterval = DateComponents()
        dayInterval.day = 1

        let totals: [(Date, Double)] = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: todayStart,
                intervalComponents: dayInterval
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [(Date, Double)] = []
                results?.enumerateStatistics(from: windowStart, to: now) { stats, _ in
                    out.append((stats.startDate, stats.sumQuantity()?.doubleValue(for: .count()) ?? 0))
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }

        // Probe: readable data is the only proof of a granted read scope.
        guard totals.contains(where: { $0.1 > 0 }) else { return nil }
        return totals.map { (date: $0.0, steps: $0.1) }
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
