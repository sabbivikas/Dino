//
//  MoodDayView.swift
//  DinoLiveActivity
//
//  Day (12pm–8pm) mood scene for small + medium families.
//  Day sky + clouds + hills + mood pills. Medium also shows mascot-day.
//

import SwiftUI
import WidgetKit

// MARK: - Small (day)

struct MoodDaySmallView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodDay

            // Clouds top
            CloudsShape()
                .frame(height: 80)
                .frame(maxHeight: .infinity, alignment: .top)

            // Hills bottom
            VStack {
                Spacer()
                HillsShape(palette: .day)
                    .frame(height: 55)
            }

            // Text + pills top-to-bottom
            VStack(alignment: .leading, spacing: 0) {
                Text("today")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.dinoInk.opacity(0.75))
                    .textCase(.uppercase)
                Text("how are\nyou feeling?")
                    .font(WidgetTheme.widgetFont(size: 16))
                    .foregroundColor(DinoPalette.dinoInk)
                    .lineLimit(2)
                    .padding(.top, 2)

                Spacer()

                HStack(spacing: 5) {
                    MoodPill(label: "calm")
                    MoodPill(label: "okay")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Medium (day)

struct MoodDayMediumView: View {
    let entry: MoodSnapshot

    private let pills = ["calm", "happy", "okay", "low"]

    var body: some View {
        ZStack {
            WidgetGradients.moodDay

            // Clouds across the top
            CloudsShape()
                .frame(height: 70)
                .frame(maxHeight: .infinity, alignment: .top)

            // Hills bottom
            VStack {
                Spacer()
                HillsShape(palette: .day)
                    .frame(height: 55)
            }

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("mood check-in")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.dinoInk.opacity(0.75))
                        .textCase(.uppercase)

                    Text("how are you\nfeeling today?")
                        .font(WidgetTheme.widgetFont(size: 20))
                        .foregroundColor(DinoPalette.dinoInk)
                        .lineLimit(2)
                        .padding(.top, 2)

                    Spacer()

                    // Mood pills — wrap to two rows by HStack-on-HStack
                    HStack(spacing: 5) {
                        MoodPill(label: pills[0])
                        MoodPill(label: pills[1])
                        MoodPill(label: pills[2])
                        MoodPill(label: pills[3])
                    }
                }
                .padding(.vertical, 12)
                .padding(.leading, 14)

                Spacer(minLength: 0)

                Image("WidgetMascotDay")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .offset(x: 8, y: 10)
            }
        }
    }
}
