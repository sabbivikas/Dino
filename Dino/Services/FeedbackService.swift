//
//  FeedbackService.swift
//  Dino
//

// Firestore rules required for /feedback (already added to firestore.rules):
//   match /feedback/{docId} {
//     allow create: if request.auth != null;
//     allow read, update, delete: if false;
//   }
// Deploy rules: `firebase deploy --only firestore:rules`
//   or Firebase Console → Firestore → Rules → paste contents of firestore.rules → Publish
// View submissions: Firebase Console → Firestore → feedback collection

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

struct FeedbackSubmission: Codable {
    let id: String
    let userEmail: String
    let userName: String
    let userUID: String
    let category: String
    let message: String
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
    let timestamp: Date
    let status: String
}

enum FeedbackError: Error, LocalizedError {
    case notAuthenticated
    case submissionFailed
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "you need to be signed in to send feedback"
        case .submissionFailed: return "couldn't send — try again"
        }
    }
}

final class FeedbackService {
    static let shared = FeedbackService()
    private let db = Firestore.firestore()
    private init() {}

    @MainActor
    func submitFeedback(category: String, message: String) async throws {
        guard let user = Auth.auth().currentUser else { throw FeedbackError.notAuthenticated }

        let submission = FeedbackSubmission(
            id: UUID().uuidString,
            userEmail: user.email ?? "unknown",
            userName: user.displayName ?? "Dino User",
            userUID: user.uid,
            category: category,
            message: message,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            iosVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            timestamp: Date(),
            status: "new"
        )

        let payload: [String: Any] = [
            "id": submission.id,
            "userEmail": submission.userEmail,
            "userName": submission.userName,
            "userUID": submission.userUID,
            "category": submission.category,
            "message": submission.message,
            "appVersion": submission.appVersion,
            "iosVersion": submission.iosVersion,
            "deviceModel": submission.deviceModel,
            "timestamp": Timestamp(date: submission.timestamp),
            "status": submission.status
        ]

        do {
            try await db.collection("feedback").document(submission.id).setData(payload)
            AnalyticsManager.shared.trackFeedbackSubmitted(category: category)
        } catch {
            #if DEBUG
            print("[Feedback] submission failed: \(error)")
            print("[Feedback]   domain: \((error as NSError).domain)")
            print("[Feedback]   code: \((error as NSError).code)")
            print("[Feedback]   description: \(error.localizedDescription)")
            #endif
            throw FeedbackError.submissionFailed
        }
    }
}
