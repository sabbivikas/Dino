//
//  MoodWidgetView.swift
//  DinoLiveActivity
//
//  Root mood widget view. Branches on `widgetFamily` (small/medium) and
//  `timeOfDay` (morning/day/night). Applies the whole-widget deep link
//  `dino://mood` per the v1 decision (per-pill AppIntents deferred).
//

import SwiftUI
import WidgetKit

struct MoodWidgetEntryView: View {
    let entry: MoodSnapshot
    @Environment(\.widgetFamily) var family

    var body: some View {
        sceneView
            .widgetURL(URL(string: "dino://mood"))
            .containerBackground(for: .widget) {
                backgroundForTimeOfDay
            }
    }

    @ViewBuilder
    private var sceneView: some View {
        switch (entry.timeOfDay, family) {
        case (.morning, .systemSmall):
            MoodMorningSmallView(entry: entry)
        case (.morning, .systemMedium):
            MoodMorningMediumView(entry: entry)
        case (.day, .systemSmall):
            MoodDaySmallView(entry: entry)
        case (.day, .systemMedium):
            MoodDayMediumView(entry: entry)
        case (.night, .systemSmall):
            MoodNightSmallView(entry: entry)
        case (.night, .systemMedium):
            MoodNightMediumView(entry: entry)
        default:
            // Fallback for unsupported families
            MoodDaySmallView(entry: entry)
        }
    }

    /// Container background used when the widget system tints unrendered areas.
    /// Switches on time-of-day — rendered as a view (not a ShapeStyle) because
    /// the branches return different `LinearGradient` values.
    @ViewBuilder
    private var backgroundForTimeOfDay: some View {
        switch entry.timeOfDay {
        case .morning:
            WidgetGradients.moodMorning
        case .day:
            WidgetGradients.moodDay
        case .night:
            WidgetGradients.moodNight
        }
    }
}
