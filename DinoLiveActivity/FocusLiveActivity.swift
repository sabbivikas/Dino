//
//  FocusLiveActivity.swift
//  DinoLiveActivity
//
//  Live Activity UI for focus / Pomodoro sessions.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Focus Live Activity Widget

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FocusExpandedBottom(context: context)
                }
            } compactLeading: {
                Text("🎯")
                    .font(.system(size: 14))
            } compactTrailing: {
                Text(formatTime(context.state.secondsRemaining))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#A8D4E6"))
                    .monospacedDigit()
            } minimal: {
                Text("🎯")
                    .font(.system(size: 12))
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Lock Screen View

struct FocusLockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    private let skyBlue = Color(hex: "#A8D4E6")

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("🎯")
                            .font(.system(size: 20))
                        Text(context.state.isPaused ? "paused" : "deep focus")
                            .font(.custom("DinoInitiativeFont-Regular", size: 16))
                            .foregroundColor(.white)
                    }

                    Text(context.state.motivationMessage)
                        .font(.custom("DinoInitiativeFont-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                Text(formatTime(context.state.secondsRemaining))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(skyBlue)
                        .frame(width: geo.size.width * context.state.progress, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "#2D3142"), skyBlue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Dynamic Island Expanded

struct FocusExpandedLeading: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        HStack(spacing: 6) {
            Text("🎯")
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.isPaused ? "paused" : "deep focus")
                    .font(.custom("DinoInitiativeFont-Regular", size: 13))
                    .foregroundColor(.white)
                Text(context.state.motivationMessage)
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 4)
    }
}

struct FocusExpandedTrailing: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    private let skyBlue = Color(hex: "#A8D4E6")

    var body: some View {
        Text(formatTime(context.state.secondsRemaining))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(skyBlue)
            .monospacedDigit()
            .padding(.trailing, 4)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct FocusExpandedBottom: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    private let skyBlue = Color(hex: "#A8D4E6")

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(skyBlue)
                        .frame(width: geo.size.width * context.state.progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 4)

            Text("focus session · dino")
                .font(.custom("DinoInitiativeFont-Regular", size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 4)
    }
}
