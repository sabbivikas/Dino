//
//  BreathingWidget.swift
//  DinoLiveActivity
//
//  Home-screen breathing widget. Small + medium. Hand-drawn 5-petal bloom
//  scaled by a timeline-driven `breathPhase` for a subtle pseudo-breath cycle.
//  Deep links to `dino://breathe`.
//
//  kind = "BreathingWidget" preserved from the prior implementation.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct BreathingTimelineProvider: TimelineProvider {
    typealias Entry = BreathingSnapshot

    /// 6 breath-phase keyframes → scale = 0.92 + 0.16 * sin(phase * 2π).
    /// Walks from ~0.92 at phase 0 through 1.08 at phase ~0.25 back down.
    private let breathPhases: [Double] = [0.0, 0.167, 0.333, 0.5, 0.667, 0.833]

    private func scaleFor(_ phase: Double) -> Double {
        0.92 + 0.16 * (0.5 + 0.5 * sin(phase * 2 * .pi))
    }

    func placeholder(in context: Context) -> BreathingSnapshot {
        BreathingSnapshot(date: Date(), breathPhase: 1.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (BreathingSnapshot) -> Void) {
        completion(BreathingSnapshot(date: Date(), breathPhase: 1.0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreathingSnapshot>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        var entries: [BreathingSnapshot] = []

        // Starting entry at now
        entries.append(BreathingSnapshot(date: now, breathPhase: scaleFor(breathPhases[0])))

        // 6 entries at 10-min cadence starting at the next 10-min boundary
        let minute = calendar.component(.minute, from: now)
        let delta = (10 - (minute % 10)) % 10
        var startBoundary = calendar.date(byAdding: .minute, value: delta == 0 ? 10 : delta, to: now) ?? now
        startBoundary = calendar.date(
            bySettingHour: calendar.component(.hour, from: startBoundary),
            minute: calendar.component(.minute, from: startBoundary),
            second: 0,
            of: startBoundary
        ) ?? startBoundary

        for step in 0..<6 {
            let d = calendar.date(byAdding: .minute, value: step * 10, to: startBoundary) ?? startBoundary
            entries.append(BreathingSnapshot(
                date: d,
                breathPhase: scaleFor(breathPhases[(step + 1) % breathPhases.count])
            ))
        }

        let last = entries.last?.date ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(last)))
    }
}

// MARK: - Entry View

struct BreathingWidgetEntryView: View {
    let entry: BreathingSnapshot
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                BreathingSmallView(entry: entry)
            case .systemMedium:
                BreathingMediumView(entry: entry)
            default:
                BreathingSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "dino://breathe"))
        // The gradient must live in the container background — on iOS 17+ the
        // system renders the widget through `.containerBackground`, so a
        // `.clear` container renders blank. The closure form (as MoodWidget
        // uses) supplies a real background and still sizes to the system frame.
        .containerBackground(for: .widget) { WidgetGradients.breathing }
    }
}

// MARK: - Widget Declaration

struct BreathingWidget: Widget {
    let kind: String = "BreathingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BreathingTimelineProvider()) { entry in
            BreathingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("breathe")
        .description("tap anytime for a one-minute breathing reset")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    BreathingWidget()
} timeline: {
    BreathingSnapshot(date: .now, breathPhase: 1.0)
    BreathingSnapshot(date: .now, breathPhase: 1.08)
}
