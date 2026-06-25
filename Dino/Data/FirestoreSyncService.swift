//
//  FirestoreSyncService.swift
//  Dino
//
//  Syncs local UserDefaults data to/from Firestore when user is signed in.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirestoreSyncService: ObservableObject {

    static let shared = FirestoreSyncService()

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var syncDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    #if DEBUG
                    print("[Firestore] user signed in — starting cloud sync")
                    #endif
                    await self?.syncFromCloud(uid: user.uid)
                } else {
                    #if DEBUG
                    print("[Firestore] user signed out — cloud sync disabled")
                    #endif
                }
            }
        }
    }

    // MARK: - Public API

    /// Schedule a debounced sync to cloud (2 second delay)
    func scheduleSyncToCloud() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                await syncToCloud()
            }
        }
    }

    /// Force immediate sync to cloud
    func syncToCloud() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("[Firestore] syncToCloud skipped — no user")
            #endif
            return
        }

        isSyncing = true
        #if DEBUG
        print("[Firestore] syncToCloud started")
        #endif

        let dm = SharedDataManager.shared
        let userRef = db.collection("users").document(uid)

        do {
            // Profile data
            let profile: [String: Any] = [
                "userName": dm.userName,
                "dinoName": dm.dinoName,
                "dinoSkin": dm.dinoSkin,
                "userFeeling": dm.userFeeling,
                "userChallenge": dm.userChallenge,
                "referralSource": dm.referralSource,
                "onboardingComplete": dm.onboardingComplete,
                "lastSynced": FieldValue.serverTimestamp()
            ]
            try await userRef.setData(profile, merge: true)

            // Mood entries
            try await syncCollection(
                parentRef: userRef, name: "moods",
                items: dm.moodEntries
            )

            // Journal entries
            try await syncCollection(
                parentRef: userRef, name: "journals",
                items: dm.journalEntries
            )

            // Gratitude notes
            try await syncCollection(
                parentRef: userRef, name: "gratitude",
                items: dm.gratitudeNotes
            )

            // Saved affirmations
            try await syncCollection(
                parentRef: userRef, name: "affirmations",
                items: dm.savedAffirmations
            )

            // Breathing sessions
            try await syncCollection(
                parentRef: userRef, name: "breathing",
                items: dm.breathingSessions
            )

            // Focus sessions
            try await syncCollection(
                parentRef: userRef, name: "focus",
                items: dm.focusSessions
            )

            // Meditation sessions
            try await syncCollection(
                parentRef: userRef, name: "meditation",
                items: dm.meditationSessions
            )

            // Assessment results
            try await syncCollection(
                parentRef: userRef, name: "assessments",
                items: dm.assessmentResults
            )

            // Streak data (single doc)
            let streakDict = encodeToDictionary(dm.streakData)
            if let streakDict = streakDict {
                try await userRef.collection("meta").document("streakData").setData(streakDict, merge: true)
            }

            // Growth stats (single doc)
            let growthDict = encodeToDictionary(dm.growthStats)
            if let growthDict = growthDict {
                try await userRef.collection("meta").document("growthStats").setData(growthDict, merge: true)
            }

            lastSyncDate = Date()
            #if DEBUG
            print("[Firestore] syncToCloud completed successfully")
            #endif
        } catch {
            #if DEBUG
            print("[Firestore] syncToCloud error")
            #endif
        }

        isSyncing = false
    }

    /// Pull data from cloud and merge into local
    func syncFromCloud(uid: String) async {
        isSyncing = true
        #if DEBUG
        print("[Firestore] syncFromCloud started")
        #endif

        let dm = SharedDataManager.shared
        let userRef = db.collection("users").document(uid)

        do {
            // Profile
            let profileDoc = try await userRef.getDocument()
            if let data = profileDoc.data() {
                if let name = data["userName"] as? String, !name.isEmpty {
                    dm.userName = name
                }
                if let dinoName = data["dinoName"] as? String, !dinoName.isEmpty {
                    dm.dinoName = dinoName
                }
                if let skin = data["dinoSkin"] as? String, !skin.isEmpty {
                    dm.dinoSkin = skin
                }
                #if DEBUG
                print("[Firestore] profile loaded from cloud")
                #endif
            }

            // Mood entries
            let moods: [MoodEntry] = try await fetchCollection(parentRef: userRef, name: "moods")
            if !moods.isEmpty {
                dm.moodEntries = mergeById(local: dm.moodEntries, cloud: moods)
                #if DEBUG
                print("[Firestore] moods synced: \(dm.moodEntries.count) entries")
                #endif
            }

            // Journal entries
            let journals: [JournalEntry] = try await fetchCollection(parentRef: userRef, name: "journals")
            if !journals.isEmpty {
                dm.journalEntries = mergeById(local: dm.journalEntries, cloud: journals)
                #if DEBUG
                print("[Firestore] journals synced: \(dm.journalEntries.count) entries")
                #endif
            }

            // Gratitude notes
            let gratitude: [GratitudeNote] = try await fetchCollection(parentRef: userRef, name: "gratitude")
            if !gratitude.isEmpty {
                dm.gratitudeNotes = mergeById(local: dm.gratitudeNotes, cloud: gratitude)
                #if DEBUG
                print("[Firestore] gratitude synced: \(dm.gratitudeNotes.count) entries")
                #endif
            }

            // Saved affirmations
            let affirmations: [SavedAffirmation] = try await fetchCollection(parentRef: userRef, name: "affirmations")
            if !affirmations.isEmpty {
                dm.savedAffirmations = mergeById(local: dm.savedAffirmations, cloud: affirmations)
                #if DEBUG
                print("[Firestore] affirmations synced: \(dm.savedAffirmations.count) entries")
                #endif
            }

            // Breathing sessions
            let breathing: [BreathingSession] = try await fetchCollection(parentRef: userRef, name: "breathing")
            if !breathing.isEmpty {
                dm.breathingSessions = mergeById(local: dm.breathingSessions, cloud: breathing)
                #if DEBUG
                print("[Firestore] breathing synced: \(dm.breathingSessions.count) entries")
                #endif
            }

            // Focus sessions
            let focus: [FocusSession] = try await fetchCollection(parentRef: userRef, name: "focus")
            if !focus.isEmpty {
                dm.focusSessions = mergeById(local: dm.focusSessions, cloud: focus)
                #if DEBUG
                print("[Firestore] focus synced: \(dm.focusSessions.count) entries")
                #endif
            }

            // Meditation sessions
            let meditation: [MeditationSession] = try await fetchCollection(parentRef: userRef, name: "meditation")
            if !meditation.isEmpty {
                dm.meditationSessions = mergeById(local: dm.meditationSessions, cloud: meditation)
                #if DEBUG
                print("[Firestore] meditation synced: \(dm.meditationSessions.count) entries")
                #endif
            }

            // Assessment results
            let assessments: [AssessmentResult] = try await fetchCollection(parentRef: userRef, name: "assessments")
            if !assessments.isEmpty {
                dm.assessmentResults = mergeById(local: dm.assessmentResults, cloud: assessments)
                #if DEBUG
                print("[Firestore] assessments synced: \(dm.assessmentResults.count) entries")
                #endif
            }

            // Streak data
            let streakDoc = try await userRef.collection("meta").document("streakData").getDocument()
            if let data = streakDoc.data(), let streak: StreakData = decodeFromDictionary(data) {
                // activeDates is the source of truth: union the sets, then derive
                // both counters from the merged set. (The old max-merge left stale
                // low streak values after reinstall / device switch.)
                var merged = dm.streakData
                merged.activeDates = merged.activeDates.union(streak.activeDates)
                merged.currentStreak = merged.computedCurrentStreak()
                merged.longestStreak = merged.computedLongestStreak()
                dm.streakData = merged
                #if DEBUG
                print("[Firestore] streak data synced")
                #endif
            }

            // Growth stats
            let growthDoc = try await userRef.collection("meta").document("growthStats").getDocument()
            if let data = growthDoc.data(), let growth: GrowthStats = decodeFromDictionary(data) {
                // Keep higher values
                if growth.level > dm.growthStats.level { dm.growthStats.level = growth.level }
                if growth.xp > dm.growthStats.xp { dm.growthStats.xp = growth.xp }
                #if DEBUG
                print("[Firestore] growth stats synced")
                #endif
            }

            lastSyncDate = Date()
            #if DEBUG
            print("[Firestore] syncFromCloud completed successfully")
            #endif
        } catch {
            #if DEBUG
            print("[Firestore] syncFromCloud error")
            #endif
        }

        isSyncing = false
    }

    // MARK: - Delete All User Data

    /// Deletes all Firestore data for the current user
    func deleteAllUserData() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("[Firestore] deleteAllUserData skipped — no user")
            #endif
            return
        }

        #if DEBUG
        print("[Firestore] deleting all user data")
        #endif
        let userRef = db.collection("users").document(uid)

        do {
            // Delete subcollections
            let subcollections = ["moods", "journals", "gratitude", "affirmations",
                                  "breathing", "focus", "meditation", "assessments", "meta"]
            for name in subcollections {
                let snapshot = try await userRef.collection(name).getDocuments()
                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
            }

            // Delete user document
            try await userRef.delete()
            #if DEBUG
            print("[Firestore] all user data deleted")
            #endif
        } catch {
            #if DEBUG
            print("[Firestore] deleteAllUserData error")
            #endif
            throw error
        }
    }

    // MARK: - Helpers

    /// Sync an array of Identifiable & Codable items to a Firestore subcollection
    private func syncCollection<T: Codable & Identifiable>(
        parentRef: DocumentReference, name: String, items: [T]
    ) async throws where T.ID == UUID {
        let colRef = parentRef.collection(name)
        for item in items {
            let dict = encodeToDictionary(item)
            if let dict = dict {
                try await colRef.document(item.id.uuidString).setData(dict, merge: true)
            }
        }
    }

    /// Fetch all docs from a subcollection and decode
    private func fetchCollection<T: Codable>(
        parentRef: DocumentReference, name: String
    ) async throws -> [T] {
        let snapshot = try await parentRef.collection(name).getDocuments()
        return snapshot.documents.compactMap { doc -> T? in
            return decodeFromDictionary(doc.data())
        }
    }

    /// Merge local and cloud arrays by ID, preferring cloud versions
    private func mergeById<T: Identifiable>(local: [T], cloud: [T]) -> [T] where T.ID: Hashable {
        var idMap: [T.ID: T] = [:]
        for item in local { idMap[item.id] = item }
        for item in cloud { idMap[item.id] = item } // cloud wins
        return Array(idMap.values)
    }

    /// Encode a Codable to a Firestore-friendly dictionary
    private func encodeToDictionary<T: Codable>(_ value: T) -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(value)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json
        } catch {
            #if DEBUG
            print("[Firestore] encode error")
            #endif
            return nil
        }
    }

    /// Decode a dictionary back to a Codable type
    private func decodeFromDictionary<T: Codable>(_ dict: [String: Any]) -> T? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[Firestore] decode error for \(T.self)")
            #endif
            return nil
        }
    }
}
