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

    // MARK: - server calls

    /// Send the star out: runs the server search+pick agent, returns the finding
    /// (or an empty/cap/failed status). The caller shows sending/away while this
    /// awaits, then the reveal card when it lands. NO PII is sent here — the
    /// search phase never sees the owner's name/email (that egress is booking
    /// only, in confirmFinding).
    func startFinding() async throws -> FindingItem {
        let functions = Functions.functions(region: region)
        let result = try await functions.httpsCallable("startFindingTask").call([:])
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

    /// Write the finding to the calendar via the existing CalendarService. The
    /// finding carries only a free-text time, so the demo schedules a gentle
    /// 1-hour hold tomorrow evening and puts the real when/where/link in the
    /// notes. Returns false on any failure (denied access, save error).
    func writeCalendar(for item: FindingItem) async -> Bool {
        guard await CalendarService.shared.ensureAccess() else { return false }
        let start = Self.defaultStart()
        let notes = [item.whenText, item.whereText, item.url]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return CalendarService.shared.createBreakEvent(
            title: item.title.isEmpty ? "a gentle outing" : item.title,
            start: start,
            duration: 3600,
            notes: notes.isEmpty ? "found by the star" : notes)
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
            createdAt: Date())
    }

    private static func defaultStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
