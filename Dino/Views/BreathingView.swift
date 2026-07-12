//
//  BreathingView.swift
//  Dino
//

import SwiftUI
import UIKit

struct BreathingView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: BreathingViewModel = BreathingViewModel(dataManager: SharedDataManager.shared)
    @StateObject private var audio = AudioManager.shared
    @Environment(\.dismiss) private var dismiss

    private let phaseTick = UIImpactFeedbackGenerator(style: .light)
    @State private var hapticsOn = BreathingHaptics.isEnabled

    private var breathingCircle: some View {
        BreathingCircle(
            scale: viewModel.circleScale,
            opacity: viewModel.circleOpacity,
            label: viewModel.phaseLabel,
            countdown: viewModel.phaseCountdown,
            accent: viewModel.selectedPattern.accent,
            quarterRingProgress: viewModel.quarterRingProgress,
            emptying: viewModel.selectedPattern.thinsOnExhale && viewModel.phase == .exhale,
            paused: viewModel.isPaused
        )
    }

    private var stepsCaption: String {
        viewModel.selectedPattern.steps
            .map { "\($0.seconds)s \($0.shortLabel)" }
            .joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Atmosphere background
                BreathingAtmosphere()
                    .ignoresSafeArea()

                // The breath you can feel — quiet toggle, hidden entirely on
                // devices without CoreHaptics (no dead switch, ever).
                if BreathingHaptics.deviceSupported {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                hapticsOn.toggle()
                                BreathingHaptics.isEnabled = hapticsOn
                                if !hapticsOn { BreathingHaptics.shared.stop() }
                            } label: {
                                Image(systemName: "water.waves")
                                    .font(.system(size: 16))
                                    .foregroundColor(DinoTheme.textSecondary.opacity(hapticsOn ? 0.85 : 0.35))
                                    .padding(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(hapticsOn ? "breathing haptics on" : "breathing haptics off")
                        }
                        Spacer()
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                if viewModel.phase == .done {
                    DoneScreen(viewModel: viewModel, onDismiss: { dismiss() })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 24) {
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

                        if viewModel.isRunning {
                            Spacer()

                            breathingCircle

                            // Timer
                            Text(viewModel.formattedTimeRemaining)
                                .font(DinoTheme.numericFont(size: 22))
                                .foregroundColor(DinoTheme.textPrimary)
                                .transition(.opacity)

                            // Cycle indicator
                            Text("cycle \(viewModel.currentCycle) of \(viewModel.totalCycles)")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)

                            // Pattern reminder
                            HStack(spacing: 8) {
                                Text(viewModel.selectedPattern.name)
                                Text("·").foregroundColor(DinoTheme.divider)
                                Text(stepsCaption)
                            }
                            .font(DinoTheme.captionFont())
                            .foregroundColor(DinoTheme.textSecondary)

                            Spacer()
                        } else {
                            // Adaptive coach entry: feeling → thinking →
                            // recommendation. The session engine below is
                            // untouched — the flow only hands back a pattern
                            // and minutes on an explicit begin tap.
                            ScrollView(showsIndicators: false) {
                                BreathingCoachFlow(onBegin: { pattern, minutes in
                                    viewModel.selectedPattern = pattern
                                    viewModel.selectedDuration = minutes * 60
                                    withAnimation { viewModel.start() }
                                })
                                .padding(.horizontal, DinoTheme.padding)
                                .padding(.top, 4)
                            }
                        }

                        // Controls — session only; the coach flow owns begin
                        if viewModel.isRunning {
                        VStack(spacing: 12) {
                            // Stop button
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
                                    .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous))
                                    .shadow(color: DinoTheme.sageGreen.opacity(0.3), radius: 8, y: 3)
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
                                        .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous)
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
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            AnalyticsManager.shared.trackScreen("breathing")
            #if DEBUG
            // -breathQARun: start a session on arrival so the breathing water
            // is screenshotable without tapping through the coach.
            if ProcessInfo.processInfo.arguments.contains("-breathQARun"),
               !viewModel.isRunning {
                viewModel.start()
            }
            #endif
        }
        .onDisappear {
            viewModel.stop()
            AudioManager.shared.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if viewModel.isRunning { viewModel.recalculateFromTimestamp() }
        }
        .onChange(of: viewModel.stepIndex) { _, idx in
            guard idx >= 0, viewModel.isRunning else { return }
            // the continuous tide replaces the discrete tick — both together
            // would read as a notification buzz, the one forbidden feeling
            if !(hapticsOn && BreathingHaptics.deviceSupported) {
                // the top up inhale gets a lighter tick so the double breath is felt
                phaseTick.impactOccurred(intensity: viewModel.isTopUpStep ? 0.55 : 0.9)
            }
        }
        .onChange(of: viewModel.isRunning) { _, running in
            if running {
                AudioManager.shared.play(track: "breathing_ambient")
                AudioManager.shared.fadeIn(duration: 2.0)
            } else {
                AudioManager.shared.stop()
            }
        }
        .onChange(of: viewModel.isPaused) { _, paused in
            if paused {
                AudioManager.shared.pause()
            } else if viewModel.isRunning {
                AudioManager.shared.resume()
            }
        }
    }
}

