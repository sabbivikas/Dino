//
//  DailyAffirmationWidget.swift
//  DinoLiveActivity
//
//  Home screen widget showing a daily affirmation that rotates each day.
//  Tapping opens the app via dino://affirmation deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Affirmations

private let affirmations: [String] = [
    "I am enough, exactly as I am.",
    "Each breath brings me closer to peace.",
    "I choose calm over chaos.",
    "My feelings are valid and worth honoring.",
    "I give myself permission to rest.",
    "Growth happens one small step at a time.",
    "I am worthy of love and kindness.",
    "Today I choose to be gentle with myself.",
    "I trust the process of my own journey.",
    "My presence is a gift to the world.",
    "I release what I cannot control.",
    "I am stronger than I think.",
    "Stillness is my superpower.",
    "I deserve joy, even in small moments.",
    "I am becoming the best version of myself.",
    "My mind is calm, my heart is open.",
    "I welcome new beginnings with ease.",
    "I am grateful for this moment.",
    "Every day is a fresh start.",
    "I radiate warmth and compassion.",
    "I honor my need for rest and renewal.",
    "I am exactly where I need to be.",
    "My inner peace is unshakeable.",
    "I attract what I put into the world.",
    "I am learning and that is enough.",
    "Small steps forward still move me forward.",
    "I choose kindness — starting with myself.",
    "This too shall pass, and I am okay.",
    "I embrace the beauty of today.",
    "I am rooted, resilient, and at peace."
]

private func todayAffirmation() -> String {
    let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let index = (dayOfYear - 1) % affirmations.count
    return affirmations[index]
}

// MARK: - Timeline Entry

struct DailyAffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
}

// MARK: - Timeline Provider

struct DailyAffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyAffirmationEntry {
        DailyAffirmationEntry(date: Date(), affirmation: "I am enough, exactly as I am.")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyAffirmationEntry) -> Void) {
        completion(DailyAffirmationEntry(date: Date(), affirmation: todayAffirmation()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAffirmationEntry>) -> Void) {
        var entries: [DailyAffirmationEntry] = []
        let calendar = Calendar.current

        // Generate entries for today + next 6 days
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) else { continue }
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) ?? 1
            let index = (dayOfYear - 1) % affirmations.count
            entries.append(DailyAffirmationEntry(date: day, affirmation: affirmations[index]))
        }

        // Refresh at start of next day
        let tomorrow = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: entries, policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Visual primitives

private let affirmationBackground = LinearGradient(
    colors: [Color(hex: "#EEE4F5"), Color(hex: "#DCC9E8")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let affirmationInk      = Color(hex: "#3D2A5A")
private let affirmationInkSoft  = Color(hex: "#6F5FB3")
private let affirmationAccent   = Color(hex: "#8B6FD1")

private struct SparkleGlyph: View {
    var size: CGFloat = 18
    var color: Color = affirmationAccent

    var body: some View {
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: size * 0.18, height: size)
            Capsule()
                .fill(color)
                .frame(width: size, height: size * 0.18)
            Circle()
                .fill(color)
                .frame(width: size * 0.32, height: size * 0.32)
        }
        .frame(width: size, height: size)
    }
}

private struct QuoteMark: View {
    var size: CGFloat
    var closing: Bool = false

    var body: some View {
        Text(closing ? "\u{201D}" : "\u{201C}")
            .font(.custom("DinoInitiativeFont-Regular", size: size))
            .foregroundColor(affirmationAccent.opacity(0.55))
    }
}

private struct AffirmationDateText: View {
    var body: some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMM d"
            return f
        }()
        return Text(formatter.string(from: Date()).lowercased())
            .font(.custom("DinoInitiativeFont-Regular", size: 12))
            .foregroundColor(affirmationInkSoft)
    }
}

// MARK: - Widget Views

struct DailyAffirmationSmallView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                SparkleGlyph(size: 16)
                SparkleGlyph(size: 10, color: affirmationAccent.opacity(0.6))
                    .offset(y: -4)
            }

            Text(affirmation)
                .font(.custom("DinoInitiativeFont-Regular", size: 16))
                .foregroundColor(affirmationInk)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("today")
                .font(.custom("DinoInitiativeFont-Regular", size: 10))
                .foregroundColor(affirmationInkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DailyAffirmationMediumView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                QuoteMark(size: 36)
                SparkleGlyph(size: 22, color: affirmationAccent.opacity(0.75))
                Spacer(minLength: 0)
                Text("today")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(affirmationInkSoft)
            }
            .frame(width: 56)

            Divider()
                .background(affirmationAccent.opacity(0.25))
                .frame(height: 90)

            VStack(alignment: .leading, spacing: 8) {
                Text(affirmation)
                    .font(.custom("DinoInitiativeFont-Regular", size: 19))
                    .foregroundColor(affirmationInk)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("sit with it for a breath")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(affirmationInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

struct DailyAffirmationLargeView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                SparkleGlyph(size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("daily affirmation")
                        .font(.custom("DinoInitiativeFont-Regular", size: 18))
                        .foregroundColor(affirmationInk)
                    AffirmationDateText()
                }
                Spacer()
                SparkleGlyph(size: 14, color: affirmationAccent.opacity(0.6))
            }

            QuoteMark(size: 28)
                .padding(.top, -6)

            Text(affirmation)
                .font(.custom("DinoInitiativeFont-Regular", size: 30))
                .foregroundColor(affirmationInk)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            QuoteMark(size: 28, closing: true)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)

            HStack {
                Text("reflect on this today")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(affirmationInkSoft)
                Spacer()
                Text("tap to journal →")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(affirmationAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DailyAffirmationEntryView: View {
    let entry: DailyAffirmationEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                DailyAffirmationSmallView(affirmation: entry.affirmation, theme: theme)
            case .systemMedium:
                DailyAffirmationMediumView(affirmation: entry.affirmation, theme: theme)
            case .systemLarge:
                DailyAffirmationLargeView(affirmation: entry.affirmation, theme: theme)
            default:
                DailyAffirmationSmallView(affirmation: entry.affirmation, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://affirmation"))
        // The gradient must live in the container background — on iOS 17+ the
        // system renders the widget through `.containerBackground`, so a
        // `.clear` container renders blank. The closure form supplies a real
        // background and still sizes to the system frame.
        .containerBackground(for: .widget) { affirmationBackground }
    }
}

// MARK: - Widget Declaration

struct DailyAffirmationWidget: Widget {
    let kind: String = "DailyAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAffirmationProvider()) { entry in
            DailyAffirmationEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("A calming affirmation that changes every day to ground and inspire you.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    DailyAffirmationWidget()
} timeline: {
    DailyAffirmationEntry(date: .now, affirmation: "I am enough, exactly as I am.")
}
