//
//  BreathingView.swift
//  Dino
//

import SwiftUI

struct BreathingView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: BreathingViewModel = BreathingViewModel(dataManager: SharedDataManager.shared)
    @StateObject private var audio = AudioManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DinoTheme.background.ignoresSafeArea()

                if viewModel.phase == .done {
                    DoneScreen(viewModel: viewModel, onDismiss: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 6) {
                            Text("breathe")
                                .font(DinoTheme.dinoDisplayFont(size: 28))
                                .foregroundColor(DinoTheme.textPrimary)
                            Text("slow down, you're safe here")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                        .padding(.top, 16)

                        // Breathing circle
                        BreathingCircle(
                            scale: viewModel.circleScale,
                            opacity: viewModel.circleOpacity,
                            phase: viewModel.phase,
                            countdown: viewModel.phaseCountdown
                        )

                        // Timer
                        if viewModel.isRunning {
                            Text(viewModel.formattedTimeRemaining)
                                .font(DinoTheme.numericFont(size: 22))
                                .foregroundColor(DinoTheme.textPrimary)
                                .transition(.opacity)
                        }

                        // Cycle indicator while running
                        if viewModel.isRunning {
                            Text("cycle \(viewModel.currentCycle) of \(viewModel.totalCycles)")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }

                        // Duration selector (before start)
                        if !viewModel.isRunning {
                            VStack(spacing: 12) {
                                Text("session length")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)

                                HStack(spacing: 12) {
                                    ForEach(viewModel.durationOptions, id: \.seconds) { option in
                                        Button(action: {
                                            viewModel.selectedDuration = option.seconds
                                        }) {
                                            Text(option.label)
                                                .font(DinoTheme.captionFont())
                                                .fontWeight(.semibold)
                                                .foregroundColor(viewModel.selectedDuration == option.seconds ? .white : DinoTheme.textPrimary)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    viewModel.selectedDuration == option.seconds
                                                        ? DinoTheme.sageGreen
                                                        : DinoTheme.cardBackground
                                                )
                                                .cornerRadius(DinoTheme.cornerRadius)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                                        .stroke(
                                                            viewModel.selectedDuration == option.seconds
                                                                ? DinoTheme.sageGreen
                                                                : DinoTheme.divider,
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                            }
                        }

                        // Pattern label
                        HStack(spacing: 8) {
                            Text("4s inhale")
                            Text("·").foregroundColor(DinoTheme.divider)
                            Text("4s hold")
                            Text("·").foregroundColor(DinoTheme.divider)
                            Text("4s exhale")
                        }
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)

                        Spacer()

                        // Controls
                        VStack(spacing: 12) {
                            // Start / Stop button
                            Button(action: {
                                withAnimation {
                                    if viewModel.isRunning {
                                        viewModel.stop()
                                    } else {
                                        viewModel.start()
                                    }
                                }
                            }) {
                                Text(viewModel.isRunning ? "stop" : "begin")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(viewModel.isRunning ? Color.red.opacity(0.8) : DinoTheme.sageGreen)
                                    .cornerRadius(DinoTheme.largeCornerRadius)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            // Pause / Resume button (only when running)
                            if viewModel.isRunning {
                                Button(action: {
                                    withAnimation {
                                        if viewModel.isPaused {
                                            viewModel.resume()
                                        } else {
                                            viewModel.pause()
                                        }
                                    }
                                }) {
                                    Text(viewModel.isPaused ? "resume" : "pause")
                                        .font(DinoTheme.headlineFont())
                                        .foregroundColor(DinoTheme.sageGreen)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(DinoTheme.sageGreen.opacity(0.1))
                                        .cornerRadius(DinoTheme.largeCornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                                                .stroke(DinoTheme.sageGreen.opacity(0.4), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isRunning {
                        Button(action: {
                            if audio.isPlaying {
                                audio.pause()
                            } else {
                                audio.resume()
                            }
                        }) {
                            Image(systemName: audio.isPlaying ? "speaker.wave.2" : "speaker.slash")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .onDisappear {
            viewModel.stop()
            AudioManager.shared.stop()
        }
        .onChange(of: viewModel.isRunning) { running in
            if running {
                AudioManager.shared.play(track: "breathing_ambient")
                AudioManager.shared.fadeIn(duration: 2.0)
            } else {
                AudioManager.shared.stop()
            }
        }
        .onChange(of: viewModel.isPaused) { paused in
            if paused {
                AudioManager.shared.pause()
            } else if viewModel.isRunning {
                AudioManager.shared.resume()
            }
        }
    }
}

// MARK: - Done Screen
struct DoneScreen: View {
    @ObservedObject var viewModel: BreathingViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🌿")
                .font(.system(size: 70))

            VStack(spacing: 10) {
                Text("well done")
                    .font(DinoTheme.dinoDisplayFont(size: 28))
                    .foregroundColor(DinoTheme.textPrimary)

                Text("you took time for yourself.")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }

            // Stats
            HStack(spacing: 20) {
                StatPill(label: "session", value: viewModel.formattedElapsed, color: DinoTheme.sageGreen)
                StatPill(label: "pattern", value: "4-4-4", color: DinoTheme.skyBlue)
                StatPill(label: "xp earned", value: "+20", color: DinoTheme.peach)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("breathe again")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(DinoTheme.sageGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.sageGreen.opacity(0.1))
                        .cornerRadius(DinoTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                .stroke(DinoTheme.sageGreen.opacity(0.4), lineWidth: 1.5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onDismiss) {
                    Text("done")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.sageGreen)
                        .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DinoTheme.padding)
            .padding(.bottom, 32)
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.textPrimary)
            Text(label)
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.12))
        .cornerRadius(DinoTheme.cornerRadius)
    }
}
