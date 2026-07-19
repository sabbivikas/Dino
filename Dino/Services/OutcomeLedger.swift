//
//  OutcomeLedger.swift
//  Dino
//
//  The enum twin of the little shelf (memory + shelf arc, F1).
//  Every agentic act — a rec shown, a gift delivered — writes ONE outcome
//  entry: what kind of thing dino brought, the coarse mood context, and what
//  happened to it. ENUM BUCKETS ONLY: no titles, no free text, no journal
//  content ever reaches this store. The only string field is a gift's source
//  domain, which always comes from the server's own trusted-sources list —
//  dino's choice of publisher, never user content.
//
//  Privacy shape (same discipline as ExpeditionSignals):
//  • fields are allowlisted in firestore.rules, enums checked server-side
//  • content (titles, links, dino's lines) lives ONLY in the on-device shelf
//  • crisis: writes ride display events, which are already crisis-gated —
//    no display, no write; this file adds no crisis logic of its own
//  • retention: TTL via expiresAt (12 months) + the nightly distiller prunes
//    to the newest 200 entries per user
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum OutcomeLedger {

    // MARK: allowlists (mirrored in firestore.rules and the server validator)

    static let kinds = ["rec", "gift"]
    static let recTypes = ["music", "book", "film"]
    static let giftNeeds = ["rest", "beauty", "hope", "wonder", "connection"]
    static let actions = ["shown", "opened", "kept", "ignored", "notTonight", "lateKept"]
    static let trends = ["improved", "steady", "heavier", "unknown"]
    static let moods = ["clear", "partlyCloudy", "overwhelmed", "drained", "none"]
    static let dayparts = ["morning", "afternoon", "evening", "night"]

    // MARK: announcement (knock timing) — rec delivery arc F6
    // The announcement lifecycle is a knock: shown → opened | ignored, each
    // stamped with the daypart it landed in, so a future distiller can learn
    // WHICH daypart earns opens vs ignores. SHOWN (at announce) and IGNORED
    // (at 72h expiry) are written SERVER-side — the client can never create
    // one, which is why 'announcement' is deliberately NOT in `kinds` (that
    // list mirrors the rules' client-create allowlist, ['rec','gift']). The
    // client's ONLY reach is flipping an existing knock to 'opened' at the
    // reveal, keyed by a deterministic id so push-tap / live-activity /
    // shelf-catch reveals of the same delivery collapse to one open.
    static let announcementKind = "announcement"
    static let announcementItemType = "parcel"          // the knock, not its contents
    static let announcementActions = ["shown", "opened", "ignored"]
    static let announcementIdPrefix = "ann_"

    static func announcementOutcomeId(deliveryId: String) -> String {
        announcementIdPrefix + deliveryId
    }

    static let retentionDays = 365
    static let followupHours = 48
    static let followupBatchLimit = 20

    // pending entry ids — only one rec and one gift are ever on screen at a
    // time, so a single slot per kind is enough to route the action update.
    static let pendingRecKey = "dino.ledger.pending.rec"
    static let pendingGiftKey = "dino.ledger.pending.gift"

    // MARK: enum helpers (pure — unit tested)

    /// Coarse mood context at display time: today's heaviest logged weather.
    static func moodContext(entries: [MoodEntry], now: Date = Date(),
                            calendar: Calendar = .current) -> String {
        let today = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }
        if today.contains(where: { $0.weatherType == .drained }) { return "drained" }
        if today.contains(where: { $0.weatherType == .overwhelmed }) { return "overwhelmed" }
        if today.contains(where: { $0.weatherType == .partlyCloudy }) { return "partlyCloudy" }
        if today.contains(where: { $0.weatherType == .clear }) { return "clear" }
        return "none"
    }

    static func daypart(hour: Int) -> String {
        switch hour {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...21: return "evening"
        default: return "night"
        }
    }

    /// Followup mapping — the current mood TREND bucket (steady/wobbly/heavy,
    /// same math the expedition signals use) read ~48h after the act, made
    /// relative to the mood context the thing arrived into. Deliberately
    /// coarse; feeds the distiller, never the UI, claims no causality.
    static func followupTrend(current trendBucket: String, shownContext: String) -> String {
        let wasHeavy = shownContext == "overwhelmed" || shownContext == "drained"
        switch trendBucket {
        case "steady": return wasHeavy ? "improved" : "steady"
        case "wobbly": return "steady"
        case "heavy":  return "heavier"
        default:       return "unknown"
        }
    }

    /// A gift's publisher domain — always one of the server's trusted
    /// sources; normalized and size-capped to match the rules.
    static func sourceDomain(from urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        let trimmed = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return String(trimmed.prefix(40))
    }

    // MARK: writes (fire-and-forget; a network miss is a quiet nothing)

    private static func entriesRef(uid: String) -> CollectionReference {
        Firestore.firestore().collection("outcomes").document(uid).collection("entries")
    }

    /// Called at display time (already crisis-gated by the presenting flow).
    /// Returns the entry id so the shelf (F4) can carry it.
    @discardableResult
    static func recordShown(kind: String, itemType: String, sourceDomain: String? = nil,
                            moodEntries: [MoodEntry], now: Date = Date(),
                            defaults: UserDefaults = .standard) -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        guard kinds.contains(kind) else { return nil }
        guard (kind == "rec" && recTypes.contains(itemType))
            || (kind == "gift" && giftNeeds.contains(itemType)) else { return nil }

        var doc: [String: Any] = [
            "kind": kind,
            "itemType": itemType,
            "moodContext": moodContext(entries: moodEntries, now: now),
            "daypart": daypart(hour: Calendar.current.component(.hour, from: now)),
            "action": "shown",
            "needsFollowup": true,
            "shownAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: now.addingTimeInterval(TimeInterval(retentionDays) * 86400)),
        ]
        if kind == "gift", let domain = sourceDomain { doc["sourceDomain"] = domain }

        let ref = entriesRef(uid: uid).document()
        ref.setData(doc) { _ in }   // silent — never a user-visible error
        defaults.set(ref.documentID, forKey: kind == "rec" ? pendingRecKey : pendingGiftKey)
        return ref.documentID
    }

    /// The user acted on the currently shown rec/gift.
    static func recordAction(kind: String, action: String,
                             defaults: UserDefaults = .standard) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard actions.contains(action), action != "shown" else { return }
        let key = kind == "rec" ? pendingRecKey : pendingGiftKey
        guard let entryId = defaults.string(forKey: key) else { return }
        entriesRef(uid: uid).document(entryId).updateData([
            "action": action,
            "actionAt": FieldValue.serverTimestamp(),
        ]) { _ in }
    }

    /// The announcement was OPENED — the user revealed the parcel (rec
    /// delivery arc F6). Flips the server-authored knock outcome in place,
    /// keyed by a deterministic id so the open dedupes across every reveal
    /// path and never double-counts against F4's SEPARATE rec-outcome (the
    /// knock and the rec are two different events). Enum-only; fire-and-forget.
    static func recordAnnouncementOpened(deliveryId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        entriesRef(uid: uid).document(announcementOutcomeId(deliveryId: deliveryId)).updateData([
            "action": "opened",
            "actionAt": FieldValue.serverTimestamp(),
        ]) { _ in }   // silent — never a user-visible error
    }

    /// Late keep from the shelf (F4) — the shelf entry carries its ledger id.
    static func recordLateKeep(entryId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        entriesRef(uid: uid).document(entryId).updateData([
            "action": "lateKept",
            "actionAt": FieldValue.serverTimestamp(),
        ]) { _ in }
    }

    /// Coarse followup, ridden by the existing daily signal sync — for each
    /// entry still waiting and older than ~48h, write the current mood trend
    /// bucket relative to the context it arrived into. No new pipeline.
    static func followupSweep(trendBucket: String, now: Date = Date()) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cutoff = Timestamp(date: now.addingTimeInterval(-TimeInterval(followupHours) * 3600))
        do {
            let snap = try await entriesRef(uid: uid)
                .whereField("needsFollowup", isEqualTo: true)
                .limit(to: followupBatchLimit)
                .getDocuments()
            let batch = Firestore.firestore().batch()
            var writes = 0
            for doc in snap.documents {
                guard let shownAt = doc.data()["shownAt"] as? Timestamp,
                      shownAt.compare(cutoff) == .orderedAscending else { continue }
                let context = doc.data()["moodContext"] as? String ?? "none"
                batch.updateData([
                    "followupTrend": followupTrend(current: trendBucket, shownContext: context),
                    "followupAt": FieldValue.serverTimestamp(),
                    "needsFollowup": false,
                ], forDocument: doc.reference)
                writes += 1
            }
            if writes > 0 { try await batch.commit() }
        } catch {
            // a quiet miss — the next daily sync tries again
        }
    }
}
