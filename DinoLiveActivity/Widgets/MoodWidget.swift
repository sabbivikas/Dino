//
//  MoodWidget.swift
//  DinoLiveActivity
//
//  Home-screen mood check-in widget. Small + Medium. The three scenes
//  (morning / day / night) swap on schedule via timeline boundary entries.
//
//  kind = "MoodCheckInWidget" preserved so existing user-placed widgets survive.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct MoodTimelineProvider: TimelineProvider {
    typealias Entry = MoodSnapshot

    func placeholder(in context: Context) -> MoodSnapshot {
        MoodSnapshot(
            date: Date(),
            timeOfDay: .day,
            sceneAnimPhase: 0,
            lastMoodEmoji: "🌤"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodSnapshot) -> Void) {
        let now = Date()
        let data = WidgetDataProvider()
        completion(MoodSnapshot(
            date: now,
            timeOfDay: DinoTimeOfDay.from(date: now),
            sceneAnimPhase: 0,
            lastMoodEmoji: data.todayMoodEmoji
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodSnapshot>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let data = WidgetDataProvider()
        let moodEmoji = data.todayMoodEmoji

        // 1. Build 6 entries per hour at 10-min cadence, starting at the next 10-min boundary.
        var entries: [MoodSnapshot] = []

        // Starting snapshot at "now"
        entries.append(MoodSnapshot(
            date: now,
            timeOfDay: DinoTimeOfDay.from(date: now),
            sceneAnimPhase: 0,
            lastMoodEmoji: moodEmoji
        ))

        // Align to next 10-min boundary
        let minute = calendar.component(.minute, from: now)
        let delta = (10 - (minute % 10)) % 10
        var startBoundary = calendar.date(byAdding: .minute, value: delta == 0 ? 10 : delta, to: now) ?? now
        // Zero seconds
        startBoundary = calendar.date(
            bySettingHour: calendar.component(.hour, from: startBoundary),
            minute: calendar.component(.minute, from: startBoundary),
            second: 0,
            of: startBoundary
        ) ?? startBoundary

        for step in 0..<6 {
            let d = calendar.date(byAdding: .minute, value: step * 10, to: startBoundary) ?? startBoundary
            entries.append(MoodSnapshot(
                date: d,
                timeOfDay: DinoTimeOfDay.from(date: d),
                sceneAnimPhase: (step + 1) % 6,
                lastMoodEmoji: moodEmoji
            ))
        }

        // 2. Insert boundary entries at the next 6:00 / 12:00 / 20:00 for exact scene flips.
        for hour in [6, 12, 20] {
            var boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            if boundary <= now {
                boundary = calendar.date(byAdding: .day, value: 1, to: boundary) ?? boundary
            }
            entries.append(MoodSnapshot(
                date: boundary,
                timeOfDay: DinoTimeOfDay.from(date: boundary),
                sceneAnimPhase: 0,
                lastMoodEmoji: moodEmoji
            ))
        }

        // 3. Sort + de-dup by date
        entries.sort { $0.date < $1.date }
        var dedup: [MoodSnapshot] = []
        for e in entries {
            if dedup.last?.date != e.date { dedup.append(e) }
        }

        let last = dedup.last?.date ?? now.addingTimeInterval(3600)
        let timeline = Timeline(entries: dedup, policy: .after(last))
        completion(timeline)
    }
}

// MARK: - Widget Declaration

struct MoodWidget: Widget {
    /// IMPORTANT: `kind` MUST remain "MoodCheckInWidget" so previously placed
    /// instances on the home screen continue to render without being orphaned.
    let kind: String = "MoodCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodTimelineProvider()) { entry in
            MoodWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("mood check-in")
        .description("quick tap to log how you're feeling")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MoodWidget()
} timeline: {
    MoodSnapshot(date: .now, timeOfDay: .morning, sceneAnimPhase: 0, lastMoodEmoji: "🌤")
    MoodSnapshot(date: .now, timeOfDay: .day,     sceneAnimPhase: 2, lastMoodEmoji: "🌤")
    MoodSnapshot(date: .now, timeOfDay: .night,   sceneAnimPhase: 4, lastMoodEmoji: "🌤")
}
