//
//  RecAnnouncementObserver.swift
//  Dino
//
//  Rec delivery F3 — the client half of the announcement. When the app
//  comes to the foreground it looks for an 'announced' delivery (readable
//  post-hold per firestore.rules) and raises the paper parcel Live
//  Activity, which persists on the lock screen / dynamic island until the
//  reveal opens it or the 6h life ends.
//
//  HONEST GAP (recorded in f3-verdict): ActivityKit push-to-start needs
//  provisioned push infra this project does not have yet, so with the app
//  fully closed only the push BANNER lands at announce time; the parcel
//  activity raises on the next app open and lives on from there.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// dino://rec-reveal/{deliveryId} — the route F3 wires and F4 inherits.
struct RecRevealLink: Identifiable, Equatable {
    let deliveryId: String
    var id: String { deliveryId }

    /// Strict parse; anything malformed is nil (silence, never a broken door).
    static func from(url: URL) -> RecRevealLink? {
        guard url.scheme == "dino", url.host == "rec-reveal" else { return nil }
        let id = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
        guard !id.isEmpty, id != "/" else { return nil }
        return RecRevealLink(deliveryId: id)
    }
}

@MainActor
enum RecAnnouncementObserver {

    /// Pure decision — tested. A parcel raises only for a fresh (<6h)
    /// announcement, and only while dino's master notifications toggle is
    /// on (notifications off = dino stays quiet on every channel; the rec
    /// itself still waits for F4's reveal, never lost).
    nonisolated static func shouldRaiseParcel(announcedAt: Date?,
                                              now: Date,
                                              masterEnabled: Bool) -> Bool {
        guard masterEnabled, let announcedAt else { return false }
        let age = now.timeIntervalSince(announcedAt)
        return age >= 0 && age < RecParcelActivityAttributes.lifetime
    }

    /// Foreground pass: end expired parcels, then raise one for the newest
    /// announced delivery (the manager refuses duplicates, so this is
    /// idempotent across every foreground return).
    static func checkOnForeground(now: Date = Date()) async {
        DinoLiveActivityManager.shared.sweepStaleRecParcels(now: now)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let snap = try? await Firestore.firestore()
            .collection("recDeliveries").document(uid)
            .collection("deliveries")
            .whereField("status", isEqualTo: "announced")
            .limit(to: 5)
            .getDocuments()
        guard let docs = snap?.documents, !docs.isEmpty else { return }
        // newest announcement wins — client-side sort, no composite index
        let newest = docs
            .compactMap { d -> (String, Date)? in
                guard let ts = d.data()["announcedAt"] as? Timestamp else { return nil }
                return (d.documentID, ts.dateValue())
            }
            .max { $0.1 < $1.1 }
        guard let (deliveryId, announcedAt) = newest,
              shouldRaiseParcel(announcedAt: announcedAt, now: now,
                                masterEnabled: NotificationManager.shared.notificationsEnabled)
        else { return }
        DinoLiveActivityManager.shared.startRecParcelActivity(
            deliveryId: deliveryId, announcedAt: announcedAt, now: now)
    }
}