// MARK: - Atmosphere Background

private struct BreathingAtmosphere: View {
    var body: some View {
        ZStack {
            // Vertical gradient: #E6F1EA → #F5F8F3 → #EFE9D8
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#E6F1EA"), location: 0),
                    .init(color: Color(hex: "#F5F8F3"), location: 0.7),
                    .init(color: Color(hex: "#EFE9D8"), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Drifting clouds
            BreathingCloud(yFraction: 0.10, scale: 1.0, opacity: 0.75, driftDuration: 32)
            BreathingCloud(yFraction: 0.22, scale: 0.75, opacity: 0.75, driftDuration: 48)
            BreathingCloud(yFraction: 0.38, scale: 0.6, opacity: 0.55, driftDuration: 40)

            // Floating leaves
            BreathingLeaf(yFraction: 0.60, color: Color(hex: "#A8C5A0"), driftDuration: 14, delay: 0)
            BreathingLeaf(yFraction: 0.72, color: Color(hex: "#C5D9A8"), driftDuration: 18, delay: 4)
            BreathingLeaf(yFraction: 0.50, color: Color(hex: "#E8B4B8"), driftDuration: 20, delay: 11)
            BreathingLeaf(yFraction: 0.85, color: Color(hex: "#F5C6AA"), driftDuration: 16, delay: 6)

            // Breeze wisps
            BreezeWisp(yFraction: 0.35, driftDuration: 9, delay: 0)
            BreezeWisp(yFraction: 0.65, driftDuration: 11, delay: 3)
            BreezeWisp(yFraction: 0.80, driftDuration: 13, delay: 6)
        }
    }
}

// MARK: - Drifting Cloud

private struct BreathingCloud: View {
    let yFraction: CGFloat
    let scale: CGFloat
    let opacity: Double
    let driftDuration: Double

    @State private var driftOffset: CGFloat = -0.25

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let w: CGFloat = 90 * scale
                let h: CGFloat = 36 * scale
                var cloud = Path()
                cloud.move(to: CGPoint(x: 18/90 * w, y: 10/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 8/90 * w, y: 18/36 * h),
                                   control: CGPoint(x: 8/90 * w, y: 10/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 0, y: 24/36 * h),
                                   control: CGPoint(x: 0, y: 18/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 10/90 * w, y: 32/36 * h),
                                   control: CGPoint(x: 0, y: 32/36 * h))
                cloud.addLine(to: CGPoint(x: 78/90 * w, y: 32/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: w, y: 22/36 * h),
                                   control: CGPoint(x: w, y: 32/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 80/90 * w, y: 14/36 * h),
                                   control: CGPoint(x: w, y: 14/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 64/90 * w, y: 4/36 * h),
                                   control: CGPoint(x: 78/90 * w, y: 4/36 * h))
                cloud.addQuadCurve(to: CGPoint(x: 38/90 * w, y: 8/36 * h),
                                   control: CGPoint(x: 50/90 * w, y: 0))
                cloud.addQuadCurve(to: CGPoint(x: 18/90 * w, y: 10/36 * h),
                                   control: CGPoint(x: 30/90 * w, y: 2/36 * h))
                cloud.closeSubpath()
                context.opacity = opacity
                context.fill(cloud, with: .color(.white.opacity(0.95)))
                context.stroke(cloud, with: .color(Color(hex: "#A8B8C8")),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            .frame(width: 90 * scale, height: 36 * scale)
            .position(x: geo.size.width * driftOffset, y: geo.size.height * yFraction)
        }
        .onAppear {
            // Start from random position for variety
            driftOffset = CGFloat.random(in: -0.2...0.3)
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                driftOffset = 1.25
            }
        }
    }
}

