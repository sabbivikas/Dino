//
//  WeeklyCheckInView.swift
//  Dino
//

import SwiftUI
import UIKit

private enum CIPalette {
    static let cream    = Color(hex: "#FAF6EC")
    static let sage     = Color(hex: "#A8C5A0")
    static let ink      = Color(hex: "#2E2A24")
    static let muted    = Color(hex: "#7A7266")
    static let amber    = Color(hex: "#F5C842")
    static let softRed  = Color(hex: "#E8645A")
    static let divider  = Color(hex: "#E5DECC")
    static let darkBg   = Color(hex: "#1A1A2E")
    static let card     = Color.white
}

struct WeeklyCheckInView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case entry
        case questions
        case generating
        case report(WeeklyCheckInResult)
    }

    @State private var phase: Phase = .entry
    @State private var answers: [Int?] = []
    @State private var currentIndex: Int = 0
    @State private var errorText: String?

    // Week metadata, computed once.
    private let weekNumber: Int
    private let year: Int
    private let dateRange: String
    private let questions: [CheckInQuestion]

    init() {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let week = cal.component(.weekOfYear, from: now)
        let year = cal.component(.yearForWeekOfYear, from: now)
        self.weekNumber = week
        self.year = year
        self.dateRange = Self.dateRangeString(for: now, calendar: cal)
        self.questions = CheckInQuestions.forWeek(week)
    }

    var body: some View {
        ZStack {
            (phase == .generating ? CIPalette.darkBg : CIPalette.cream)
                .ignoresSafeArea()

            Group {
                switch phase {
                case .entry:
                    EntryView(
                        weekNumber: weekNumber,
                        dateRange: dateRange,
                        existing: existingThisWeek(),
                        onBegin: startQuestions,
                        onViewReport: { result in withAnimation { phase = .report(result) } },
                        onDismiss: { dismiss() }
                    )
                case .questions:
                    QuestionView(
                        weekNumber: weekNumber,
                        questions: questions,
                        answers: $answers,
                        currentIndex: $currentIndex,
                        onFinish: finishAndGenerate,
                        onCancel: { dismiss() }
                    )
                case .generating:
                    GeneratingView(
                        errorText: errorText,
                        onRetry: finishAndGenerate,
                        onCancel: { withAnimation { phase = .questions; errorText = nil } }
                    )
                case .report(let result):
                    ReportView(
                        result: result,
                        userName: dataManager.userName,
                        onDismiss: { dismiss() }
                    )
                }
            }
            .transition(.opacity)
        }
        .onAppear { AnalyticsManager.shared.trackAssessmentStarted() }
    }

    // MARK: - Flow

    private func startQuestions() {
        answers = Array(repeating: nil, count: questions.count)
        currentIndex = 0
        withAnimation { phase = .questions }
    }

    private func finishAndGenerate() {
        errorText = nil
        withAnimation { phase = .generating }
        let answered = answers.map { $0 ?? 0 }
        let prev = dataManager.weeklyCheckIns.first
        let previousScores: [String: Int]?
        if let p = prev {
            previousScores = [
                "overallScore": p.report.overallScore,
                "moodEnergyScore": p.report.moodEnergyScore,
                "anxietyStressScore": p.report.anxietyStressScore,
                "wellbeingScore": p.report.wellbeingScore,
            ]
        } else {
            previousScores = nil
        }
        Task {
            do {
                let report = try await CheckInAIService.shared.generateReport(
                    weekNumber: weekNumber,
                    year: year,
                    dateRange: dateRange,
                    questions: questions,
                    answers: answered,
                    previousScores: previousScores
                )
                let result = WeeklyCheckInResult(
                    weekNumber: weekNumber,
                    year: year,
                    dateRange: dateRange,
                    questions: questions.map { $0.text },
                    answers: answered,
                    report: report
                )
                await MainActor.run {
                    dataManager.addWeeklyCheckIn(result)
                    AnalyticsManager.shared.trackAssessmentCompleted(score: report.overallScore)
                    withAnimation { phase = .report(result) }
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func existingThisWeek() -> WeeklyCheckInResult? {
        if let latest = dataManager.weeklyCheckIns.first,
           latest.weekNumber == weekNumber, latest.year == year {
            return latest
        }
        return nil
    }

    // MARK: - Helpers

    private static func dateRangeString(for date: Date, calendar: Calendar) -> String {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86400)
        let start = interval.start
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: start).lowercased()
        let endStr: String
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "d"
            endStr = dayFmt.string(from: end)
        } else {
            endStr = fmt.string(from: end).lowercased()
        }
        return "\(startStr)–\(endStr)"
    }
}

// MARK: - Entry

