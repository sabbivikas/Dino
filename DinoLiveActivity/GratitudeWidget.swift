//
//  GratitudeWidget.swift
//  DinoLiveActivity
//
//  Home screen widget for tracking daily gratitude entries.
//  Tapping opens the app's gratitude jar via dino://gratitude deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct GratitudeEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    let totalCount: Int
}

// MARK: - Timeline Provider

struct GratitudeProvider: TimelineProvider {
    func placeholder(in context: Context) -> GratitudeEntry {
        GratitudeEntry(date: Date(), todayCount: 2, totalCount: 47)
    }

    func getSnapshot(in context: Context, completion: @escaping (GratitudeEntry) -> Void) {
        let data = WidgetDataProvider()
        completion(GratitudeEntry(
            date: Date(),
            todayCount: data.todayGratitudeCount,
            totalCount: data.totalGratitudeCount
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GratitudeEntry>) -> Void) {
        let data = WidgetDataProvider()
        let entry = GratitudeEntry(
            date: Date(),
            todayCount: data.todayGratitudeCount,
            totalCount: data.totalGratitudeCount
        )
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Visual primitives

private let gratitudeBackground = LinearGradient(
    colors: [Color(hex: "#FDEBE0"), Color(hex: "#F7D5C5")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private struct JarView: View {
    var size: CGFloat = 80

    private var height: CGFloat { size * 110.0 / 80.0 }

    var body: some View {
        let glass = Color(hex: "#F4D8C8").opacity(0.55)
        let stroke = Color(hex: "#C26A1E").opacity(0.55)
        let cork = Color(hex: "#C26A1E")
        let slipColors: [Color] = [
            Color(hex: "#F5A245"),
            Color(hex: "#FCD56B"),
            Color(hex: "#F4A79A"),
            Color(hex: "#FBE3C2")
        ]

        ZStack {
            // Cork / lid
            RoundedRectangle(cornerRadius: size * 0.10)
                .fill(cork)
                .frame(width: size * 0.55, height: size * 0.13)
                .offset(y: -height * 0.46)

            // Jar body
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(glass)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .stroke(stroke, lineWidth: 1.5)
                )
                .frame(width: size, height: height * 0.82)
                .offset(y: height * 0.04)

            // Paper slips inside
            ZStack {
                slip(color: slipColors[0], width: size * 0.55, rotation: -8)
                    .offset(x: -size * 0.06, y: height * 0.06)
                slip(color: slipColors[1], width: size * 0.5, rotation: 6)
                    .offset(x: size * 0.10, y: height * 0.14)
                slip(color: slipColors[2], width: size * 0.45, rotation: -4)
                    .offset(x: -size * 0.04, y: height * 0.22)
                slip(color: slipColors[3], width: size * 0.4, rotation: 10)
                    .offset(x: size * 0.07, y: height * 0.30)
            }
        }
        .frame(width: size, height: height)
    }

    private func slip(color: Color, width: CGFloat, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: width, height: 6)
            .rotationEffect(.degrees(rotation))
    }
}

private struct DualStrokeProgressBar: View {
    let progress: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0.0, min(1.0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#F4D8C8").opacity(0.5))
                    .frame(height: height)
                Capsule()
                    .stroke(Color(hex: "#C26A1E").opacity(0.55), lineWidth: 1)
                    .frame(height: height)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#F5A245"))
                        .frame(height: height)
                    Capsule()
                        .stroke(Color(hex: "#C26A1E"), lineWidth: 1.2)
                        .frame(height: height)
                        .offset(x: 1, y: 1)
                }
                .frame(width: max(height, geo.size.width * clamped))
                .clipShape(Capsule())
            }
        }
        .frame(height: height + 1)
    }
}

// MARK: - Widget Views

struct GratitudeSmallView: View {
    let todayCount: Int
    let theme: WidgetTheme

