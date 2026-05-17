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
        case .notAuthenticated: return "you need to be signed in to send feedback"
        case .submissionFailed: return "couldn't send — try again"
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
        let templateID = Self.config("EMAILJS_TEMPLATE_ID", fallback: "template_14m442q")
        let publicKey = Self.config("EMAILJS_PUBLIC_KEY", fallback: "RtQfJvwvxaAyIwlsh")

        let params: [String: Any] = [
            "service_id": serviceID,
            "template_id": templateID,
            "user_id": publicKey,
            "template_params": [
                "user_name": user.displayName ?? "Dino User",
                "user_email": user.email ?? "unknown",
                "category": category,
                "message": message,
                "app_version": appVersion,
                "device": device,
                "ios_version": iosVersion,
                "user_id": user.uid,
                "reply_to": user.email ?? "unknown",
                "from_name": user.displayName ?? "Dino User"
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
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                #if DEBUG
                print("[Feedback] EmailJS submit failed status=\(code) body=\(body)")
                #endif
                throw FeedbackError.submissionFailed
            }
            await MainActor.run {
                AnalyticsManager.shared.trackFeedbackSubmitted(category: category)
            }
        } catch let error as FeedbackError {
            throw error
        } catch {
            #if DEBUG
            print("[Feedback] EmailJS submit error: \(error)")
            print("[Feedback]   domain: \((error as NSError).domain)")
            print("[Feedback]   code: \((error as NSError).code)")
            #endif
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
