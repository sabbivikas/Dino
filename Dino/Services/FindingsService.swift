//
//  FindingsService.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. Bridges the findings tab to the server
//  onCalls (startFindingTask, getFindingTask, confirmFinding) and to the
//  EXISTING CalendarService for the local calendar write.
//
//  THE HONEST-BOOKING RULE: "booked" is shown ONLY when BOTH the server booking
//  result AND the local calendar write succeeded. If either fails we surface an
//  honest partial state, never a false "booked".
//
//  English-only demo (owner decision): plain string literals only.
//

import Foundation
import FirebaseFunctions

@MainActor
final class FindingsService {
    static let shared = FindingsService()
    private init() {}

    private let region = "us-central1"

    enum FindingsError: Error { case notEnabled, badResponse }

    /// What a calendar write actually did. `alreadyWritten` is the duplicate
    /// guard firing (not a failure); `noConfirmedTime` is the honest refusal to
    /// invent a date when the listing never stated one.
    enum CalendarWrite { case written, alreadyWritten, noConfirmedTime, failed }

    /// Distinguish a GATE DENIAL (the callable rejecting an unauthenticated or
    /// unauthorized caller — e.g. the demo running on a non-owner dino) from a
    /// genuine failure. FirebaseFunctions surfaces these as an NSError in
    /// FunctionsErrorDomain whose code is the FunctionsErrorCode raw value.
    /// The UI shows a distinct quiet line for a denial instead of the generic
    /// "lost its way" (owner fix #8).
    static func isGateDenied(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain else { return false }
        return ns.code == FunctionsErrorCode.unauthenticated.rawValue
            || ns.code == FunctionsErrorCode.permissionDenied.rawValue
    }

    // MARK: - server calls

    /// Send the star out: runs the server search+pick agent, returns the finding
    /// (or an empty/cap/failed status). The caller shows sending/away while this
    /// awaits, then the reveal card when it lands. NO PII is sent here — the
    /// search phase never sees the owner's name/email (that egress is booking
    /// only, in confirmFinding).
    /// `preferBookable` biases the SERVER's source list toward registration /
    /// signup portals. It is a prompt-level bias only: the 30-step kill and the
    /// 5/day cap are untouched by it.
    func startFinding(preferBookable: Bool = false) async throws -> FindingItem {
        let functions = Functions.functions(region: region)
        let result = try await functions.httpsCallable("startFindingTask")
            .call(["preferBookable": preferBookable])
        guard let data = result.data as? [String: Any] else { throw FindingsError.badResponse }
        return Self.item(from: data)
    }

    /// Re-read a task's current status (used when the app foregrounds after a
    /// push, or to refresh the shelf).
    func pollFinding(taskId: String) async throws -> FindingItem {
        let functions = Functions.functions(region: region)
        let result = try await functions.httpsCallable("getFindingTask")
            .call(["taskId": taskId])
        guard let data = result.data as? [String: Any] else { throw FindingsError.badResponse }
        return Self.item(from: data)
    }

    /// Ask the server for the caller's MOST RECENT task (getFindingTask with no
    /// taskId). This is the reconciliation door: a cold open after the app was
    /// killed mid-search, or a foreground after the push, learns that the star
    /// already came back. A user who has never sent a star out gets a quiet
    /// status "none" rather than an error.
    func pollLatest() async throws -> FindingItem {
        let functions = Functions.functions(region: region)
        let result = try await functions.httpsCallable("getFindingTask").call([:])
        guard let data = result.data as? [String: Any] else { throw FindingsError.badResponse }
        return Self.item(from: data)
    }

    /// Confirm/book a finding. Returns the server status (booked | handoff |
    /// confirmed | failed) and, for a handoff, the url the owner finishes at.
    func confirmFinding(taskId: String, userName: String) async throws -> (status: String, url: String) {
        let functions = Functions.functions(region: region)
        let result = try await functions.httpsCallable("confirmFinding")
            .call(["taskId": taskId, "userName": userName])
        guard let data = result.data as? [String: Any],
              let status = data["status"] as? String else { throw FindingsError.badResponse }
        let url = data["url"] as? String ?? ""
        return (status, url)
    }

