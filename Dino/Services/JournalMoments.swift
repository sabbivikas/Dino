//
//  JournalMoments.swift
//  Dino
//
//  Pure logic + copy for journaling suggestions (Apple's private picker).
//  No JournalingSuggestions import here — everything is testable on any OS.
//
//  PRIVACY: nothing from the picker is logged, synced, or sent anywhere.
//  Suggestion content never enters analytics, not even the moment's type.
//  The entry it seeds is a normal journal entry.
//

import Foundation

/// A framework-free description of the one moment the user picked — just the
/// strings the seed line needs, nothing else retained.
enum MomentKind: Equatable {
    case location(place: String?, daypart: String?)
    case locationGroup(firstPlace: String?)
    case workout(activity: String?)
    case motion
    case song(title: String?)
    case podcast(show: String?)
    case contact(name: String)
    case genericMedia
}

enum JournalMoments {

    // MARK: - Copy (owner-approved 2026-07-09; lowercase, no dashes)

    static let inviteLine = String(localized: "want to write about your day?")   // short: the row is single-line
    static let inviteAction = String(localized: "show me")

    static let consentTitle = String(localized: "moments from your day")
    static let consentBody = String(localized: "your iphone can gather little moments privately. a photo you took, a place you visited, a song you played. your iphone shows them only to you first. dino sees just the one moment you choose to write about, and only then. nothing is shared or sent anywhere.")
    static let consentPrimary = String(localized: "show my moments")
    static let consentSecondary = String(localized: "maybe later")

    // MARK: - Storage keys

    static let dismissedDayKeyKey = "dino.journal.momentsDismissedDayKey"
    static let consentSeenKey = "dino.journal.momentsConsentSeen"

    // MARK: - Invitation gate (pure)

    /// The invitation exists ONLY in the empty composer, at most once per
    /// composer session, not after a same-day dismissal, and never below
    /// iOS 17.2 (availability arrives as an input so this stays testable).
    static func shouldInvite(composerEmpty: Bool,
                             dismissedDayKey: String?,
                             todayKey: String,
                             shownThisSession: Bool,
                             available: Bool) -> Bool {
        available
            && composerEmpty
            && !shownThisSession
            && dismissedDayKey != todayKey
    }

    // MARK: - Seed lines (ONE line max, never more; the cursor is theirs)

    /// morning 5–11, afternoon 12–17, evening 18–22, else nil (→ "today").
    static func daypart(hour: Int) -> String? {
        switch hour {
        case 5..<12:  return String(localized: "morning")
        case 12..<18: return String(localized: "afternoon")
        case 18..<23: return String(localized: "evening")
        default:      return nil
        }
    }

    static func seedLine(for kind: MomentKind) -> String {
        switch kind {
        case .location(let place, let daypart):
            guard let place, !place.isEmpty else { return String(localized: "somewhere that held today 🌿") }
            if let daypart { return String(localized: "\(place.lowercased()), this \(daypart) 🌿") }
            return String(localized: "\(place.lowercased()), today 🌿")
        case .locationGroup(let firstPlace):
            guard let firstPlace, !firstPlace.isEmpty else { return String(localized: "somewhere that held today 🌿") }
            return String(localized: "\(firstPlace.lowercased()), and a little wandering 🌿")
        case .workout(let activity):
            guard let activity, !activity.isEmpty else { return String(localized: "my body did something good today 🌿") }
            return String(localized: "my body did some \(activity.lowercased()) today 🌿")
        case .motion:
            return String(localized: "today had a walk in it 🌿")
        case .song(let title):
            guard let title, !title.isEmpty else { return String(localized: "music carried a bit of today 🎧") }
            return String(localized: "\(title.lowercased()) has been in my ears today 🎧")
        case .podcast(let show):
            guard let show, !show.isEmpty else { return String(localized: "a voice kept me company today 🎧") }
            return String(localized: "listened to \(show.lowercased()) today 🎧")
        case .contact(let name):
            // neutral by owner decision: time with a person isn't always warm;
            // the writer brings the feeling
            return String(localized: "time with \(name.lowercased()) today")
        case .genericMedia:
            return String(localized: "something i watched stayed with me today")
        }
    }

    // MARK: - Day-key store (UserDefaults — kept out of the pure logic above)

    static func todayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: now)
    }

    @MainActor
    static func markDismissedToday() {
        UserDefaults.standard.set(todayKey(), forKey: dismissedDayKeyKey)
    }

    @MainActor
    static var consentSeen: Bool {
        get { UserDefaults.standard.bool(forKey: consentSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: consentSeenKey) }
    }
}
