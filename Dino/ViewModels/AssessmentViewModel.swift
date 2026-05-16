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
        AssessmentQuestion(topic: "sleep", question: "how well have you been sleeping?", lowLabel: "poorly", highLabel: "great"),
        AssessmentQuestion(topic: "energy", question: "how's your energy been?", lowLabel: "very low", highLabel: "high"),
        AssessmentQuestion(topic: "stress", question: "how stressed have you felt?", lowLabel: "very stressed", highLabel: "very calm"),
        AssessmentQuestion(topic: "mood", question: "how would you rate your overall mood?", lowLabel: "low", highLabel: "great"),
        AssessmentQuestion(topic: "connection", question: "how connected have you felt to others?", lowLabel: "isolated", highLabel: "very connected")
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
        PostHogSDK.shared.capture("assessment_completed", properties: [
            "total_score": totalScore,
            "sleep_score": answers[0],
            "energy_score": answers[1],
            "stress_score": answers[2],
            "mood_score": answers[3],
            "connection_score": answers[4],
        ])
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
