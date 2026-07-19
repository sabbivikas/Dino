//
//  AssessmentViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import PostHog

struct AssessmentQuestion {
    let topic: String
    let question: String
    let lowLabel: String
    let highLabel: String
}

@MainActor
class AssessmentViewModel: ObservableObject {
    @Published var currentQuestionIndex: Int = 0
    @Published var answers: [Int] = [0, 0, 0, 0, 0]
    @Published var isComplete: Bool = false
    @Published var savedResult: AssessmentResult? = nil

    let questions: [AssessmentQuestion] = [
        AssessmentQuestion(topic: "sleep", question: String(localized: "how well have you been sleeping?"), lowLabel: String(localized: "poorly"), highLabel: String(localized: "great")),
        AssessmentQuestion(topic: "energy", question: String(localized: "how's your energy been?"), lowLabel: String(localized: "very low"), highLabel: String(localized: "high")),
        AssessmentQuestion(topic: "stress", question: String(localized: "how stressed have you felt?"), lowLabel: String(localized: "very stressed"), highLabel: String(localized: "very calm")),
        AssessmentQuestion(topic: "mood", question: String(localized: "how would you rate your overall mood?"), lowLabel: String(localized: "low"), highLabel: String(localized: "great")),
        AssessmentQuestion(topic: "connection", question: String(localized: "how connected have you felt to others?"), lowLabel: String(localized: "isolated"), highLabel: String(localized: "very connected"))
    ]

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    var currentQuestion: AssessmentQuestion {
        questions[currentQuestionIndex]
    }

    var currentAnswer: Int {
        answers[currentQuestionIndex]
    }

    var totalScore: Int {
        answers.reduce(0, +)
    }

    var progress: Double {
        Double(currentQuestionIndex) / Double(questions.count)
    }

    func setAnswer(_ value: Int) {
        answers[currentQuestionIndex] = value
    }

    func next() {
        if currentQuestionIndex < questions.count - 1 {
            withAnimation {
                currentQuestionIndex += 1
            }
        } else {
            complete()
        }
    }

    func previous() {
        if currentQuestionIndex > 0 {
            withAnimation {
                currentQuestionIndex -= 1
            }
        }
    }

    private func complete() {
        let result = AssessmentResult(score: totalScore, answers: answers)
        dataManager.saveAssessmentResult(result)
        savedResult = result
        AnalyticsManager.shared.trackAssessmentCompleted(score: totalScore)
        withAnimation {
            isComplete = true
        }
    }

    func reset() {
        currentQuestionIndex = 0
        answers = [0, 0, 0, 0, 0]
        isComplete = false
        savedResult = nil
    }

    var recentResults: [AssessmentResult] {
        Array(dataManager.assessmentResults.prefix(4))
    }
}
