//
//  CrisisMarker.swift
//  Dino
//
//  LOCAL-ONLY marker of the last time a crisis surface was shown. Lives in
//  UserDefaults and NOWHERE else: never written to Firestore, never attached
//  to analytics events, never included in any network payload. Its only
//  consumer is the daily-nudge payload builder, which uses it to strip
//  body-context fields for a quiet week — the marker itself, and the fact
//  that it exists, never leave the device.
//

import Foundation

enum CrisisMarker {
    static let key = "dino.crisis.lastTriggeredDayKey"

    private static func formatter(_ calendar: Calendar) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    static func stamp(now: Date = Date(), calendar: Calendar = .current) {
        UserDefaults.standard.set(formatter(calendar).string(from: now), forKey: key)
    }

    static func lastTriggered(calendar: Calendar = .current) -> Date? {
        guard let s = UserDefaults.standard.string(forKey: key) else { return nil }
        return formatter(calendar).date(from: s)
    }
}