    var body: some View {
        VStack(spacing: 4) {
            JarView(size: 56)

            Text("\(todayCount)")
                .font(.custom("DinoInitiativeFont-Regular", size: 32))
                .foregroundColor(Color(hex: "#C26A1E"))

            Text(todayCount == 1 ? "gratitude today" : "gratitudes today")
                .font(.custom("DinoInitiativeFont-Regular", size: 10))
                .foregroundColor(Color(hex: "#8A4A1A"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(gratitudeBackground)
    }
}

struct GratitudeMediumView: View {
    let todayCount: Int
    let totalCount: Int
    let theme: WidgetTheme

    private let dailyGoal = 3
    private var fillFraction: Double {
        min(Double(todayCount) / Double(dailyGoal), 1.0)
    }

    private var encouragement: String {
        switch todayCount {
        case 0:  return "what are you grateful\nfor today?"
        case 1:  return "a great start —\nwhat else?"
        case 2:  return "almost there —\none more slip?"
        default: return "your jar is full of\ngood things ✨"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            JarView(size: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text("today's jar")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(Color(hex: "#8A4A1A"))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(todayCount)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 34))
                        .foregroundColor(Color(hex: "#C26A1E"))
                    Text("of \(dailyGoal)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 13))
                        .foregroundColor(Color(hex: "#8A4A1A"))
                }

                Text(encouragement)
                    .font(.custom("DinoInitiativeFont-Regular", size: 13))
                    .foregroundColor(Color(hex: "#4A2A10"))
                    .lineLimit(2)

                Spacer(minLength: 4)

                DualStrokeProgressBar(progress: fillFraction, height: 8)

                Text("\(totalCount) slips total")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(Color(hex: "#8A4A1A").opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(gratitudeBackground)
    }
}

struct GratitudeLargeView: View {
    let todayCount: Int
    let totalCount: Int
    let theme: WidgetTheme

    private let dailyGoal = 3
    private var fillFraction: Double {
        min(Double(todayCount) / Double(dailyGoal), 1.0)
    }

    private var encouragement: String {
        switch todayCount {
        case 0:  return "what are you grateful for today?"
        case 1:  return "a great start — what else?"
        case 2:  return "almost there — one more slip?"
        default: return "your jar is full of good things ✨"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                JarView(size: 86)

                VStack(alignment: .leading, spacing: 4) {
                    Text("gratitude jar")
                        .font(.custom("DinoInitiativeFont-Regular", size: 22))
                        .foregroundColor(Color(hex: "#4A2A10"))
                    Text("\(totalCount) slips total")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(Color(hex: "#8A4A1A"))
                    Spacer(minLength: 0)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(todayCount)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 36))
                        .foregroundColor(Color(hex: "#C26A1E"))
                    Text("of \(dailyGoal)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 11))
                        .foregroundColor(Color(hex: "#8A4A1A"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("today's progress")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(Color(hex: "#8A4A1A"))

                DualStrokeProgressBar(progress: fillFraction, height: 12)

                Text("\(todayCount) of \(dailyGoal) daily gratitudes added")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(Color(hex: "#8A4A1A").opacity(0.7))
            }

            Text(encouragement)
                .font(.custom("DinoInitiativeFont-Regular", size: 16))
                .foregroundColor(Color(hex: "#4A2A10"))
                .multilineTextAlignment(.leading)

            Spacer()

            Text("tap to add a gratitude →")
                .font(.custom("DinoInitiativeFont-Regular", size: 13))
                .foregroundColor(Color(hex: "#C26A1E"))
        }
        .padding(16)
        .background(gratitudeBackground)
    }
}

struct GratitudeWidgetEntryView: View {
    let entry: GratitudeEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                GratitudeSmallView(todayCount: entry.todayCount, theme: theme)
            case .systemMedium:
                GratitudeMediumView(
                    todayCount: entry.todayCount,
                    totalCount: entry.totalCount,
                    theme: theme
                )
            case .systemLarge:
                GratitudeLargeView(
                    todayCount: entry.todayCount,
                    totalCount: entry.totalCount,
                    theme: theme
                )
            default:
                GratitudeSmallView(todayCount: entry.todayCount, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://gratitude"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct GratitudeWidget: Widget {
    let kind: String = "GratitudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GratitudeProvider()) { entry in
            GratitudeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Gratitude Jar")
        .description("See how many gratitudes you've added today and keep the jar filling up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    GratitudeWidget()
} timeline: {
    GratitudeEntry(date: .now, todayCount: 2, totalCount: 47)
}
