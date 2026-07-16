//
//  FeedbackService.swift
//  Dino
//
//  Submits user feedback via EmailJS HTTP API.
//  Credentials live in Secrets.xcconfig (Info.plist passthrough) with hardcoded fallbacks.
//

import Foundation
import FirebaseAuth
import UIKit

enum FeedbackError: Error, LocalizedError {
    case notAuthenticated
    case submissionFailed
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return String(localized: "you need to be signed in to send feedback")
        case .submissionFailed: return String(localized: "couldn't send — try again")
        }
    }
}

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    func submitFeedback(category: String, message: String) async throws {
        guard let user = Auth.auth().currentUser else { throw FeedbackError.notAuthenticated }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let iosVersion = await MainActor.run { UIDevice.current.systemVersion }
        let device = await MainActor.run { UIDevice.current.model }

        let serviceID = Self.config("EMAILJS_SERVICE_ID", fallback: "service_bmmdob8")
        let templateID = Self.config("EMAILJS_TEMPLATE_ID", fallback: "template_dkc4sqt")
        let publicKey = Self.config("EMAILJS_PUBLIC_KEY", fallback: "RtQfJvwvxaAyIwlsh")

        let userName = user.displayName ?? "Dino User"
        let userEmail = user.email ?? "unknown"

        // Build a self-contained feedback body that includes everything.
        // If the EmailJS template body just renders {{message}}, the feedback
        // arrives fully formatted. We also pass individual template params for
        // any template that wires them up separately.
        let fullBody = """
        NEW FEEDBACK FROM DINO APP

        From:     \(userName) (\(userEmail))
        Category: \(category)
        UID:      \(user.uid)

        Message:
        \(message)

        ---
        App version: \(appVersion)
        Device:      \(device)
        iOS:         \(iosVersion)
        """

        let params: [String: Any] = [
            "service_id": serviceID,
            "template_id": templateID,
            "user_id": publicKey,
            "template_params": [
                "to_email": "sabbi.vikas@gmail.com",
                "user_name": userName,
                "user_email": userEmail,
                "category": category,
                "message": fullBody,
                "app_version": appVersion,
                "device": device,
                "ios_version": iosVersion,
                "user_id": user.uid,
                "reply_to": userEmail,
                "from_name": "\(userName) (dino feedback)",
                "subject": "dino feedback: \(category)"
            ]
        ]

        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else {
            throw FeedbackError.submissionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            // Always log (release too) so we can diagnose on real devices.
            print("🦕 FEEDBACK status=\(code) body=\(body)")
            guard code == 200 else {
                throw FeedbackError.submissionFailed
            }
            await MainActor.run {
                AnalyticsManager.shared.trackFeedbackSubmitted(category: category)
            }
        } catch let error as FeedbackError {
            throw error
        } catch {
            print("🦕 FEEDBACK NETWORK ERROR: \(error)")
            print("🦕 FEEDBACK   domain: \((error as NSError).domain) code: \((error as NSError).code)")
            throw FeedbackError.submissionFailed
        }
    }

    private static func config(_ key: String, fallback: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            return fallback
        }
        return value
    }
}
