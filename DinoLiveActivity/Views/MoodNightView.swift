//
//  MoodNightView.swift
//  DinoLiveActivity
//
//  Night (8pm–6am) mood scene for small + medium families.
//  Night sky + stars + moon + mountain silhouette + WidgetMascotNight mascot.
//

import SwiftUI
import WidgetKit

// MARK: - Small (night)

struct MoodNightSmallView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodNight

            // Stars scattered across upper band
            StarsShape()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Moon top-right
            MoonShape()
                .frame(width: 34, height: 34)
                .position(x: 130, y: 34)

            // Mountains bottom
            VStack {
                Spacer()
                MountainsShape()
                    .frame(height: 80)
            }

            // Mascot bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("WidgetMascotNight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .offset(x: 10, y: 10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("tonight")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.nightTextSecondary)
                    .textCase(.uppercase)
                Text("time to\nslow down")
                    .font(WidgetTheme.widgetFont(size: 17))
                    .foregroundColor(DinoPalette.nightTextPrimary)
                    .lineLimit(2)
                Spacer()
                Text("reflect gently")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.nightTextSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Medium (night)

struct MoodNightMediumView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodNight

            // Stars across top
            StarsShape()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Moon
            MoonShape()
                .frame(width: 44, height: 44)
                .position(x: 260, y: 36)

            // Mountains
            VStack {
                Spacer()
                MountainsShape()
                    .frame(height: 90)
            }

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("tonight")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.nightTextSecondary)
                        .textCase(.uppercase)

                    Text("time to\nslow down")
                        .font(WidgetTheme.widgetFont(size: 22))
                        .foregroundColor(DinoPalette.nightTextPrimary)
                        .lineLimit(2)

                    Spacer()

                    Text("take a quiet moment")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.nightTextSecondary)
                }
                .padding(.vertical, 12)
                .padding(.leading, 14)

                Spacer(minLength: 0)

                Image("WidgetMascotNight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .offset(x: 8, y: 12)
            }
        }
    }
}
