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

    // MARK: - Published Properties
    @Published var isSignedIn: Bool {
        didSet { defaults.set(isSignedIn, forKey: "isSignedIn") }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") }
    }
    @Published var userName: String {
        didSet { defaults.set(userName, forKey: "userName") }
    }
    @Published var userTimezone: String {
        didSet { defaults.set(userTimezone, forKey: "userTimezone") }
    }
    @Published var userIntentions: [String] {
        didSet { save(userIntentions, forKey: "userIntentions") }
    }
    @Published var moodEntries: [MoodEntry] {
        didSet { save(moodEntries, forKey: "moodEntries") }
    }
    @Published var journalEntries: [JournalEntry] {
        didSet { save(journalEntries, forKey: "journalEntries") }
    }
    @Published var gratitudeNotes: [GratitudeNote] {
        didSet { save(gratitudeNotes, forKey: "gratitudeNotes") }
    }
    @Published var savedAffirmations: [SavedAffirmation] {
        didSet { save(savedAffirmations, forKey: "savedAffirmations") }
    }
    @Published var breathingSessions: [BreathingSession] {
        didSet { save(breathingSessions, forKey: "breathingSessions") }
    }
    @Published var focusSessions: [FocusSession] {
        didSet { save(focusSessions, forKey: "focusSessions") }
    }
    @Published var meditationSessions: [MeditationSession] {
        didSet { save(meditationSessions, forKey: "meditationSessions") }
    }
    @Published var assessmentResults: [AssessmentResult] {
        didSet { save(assessmentResults, forKey: "assessmentResults") }
    }
    @Published var streakData: StreakData {
        didSet { save(streakData, forKey: "streakData") }
    }
    @Published var growthStats: GrowthStats {
        didSet { save(growthStats, forKey: "growthStats") }
    }
    @Published var dinoSkin: String {
        didSet { defaults.set(dinoSkin, forKey: "dinoSkin") }
    }
    @Published var dinoName: String {
        didSet { defaults.set(dinoName, forKey: "dinoName") }
    }
    @Published var userFeeling: String {
        didSet { defaults.set(userFeeling, forKey: "userFeeling") }
    }
    @Published var userChallenge: String {
        didSet { defaults.set(userChallenge, forKey: "userChallenge") }
    }
    @Published var referralSource: String {
        didSet { defaults.set(referralSource, forKey: "referralSource") }
    }

    // MARK: - Deep Link State
    @Published var deepLinkTab: Int = 0
    @Published var showBreathingFromDeepLink: Bool = false

    // MARK: - Member Since
    var memberSinceDate: Date {
        if let data = defaults.object(forKey: "memberSinceDate") as? Double {
            return Date(timeIntervalSince1970: data)
        }
        let now = Date()
        defaults.set(now.timeIntervalSince1970, forKey: "memberSinceDate")
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

        self.isSignedIn = ud.bool(forKey: "isSignedIn")
        self.onboardingComplete = ud.bool(forKey: "onboardingComplete")
        self.userName = ud.string(forKey: "userName") ?? ""
        self.userTimezone = ud.string(forKey: "userTimezone") ?? TimeZone.current.identifier
        self.dinoSkin = ud.string(forKey: "dinoSkin") ?? "default"
        self.dinoName = ud.string(forKey: "dinoName") ?? "Dino"
        self.userFeeling = ud.string(forKey: "userFeeling") ?? ""
        self.userChallenge = ud.string(forKey: "userChallenge") ?? ""
        self.referralSource = ud.string(forKey: "referralSource") ?? ""

        self.userIntentions = Self.load([String].self, from: ud, key: "userIntentions") ?? []
        self.moodEntries = Self.load([MoodEntry].self, from: ud, key: "moodEntries") ?? []
        self.journalEntries = Self.load([JournalEntry].self, from: ud, key: "journalEntries") ?? []
        self.gratitudeNotes = Self.load([GratitudeNote].self, from: ud, key: "gratitudeNotes") ?? []
        self.savedAffirmations = Self.load([SavedAffirmation].self, from: ud, key: "savedAffirmations") ?? []
        self.breathingSessions = Self.load([BreathingSession].self, from: ud, key: "breathingSessions") ?? []
        self.focusSessions = Self.load([FocusSession].self, from: ud, key: "focusSessions") ?? []
        self.meditationSessions = Self.load([MeditationSession].self, from: ud, key: "meditationSessions") ?? []
        self.assessmentResults = Self.load([AssessmentResult].self, from: ud, key: "assessmentResults") ?? []
        self.streakData = Self.load(StreakData.self, from: ud, key: "streakData") ?? StreakData()
        self.growthStats = Self.load(GrowthStats.self, from: ud, key: "growthStats") ?? GrowthStats()

        resetSelfCareIfNewDay()
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
        let lastDate = defaults.object(forKey: "selfCareDate") as? Double
        let today = Date().timeIntervalSince1970
        let oneDaySeconds: Double = 86400

        if let last = lastDate, today - last < oneDaySeconds {
            selfCareWater = defaults.bool(forKey: "selfCareWater")
            selfCareEat = defaults.bool(forKey: "selfCareEat")
            selfCareRest = defaults.bool(forKey: "selfCareRest")
            selfCareConnect = defaults.bool(forKey: "selfCareConnect")
        } else {
            selfCareWater = false
            selfCareEat = false
            selfCareRest = false
            selfCareConnect = false
            defaults.set(today, forKey: "selfCareDate")
        }
    }

    func toggleSelfCare(_ type: SelfCareType) {
        switch type {
        case .water:
            selfCareWater.toggle()
            defaults.set(selfCareWater, forKey: "selfCareWater")
        case .eat:
            selfCareEat.toggle()
            defaults.set(selfCareEat, forKey: "selfCareEat")
        case .rest:
            selfCareRest.toggle()
            defaults.set(selfCareRest, forKey: "selfCareRest")
        case .connect:
            selfCareConnect.toggle()
            defaults.set(selfCareConnect, forKey: "selfCareConnect")
        }
    }

    // MARK: - Clear All Data
    func clearAllData() {
        isSignedIn = false
        onboardingComplete = false
        userName = ""
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

    func signOut() {
        isSignedIn = false
    }

    func resetOnboarding() {
        onboardingComplete = false
    }
}

enum SelfCareType {
    case water, eat, rest, connect
}
