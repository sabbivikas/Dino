//
//  RecParcelLiveActivity.swift
//  DinoLiveActivity
//
//  Rec delivery F3 — the announcement's lock-screen presence: the paper
//  parcel (RecParcelView, shared) gently glowing on cream paper with
//  "dino has something for you". Dynamic Island compact: mini parcel +
//  the short tease. Tap anywhere → dino://rec-reveal/{deliveryId}
//  (F3 lands on a placeholder; F4 replaces the destination).
//  Lock-screen layout stays inside the 374x136 budget like the others.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RecParcelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecParcelActivityAttributes.self) { context in
            RecParcelLockScreenView(context: context)
                .widgetURL(recRevealURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RecParcelView(size: 52, glowing: false)
                        .frame(width: 72, alignment: .center)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("dino has something for you")
                            .font(.custom("DinoInitiativeFont-Regular", size: 18))
                            .foregroundColor(Color(hex: "#F5E9C4"))
                            .lineLimit(2)
                        Text("what is it? \u{1F381}")
                            .font(.custom("DinoInitiativeFont-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                RecParcelView(size: 20, glowing: false)
                    .frame(width: 26, height: 26)
            } compactTrailing: {
                Text("what is it? \u{1F381}")
                    .font(.custom("DinoInitiativeFont-Regular", size: 13))
                    .foregroundColor(Color(hex: "#F5E9C4"))
                    .lineLimit(1)
            } minimal: {
                RecParcelView(size: 20, glowing: false)
                    .frame(width: 26, height: 26)
            }
            .widgetURL(recRevealURL(context))
        }
    }
}

private func recRevealURL(_ context: ActivityViewContext<RecParcelActivityAttributes>) -> URL? {
    URL(string: "dino://rec-reveal/\(context.attributes.deliveryId)")
}

// MARK: - Lock Screen

struct RecParcelLockScreenView: View {
    let context: ActivityViewContext<RecParcelActivityAttributes>

    var body: some View {
        ZStack {
            // quiet paper, not a scene — the parcel is the whole event
            LinearGradient(
                colors: [Color(hex: "#FBF6EB"), Color(hex: "#F2EAD8")],
                startPoint: .top, endPoint: .bottom)

            HStack(spacing: 16) {
                RecParcelView(size: 84, glowing: true)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 6) {
                    Text("dino has something for you")
                        .font(.custom("DinoInitiativeFont-Regular", size: 26))
                        .kerning(-0.3)
                        .foregroundColor(DinoPalette.laInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("what is it? \u{1F381}")
                        .font(.system(.callout))
                        .foregroundColor(DinoPalette.laCueText.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 136)
    }
}
