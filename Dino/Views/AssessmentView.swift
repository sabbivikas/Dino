//
//  AssessmentView.swift
//  Dino
//

import SwiftUI

struct AssessmentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: AssessmentViewModel = AssessmentViewModel(dataManager: SharedDataManager.shared)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
            if viewModel.isComplete, let result = viewModel.savedResult {
                AssessmentResultView(
                    result: result,
                    recentResults: viewModel.recentResults,
                    onDone: { dismiss() },
                    onRetake: { viewModel.reset() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                VStack(spacing: 0) {
                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("weekly check-in")
                                .font(DinoTheme.titleFont())
                                .foregroundColor(DinoTheme.textPrimary)
                            Spacer()
                            Text("\(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DinoTheme.divider)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DinoTheme.sageGreen)
                                    .frame(width: max(4, geo.size.width * (viewModel.progress + (1.0/5.0))), height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentQuestionIndex)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(DinoTheme.padding)

                    Spacer()

                    // Question
                    VStack(spacing: 32) {
                        Text(viewModel.currentQuestion.question)
                            .font(DinoTheme.dinoFont(size: 22))
                            .foregroundColor(DinoTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DinoTheme.largePadding)
                            .id(viewModel.currentQuestionIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                        // Scale buttons 1-5
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { value in
                                    Button(action: {
                                        withAnimation {
                                            viewModel.setAnswer(value)
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    viewModel.currentAnswer == value
                                                        ? DinoTheme.sageGreen
                                                        : DinoTheme.cardBackground
                                                )
                                                .frame(width: 52, height: 52)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            viewModel.currentAnswer == value
                                                                ? DinoTheme.sageGreen
                                                                : DinoTheme.divider,
                                                            lineWidth: 1.5
                                                        )
                                                )
                                                .shadow(
                                                    color: viewModel.currentAnswer == value
                                                        ? DinoTheme.sageGreen.opacity(0.3)
                                                        : .clear,
                                                    radius: 8, y: 3
                                                )

                                            Text("\(value)")
                                                .font(DinoTheme.headlineFont())
                                                .foregroundColor(
                                                    viewModel.currentAnswer == value ? .white : DinoTheme.textPrimary
                                                )
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }

                            HStack {
                                Text(viewModel.currentQuestion.lowLabel)
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                                Spacer()
                                Text(viewModel.currentQuestion.highLabel)
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    Spacer()
                    Spacer()

                    // Nav buttons
                    HStack(spacing: 16) {
                        if viewModel.currentQuestionIndex > 0 {
                            Button("back") { viewModel.previous() }
                                .font(DinoTheme.bodyFont())
                                .foregroundColor(DinoTheme.textSecondary)
                                .frame(width: 80)
                        }

                        Spacer()

                        Button(action: { viewModel.next() }) {
                            Text(viewModel.currentQuestionIndex == viewModel.questions.count - 1 ? "finish" : "next")
                                .font(DinoTheme.headlineFont())
                                .foregroundColor(.white)
                                .frame(width: 140)
                                .padding(.vertical, 16)
                                .background(
                                    viewModel.currentAnswer > 0
                                        ? DinoTheme.sageGreen
                                        : DinoTheme.textSecondary.opacity(0.5)
                                )
                                .cornerRadius(DinoTheme.cornerRadius)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(viewModel.currentAnswer == 0)
                    }
                    .padding(.horizontal, DinoTheme.largePadding)
                    .padding(.bottom, 40)
                }
                .background(DinoTheme.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("cancel") { dismiss() }
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
            }
            }
            .onAppear { AnalyticsManager.shared.trackAssessmentStarted() }
        }
    }
}

// MARK: - Result View
struct AssessmentResultView: View {
    let result: AssessmentResult
    let recentResults: [AssessmentResult]
    let onDone: () -> Void
    let onRetake: () -> Void

    var scoreColor: Color {
        switch result.score {
        case 20...: return DinoTheme.sageGreen
        case 15...: return DinoTheme.skyBlue
        case 10...: return DinoTheme.peach
        default: return DinoTheme.warmRose
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("✨")
                        .font(.system(size: 50))
                        .padding(.top, 24)

                    Text("check-in complete")
                        .font(DinoTheme.dinoDisplayFont(size: 28))
                        .foregroundColor(DinoTheme.textPrimary)

                    // Score ring
                    ZStack {
                        Circle()
                            .stroke(DinoTheme.divider, lineWidth: 10)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: CGFloat(result.score) / 25.0)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: result.score)

                        VStack(spacing: 2) {
                            Text("\(result.score)")
                                .font(DinoTheme.dinoDisplayFont(size: 28))
                                .foregroundColor(DinoTheme.textPrimary)
                            Text("/ 25")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                    }

                    Text(result.supportiveMessage)
                        .font(DinoTheme.bodyFont())
                        .foregroundColor(DinoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Bar chart of past scores
                if recentResults.count > 1 {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("recent check-ins")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)

                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(recentResults.reversed()) { r in
                                VStack(spacing: 6) {
                                    Text("\(r.score)")
                                        .font(DinoTheme.captionFont())
                                        .foregroundColor(DinoTheme.textSecondary)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(r.id == result.id ? DinoTheme.sageGreen : DinoTheme.sageGreen.opacity(0.3))
                                        .frame(width: 40, height: max(20, CGFloat(r.score) * 4))

                                    Text(r.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(DinoTheme.caption2Font())
                                        .foregroundColor(DinoTheme.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                    .padding(DinoTheme.padding)
                    .dinoCardWhite()
                    .padding(.horizontal, DinoTheme.padding)
                }

                VStack(spacing: 12) {
                    Button(action: onDone) {
                        Text("done")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DinoTheme.sageGreen)
                            .cornerRadius(DinoTheme.cornerRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: onRetake) {
                        Text("retake")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
                .padding(.horizontal, DinoTheme.padding)
                .padding(.bottom, 32)
            }
        }
        .background(DinoTheme.background.ignoresSafeArea())
    }
}
