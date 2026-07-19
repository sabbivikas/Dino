//
//  RecRevealService.swift
//  Dino
//
//  Rec delivery F4 — the reveal's plumbing: the status-gated payload read
//  (allowed post-hold per firestore.rules), the one client write the rules
//  permit (announced → opened + server-stamped openedAt), and the pure
//  little state machine the unwrap moment runs on.
//
//  THE OPENED RULE (recorded in f4-verdict): card revealed = opened.
//  Dismissing while the parcel is still wrapped (or mid-unwrap) leaves the
//  delivery 'announced' — the parcel stays catchable later (F5's shelf
//  catch), and the live activity stays up.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - The reveal's state machine (pure — tested)

enum RecRevealPhase: String, Equatable {
    case wrapped       // the parcel sits center-screen, payload may still be loading
    case unwrapping    // ~1s of paper folding away
    case revealed      // the card has bloomed — this is the 'opened' moment
}

enum RecRevealMachine {
    /// The unwrap beat — flaps fold away, then the card blooms.
    static let unwrapDuration: TimeInterval = 0.95

    /// A parcel tap unwraps only when there is something inside to show
    /// (payload fetched). Reduce Motion skips the fold and fades straight
    /// to the card.
    static func afterParcelTap(phase: RecRevealPhase, payloadReady: Bool,
                               reduceMotion: Bool) -> RecRevealPhase {
        guard phase == .wrapped, payloadReady else { return phase }
        return reduceMotion ? .revealed : .unwrapping
    }

    static func afterUnwrapAnimation(phase: RecRevealPhase) -> RecRevealPhase {
        phase == .unwrapping ? .revealed : phase
    }

    /// First reveal = the delivery was still 'announced' when we fetched it.
    /// A stale push re-tap (already 'opened') shows the card again but
    /// writes nothing twice — no duplicate keepsake, no rules rejection.
    static func isFirstReveal(deliveryStatus: String?) -> Bool {
        deliveryStatus == "announced"
    }

    static func shouldMarkOpened(phase: RecRevealPhase, deliveryStatus: String?) -> Bool {
        phase == .revealed && isFirstReveal(deliveryStatus: deliveryStatus)
    }

    /// Swipe-down before the card ever showed → the delivery stays
    /// 'announced' and the parcel (incl. the live activity) stays for later.
    static func parcelStaysForLater(phase: RecRevealPhase) -> Bool {
        phase != .revealed
    }
}

// MARK: - Share payload (title + link — locked spec; pure, tested)

enum RecRevealShare {
    static func message(for rec: RichRec) -> String {
        "\(rec.title) \u{00B7} \(rec.creator)"
    }

    static func url(for rec: RichRec) -> URL? {
        rec.reopenLink()?.url
    }
}

// MARK: - The source pill (watch-provider or source; pure, tested)

enum RecRevealVoice {
    /// Brand/provider names stay plain lowercase english by house rule
    /// (same class as the watch-provider button); a film without a provider
    /// falls back to the localized type word.
    static func sourcePill(for rec: RichRec, rememberedMusicApp: String?) -> String {
        switch rec.type {
        case "music":
            return rememberedMusicApp ?? RecOpenMemory.appleMusic
        case "book":
            return "apple books"
        case "film":
            if let p = rec.watchProvider, !p.isEmpty { return p }
            return rec.type.localized
        default:
            return rec.type.localized
        }
    }
}

// MARK: - Firestore plumbing

@MainActor
enum RecRevealService {

    struct Delivery: Equatable {
        let status: String     // announced | opened | expired (held is unreadable)
        let recs: [RichRec]    // sanitized; first is the reveal, rest go to the cache
    }

    /// Rec delivery F5 — the shelf catch's read: every delivery still
    /// 'announced' (never opened) for this user, as wrapped parcels. The
    /// no-leak rule permits this client read (status != 'held'); the payload
    /// stays sealed until the reveal. Empty on any miss — the shelf simply
    /// shows the opened keepsakes alone.
    static func announcedDeliveries() async -> [WrappedDelivery] {
        #if DEBUG
        if let qa = qaWrappedDeliveries() { return qa }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let snap = try? await Firestore.firestore()
            .collection("recDeliveries").document(uid)
            .collection("deliveries")
            .whereField("status", isEqualTo: "announced")
            .limit(to: 20)
            .getDocuments()
        guard let docs = snap?.documents else { return [] }
        return docs.compactMap { d -> WrappedDelivery? in
            guard let ts = d.data()["announcedAt"] as? Timestamp else { return nil }
            return WrappedDelivery(deliveryId: d.documentID, announcedAt: ts.dateValue())
        }
    }

    /// Reads the delivery status + the status-gated payload. nil on any miss
    /// (offline, still held, signed out) — the parcel simply stays wrapped.
    static func fetch(deliveryId: String) async -> Delivery? {
        #if DEBUG
        if let qa = qaDelivery(for: deliveryId) { return qa }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let parent = Firestore.firestore().collection("recDeliveries").document(uid)
        guard let deliverySnap = try? await parent.collection("deliveries")
            .document(deliveryId).getDocument(),
              let status = deliverySnap.data()?["status"] as? String else { return nil }
        guard let payloadSnap = try? await parent.collection("payloads")
            .document(deliveryId).getDocument(),
              let raw = payloadSnap.data()?["recs"] as? [[String: Any]] else { return nil }
        let recs = raw.compactMap { ComfortRecSanitizer.rec(from: $0) }
        guard !recs.isEmpty else { return nil }
        return Delivery(status: status, recs: recs)
    }

    /// The one write firestore.rules allows a client on a delivery:
    /// announced → opened, openedAt server-stamped. Fire and forget — a
    /// network miss is a quiet nothing (the card still shows; F5's shelf
    /// catch reads status server-side and self-heals).
    static func markOpened(deliveryId: String) {
        #if DEBUG
        guard !deliveryId.hasPrefix("qa-") else { return }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("recDeliveries").document(uid)
            .collection("deliveries").document(deliveryId)
            .updateData([
                "status": "opened",
                "openedAt": FieldValue.serverTimestamp(),
            ]) { _ in }   // silent — never a user-visible error
    }

    #if DEBUG
    /// -recRevealQA fixtures — screenshot verification only. qa- ids never
    /// touch firestore, the ledger, or the shelf.
    static func qaDelivery(for deliveryId: String,
                           arguments: [String] = ProcessInfo.processInfo.arguments) -> Delivery? {
        guard deliveryId.hasPrefix("qa-") else { return nil }
        if arguments.contains("-recRevealQAPaper") {
            return Delivery(status: "announced", recs: [.qaPaperOnlySample])
        }
        return Delivery(status: "announced", recs: [.qaFilmSample])
    }

    /// -recShelfWrappedQA fixtures — two wrapped parcels for the shelf-catch
    /// screenshots. The qa- ids route through qaDelivery on tap (the film /
    /// paper reveal fixtures), so a wrapped parcel opens the real F4 reveal
    /// without touching Firestore, the ledger, or the shelf archive.
    static func qaWrappedDeliveries(now: Date = Date(),
                                    arguments: [String] = ProcessInfo.processInfo.arguments) -> [WrappedDelivery]? {
        guard arguments.contains("-recShelfWrappedQA") else { return nil }
        return [
            WrappedDelivery(deliveryId: "qa-parcel", announcedAt: now),
            WrappedDelivery(deliveryId: "qa-wrapped-2",
                            announcedAt: now.addingTimeInterval(-3600)),
        ]
    }
    #endif
}