private struct EntryView: View {
    let weekNumber: Int
    let dateRange: String
    let existing: WeeklyCheckInResult?
    let onBegin: () -> Void
    let onViewReport: (WeeklyCheckInResult) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CIPalette.muted)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text("week \(weekNumber) · \(dateRange)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CIPalette.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            Image.cached("DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .padding(.bottom, 24)

            Text("weekly check-in")
                .font(DinoTheme.dinoFont(size: 28))
                .foregroundColor(CIPalette.ink)
                .padding(.bottom, 10)

            Text("a few questions to understand how you've been")
                .font(.system(size: 14, weight: .regular).italic())
                .foregroundColor(CIPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 18)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("this takes about 3-5 minutes")
                    .font(.system(size: 12))
            }
            .foregroundColor(CIPalette.muted)
            .padding(.bottom, 28)

            if let existing = existing {
                VStack(spacing: 14) {
                    Text("you completed this week's check-in ✓")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CIPalette.sage)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onViewReport(existing)
                    } label: {
                        Text("view report")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(CIPalette.sage))
                    }
                }
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onBegin()
                } label: {
                    HStack(spacing: 6) {
                        Text("begin check-in")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(CIPalette.sage))
                }
            }

            Spacer()

            Text("this is a personal reflection tool and not a medical diagnosis.")
                .font(.system(size: 10))
                .foregroundColor(CIPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 18)
        }
    }
}

// MARK: - Questions

private struct QuestionView: View {
    let weekNumber: Int
    let questions: [CheckInQuestion]
    @Binding var answers: [Int?]
    @Binding var currentIndex: Int
    let onFinish: () -> Void
    let onCancel: () -> Void

    private var current: CheckInQuestion { questions[currentIndex] }
    private var currentAnswer: Int? { answers[currentIndex] }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button(action: back) {
                    Image(systemName: currentIndex == 0 ? "xmark" : "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CIPalette.muted)
                        .frame(width: 32, height: 32)
                }
                progressBar
                Text("\(currentIndex + 1) of \(questions.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(CIPalette.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer().frame(height: 32)

            HStack {
                Text(String(format: "%02d", currentIndex + 1))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CIPalette.muted)
                Spacer()
            }
            .padding(.horizontal, 24)

            Text(current.text)
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(CIPalette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .id(currentIndex)
                .transition(.opacity)

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                ForEach(AnswerOption.allCases, id: \.rawValue) { opt in
                    answerCard(opt)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text("there are no wrong answers 🌿")
                .font(.system(size: 12).italic())
                .foregroundColor(CIPalette.muted)
                .padding(.bottom, 12)

            Button(action: nextTapped) {
                HStack(spacing: 6) {
                    Text(currentIndex == questions.count - 1 ? "finish" : "next")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Capsule().fill(currentAnswer != nil ? CIPalette.sage : CIPalette.muted.opacity(0.4)))
            }
            .disabled(currentAnswer == nil)
            .padding(.bottom, 28)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<questions.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentIndex ? CIPalette.sage : CIPalette.divider)
                        .frame(height: 4)
                }
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 4)
    }

    private func answerCard(_ opt: AnswerOption) -> some View {
        let selected = currentAnswer == opt.rawValue
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) {
                answers[currentIndex] = opt.rawValue
            }
        } label: {
            HStack {
                Text(opt.label)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .white : CIPalette.ink)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? CIPalette.sage : CIPalette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? CIPalette.sage : CIPalette.divider, lineWidth: 1)
                    )
            )
            .scaleEffect(selected ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selected)
        }
        .buttonStyle(.plain)
    }

    private func back() {
        if currentIndex == 0 {
            onCancel()
        } else {
            withAnimation { currentIndex -= 1 }
        }
    }

    private func nextTapped() {
        guard currentAnswer != nil else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if currentIndex == questions.count - 1 {
            onFinish()
        } else {
            withAnimation { currentIndex += 1 }
        }
    }
}

// MARK: - Generating

private struct GeneratingView: View {
    let errorText: String?
    let onRetry: () -> Void
    let onCancel: () -> Void

    @State private var stageIndex = 0
    @State private var dotPhase: CGFloat = 0
    private let stages = [
        "looking at your patterns...",
        "understanding your week...",
        "writing your report...",
        "almost ready..."
    ]

    var body: some View {
        VStack {
            Spacer()
            Image.cached("DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .padding(.bottom, 24)
                .opacity(errorText == nil ? 1 : 0.8)

            if let err = errorText {
                VStack(spacing: 16) {
                    Text("something went sideways")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("cancel")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Capsule().stroke(Color.white.opacity(0.3)))
                        }
                        Button(action: onRetry) {
                            Text("try again")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(CIPalette.sage))
                        }
                    }
                }
            } else {
                Text(stages[stageIndex])
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .id(stageIndex)
                    .transition(.opacity)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotPhase == CGFloat(i) ? 1.3 : 0.8)
                            .opacity(dotPhase == CGFloat(i) ? 1.0 : 0.5)
                    }
                }
                .padding(.top, 24)
                .task { await animateDots() }
            }

            Spacer()
        }
        .task { await runStages() }
    }

    @MainActor
    private func runStages() async {
        var index = stageIndex
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, errorText == nil else { return }
            index = (index + 1) % stages.count
            withAnimation { stageIndex = index }
        }
    }

    @MainActor
    private func animateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, errorText == nil else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                dotPhase = CGFloat((Int(dotPhase) + 1) % 3)
            }
        }
    }
}

