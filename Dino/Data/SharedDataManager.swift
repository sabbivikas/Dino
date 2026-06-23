//
//  SharedDataManager.swift
//  Dino
//

import Foundation
import Combine
import WidgetKit

private let suiteName = "group.com.vikassabbi.dino"

@MainActor
final class SharedDataManager: ObservableObject {
    static let shared = SharedDataManager()

    private let defaults: UserDefaults

    // MARK: - Per-User Identity
    /// Persisted in standard UserDefaults (not namespaced) so it survives
    /// across sessions and is available before any user signs in.
    private(set) var currentUserId: String? {
        didSet {
            persistCurrentUserId()
            scheduleWidgetReload()
        }
    }

    private var widgetReloadTask: Task<Void, Never>?

    func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// Returns a UserDefaults key prefixed with the current user's UID.
    /// Falls back to the bare key when no user is loaded (guest / pre-auth).
    private func userKey(_ key: String) -> String {
        guard let uid = currentUserId else { return key }
        return "\(uid)_\(key)"
    }

    // MARK: - Published Properties

    @Published var isSignedIn: Bool {
        didSet { defaults.set(isSignedIn, forKey: "isSignedIn") }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: userKey("onboardingComplete")) }
    }
    @Published var userName: String {
        didSet { defaults.set(userName, forKey: userKey("userName")) }
    }
    @Published var userTimezone: String {
        didSet { defaults.set(userTimezone, forKey: userKey("userTimezone")) }
    }
    @Published var userIntentions: [String] {
        didSet { save(userIntentions, forKey: userKey("userIntentions")) }
    }
    @Published var moodEntries: [MoodEntry] {
        didSet {
            save(moodEntries, forKey: userKey("moodEntries"))
            scheduleWidgetReload()
        }
    }
    @Published var journalEntries: [JournalEntry] {
        didSet {
            save(journalEntries, forKey: userKey("journalEntries"))
            scheduleWidgetReload()
        }
    }
    @Published var gratitudeNotes: [GratitudeNote] {
        didSet {
            save(gratitudeNotes, forKey: userKey("gratitudeNotes"))
            scheduleWidgetReload()
        }
    }
    @Published var savedAffirmations: [SavedAffirmation] {
        didSet {
            save(savedAffirmations, forKey: userKey("savedAffirmations"))
            scheduleWidgetReload()
        }
    }
    @Published var breathingSessions: [BreathingSession] {
        didSet {
            save(breathingSessions, forKey: userKey("breathingSessions"))
            scheduleWidgetReload()
        }
    }
    @Published var focusSessions: [FocusSession] {
        didSet { save(focusSessions, forKey: userKey("focusSessions")) }
    }
    @Published var meditationSessions: [MeditationSession] {
        didSet { save(meditationSessions, forKey: userKey("meditationSessions")) }
    }
    @Published var assessmentResults: [AssessmentResult] {
        didSet { save(assessmentResults, forKey: userKey("assessmentResults")) }
    }
    @Published var weeklyCheckIns: [WeeklyCheckInResult] = [] {
        didSet { save(weeklyCheckIns, forKey: userKey("weeklyCheckIns")) }
    }
    @Published var streakData: StreakData {
        didSet {
            save(streakData, forKey: userKey("streakData"))
            scheduleWidgetReload()
            print("\u{1F331} PLANT NUDGE CHECK: streak=\(streakData.currentStreak) level=\(growthStats.level)")
            NotificationManager.shared.checkAndSchedulePlantNudge(streakData: streakData, growthStats: growthStats)
        }
    }
    @Published var growthStats: GrowthStats {
        didSet {
            save(growthStats, forKey: userKey("growthStats"))
            print("🌱 PLANT NUDGE CHECK: streak=\(streakData.currentStreak) level=\(growthStats.level)")
            NotificationManager.shared.checkAndSchedulePlantNudge(streakData: streakData, growthStats: growthStats)
        }
    }
    @Published var dinoSkin: String {
        didSet { defaults.set(dinoSkin, forKey: userKey("dinoSkin")) }
    }
    @Published var dinoName: String {
        didSet { defaults.set(dinoName, forKey: userKey("dinoName")) }
    }
    @Published var userFeeling: String {
        didSet { defaults.set(userFeeling, forKey: userKey("userFeeling")) }
    }
    @Published var userChallenge: String {
        didSet { defaults.set(userChallenge, forKey: userKey("userChallenge")) }
    }
    @Published var referralSource: String {
        didSet { defaults.set(referralSource, forKey: userKey("referralSource")) }
    }

    // MARK: - Deep Link State
    @Published var deepLinkTab: Int?
    @Published var showBreathingFromDeepLink: Bool = false
    @Published var showFocusFromDeepLink: Bool = false
    @Published var showAmbientFromDeepLink: Bool = false
    @Published var showMeditationFromDeepLink: Bool = false

    // MARK: - Break-finder (once-per-day suggestion gate)
    private let lastBreakSuggestionKey = "dino.lastBreakSuggestionDate"
    var lastBreakSuggestionDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBreakSuggestionKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBreakSuggestionKey) }
    }
    /// True if no break has been suggested yet today (local day).
    var shouldSuggestBreakToday: Bool {
        guard let last = lastBreakSuggestionDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }
    func markBreakSuggested() { lastBreakSuggestionDate = Date() }
    @Published var presentAddGratitude: Bool = false

    // MARK: - Member Since
    var memberSinceDate: Date {
        if let data = defaults.object(forKey: userKey("memberSinceDate")) as? Double {
            return Date(timeIntervalSince1970: data)
        }
        let now = Date()
        defaults.set(now.timeIntervalSince1970, forKey: userKey("memberSinceDate"))
        return now
    }

    // MARK: - Self-care toggles (daily reset)
    @Published var selfCareWater: Bool = false
    @Published var selfCareEat: Bool = false
    @Published var selfCareRest: Bool = false
    @Published var selfCareConnect: Bool = false

    private init() {
        let ud = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        self.defaults = ud

        // Restore last known userId (if any) so we load the right data on cold start
        self.currentUserId = UserDefaults.standard.string(forKey: "currentUserId")
            ?? ud.string(forKey: "currentUserId")

        // Global (non-user-namespaced) flags
        self.isSignedIn = ud.bool(forKey: "isSignedIn")

        // Load user-namespaced data using whatever userId we have (may be nil for guests)
        let uid = self.currentUserId
        self.onboardingComplete = ud.bool(forKey: Self.staticUserKey(uid, "onboardingComplete"))
        self.userName = ud.string(forKey: Self.staticUserKey(uid, "userName")) ?? ""
        self.userTimezone = ud.string(forKey: Self.staticUserKey(uid, "userTimezone")) ?? TimeZone.current.identifier
        self.dinoSkin = ud.string(forKey: Self.staticUserKey(uid, "dinoSkin")) ?? "default"
        self.dinoName = ud.string(forKey: Self.staticUserKey(uid, "dinoName")) ?? "Dino"
        self.userFeeling = ud.string(forKey: Self.staticUserKey(uid, "userFeeling")) ?? ""
        self.userChallenge = ud.string(forKey: Self.staticUserKey(uid, "userChallenge")) ?? ""
        self.referralSource = ud.string(forKey: Self.staticUserKey(uid, "referralSource")) ?? ""
        self.userIntentions = Self.load([String].self, from: ud, key: Self.staticUserKey(uid, "userIntentions")) ?? []
        self.moodEntries = Self.load([MoodEntry].self, from: ud, key: Self.staticUserKey(uid, "moodEntries")) ?? []
        self.journalEntries = Self.load([JournalEntry].self, from: ud, key: Self.staticUserKey(uid, "journalEntries")) ?? []
        self.gratitudeNotes = Self.load([GratitudeNote].self, from: ud, key: Self.staticUserKey(uid, "gratitudeNotes")) ?? []
        self.savedAffirmations = Self.load([SavedAffirmation].self, from: ud, key: Self.staticUserKey(uid, "savedAffirmations")) ?? []
        self.breathingSessions = Self.load([BreathingSession].self, from: ud, key: Self.staticUserKey(uid, "breathingSessions")) ?? []
        self.focusSessions = Self.load([FocusSession].self, from: ud, key: Self.staticUserKey(uid, "focusSessions")) ?? []
        self.meditationSessions = Self.load([MeditationSession].self, from: ud, key: Self.staticUserKey(uid, "meditationSessions")) ?? []
        self.assessmentResults = Self.load([AssessmentResult].self, from: ud, key: Self.staticUserKey(uid, "assessmentResults")) ?? []
        self.weeklyCheckIns = Self.load([WeeklyCheckInResult].self, from: ud, key: Self.staticUserKey(uid, "weeklyCheckIns")) ?? []
        self.streakData = Self.load(StreakData.self, from: ud, key: Self.staticUserKey(uid, "streakData")) ?? StreakData()
        self.growthStats = Self.load(GrowthStats.self, from: ud, key: Self.staticUserKey(uid, "growthStats")) ?? GrowthStats()

        resetSelfCareIfNewDay()
        persistCurrentUserId()
        applyFileProtectionToExistingAudio()
        applyFileProtectionToExistingPaintings()
        excludeDocumentsFromBackup()
    }

    // MARK: - File Protection / Backup Exclusion (one-time on launch)

    private func applyFileProtectionToExistingAudio() {
        Task.detached(priority: .background) {
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            guard let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
            let audioExts: Set<String> = ["m4a", "caf", "wav", "aac", "mp3"]
            for var url in files where audioExts.contains(url.pathExtension.lowercased()) {
                var v = URLResourceValues()
                v.isExcludedFromBackup = true
                try? url.setResourceValues(v)
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            }
        }
    }

    private func applyFileProtectionToExistingPaintings() {
        Task.detached(priority: .background) {
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            guard let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
            for var url in files where url.lastPathComponent.hasPrefix("painting_") && ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) {
                var v = URLResourceValues()
                v.isExcludedFromBackup = true
                try? url.setResourceValues(v)
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            }
        }
    }

    private func excludeDocumentsFromBackup() {
        Task.detached(priority: .background) {
            guard var docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            var v = URLResourceValues()
            v.isExcludedFromBackup = true
            try? docs.setResourceValues(v)
        }
    }

    // Static helper used before `self` is fully initialized
    private static func staticUserKey(_ uid: String?, _ key: String) -> String {
        guard let uid = uid else { return key }
        return "\(uid)_\(key)"
    }

    // MARK: - Per-User Data Management

    /// Call when a Firebase user signs in. Clears in-memory data if this is a
    /// different user than the previous session, then loads from namespaced keys.
    func loadDataForUser(_ userId: String) {
        #if DEBUG
        print("[DataManager] loading data for user")
        #endif
        let previousUser = currentUserId
        currentUserId = userId

        if previousUser != userId {
            // Different user — wipe in-memory state before loading
            clearInMemoryData()
        }

        loadUserData()
    }

    /// Call on sign-out. Clears in-memory data and forgets the current user.
    func clearForSignOut() {
        #if DEBUG
        print("[DataManager] clearing data for sign-out")
        #endif
        // IMPORTANT: nil out the userId FIRST so clearInMemoryData()'s
        // didSet writes go to un-namespaced keys (throwaway) and don't
        // overwrite the real user's persisted data with empty values.
        currentUserId = nil
        isSignedIn = false
        clearInMemoryData()

        // Clean up legacy SHARED keys/files written by older builds so they
        // don't leak into the next signed-in session. These are the bare,
        // un-namespaced keys that the old ProfileDetailsView / PhotoStore
        // wrote before per-user storage was introduced. We leave the
        // per-user `{uid}_...` copies alone so each user's data is intact.
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "userName")
        ud.removeObject(forKey: "user_bio")
        // Legacy profile photo file + "has photo" flag
        PhotoStore.clearLegacyShared()
    }

    /// Reload all persistent data from user-namespaced UserDefaults keys.
    private func loadUserData() {
        let ud = defaults
        onboardingComplete = ud.bool(forKey: userKey("onboardingComplete"))
        userName = ud.string(forKey: userKey("userName")) ?? ""
        userTimezone = ud.string(forKey: userKey("userTimezone")) ?? TimeZone.current.identifier
        dinoSkin = ud.string(forKey: userKey("dinoSkin")) ?? "default"
        dinoName = ud.string(forKey: userKey("dinoName")) ?? "Dino"
        userFeeling = ud.string(forKey: userKey("userFeeling")) ?? ""
        userChallenge = ud.string(forKey: userKey("userChallenge")) ?? ""
        referralSource = ud.string(forKey: userKey("referralSource")) ?? ""

        userIntentions = Self.load([String].self, from: ud, key: userKey("userIntentions")) ?? []
        moodEntries = Self.load([MoodEntry].self, from: ud, key: userKey("moodEntries")) ?? []
        journalEntries = Self.load([JournalEntry].self, from: ud, key: userKey("journalEntries")) ?? []
        gratitudeNotes = Self.load([GratitudeNote].self, from: ud, key: userKey("gratitudeNotes")) ?? []
        savedAffirmations = Self.load([SavedAffirmation].self, from: ud, key: userKey("savedAffirmations")) ?? []
        breathingSessions = Self.load([BreathingSession].self, from: ud, key: userKey("breathingSessions")) ?? []
        focusSessions = Self.load([FocusSession].self, from: ud, key: userKey("focusSessions")) ?? []
        meditationSessions = Self.load([MeditationSession].self, from: ud, key: userKey("meditationSessions")) ?? []
        assessmentResults = Self.load([AssessmentResult].self, from: ud, key: userKey("assessmentResults")) ?? []
        weeklyCheckIns = Self.load([WeeklyCheckInResult].self, from: ud, key: userKey("weeklyCheckIns")) ?? []
        streakData = Self.load(StreakData.self, from: ud, key: userKey("streakData")) ?? StreakData()
        growthStats = Self.load(GrowthStats.self, from: ud, key: userKey("growthStats")) ?? GrowthStats()

        resetSelfCareIfNewDay()
        #if DEBUG
        print("[DataManager] data loaded — entries: \(moodEntries.count) moods")
        #endif
    }

    /// Zero out all in-memory user data without touching UserDefaults.
    private func clearInMemoryData() {
        userName = ""
        userTimezone = TimeZone.current.identifier
        userIntentions = []
        moodEntries = []
        journalEntries = []
        gratitudeNotes = []
        savedAffirmations = []
        breathingSessions = []
        focusSessions = []
        meditationSessions = []
        assessmentResults = []
        weeklyCheckIns = []
        streakData = StreakData()
        growthStats = GrowthStats()
        dinoSkin = "default"
        dinoName = "Dino"
        userFeeling = ""
        userChallenge = ""
        referralSource = ""
        selfCareWater = false
        selfCareEat = false
        selfCareRest = false
        selfCareConnect = false
    }

    // MARK: - Generic Save/Load
    private func save<T: Encodable & Sendable>(_ value: T, forKey key: String) {
        let snapshot = value
        let ud = defaults
        Task.detached(priority: .background) {
            if let data = try? JSONEncoder().encode(snapshot) {
                ud.set(data, forKey: key)
            }
        }
        scheduleWidgetReload()
    }

    private static func load<T: Decodable>(_ type: T.Type, from ud: UserDefaults, key: String) -> T? {
        guard let data = ud.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func persistCurrentUserId() {
        let appGroupDefaults = UserDefaults(suiteName: suiteName) ?? defaults
        if let currentUserId, !currentUserId.isEmpty {
            UserDefaults.standard.set(currentUserId, forKey: "currentUserId")
            appGroupDefaults.set(currentUserId, forKey: "currentUserId")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentUserId")
            appGroupDefaults.removeObject(forKey: "currentUserId")
        }
    }

    // MARK: - Activity Tracking
    func recordActivity() {
        updateStreak()
        FirestoreSyncService.shared.scheduleSyncToCloud()
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: streakData.lastActiveDate)

        // Always record today as active
        let todayKey = StreakData.dateKey(for: today)
        if !streakData.activeDates.contains(todayKey) {
            streakData.activeDates.insert(todayKey)
        }

        if calendar.isDate(today, inSameDayAs: lastActive) {
            return
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            streakData.currentStreak = 1
            return
        }

        if calendar.isDate(lastActive, inSameDayAs: yesterday) {
            streakData.currentStreak += 1
        } else {
            streakData.currentStreak = 1
        }

        if streakData.currentStreak > streakData.longestStreak {
            streakData.longestStreak = streakData.currentStreak
        }

        streakData.lastActiveDate = Date()
    }

    // MARK: - XP System
    func addXP(_ amount: Int) {
        growthStats.xp += amount
        let newLevel = (growthStats.xp / 100) + 1
        if newLevel > growthStats.level {
            growthStats.level = newLevel
        }
    }

    // MARK: - Mood
    func logMood(_ entry: MoodEntry) {
        moodEntries.insert(entry, at: 0)
        addXP(10)
        recordActivity()
        NotificationManager.shared.userDidLogMood()
        scheduleWidgetReload()
    }

    // MARK: - Journal
    func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.insert(entry, at: 0)
        addXP(15)
        recordActivity()
        NotificationManager.shared.userDidLogActivity()
        scheduleWidgetReload()
    }

    func deleteJournalEntry(_ entry: JournalEntry) {
        journalEntries.removeAll { $0.id == entry.id }
        deleteAudioFile(named: entry.audioFileName)
        FirestoreSyncService.shared.scheduleSyncToCloud()
    }

    func toggleFavoriteJournal(_ entry: JournalEntry) {
        if let idx = journalEntries.firstIndex(where: { $0.id == entry.id }) {
            journalEntries[idx].isFavorite.toggle()
        }
    }

    private func deleteAudioFile(named fileName: String) {
        let url = audioFileURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func audioFileURL(for fileName: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    // MARK: - Gratitude
    func addGratitudeNote(_ text: String, tokenType: String = "heart") {
        let note = GratitudeNote(text: text, tokenType: tokenType)
        gratitudeNotes.insert(note, at: 0)
        addXP(5)
        recordActivity()
        NotificationManager.shared.userDidLogActivity()
    }

    func deleteGratitudeNote(_ note: GratitudeNote) {
        gratitudeNotes.removeAll { $0.id == note.id }
        FirestoreSyncService.shared.scheduleSyncToCloud()
    }

    var todayGratitudeCount: Int {
        let calendar = Calendar.current
        return gratitudeNotes.filter { calendar.isDateInToday($0.createdAt) }.count
    }

    // MARK: - Affirmations
    func saveAffirmation(_ text: String) {
        if !savedAffirmations.contains(where: { $0.text == text }) {
            savedAffirmations.insert(SavedAffirmation(text: text), at: 0)
            FirestoreSyncService.shared.scheduleSyncToCloud()
        }
    }

    func removeAffirmation(_ text: String) {
        savedAffirmations.removeAll { $0.text == text }
        FirestoreSyncService.shared.scheduleSyncToCloud()
    }

    func isAffirmationSaved(_ text: String) -> Bool {
        savedAffirmations.contains { $0.text == text }
    }

    // MARK: - Breathing
    func logBreathingSession(_ session: BreathingSession) {
        breathingSessions.insert(session, at: 0)
        addXP(20)
        recordActivity()
        NotificationManager.shared.userDidLogActivity()
        scheduleWidgetReload()
    }

    // MARK: - Focus
    func logFocusSession(_ session: FocusSession) {
        focusSessions.insert(session, at: 0)
        if session.completed { addXP(25) }
        recordActivity()
    }

    // MARK: - Meditation
    func logMeditationSession(_ session: MeditationSession) {
        meditationSessions.insert(session, at: 0)
        if session.completed { addXP(20) }
        recordActivity()
        NotificationManager.shared.userDidLogActivity()
    }

    // MARK: - Assessment
    func saveAssessmentResult(_ result: AssessmentResult) {
        assessmentResults.insert(result, at: 0)
        recordActivity()
    }

    func addWeeklyCheckIn(_ result: WeeklyCheckInResult) {
        weeklyCheckIns.insert(result, at: 0)
        recordActivity()
    }

    // MARK: - Self-care
    private func resetSelfCareIfNewDay() {
        let lastDate = defaults.object(forKey: userKey("selfCareDate")) as? Double
        let today = Date().timeIntervalSince1970
        let oneDaySeconds: Double = 86400

        if let last = lastDate, today - last < oneDaySeconds {
            selfCareWater = defaults.bool(forKey: userKey("selfCareWater"))
            selfCareEat = defaults.bool(forKey: userKey("selfCareEat"))
            selfCareRest = defaults.bool(forKey: userKey("selfCareRest"))
            selfCareConnect = defaults.bool(forKey: userKey("selfCareConnect"))
        } else {
            selfCareWater = false
            selfCareEat = false
            selfCareRest = false
            selfCareConnect = false
            defaults.set(today, forKey: userKey("selfCareDate"))
        }
    }

    func toggleSelfCare(_ type: SelfCareType) {
        switch type {
        case .water:
            selfCareWater.toggle()
            defaults.set(selfCareWater, forKey: userKey("selfCareWater"))
        case .eat:
            selfCareEat.toggle()
            defaults.set(selfCareEat, forKey: userKey("selfCareEat"))
        case .rest:
            selfCareRest.toggle()
            defaults.set(selfCareRest, forKey: userKey("selfCareRest"))
        case .connect:
            selfCareConnect.toggle()
            defaults.set(selfCareConnect, forKey: userKey("selfCareConnect"))
        }
    }

    // MARK: - Clear All Data
    func clearAllData() {
        isSignedIn = false
        onboardingComplete = false
        clearInMemoryData()
    }

    func signOut() {
        clearForSignOut()
    }

    func resetOnboarding() {
        onboardingComplete = false
    }
}

enum SelfCareType {
    case water, eat, rest, connect
}
