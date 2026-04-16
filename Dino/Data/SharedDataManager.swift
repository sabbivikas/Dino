//
//  SharedDataManager.swift
//  Dino
//

import Foundation
import Combine

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
            UserDefaults.standard.set(currentUserId, forKey: "currentUserId")
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
        didSet { save(moodEntries, forKey: userKey("moodEntries")) }
    }
    @Published var journalEntries: [JournalEntry] {
        didSet { save(journalEntries, forKey: userKey("journalEntries")) }
    }
    @Published var gratitudeNotes: [GratitudeNote] {
        didSet { save(gratitudeNotes, forKey: userKey("gratitudeNotes")) }
    }
    @Published var savedAffirmations: [SavedAffirmation] {
        didSet { save(savedAffirmations, forKey: userKey("savedAffirmations")) }
    }
    @Published var breathingSessions: [BreathingSession] {
        didSet { save(breathingSessions, forKey: userKey("breathingSessions")) }
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
    @Published var streakData: StreakData {
        didSet { save(streakData, forKey: userKey("streakData")) }
    }
    @Published var growthStats: GrowthStats {
        didSet { save(growthStats, forKey: userKey("growthStats")) }
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
    @Published var deepLinkTab: Int = 0
    @Published var showBreathingFromDeepLink: Bool = false

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

        // Global (non-user-namespaced) flags
        self.isSignedIn = ud.bool(forKey: "isSignedIn")

        // Load user-namespaced data using whatever userId we have (may be nil for guests)
        self.onboardingComplete = ud.bool(forKey: self.userKeyStatic(self.currentUserId, "onboardingComplete"))
        self.userName = ud.string(forKey: self.userKeyStatic(self.currentUserId, "userName")) ?? ""
        self.userTimezone = ud.string(forKey: self.userKeyStatic(self.currentUserId, "userTimezone")) ?? TimeZone.current.identifier
        self.dinoSkin = ud.string(forKey: self.userKeyStatic(self.currentUserId, "dinoSkin")) ?? "default"
        self.dinoName = ud.string(forKey: self.userKeyStatic(self.currentUserId, "dinoName")) ?? "Dino"
        self.userFeeling = ud.string(forKey: self.userKeyStatic(self.currentUserId, "userFeeling")) ?? ""
        self.userChallenge = ud.string(forKey: self.userKeyStatic(self.currentUserId, "userChallenge")) ?? ""
        self.referralSource = ud.string(forKey: self.userKeyStatic(self.currentUserId, "referralSource")) ?? ""

        let uid = self.currentUserId
        self.userIntentions = Self.load([String].self, from: ud, key: Self.staticUserKey(uid, "userIntentions")) ?? []
        self.moodEntries = Self.load([MoodEntry].self, from: ud, key: Self.staticUserKey(uid, "moodEntries")) ?? []
        self.journalEntries = Self.load([JournalEntry].self, from: ud, key: Self.staticUserKey(uid, "journalEntries")) ?? []
        self.gratitudeNotes = Self.load([GratitudeNote].self, from: ud, key: Self.staticUserKey(uid, "gratitudeNotes")) ?? []
        self.savedAffirmations = Self.load([SavedAffirmation].self, from: ud, key: Self.staticUserKey(uid, "savedAffirmations")) ?? []
        self.breathingSessions = Self.load([BreathingSession].self, from: ud, key: Self.staticUserKey(uid, "breathingSessions")) ?? []
        self.focusSessions = Self.load([FocusSession].self, from: ud, key: Self.staticUserKey(uid, "focusSessions")) ?? []
        self.meditationSessions = Self.load([MeditationSession].self, from: ud, key: Self.staticUserKey(uid, "meditationSessions")) ?? []
        self.assessmentResults = Self.load([AssessmentResult].self, from: ud, key: Self.staticUserKey(uid, "assessmentResults")) ?? []
        self.streakData = Self.load(StreakData.self, from: ud, key: Self.staticUserKey(uid, "streakData")) ?? StreakData()
        self.growthStats = Self.load(GrowthStats.self, from: ud, key: Self.staticUserKey(uid, "growthStats")) ?? GrowthStats()

        resetSelfCareIfNewDay()
    }

    // Static helpers used before `self` is fully initialized
    private func userKeyStatic(_ uid: String?, _ key: String) -> String {
        guard let uid = uid else { return key }
        return "\(uid)_\(key)"
    }

    private static func staticUserKey(_ uid: String?, _ key: String) -> String {
        guard let uid = uid else { return key }
        return "\(uid)_\(key)"
    }

    // MARK: - Per-User Data Management

    /// Call when a Firebase user signs in. Clears in-memory data if this is a
    /// different user than the previous session, then loads from namespaced keys.
    func loadDataForUser(_ userId: String) {
        print("[DataManager] loading data for user: \(userId)")
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
        print("[DataManager] clearing data for sign-out")
        // IMPORTANT: nil out the userId FIRST so clearInMemoryData()'s
        // didSet writes go to un-namespaced keys (throwaway) and don't
        // overwrite the real user's persisted data with empty values.
        currentUserId = nil
        isSignedIn = false
        clearInMemoryData()
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
        streakData = Self.load(StreakData.self, from: ud, key: userKey("streakData")) ?? StreakData()
        growthStats = Self.load(GrowthStats.self, from: ud, key: userKey("growthStats")) ?? GrowthStats()

        resetSelfCareIfNewDay()
        print("[DataManager] data loaded — onboarding: \(onboardingComplete), entries: \(moodEntries.count) moods")
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
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from ud: UserDefaults, key: String) -> T? {
        guard let data = ud.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
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

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

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
    }

    // MARK: - Journal
    func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.insert(entry, at: 0)
        addXP(15)
        recordActivity()
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
    func addGratitudeNote(_ text: String) {
        let note = GratitudeNote(text: text)
        gratitudeNotes.insert(note, at: 0)
        addXP(5)
        recordActivity()
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
    }

    // MARK: - Assessment
    func saveAssessmentResult(_ result: AssessmentResult) {
        assessmentResults.insert(result, at: 0)
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