// MARK: - Floating Leaf

private struct BreathingLeaf: View {
    let yFraction: CGFloat
    let color: Color
    let driftDuration: Double
    let delay: Double

    @State private var xOffset: CGFloat = -0.1
    @State private var rotation: Double = 0
    @State private var bobOffset: CGFloat = 0
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                var leaf = Path()
                leaf.move(to: CGPoint(x: size.width / 2, y: 0))
                leaf.addQuadCurve(to: CGPoint(x: size.width / 2, y: size.height),
                                  control: CGPoint(x: size.width, y: size.height / 2))
                leaf.addQuadCurve(to: CGPoint(x: size.width / 2, y: 0),
                                  control: CGPoint(x: 0, y: size.height / 2))
                leaf.closeSubpath()
                // Vein
                var vein = Path()
                vein.move(to: CGPoint(x: size.width / 2, y: 1))
                vein.addLine(to: CGPoint(x: size.width / 2, y: size.height - 1))
                context.fill(leaf, with: .color(color))
                context.stroke(vein, with: .color(color.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 0.8))
            }
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(rotation))
            .position(
                x: geo.size.width * xOffset,
                y: geo.size.height * yFraction + bobOffset
            )
            .opacity(started ? 1 : 0)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                started = true
                withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                    xOffset = 1.15
                }
                withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: driftDuration / 2).repeatForever(autoreverses: true)) {
                    bobOffset = -14
                }
            }
        }
    }
}

// MARK: - Breeze Wisp

private struct BreezeWisp: View {
    let yFraction: CGFloat
    let driftDuration: Double
    let delay: Double

    @State private var xOffset: CGFloat = -0.35
    @State private var wispOpacity: Double = 0
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                var wisp = Path()
                wisp.move(to: CGPoint(x: 0, y: size.height / 2))
                wisp.addQuadCurve(to: CGPoint(x: size.width * 0.5, y: size.height / 2),
                                  control: CGPoint(x: size.width * 0.25, y: 0))
                wisp.addQuadCurve(to: CGPoint(x: size.width, y: size.height / 2),
                                  control: CGPoint(x: size.width * 0.75, y: size.height))
                context.stroke(wisp, with: .color(Color(hex: "#A8C5A0").opacity(0.55)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            .frame(width: geo.size.width * 0.4, height: 6)
            .position(x: geo.size.width * xOffset, y: geo.size.height * yFraction)
            .opacity(wispOpacity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                started = true
                startWispCycle()
            }
        }
    }

    private func startWispCycle() {
        xOffset = -0.35
        wispOpacity = 0
        // Fade in during first 20%
        withAnimation(.easeIn(duration: driftDuration * 0.2)) {
            wispOpacity = 0.5
        }
        // Drift across
        withAnimation(.linear(duration: driftDuration)) {
            xOffset = 1.15
        }
        // Fade out during last 20%
        DispatchQueue.main.asyncAfter(deadline: .now() + driftDuration * 0.8) {
            withAnimation(.easeOut(duration: driftDuration * 0.2)) {
                wispOpacity = 0
            }
        }
        // Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + driftDuration) {
            startWispCycle()
        }
    }
}

// MARK: - Done Screen
struct DoneScreen: View {
    @ObservedObject var viewModel: BreathingViewModel
    let onDismiss: () -> Void
    @State private var showShareRow = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🌿")
                .font(.system(size: 70))
                .onAppear {
                    if ShareDino.shouldShowContextualNow() {
                        ShareDino.markContextualShown()
                        showShareRow = true
                    }
                }

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
                StatPill(label: "pattern", value: viewModel.selectedPattern.shortName, color: DinoTheme.skyBlue)
                StatPill(label: "xp earned", value: "+\(viewModel.xpEarned)", color: DinoTheme.peach)
            }

            Text(viewModel.selectedPattern.closingLine)
                .font(DinoTheme.subheadlineFont())
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DinoTheme.padding)

            // Share dino — the once-ever contextual moment (never naggy).
            if showShareRow {
                HStack(spacing: 10) {
                    ShareLink(item: ShareDino.appStoreURL,
                              message: Text(ShareDino.shareText)) {
                        HStack(spacing: 8) {
                            Text("🦕")
                            Text(ShareDino.contextualLine)
                                .font(DinoTheme.dinoFont(size: 13))
                                .foregroundColor(DinoTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Button {
                        withAnimation { showShareRow = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DinoTheme.padding)
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
