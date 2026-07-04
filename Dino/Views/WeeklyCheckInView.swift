//
//  WeeklyCheckInView.swift
//  Dino
//
//  Four-phase weekly check-in: entry → questions (10) → generating → report.
//  All paths safe: zero force unwraps, service never throws.
//

import SwiftUI

struct WeeklyCheckInView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    enum Phase { case entry, questions, generating, report }

    @State private var phase: Phase = .entry
    @State private var currentQuestion: Int = 0
    @State private var answers: [Int] = Array(repeating: -1, count: 10)
    @State private var generatedReport: WeeklyReport? = nil
    @State private var generatedResult: WeeklyCheckInResult? = nil

    private static let questions: [String] = [
        "over the past week, how often have you felt little interest or pleasure in doing things?",
        "over the past week, how often have you felt down, depressed, or hopeless?",
        "over the past week, how often have you felt nervous, anxious, or on edge?",
        "over the past week, how often have you not been able to stop or control worrying?",
        "over the past week, how often have you had trouble falling or staying asleep?",
        "over the past week, how often have you felt tired or had little energy?",
        "over the past week, how often have you felt cheerful and in good spirits?",
        "over the past week, how often have you felt calm and relaxed?",
        "over the past week, how often have you woken up feeling fresh and rested?",
        "over the past week, how often has your daily life been filled with things that interest you?"
    ]

    private static let optionLabels = [
        "not at all",
        "several days",
        "more than half the days",
        "nearly every day"
    ]

    // Tokens
    private let cream      = Color(hex: "#FAF6EC")
    private let sage       = Color(hex: "#A8C5A0")
    private let darkInk    = Color(hex: "#2E2A24")
    private let mutedInk   = Color(hex: "#7A7266")
    private let amber      = Color(hex: "#F5C842")
    private let softRed    = Color(hex: "#E8645A")
    private let darkBg     = Color(hex: "#1A1A2E")

    var body: some View {
        Group {
            switch phase {
            case .entry:
                EntryView(
                    cream: cream, sage: sage, darkInk: darkInk, mutedInk: mutedInk,
                    alreadyCompleted: alreadyCompletedThisWeek,
                    existingResult: existingResultThisWeek,
                    onBegin: { withAnimation(.easeInOut) { phase = .questions } },
                    onViewExisting: { result in
                        generatedReport = result.report
                        generatedResult = result
                        withAnimation(.easeInOut) { phase = .report }
                    },
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            case .questions:
                QuestionView(
                    cream: cream, sage: sage, darkInk: darkInk, mutedInk: mutedInk,
                    questions: Self.questions,
                    optionLabels: Self.optionLabels,
                    currentQuestion: $currentQuestion,
                    answers: $answers,
                    onBack: {
                        if currentQuestion == 0 {
                            withAnimation(.easeInOut) { phase = .entry }
                        } else {
                            withAnimation(.easeInOut) { currentQuestion -= 1 }
                        }
                    },
                    onAdvance: {
                        if currentQuestion == Self.questions.count - 1 {
                            withAnimation(.easeInOut) { phase = .generating }
                        } else {
                            withAnimation(.easeInOut) { currentQuestion += 1 }
                        }
                    }
                )
                .transition(.opacity)
            case .generating:
                GeneratingView(darkBg: darkBg)
                    .transition(.opacity)
                    .task { await runGeneration() }
            case .report:
                ReportView(
                    cream: cream, sage: sage, amber: amber, softRed: softRed,
                    darkInk: darkInk, mutedInk: mutedInk,
                    report: generatedReport ?? fallbackReport(),
                    weekNumber: currentWeek,
                    dateRange: currentDateRange,
                    onSave: { saveAndClose() },
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: phase)
        .onAppear {
            AnalyticsManager.shared.trackScreen("weekly_checkin")
            AnalyticsManager.shared.trackAssessmentStarted()
        }
    }

    // MARK: - Helpers

    private var currentWeek: Int {
        let cal = Calendar.current
        return cal.component(.weekOfYear, from: Date())
    }

    private var currentYear: Int {
        let cal = Calendar.current
        return cal.component(.yearForWeekOfYear, from: Date())
    }

    private var currentDateRange: String {
        let cal = Calendar.current
        let now = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else {
            return ""
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = fmt.string(from: weekInterval.start)
        let endDate = cal.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        let end = fmt.string(from: endDate)
        return "\(start) \u{2013} \(end)"
    }

    private var alreadyCompletedThisWeek: Bool {
        existingResultThisWeek != nil
    }

    private var existingResultThisWeek: WeeklyCheckInResult? {
        dataManager.weeklyCheckIns.first {
            $0.weekNumber == currentWeek && $0.year == currentYear
        }
    }

    private func runGeneration() async {
        let qa: [(String, Int)] = Self.questions.enumerated().map { idx, q in
            let raw = idx < answers.count ? answers[idx] : 0
            return (q, max(0, min(3, raw)))
        }
        let report = await WeeklyCheckInService.shared.generateReport(
            weekNumber: currentWeek,
            year: currentYear,
            dateRange: currentDateRange,
            questionsAndAnswers: qa,
            previousScores: nil
        )
        let result = WeeklyCheckInResult(
            id: UUID(),
            weekNumber: currentWeek,
            year: currentYear,
            dateRange: currentDateRange,
            completedAt: Date(),
            report: report
        )
        await MainActor.run {
            generatedReport = report
            generatedResult = result
            AnalyticsManager.shared.trackWeeklyCheckInCompleted()
            withAnimation(.easeInOut) { phase = .report }
        }
    }

    private func fallbackReport() -> WeeklyReport {
        WeeklyReport(
            overallScore: 70,
            overallLabel: "thanks for checking in",
            overallEmoji: "\u{1F33F}",
            moodEnergyScore: 70,
            moodEnergyInsight: "keep noticing how your week feels.",
            anxietyStressScore: 70,
            anxietyStressInsight: "small steady steps add up.",
            wellbeingScore: 70,
            wellbeingInsight: "you showed up. that matters.",
            weeklyReflection: "thanks for taking a few minutes for yourself.",
            trend: "stable",
            trendNote: "keep going"
        )
    }

    private func saveAndClose() {
        if let result = generatedResult {
            dataManager.addWeeklyCheckIn(result)
        }
        dismiss()
    }
}

// MARK: - Entry

private struct EntryView: View {
    let cream: Color
    let sage: Color
    let darkInk: Color
    let mutedInk: Color
    let alreadyCompleted: Bool
    let existingResult: WeeklyCheckInResult?
    let onBegin: () -> Void
    let onViewExisting: (WeeklyCheckInResult) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image.cached("DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Text("weekly check-in")
                    .font(DinoTheme.dinoFont(size: 28))
                    .foregroundColor(darkInk)

                Text("a few questions to understand how you've been")
                    .font(.system(size: 14).italic())
                    .foregroundColor(mutedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("this takes about 3 minutes")
                    .font(.system(size: 12))
                    .foregroundColor(mutedInk.opacity(0.8))

                if alreadyCompleted, let existing = existingResult {
                    VStack(spacing: 12) {
                        Text("you completed this week \u{2713}")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(sage)
                        Button(action: { onViewExisting(existing) }) {
                            Text("view report")
                                .font(DinoTheme.dinoFont(size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(sage))
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Button(action: onBegin) {
                        Text("begin check-in \u{2192}")
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(sage))
                    }
                    .padding(.top, 8)
                }

                Spacer()

                Text("this is a reflection tool, not a clinical diagnosis.")
                    .font(.system(size: 10))
                    .foregroundColor(mutedInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(mutedInk)
                    .padding(12)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}

// MARK: - Question

private struct QuestionView: View {
    let cream: Color
    let sage: Color
    let darkInk: Color
    let mutedInk: Color
    let questions: [String]
    let optionLabels: [String]
    @Binding var currentQuestion: Int
    @Binding var answers: [Int]
    let onBack: () -> Void
    let onAdvance: () -> Void

    private var currentAnswer: Int {
        guard currentQuestion < answers.count else { return -1 }
        return answers[currentQuestion]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cream.ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress bar — 10 segments
                HStack(spacing: 4) {
                    ForEach(0..<questions.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= currentQuestion ? sage : mutedInk.opacity(0.18))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)

                Text("question \(currentQuestion + 1) of \(questions.count)")
                    .font(.system(size: 12))
                    .foregroundColor(mutedInk)

                Spacer().frame(height: 8)

                Text(safeQuestion)
                    .font(DinoTheme.dinoFont(size: 22))
                    .foregroundColor(darkInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .id(currentQuestion)
                    .transition(.opacity)

                VStack(spacing: 12) {
                    ForEach(0..<optionLabels.count, id: \.self) { idx in
                        OptionCard(
                            label: optionLabels[idx],
                            isSelected: currentAnswer == idx,
                            sage: sage,
                            cream: cream,
                            darkInk: darkInk,
                            mutedInk: mutedInk,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if currentQuestion < answers.count {
                                        answers[currentQuestion] = idx
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)

                Text("there are no wrong answers \u{1F33F}")
                    .font(.system(size: 12).italic())
                    .foregroundColor(mutedInk)

                Spacer()

                Button(action: {
                    guard currentAnswer >= 0 else { return }
                    onAdvance()
                }) {
                    Text(currentQuestion == questions.count - 1 ? "finish \u{2192}" : "next \u{2192}")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(currentAnswer >= 0 ? sage : mutedInk.opacity(0.4))
                        )
                }
                .disabled(currentAnswer < 0)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)

            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(darkInk)
                    .padding(12)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }

    private var safeQuestion: String {
        guard currentQuestion < questions.count else { return "" }
        return questions[currentQuestion]
    }
}

private struct OptionCard: View {
    let label: String
    let isSelected: Bool
    let sage: Color
    let cream: Color
    let darkInk: Color
    let mutedInk: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(isSelected ? .white : darkInk)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? sage : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? sage : mutedInk.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generating

private struct GeneratingView: View {
    let darkBg: Color

    @State private var messageIndex: Int = 0
    @State private var dotPhase: Int = 0

    private let messages = [
        "looking at your patterns...",
        "understanding your week...",
        "writing your report...",
        "almost ready..."
    ]

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 28) {
                Image.cached("DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Text(safeMessage)
                    .font(DinoTheme.dinoFont(size: 18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .id(messageIndex)
                    .transition(.opacity)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(dotPhase == i ? 0.9 : 0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .task {
            await rotateMessages()
        }
        .task {
            await rotateDots()
        }
    }

    private var safeMessage: String {
        guard messageIndex < messages.count else { return messages.last ?? "" }
        return messages[messageIndex]
    }

    private func rotateMessages() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { break }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }

    private func rotateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { break }
            await MainActor.run {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

// MARK: - Report

private struct ReportView: View {
    let cream: Color
    let sage: Color
    let amber: Color
    let softRed: Color
    let darkInk: Color
    let mutedInk: Color
    let report: WeeklyReport
    let weekNumber: Int
    let dateRange: String
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 48)

                    Text("your week \(weekNumber) report")
                        .font(DinoTheme.dinoFont(size: 24))
                        .foregroundColor(darkInk)

                    Text(dateRange)
                        .font(.system(size: 13))
                        .foregroundColor(mutedInk)

                    if report.isMock == true {
                        Text("offline summary")
                            .font(DinoTheme.dinoFont(size: 12))
                            .foregroundColor(sage)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }

                    // Overall gauge
                    OverallGauge(
                        score: report.overallScore,
                        label: report.overallLabel,
                        emoji: report.overallEmoji,
                        sage: sage, amber: amber, softRed: softRed,
                        darkInk: darkInk, mutedInk: mutedInk
                    )
                    .padding(.top, 8)

                    // Sub-scores
                    VStack(spacing: 14) {
                        ScoreCard(
                            title: "mood & energy",
                            score: report.moodEnergyScore,
                            insight: report.moodEnergyInsight,
                            sage: sage, amber: amber, softRed: softRed,
                            darkInk: darkInk, mutedInk: mutedInk
                        )
                        ScoreCard(
                            title: "anxiety & stress",
                            score: report.anxietyStressScore,
                            insight: report.anxietyStressInsight,
                            sage: sage, amber: amber, softRed: softRed,
                            darkInk: darkInk, mutedInk: mutedInk
                        )
                        ScoreCard(
                            title: "well-being",
                            score: report.wellbeingScore,
                            insight: report.wellbeingInsight,
                            sage: sage, amber: amber, softRed: softRed,
                            darkInk: darkInk, mutedInk: mutedInk
                        )
                    }
                    .padding(.horizontal, 20)

                    // Reflection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("this week's reflection")
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(darkInk)
                        Text(report.weeklyReflection)
                            .font(.system(size: 14))
                            .foregroundColor(darkInk.opacity(0.85))
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                    )
                    .padding(.horizontal, 20)

                    // Trend
                    HStack(spacing: 8) {
                        Text(report.trendNote)
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(darkInk)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(sage.opacity(0.18))
                    )

                    Button(action: onSave) {
                        Text("save")
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(.white)
                            .padding(.horizontal, 56)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(sage))
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(mutedInk)
                    .padding(12)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}

private struct OverallGauge: View {
    let score: Int
    let label: String
    let emoji: String
    let sage: Color
    let amber: Color
    let softRed: Color
    let darkInk: Color
    let mutedInk: Color

    private var color: Color {
        switch score {
        case 70...: return sage
        case 40...: return amber
        default: return softRed
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(mutedInk.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(DinoTheme.dinoFont(size: 44))
                        .foregroundColor(darkInk)
                    Text("out of 100")
                        .font(.system(size: 11))
                        .foregroundColor(mutedInk)
                }
            }
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 18))
                Text(label)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(darkInk)
            }
        }
    }
}

private struct ScoreCard: View {
    let title: String
    let score: Int
    let insight: String
    let sage: Color
    let amber: Color
    let softRed: Color
    let darkInk: Color
    let mutedInk: Color

    private var color: Color {
        switch score {
        case 70...: return sage
        case 40...: return amber
        default: return softRed
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(mutedInk.opacity(0.15), lineWidth: 5)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(darkInk)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(darkInk)
                Text(insight)
                    .font(.system(size: 13))
                    .foregroundColor(darkInk.opacity(0.8))
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
    }
}