// MARK: - Report

private struct ReportView: View {
    let result: WeeklyCheckInResult
    let userName: String
    let onDismiss: () -> Void

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showExporter = false
    @State private var exporterURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CIPalette.muted)
                        .frame(width: 32, height: 32)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("your week \(result.weekNumber) report")
                            .font(DinoTheme.dinoFont(size: 24))
                            .foregroundColor(CIPalette.ink)
                        Text(result.dateRange)
                            .font(.system(size: 12))
                            .foregroundColor(CIPalette.muted)
                    }
                    .padding(.top, 4)

                    overallCard
                    scoreCards
                    reflectionCard
                    trendCard
                    actionButtons
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showExporter) {
            if let url = exporterURL { DocumentExporter(url: url) }
        }
        .onAppear {
            AnalyticsManager.shared.trackScreenViewed("weekly_checkin_report")
        }
    }

    private var overallCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(CIPalette.divider, lineWidth: 10)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: CGFloat(result.report.overallScore) / 100.0)
                    .stroke(scoreColor(result.report.overallScore),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(result.report.overallScore)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundColor(CIPalette.ink)
                    Text("/ 100")
                        .font(.system(size: 11))
                        .foregroundColor(CIPalette.muted)
                }
            }
            HStack(spacing: 6) {
                Text(result.report.overallEmoji)
                    .font(.system(size: 20))
                Text(result.report.overallLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CIPalette.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 18).fill(CIPalette.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CIPalette.divider, lineWidth: 1))
    }

    private var scoreCards: some View {
        VStack(spacing: 10) {
            scoreRow(label: "mood & energy",
                     score: result.report.moodEnergyScore,
                     insight: result.report.moodEnergyInsight)
            scoreRow(label: "anxiety & stress",
                     score: result.report.anxietyStressScore,
                     insight: result.report.anxietyStressInsight)
            scoreRow(label: "well-being",
                     score: result.report.wellbeingScore,
                     insight: result.report.wellbeingInsight)
        }
    }

    private func scoreRow(label: String, score: Int, insight: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(CIPalette.divider, lineWidth: 4)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CIPalette.ink)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CIPalette.ink)
                Text(insight)
                    .font(.system(size: 12))
                    .foregroundColor(CIPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(CIPalette.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CIPalette.divider, lineWidth: 1))
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("this week's reflection")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CIPalette.ink)
            Text(result.report.weeklyReflection)
                .font(.system(size: 13))
                .foregroundColor(CIPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(CIPalette.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CIPalette.divider, lineWidth: 1))
    }

    private var trendCard: some View {
        HStack(spacing: 12) {
            Text(trendIcon)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.report.trend)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CIPalette.ink)
                Text(result.report.trendNote)
                    .font(.system(size: 12))
                    .foregroundColor(CIPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(trendTint.opacity(0.15)))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: download) {
                HStack(spacing: 6) {
                    Text("download report")
                    Text("📄")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(CIPalette.sage))
            }
            Button(action: share) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("share")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CIPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().stroke(CIPalette.divider, lineWidth: 1))
            }
        }
    }

    private var disclaimer: some View {
        Text("this is a personal reflection tool and not a medical diagnosis. please consult a professional for clinical concerns.")
            .font(.system(size: 10).italic())
            .foregroundColor(CIPalette.muted)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var trendIcon: String {
        switch result.report.trend.lowercased() {
        case let s where s.contains("improv"): return "↑"
        case let s where s.contains("needs"):  return "↓"
        default: return "→"
        }
    }

    private var trendTint: Color {
        switch result.report.trend.lowercased() {
        case let s where s.contains("improv"): return CIPalette.sage
        case let s where s.contains("needs"):  return CIPalette.softRed
        default: return CIPalette.amber
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 70...: return CIPalette.sage
        case 40...: return CIPalette.amber
        default:    return CIPalette.softRed
        }
    }

    private func download() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let url = try CheckInPDFRenderer.render(result: result, userName: userName)
            exporterURL = url
            showExporter = true
        } catch {
            #if DEBUG
            print("[CheckIn] pdf render failed: \(error)")
            #endif
        }
    }

    private func share() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let url = try CheckInPDFRenderer.render(result: result, userName: userName)
            shareURL = url
            showShare = true
        } catch {
            #if DEBUG
            print("[CheckIn] pdf render failed: \(error)")
            #endif
        }
    }
}

// MARK: - Share / Exporter wrappers (local to this file)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

private struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
}
