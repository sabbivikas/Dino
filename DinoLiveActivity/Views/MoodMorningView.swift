//
//  MoodMorningView.swift
//  DinoLiveActivity
//
//  Morning (6am–12pm) mood scene for small + medium families.
//  Sky gradient + sun (rotating per timeline phase) + hills + WidgetMascotMorning mascot.
//

import SwiftUI
import WidgetKit

// MARK: - Small (morning)

struct MoodMorningSmallView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodMorning

            // Sun top-left
            SunShape(rotationDegrees: Double(entry.sceneAnimPhase) * 6.0)
                .frame(width: 70, height: 70)
                .offset(x: -40, y: -40)

            // Hills across the bottom
            VStack {
                Spacer()
                HillsShape(palette: .morning)
                    .frame(height: 70)
            }

            // Mascot bottom-right (bleeds past the edge a bit)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("WidgetMascotMorning")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .offset(x: 12, y: 12)
                }
            }

            // Greeting top-left
            VStack(alignment: .leading, spacing: 2) {
                Text("morning")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.morningInkSoft)
                    .textCase(.uppercase)
                Text("good\nmorning")
                    .font(WidgetTheme.widgetFont(size: 19))
                    .foregroundColor(DinoPalette.morningInk)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Medium (morning)

struct MoodMorningMediumView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodMorning

            // Sun — placed at mid-left, size scales with medium proportions
            SunShape(rotationDegrees: Double(entry.sceneAnimPhase) * 6.0)
                .frame(width: 80, height: 80)
                .offset(x: -100, y: -30)

            // Hills
            VStack {
                Spacer()
                HillsShape(palette: .morning)
                    .frame(height: 80)
            }

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("morning")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.morningInkSoft)
                        .textCase(.uppercase)
                    Text("good\nmorning")
                        .font(WidgetTheme.widgetFont(size: 22))
                        .foregroundColor(DinoPalette.morningInk)
                        .lineLimit(2)
                    Spacer()
                    Text("take it easy today")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.morningInkSoft)
                }
                .padding(.leading, 14)
                .padding(.vertical, 12)

                Spacer(minLength: 0)

                Image("WidgetMascotMorning")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .offset(x: 10, y: 12)
            }
        }
    }
}
