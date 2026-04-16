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

        // Home Screen Widgets — existing (now theme-synced + large)
        MoodCheckInWidget()
        DailyAffirmationWidget()

        // Home Screen Widgets — new
        StreakWidget()
        GratitudeWidget()
        BreathingWidget()
        TodaysFocusWidget()
    }
}
