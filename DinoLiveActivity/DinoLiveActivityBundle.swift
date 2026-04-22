//
//  DinoLiveActivityBundle.swift
//  DinoLiveActivity
//
//  Widget extension entry point. Bundles all Live Activity and home screen widgets.
//

import WidgetKit
import SwiftUI

@main
struct DinoLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        // Live Activities (keep untouched)
        BreathingLiveActivity()
        MeditationLiveActivity()
        FocusLiveActivity()

        // Home Screen Widgets — mood/streak/breathing redesigned
        MoodWidget()
        StreakWidget()
        BreathingWidget()

        // Home Screen Widgets — unchanged
        DailyAffirmationWidget()
        GratitudeWidget()
        TodaysFocusWidget()
    }
}
