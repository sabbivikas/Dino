//
//  FindingsKeepsake.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — branch-owned. The redesign REMOVED the
//  local findings shelf; an ACCEPTED finding now rests on the EXISTING profile
//  shelf, right alongside the comfort recs and kept expedition gifts.
//
//  IT TOUCHES NO SHIPPING FILE: it constructs a `RichRec` (a struct internal to
//  the app module) and calls `RichRecStore.recordKeepsake(_:kept:)` — both
//  already reachable from branch-owned code — exactly mirroring how a kept
//  expedition gift is written (ExpeditionGift.asKeepsakeRec). The shelf already
//  renders a type-"gift" keepsake with the dove icon and the gold tint, and a
//  tap reopens `watchLink`; a finding rides the same rails.
//
//  THE ACTED MOMENT: recordAccepted is called the instant a finding is ACCEPTED
//  in the card — a calendar write succeeded, it was booked, or a handoff /
//  finish-signup page was opened — and never before. FindingsStore.isShelved
//  guarantees exactly one keepsake per finding.
//
//  Field mapping (matches the expedition keep-path exactly):
//    type      "gift"                 (dove icon, gold tint, reopen → watchLink)
//    title     finding title
//    creator   venue
//    why       dino's why line
//    watchLink the listing url        (what a shelf tap reopens)
//
//  English-only demo (owner decision): plain string literals only.
//

import Foundation

enum FindingsKeepsake {
    /// Write an accepted finding to the profile shelf as a keepsake, once.
    static func recordAccepted(_ item: FindingItem, now: Date = Date()) {
        guard !item.taskId.isEmpty, !FindingsStore.isShelved(taskId: item.taskId) else { return }
        let rec = RichRec(
            type: "gift",
            title: item.title.isEmpty ? "a gentle outing" : item.title,
            creator: item.whereText,
            year: Calendar.current.component(.year, from: now),
            why: item.why,
            flags: ["a soft one"],
            feel: "quiet",
            length: "",
            watchProvider: nil,
            watchLink: item.url)
        RichRecStore.recordKeepsake(rec, kept: true, now: now)
        FindingsStore.markShelved(taskId: item.taskId)
    }
}
