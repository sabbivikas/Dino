//
//  RecShelf.swift
//  Dino
//
//  Rec delivery F5 — the shelf catch. The little shelf (RecKeepsakesView,
//  under Profile) now unifies two sources into one collage:
//    • WRAPPED PARCELS — deliveries still 'announced' and never opened
//      (the "dismissed while wrapped" and "banner fired but never tapped"
//      cases). They show as a still-wrapped parcel; a tap opens the SAME F4
//      reveal for that deliveryId.
//    • OPENED KEEPSAKES — the local archive (RichRecStore.keepsakes), each
//      an opened rec with its image thumbnail + washi mark.
//
//  This file is the pure, tested merge/sort/dedupe — no SwiftUI, no
//  Firestore — so the shelf's ordering rule lives in one place.
//

import Foundation

/// One announced-but-unopened delivery, as the shelf shows it: a still
/// wrapped parcel. The content stays sealed — no payload read, no title —
/// because the parcel is a mystery until the reveal. Only the id (to open
/// it) and the announce time (to sort it) are carried.
struct WrappedDelivery: Equatable, Identifiable {
    let deliveryId: String
    let announcedAt: Date
    var id: String { deliveryId }
}

/// The shelf's unified item model + its ordering rule.
enum RecShelf {

    /// A shelf slot: a wrapped parcel still waiting, or an opened keepsake.
    enum Entry: Equatable, Identifiable {
        case wrapped(WrappedDelivery)
        case opened(RichRecStore.Keepsake)

        var id: String {
            switch self {
            case .wrapped(let w):
                return "wrapped-\(w.deliveryId)"
            case .opened(let k):
                return "opened-\(k.rec.title)-\(k.shownAt.timeIntervalSince1970)"
            }
        }

        var isWrapped: Bool {
            if case .wrapped = self { return true }
            return false
        }
    }

    /// Merge the announced parcels with the opened keepsakes into one shelf.
    ///
    /// - Dedupe (by delivery identity): a delivery already opened on this
    ///   device — its id in `openedIds` — never shows as a wrapped parcel.
    ///   Its opened keepsake (written at reveal time) is the single entry.
    ///   This covers the window between the fire-and-forget markOpened write
    ///   and the server flipping the doc out of the announced query, so a
    ///   just-opened parcel never lingers as a duplicate.
    /// - Sort: wrapped-and-waiting FIRST (newest announcement first) — the
    ///   catch keeps an unopened gift at the top of the shelf where it can't
    ///   be missed — then the opened keepsakes, newest-first (the archive's
    ///   natural order).
    static func merge(wrapped: [WrappedDelivery],
                      keepsakes: [RichRecStore.Keepsake],
                      openedIds: Set<String>) -> [Entry] {
        let parcels = wrapped
            .filter { !openedIds.contains($0.deliveryId) }
            .sorted { $0.announcedAt > $1.announcedAt }
            .map(Entry.wrapped)
        let opened = keepsakes
            .sorted { $0.shownAt > $1.shownAt }
            .map(Entry.opened)
        return parcels + opened
    }

    /// The everything · kept filter. "kept" shows only kept OPENED keepsakes;
    /// a wrapped parcel is not yet anything to keep, so it hides under kept
    /// and only appears under everything (the default).
    static func visible(_ entries: [Entry], keptOnly: Bool) -> [Entry] {
        guard keptOnly else { return entries }
        return entries.filter {
            if case .opened(let k) = $0 { return k.kept }
            return false
        }
    }
}
