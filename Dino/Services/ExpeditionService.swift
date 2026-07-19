//
//  ExpeditionService.swift
//  Dino
//
//  F3 of the expedition engine: the delivery. The server writes the gift;
//  the client collects it ONCE and everything after that is local — shown
//  state, keepsakes, ignores. The card waits on the mood screen like the
//  lantern; there is no push, ever.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ExpeditionGift: Codable, Equatable {
    let needKind: String    // rest | beauty | hope | wonder | connection
    let title: String
    let source: String
    let excerpt: String     // short, copyright safe; the url carries the rest
    let url: String
    let dinoLine: String    // the one warm line dino wrote
    let foundAt: Date
}

enum ExpeditionVoice {
    // fixed strings (lowercase, zero dashes — voice tested)
    static let cardHeader = String(localized: "dino went looking and found this for you \u{1F54A}")
    static let fromPrefix = String(localized: "from")
    static let openLink = String(localized: "see where it lives")
    static let keepIt = String(localized: "keep this")
    static let driftedAway = String(localized: "this one has drifted away")
    static let settingsTitle = String(localized: "little expeditions")
    static let settingsBody = String(localized: "dino sometimes goes looking for small things for you, using only your weather patterns, never your words.")
    static let fallbackLine = String(localized: "dino went looking tonight and this glimmered")
    static let needKinds = ["rest", "beauty", "hope", "wonder", "connection"]

    static var allFixedStrings: [String] {
        [cardHeader, fromPrefix, openLink, keepIt, driftedAway,
         settingsTitle, settingsBody, fallbackLine] + needKinds
    }
}

enum ExpeditionParser {
    /// Pure parse + belt and suspenders re sanitize of the server doc — the
    /// server already validated, but dino's voice rules are enforced again
    /// at the door. Anything off = nil = silence.
    static func gift(from data: [String: Any], now: Date = Date()) -> ExpeditionGift? {
        guard let g = data["gift"] as? [String: Any] else { return nil }
        let needKind = (data["needKind"] as? String ?? "").lowercased()
        guard ExpeditionVoice.needKinds.contains(needKind) else { return nil }
        let title = ComfortRecSanitizer.voiceLine(g["title"] as? String ?? "", cap: 80)
        let source = ComfortRecSanitizer.voiceLine(g["source"] as? String ?? "", cap: 60)
        let excerpt = ComfortRecSanitizer.voiceLine(g["excerpt"] as? String ?? "", cap: 280)
        let dinoLine = ComfortRecSanitizer.voiceLine(g["dinoLine"] as? String ?? "", cap: 120)
        let url = g["url"] as? String ?? ""
        guard !title.isEmpty, !source.isEmpty, !excerpt.isEmpty, url.hasPrefix("https://") else { return nil }
        let foundAt = (data["lastAt"] as? Timestamp)?.dateValue() ?? now
        return ExpeditionGift(needKind: needKind, title: title, source: source,
                              excerpt: excerpt, url: url,
                              dinoLine: dinoLine.isEmpty ? ExpeditionVoice.fallbackLine : dinoLine,
                              foundAt: foundAt)
    }
}

enum ExpeditionStore {
    /// Shown once semantics: the expeditions doc is server write only, so
    /// delivery state lives on device (the same key the signal buckets read).
    static func shouldPresent(_ gift: ExpeditionGift, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: ExpeditionSignals.enabledKey) as? Bool ?? true else { return false }
        if let last = defaults.object(forKey: ExpeditionSignals.lastDeliveredKey) as? Date,
           gift.foundAt <= last { return false }
        return true
    }

    static func markPresented(_ gift: ExpeditionGift, defaults: UserDefaults = .standard) {
        defaults.set(gift.foundAt, forKey: ExpeditionSignals.lastDeliveredKey)
    }

    /// "keep this" — the delivery already sits on the shelf (F4 archives at
    /// display time); keeping marks that entry rather than inserting again.
    /// Falls back to an insert if the entry is somehow missing.
    static func keep(_ gift: ExpeditionGift, now: Date = Date(), defaults: UserDefaults = .standard) {
        if RichRecStore.markKept(title: gift.title, now: now, defaults: defaults) == nil {
            RichRecStore.recordKeepsake(gift.asKeepsakeRec, kept: true, now: now, defaults: defaults)
        }
    }
}

extension ExpeditionGift {
    /// The shelf speaks RichRec; a gift rides along as type "gift" with its
    /// source url in watchLink so a shelf tap re opens where it lives.
    var asKeepsakeRec: RichRec {
        RichRec(type: "gift", title: title, creator: source,
                year: Calendar.current.component(.year, from: foundAt),
                why: dinoLine, flags: ["a soft one"], feel: needKind, length: "",
                watchProvider: nil, watchLink: url)
    }
}

enum ExpeditionReader {
    /// A gentle probe before re opening a kept gift — alive means reachable
    /// and not clearly gone. 405 (head not allowed) still counts as alive;
    /// timeouts and 4xx/5xx do not.
    static func pageAlive(url: URL, timeout: TimeInterval = 5) async -> Bool {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "HEAD"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            return http.statusCode < 400 || http.statusCode == 405
        } catch {
            return false
        }
    }
}

@MainActor
enum ExpeditionCoordinator {
    /// Collect the pending gift, if there is one and it has not been shown.
    static func fetchPending() async -> ExpeditionGift? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            let snap = try await Firestore.firestore().collection("expeditions").document(uid).getDocument()
            guard let data = snap.data(), let gift = ExpeditionParser.gift(from: data) else { return nil }
            return ExpeditionStore.shouldPresent(gift) ? gift : nil
        } catch {
            return nil   // network trouble = a quiet day, never an error
        }
    }
}

#if DEBUG
extension ExpeditionGift {
    /// -expeditionQA sample — public domain, screenshot verification only.
    static let qaSample = ExpeditionGift(
        needKind: "hope",
        title: "hope is the thing with feathers",
        source: "poetry foundation",
        excerpt: "hope is the thing with feathers that perches in the soul, and sings the tune without the words, and never stops at all",
        url: "https://www.poetryfoundation.org/poems/42889/hope-is-the-thing-with-feathers-314",
        dinoLine: "dino went looking and this one sang back",
        foundAt: Date())
}
#endif