    // MARK: - calendar (reuse the EXISTING CalendarService)

    /// Write the finding to the calendar via the existing CalendarService.
    ///
    /// THE BUG THIS FIXES: this used to ignore the finding's date entirely and
    /// schedule a hardcoded "tomorrow, 18:00 local" hold, leaving the real time
    /// only in the notes — so a thing found on the 28th landed on the 29th. The
    /// event start now comes from the agent's machine-readable startISO, parsed
    /// with its embedded offset (NOT re-read in device-local time), and there is
    /// no placeholder date left anywhere: no startISO means no event.
    ///
    /// DUPLICATE GUARD: re-reads the CURRENT stored item and refuses to write
    /// when this finding has already been acted on or already carries a write
    /// stamp, so a second tap can never create a second event.
    @discardableResult
    func writeCalendar(for item: FindingItem) async -> CalendarWrite {
        // belt: whatever the caller is holding may be a stale snapshot.
        let current = FindingsStore.item(taskId: item.taskId) ?? item
        // suspenders: the persisted write stamp outlives any in-memory state.
        if FindingsStore.hasCalendarWrite(current) { return .alreadyWritten }

        guard let window = Self.eventWindow(startISO: current.startISO, endISO: current.endISO),
              current.hasConfirmedTime else { return .noConfirmedTime }
        guard await CalendarService.shared.ensureAccess() else { return .failed }

        var noteLines = [current.whenText, current.whereText, current.url].filter { !$0.isEmpty }
        if current.dateConfidence == "approximate" {
            noteLines.append("this time is approximate. the listing is the authority, "
                             + "so please double check it before you go.")
        }
        let notes = noteLines.joined(separator: "\n")
        let ok = CalendarService.shared.createBreakEvent(
            title: current.title.isEmpty ? "a gentle outing" : current.title,
            start: window.start,
            duration: window.duration,
            notes: notes.isEmpty ? "found by the star" : notes)
        guard ok else { return .failed }
        FindingsStore.markCalendarWritten(taskId: current.taskId)
        return .written
    }

    /// PURE: the real event window from the agent's ISO fields. Returns nil when
    /// there is no usable start — the caller must then NOT write anything.
    /// Duration is endISO − startISO when both parse and the end is after the
    /// start; otherwise a gentle one hour hold.
    static func eventWindow(startISO: String?, endISO: String?) -> (start: Date, duration: TimeInterval)? {
        guard let startISO, let start = parseISO(startISO) else { return nil }
        if let endISO, let end = parseISO(endISO) {
            let seconds = end.timeIntervalSince(start)
            // sane windows only (positive, under a day) — otherwise the 1h hold.
            if seconds > 0, seconds <= 24 * 3600 { return (start, seconds) }
        }
        return (start, 3600)
    }

    /// Parse an ISO 8601 datetime RESPECTING ITS EMBEDDED OFFSET. Two passes
    /// because .withFractionalSeconds is all-or-nothing in ISO8601DateFormatter.
    static func parseISO(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: s) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: s)
    }

    // MARK: - mapping

    private static func item(from data: [String: Any]) -> FindingItem {
        let taskId = data["taskId"] as? String ?? ""
        let status = data["status"] as? String ?? "failed"
        let finding = data["finding"] as? [String: Any]
        return FindingItem(
            taskId: taskId,
            status: status,
            title: finding?["title"] as? String ?? "",
            whenText: finding?["when"] as? String ?? "",
            whereText: finding?["venue"] as? String ?? "",
            why: finding?["why"] as? String ?? "",
            url: finding?["url"] as? String ?? "",
            outcome: finding?["outcome"] as? String ?? "",
            createdAt: Date(),
            // the structured date the agent vouched for. Absent/NSNull → nil,
            // which the card reads as "no confirmed time on the listing".
            startISO: finding?["startISO"] as? String,
            endISO: finding?["endISO"] as? String,
            dateConfidence: finding?["dateConfidence"] as? String ?? "unknown")
    }
}
