//
//  CheckInAIService.swift
//  Dino
//

import Foundation
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

enum CheckInAIError: Error, LocalizedError {
    case notAuthenticated
    case alreadyExists
    case invalidResponse
    case decodeFailed
    case notConfigured
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "you need to be signed in"
        case .alreadyExists: return "you've already completed this week's check-in"
        case .invalidResponse: return "we couldn't read the report"
        case .decodeFailed: return "the report came back in an unexpected format"
        case .notConfigured: return "report service is not configured yet — add FirebaseFunctions to the Dino target in Xcode"
        case .network(let m): return m
        }
    }
}

@MainActor
final class CheckInAIService {
    static let shared = CheckInAIService()
    private init() {}

    func generateReport(
        weekNumber: Int,
        year: Int,
        dateRange: String,
        questions: [CheckInQuestion],
        answers: [Int],
        previousScores: [String: Int]?
    ) async throws -> WeeklyReport {
        #if canImport(FirebaseFunctions)
        let functions = Functions.functions(region: "us-central1")
        let callable = functions.httpsCallable("generateWeeklyReport")

        var payload: [String: Any] = [
            "questions": questions.map { $0.text },
            "answers": answers,
            "weekNumber": weekNumber,
            "year": year,
            "dateRange": dateRange,
        ]
        if let previousScores = previousScores {
            payload["previousScores"] = previousScores
        }

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(payload)
        } catch let error as NSError {
            #if DEBUG
            print("[CheckIn] Cloud Function failed: code=\(error.code) domain=\(error.domain) msg=\(error.localizedDescription)")
            #endif
            if error.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: error.code) {
                switch code {
                case .unauthenticated: throw CheckInAIError.notAuthenticated
                case .alreadyExists:   throw CheckInAIError.alreadyExists
                default: break
                }
            }
            throw CheckInAIError.network(error.localizedDescription)
        }

        guard let dict = result.data as? [String: Any] else {
            throw CheckInAIError.invalidResponse
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(WeeklyReport.self, from: data)
        } catch {
            #if DEBUG
            print("[CheckIn] decode failed: \(error)")
            #endif
            throw CheckInAIError.decodeFailed
        }
        #else
        throw CheckInAIError.notConfigured
        #endif
    }
}
