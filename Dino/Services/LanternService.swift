//
//  LanternService.swift
//  Dino
//
//  Client side of lanterns. Sending goes through the moderateLantern function
//  (strict gate; approved verbatim or rejected — never rewritten server-side).
//  Receiving goes through claimLantern (server picks the oldest undelivered,
//  max one per day). Reports write to lanternReports for manual review.
//

import Foundation
import FirebaseFunctions
import FirebaseFirestore

@MainActor
enum LanternService {
    enum SendResult {
        case approved
        case rejected
        case limitReached
        case failed
    }

    static let maxChars = 140

    /// The three tap-to-use suggestion phrases on the compose sheet.
    static let suggestions = [
        "you're doing better than you think 🌱",
        "this feeling will pass. you've made it through every hard day so far",
        "someone across the world is rooting for you 🏮",
    ]

    static func sendLantern(text: String) async -> SendResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxChars else { return .rejected }
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("moderateLantern").call([
                "text": trimmed,
                "countryCode": WorldMoodService.countryCode(from: Locale.current.region?.identifier),
            ])
            let approved = (result.data as? [String: Any])?["approved"] as? Bool ?? false
            if approved {
                SharedDataManager.shared.incrementSentLanternCount()
                AnalyticsManager.shared.trackLanternSent()
                return .approved
            } else {
                AnalyticsManager.shared.trackLanternRejected()
                return .rejected
            }
        } catch {
            let ns = error as NSError
            #if DEBUG
            print("🏮 lantern send failed: \(error.localizedDescription)")
            #endif
            if ns.domain == FunctionsErrorDomain,
               ns.code == FunctionsErrorCode.resourceExhausted.rawValue {
                return .limitReached
            }
            return .failed
        }
    }

    /// Asks the server for today's lantern. Nil = already claimed today, empty
    /// pool, or offline — the UI simply shows nothing.
    static func claimLantern() async -> ReceivedLantern? {
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("claimLantern").call([:])
            guard let data = result.data as? [String: Any],
                  let payload = data["lantern"] as? [String: Any],
                  let text = payload["text"] as? String, !text.isEmpty else { return nil }
            let country = payload["countryCode"] as? String ?? "elsewhere"
            let lantern = ReceivedLantern(text: text, countryCode: country)
            SharedDataManager.shared.addReceivedLantern(lantern)
            AnalyticsManager.shared.trackLanternReceived()
            return lantern
        } catch {
            #if DEBUG
            print("🏮 lantern claim failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Report a received lantern for manual review (create-only collection).
    static func report(_ lantern: ReceivedLantern) async {
        guard let uid = SharedDataManager.shared.currentUserId else { return }
        let doc: [String: Any] = [
            "text": String(lantern.text.prefix(200)),
            "countryCode": lantern.countryCode,
            "receivedAt": Timestamp(date: lantern.receivedAt),
            "createdAt": FieldValue.serverTimestamp(),
            "reporterUid": uid,
        ]
        do {
            try await Firestore.firestore().collection("lanternReports").addDocument(data: doc)
            AnalyticsManager.shared.trackLanternReported()
        } catch {
            #if DEBUG
            print("🏮 lantern report failed: \(error.localizedDescription)")
            #endif
        }
    }

    static func countryName(_ code: String) -> String {
        if code == "elsewhere" { return "somewhere in the world" }
        return (Locale.current.localizedString(forRegionCode: code) ?? code).lowercased()
    }
}
