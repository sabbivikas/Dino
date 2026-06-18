//
//  BreathingWidgetView.swift
//  DinoLiveActivity
//
//  Breathing widget bodies for small + medium families. Uses BreathingBloomShape
//  with Timeline-driven `breathPhase` for pseudo-breath animation (scale cycle).
//

import SwiftUI
import WidgetKit

// MARK: - Small

struct BreathingSmallView: View {
    let entry: BreathingSnapshot

    var body: some View {
        // Background now comes from the widget's `.containerBackground`.
        ZStack {
            VStack(spacing: 6) {
                BreathingBloomShape(breathPhase: entry.breathPhase)
                    .frame(width: 72, height: 72)

                Text("breathe")
                    .font(WidgetTheme.widgetFont(size: 16))
                    .foregroundColor(DinoPalette.dinoInk)

                Text("take 1 minute")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.dinoInk.opacity(0.7))
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium

struct BreathingMediumView: View {
    let entry: BreathingSnapshot

    var body: some View {
        // Background now comes from the widget's `.containerBackground`.
        ZStack {
            HStack(spacing: 16) {
                BreathingBloomShape(breathPhase: entry.breathPhase)
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text("breathe")
                        .font(WidgetTheme.widgetFont(size: 22))
                        .foregroundColor(DinoPalette.dinoInk)

                    Text("a mindful minute to\nreset and return to center")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.dinoInk.opacity(0.75))
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(DinoPalette.ink)
                                .frame(width: 18, height: 18)
                            // Play triangle
                            Path { p in
                                p.move(to: CGPoint(x: 7, y: 5))
                                p.addLine(to: CGPoint(x: 13, y: 9))
                                p.addLine(to: CGPoint(x: 7, y: 13))
                                p.closeSubpath()
                            }
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                        }
                        Text("start breathing")
                            .font(WidgetTheme.widgetFont(size: 12))
                            .foregroundColor(DinoPalette.ink)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
