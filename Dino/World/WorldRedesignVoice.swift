//
//  WorldRedesignVoice.swift
//  Dino
//
//  Strings for the world screen redesign (build 12): the number under the
//  globe reuses WorldConstellationVoice (past-day variants kept there); this
//  enum carries the new row-reveal, expander, and lantern-section copy.
//  Lowercase, zero dashes, voice-tested.
//

import SwiftUI

enum WorldRedesignVoice {

    // MARK: - The number, split so only the total wears the gold

    static func totalNumber(_ total: Int) -> String { "\(total)" }

    static func totalSuffix(total: Int, isToday: Bool) -> String {
        switch (total == 1, isToday) {
        case (true, true):   return String(localized: " feeling shared today")
        case (false, true):  return String(localized: " feelings shared today")
        case (true, false):  return String(localized: " feeling shared this day")
        case (false, false): return String(localized: " feelings shared this day")
        }
    }

    // MARK: - Country rows

    /// inline count that fades in on tap
    static func rowCount(_ n: Int, isToday: Bool) -> String {
        isToday ? String(localized: "\(n) tonight") : String(localized: "\(n) that day")
    }

    /// a11y row label always carries the count, revealed or not
    static func rowAccessibility(country: String, count: Int, isToday: Bool) -> String {
        "\(country), \(rowCount(count, isToday: isToday))"
    }

    static let expanderCollapsed = String(localized: "and a few from elsewhere")
    static let expanderExpanded = String(localized: "the quieter lights")

    // MARK: - Lanterns

    static let lanternHeader = String(localized: "your lanterns")
    static let lanternSubline = String(localized: "kindness that drifted to you from around the world")
    static func seeAll(_ total: Int) -> String { String(localized: "see all \(total) \u{203A}") }

    /// "{country} · {date}" — the card's quiet footer
    static func cardMeta(country: String, date: String) -> String { "\(country) \u{00B7} \(date)" }

    // MARK: - The gallery screen

    static let galleryHeader = String(localized: "your lanterns")

    static func gallerySubline(total: Int, countries: Int) -> String {
        let kept = total == 1 ? String(localized: "1 kindness kept") : String(localized: "\(total) kindnesses kept")
        let from = countries == 1 ? String(localized: "from 1 country") : String(localized: "from \(countries) countries")
        return "\(kept), \(from)"
    }

    static var allFixedStrings: [String] {
        [totalSuffix(total: 1, isToday: true), totalSuffix(total: 7, isToday: true),
         totalSuffix(total: 1, isToday: false), totalSuffix(total: 7, isToday: false),
         rowCount(1, isToday: true), rowCount(9, isToday: false),
         expanderCollapsed, expanderExpanded,
         lanternHeader, lanternSubline, seeAll(9),
         cardMeta(country: "japan", date: "jul 12"),
         galleryHeader,
         gallerySubline(total: 1, countries: 1), gallerySubline(total: 9, countries: 4)]
    }
}
