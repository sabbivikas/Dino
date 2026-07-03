//
//  AnalyticsManager.swift
//  Dino
//
//  Single point of entry for analytics. All PostHog events flow through here
//  so privacy rules (opt-out, no PII, no journal content) stay in one place.
//

import Foundation
import PostHog

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    private let analyticsEnabledKey = "dino.analyticsEnabled"

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: analyticsEnabledKey) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: analyticsEnabledKey)
        if !enabled {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
        }
    }

    private func capture(_ event: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }

    // MARK: - Auth

    func trackSignIn(method: String) {
        capture("user_signed_in", properties: ["method": method])
    }

    func trackSignUp(method: String) {
        capture("user_signed_up", properties: ["method": method])
    }

    func trackSignOut() {
        capture("user_signed_out")
    }

    func trackOnboardingStep(_ step: Int, total: Int) {
        capture("onboarding_step_viewed", properties: ["step": step, "total": total])
    }

    func trackOnboardingComplete() {
        capture("onboarding_completed")
    }

    // MARK: - Journal

    func trackJournalOpened() {
        capture("journal_opened")
    }

    func trackJournalEntryCreated(type: String) {
        capture("journal_entry_created", properties: ["type": type])
    }

    func trackJournalEntryViewed() {
        capture("journal_entry_viewed")
    }

    func trackJournalFlipped() {
        capture("journal_card_flipped")
    }

    func trackSeeAllMemoriesTapped(count: Int) {
        capture("journal_see_all_tapped", properties: ["count": count])
    }

    // MARK: - Mood

    func trackMoodLogged(weather: String, energy: Int, intensity: Int) {
        capture("mood_logged", properties: [
            "weather": weather,
            "energy": energy,
            "intensity": intensity
        ])
    }

    func trackMoodScreenOpened() {
        capture("mood_screen_opened")
    }

    // MARK: - Breathing

    func trackBreathingSessionStarted(duration: Int, pattern: String) {
        capture("breathing_session_started", properties: [
            "duration": duration,
            "pattern": pattern
        ])
    }

    func trackBreathingSessionCompleted(duration: Int) {
        capture("breathing_session_completed", properties: ["duration": duration])
    }

    func trackBreathingSessionAbandoned(atSecond: Int) {
        capture("breathing_session_abandoned", properties: ["at_second": atSecond])
    }

    // MARK: - Meditation

    func trackMeditationSessionStarted(scene: String, duration: Int) {
        capture("meditation_session_started", properties: [
            "scene": scene,
            "duration": duration
        ])
    }

    func trackMeditationSessionCompleted(duration: Int) {
        capture("meditation_session_completed", properties: ["duration": duration])
    }

    func trackMeditationSessionAbandoned(atSecond: Int) {
        capture("meditation_session_abandoned", properties: ["at_second": atSecond])
    }

    // MARK: - Gratitude

    func trackGratitudeJarOpened() {
        capture("gratitude_jar_opened")
    }

    func trackGratitudeTokenAdded(type: String) {
        capture("gratitude_token_added", properties: ["type": type])
    }

    func trackGratitudeNoteViewed() {
        capture("gratitude_note_viewed")
    }

    func trackGratitudeMilestone(count: Int) {
        capture("gratitude_milestone_reached", properties: ["count": count])
    }

    // MARK: - Affirmations

    func trackAffirmationsOpened() {
        capture("affirmations_opened")
    }

    func trackAffirmationFavorited() {
        capture("affirmation_favorited")
    }

    func trackAffirmationWriteBackTapped() {
        capture("affirmation_write_back_tapped")
    }

    func trackAffirmationMirrorFull() {
        capture("affirmation_mirror_full")
    }

    // MARK: - Growth

    func trackGrowthGardenOpened() {
        capture("growth_garden_opened")
    }

    func trackGrowthStageReached(stage: String) {
        capture("growth_stage_reached", properties: ["stage": stage])
    }

    // MARK: - Assessment

    func trackAssessmentStarted() {
        capture("assessment_started")
    }

    func trackAssessmentCompleted(score: Int) {
        capture("assessment_completed", properties: ["score": score])
    }

    func trackScreenViewed(_ screen: String) {
        capture("screen_viewed", properties: ["screen": screen])
    }

    // MARK: - Focus

    func trackFocusSessionStarted(duration: Int) {
        capture("focus_session_started", properties: ["duration": duration])
    }

    func trackFocusSessionCompleted(duration: Int) {
        capture("focus_session_completed", properties: ["duration": duration])
    }

    func trackFocusSessionAbandoned(atMinute: Int) {
        capture("focus_session_abandoned", properties: ["at_minute": atMinute])
    }

    // MARK: - Notifications

    func trackNotificationCenterOpened() {
        capture("notification_center_opened")
    }

    func trackNotificationTapped(type: String) {
        capture("notification_tapped", properties: ["type": type])
    }

    func trackSelfCareReminderToggled(type: String, enabled: Bool) {
        capture("self_care_reminder_toggled", properties: [
            "type": type,
            "enabled": enabled
        ])
    }

    // MARK: - Streak

    func trackStreakCalendarOpened() {
        capture("streak_calendar_opened")
    }

    func trackStreakMilestone(days: Int) {
        capture("streak_milestone_reached", properties: ["days": days])
    }

    // MARK: - Profile

    func trackFeedbackSubmitted(category: String) {
        capture("feedback_submitted", properties: ["category": category])
    }

    func trackProfileOpened() {
        capture("profile_opened")
    }

    func trackThemeChanged(theme: String) {
        capture("theme_changed", properties: ["theme": theme])
    }

    func trackWellnessProgressOpened() {
        capture("wellness_progress_opened")
    }

    func trackPaintingGalleryOpened() {
        capture("painting_gallery_opened")
    }

    // MARK: - Home

    func trackHomeOpened() {
        capture("home_opened")
    }

    func trackActionCardTapped(feature: String) {
        capture("action_card_tapped", properties: ["feature": feature])
    }

    func trackWeatherPillShown(condition: String, temp: Double) {
        capture("weather_pill_shown", properties: [
            "condition": condition,
            "temp": temp
        ])
    }

    func trackAppBackgrounded(sessionDuration: Double) {
        capture("app_backgrounded", properties: ["session_duration_seconds": sessionDuration])
    }

    // MARK: - Rating

    func trackRatingScreenShown() {
        capture("rating_screen_shown", properties: [:])
    }

    func trackRatingStarTapped(stars: Int) {
        capture("rating_star_tapped", properties: ["stars": stars])
    }

    func trackRatingSubmitted(stars: Int) {
        capture("rating_submitted", properties: ["stars": stars])
    }

    func trackRatingSkipped() {
        capture("rating_skipped", properties: [:])
    }

    // MARK: - Session

    func trackSessionStarted() {
        capture("session_started", properties: [
            "time_of_day": Calendar.current.component(.hour, from: Date())
        ])
    }

    func trackSessionEnded(durationSeconds: Int) {
        capture("session_ended", properties: [
            "duration_seconds": durationSeconds
        ])
    }

    // MARK: - Rhythms

    func trackRhythmsOpened() {
        capture("rhythms_opened")
    }

    func trackRhythmsLearningStateShown(daysRemaining: Int) {
        capture("rhythms_learning_state_shown", properties: ["days_remaining": daysRemaining])
    }

    func trackRhythmsForecastViewed(tomorrowRisk: String) {
        capture("rhythms_forecast_viewed", properties: ["tomorrow_risk": tomorrowRisk])
    }

    func trackRhythmsHelixFormationChanged(formation: String) {
        capture("rhythms_helix_formation_changed", properties: ["formation": formation])
    }

    func trackRhythmsInsightViewed(insightType: String) {
        capture("rhythms_insight_viewed", properties: ["insight_type": insightType])
    }

    func trackRhythmsHardDayPredicted(weekday: String) {
        capture("rhythms_hard_day_predicted", properties: ["weekday": weekday])
    }

    func trackRhythmsLetterReceived() {
        capture("rhythms_letter_received")
    }

    func trackRhythmsLetterSaved() {
        capture("rhythms_letter_saved")
    }

    // MARK: - Weekly Check-In

    func trackWeeklyCheckInCompleted() {
        capture("weekly_checkin_completed")
    }

    // MARK: - Mood Painting

    func trackMoodPaintingCreated() {
        capture("mood_painting_created")
    }

    // MARK: - Forest Letter

    func trackForestLetterOpened() {
        capture("forest_letter_opened")
    }

    func trackForestLetterSavedToJar() {
        capture("forest_letter_saved_to_jar")
    }

    func trackHealthPermissionGranted() {
        capture("health_permission_granted")
    }

    func trackHealthPermissionDenied() {
        capture("health_permission_denied")
    }

    func trackHealthPermissionSkipped() {
        capture("health_permission_skipped")
    }

    /// Break-finder AI call failed (e.g. bad OpenAI key, rate limit, timeout).
    /// No PII — only the error domain + code so silent fallbacks are visible.
    func trackBreakFinderAIFailed(domain: String, code: Int) {
        capture("break_finder_ai_failed", properties: ["error_domain": domain, "error_code": code])
    }

    // MARK: - Dino World (no country codes in event properties)

    func trackWorldViewed() {
        capture("world_viewed")
    }

    func trackWorldCardTapped() {
        capture("world_card_tapped")
    }

    func trackWorldPostLogTapped() {
        capture("world_post_log_tapped")
    }

    func trackWorldFindMyLight() {
        capture("world_find_my_light")
    }

    func trackWorldRewindUsed() {
        capture("world_rewind_used")
    }

    // MARK: - Account

    func trackAccountDeleted() {
        capture("account_deleted")
    }

    // MARK: - Voice Journal

    func trackVoiceRecordingStarted() {
        capture("voice_recording_started")
    }

    func trackVoiceTranscriptionCompleted() {
        capture("voice_transcription_completed")
    }

    // MARK: - Deep Links

    func trackDeepLinkOpened(screen: String) {
        capture("deep_link_opened", properties: ["screen": screen])
    }

    // MARK: - Screen Tracking (autocaptured by PostHog as $screen)

    func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        var props: [String: Any] = [
            "$screen_name": screenName
        ]
        if let extra = properties {
            props.merge(extra) { _, new in new }
        }
        PostHogSDK.shared.capture("$screen", properties: props)
    }

    // MARK: - Identity

    func identify(uid: String) {
        guard isEnabled else { return }
        PostHogSDK.shared.identify(uid)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }

    /// Force-send the queued events now. Used right after auth-moment events
    /// (identify + signed_up/in) so they ship immediately instead of waiting
    /// for the 30s timer / 20-event batch / backgrounding.
    func flush() {
        PostHogSDK.shared.flush()
    }
}
