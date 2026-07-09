//
//  DinoIntents.swift
//  Dino
//
//  Siri via App Intents — dino, hands free. Capture intents (mood, journal,
//  gratitude) run in the BACKGROUND (the app process launches headless;
//  Firestore queues offline). Breathing opens the app straight into the
//  breathing space — panic wants a screen, not a chat. No Siri entitlement
//  is needed for App Intents, and donation to the system is automatic.
//
//  Voice capture deliberately skips ALL post-log theater (world moment,
//  lantern, gentle rec, break card) — those live in the view layer, so the
//  data pipelines here are frictionless by construction.
//

import AppIntents
import Foundation

// MARK: - Mood entity (fuzzy matching via EntityStringQuery)

struct MoodEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "mood"
    static var defaultQuery = MoodQuery()

    let id: String   // EmotionalWeather.rawValue

    var weather: EmotionalWeather { EmotionalWeather(rawValue: id) ?? .partlyCloudy }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(weather.label.lowercased())")
    }

    static let all = EmotionalWeather.allCases.map { MoodEntity(id: $0.rawValue) }
}

struct MoodQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MoodEntity] {
        identifiers.compactMap { id in MoodEntity.all.first { $0.id == id } }
    }

    func entities(matching string: String) async throws -> [MoodEntity] {
        guard let match = MoodSynonyms.match(string) else { return [] }
        return [MoodEntity(id: match.rawValue)]
    }

    func suggestedEntities() async throws -> [MoodEntity] { MoodEntity.all }
}

// MARK: - 1. log mood by voice (background)

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "tell dino how you feel"
    static var description = IntentDescription("logs your mood in dino. no questions asked.")

    @Parameter(title: "mood",
               requestValueDialog: "how's the weather inside? clear, partly cloudy, overwhelmed, or drained?")
    var mood: MoodEntity

    static var parameterSummary: some ParameterSummary {
        Summary("tell dino i'm feeling \(\.$mood)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let weather = mood.weather
        let entry = MoodEntry(weatherType: weather, energyLevel: 5, intensityLevel: 5)
        SharedDataManager.shared.logMood(entry)   // xp + streak + worldMoods write included
        AnalyticsManager.shared.trackMoodLogged(weather: weather.rawValue, energy: 5, intensity: 5)
        SiriReturnMoment.stamp()
        let rotation = SharedDataManager.shared.moodEntries.count
        return .result(dialog: IntentDialog(stringLiteral: SiriReplies.moodLine(for: weather, rotation: rotation)))
    }
}

// MARK: - 2. journal a thought (background)

struct JournalThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "add to dino journal"
    static var description = IntentDescription("keeps a spoken thought in your dino journal.")

    @Parameter(title: "thought", requestValueDialog: "what's on your mind?")
    var thought: String

    static var parameterSummary: some ParameterSummary {
        Summary("journal \(\.$thought) in dino")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: SiriReplies.emptyCaptureLine))
        }

        let df = DateFormatter()
        df.dateStyle = .medium
        let entry = JournalEntry(
            audioFileName: "",
            title: "journal entry \u{2014} \(df.string(from: Date()))",   // matches the composer's title convention
            summary: trimmed,
            moodTag: "reflective"
        )
        SharedDataManager.shared.addJournalEntry(entry)
        AnalyticsManager.shared.trackJournalEntryCreated(type: "siri")

        // DinoMind (opt-in only): same theme pipeline as the composer.
        if SharedDataManager.shared.journalThemeLearningEnabled {
            let moodSnapshot = SharedDataManager.shared.moodEntries
                .first(where: { Calendar.current.isDateInToday($0.date) })?
                .weatherType.rawValue ?? ""
            Task {
                if let theme = await ThemeExtractionService.extractTheme(from: trimmed) {
                    SharedDataManager.shared.recordThemeTag(theme: theme, mood: moodSnapshot, source: ThemeTag.sourceJournal)
                }
            }
        }

        let hour = Calendar.current.component(.hour, from: Date())
        return .result(dialog: IntentDialog(stringLiteral: SiriReplies.journalLine(hour: hour)))
    }
}

// MARK: - 3. start breathing (opens the app — no dialogue)

struct StartBreathingIntent: AppIntent {
    static var title: LocalizedStringResource = "breathe with dino"
    static var description = IntentDescription("opens dino straight into the breathing space.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedDataManager.shared.showBreathingFromDeepLink = true
        return .result()
    }
}

// MARK: - 4. gratitude by voice (background)

struct GratitudeIntent: AppIntent {
    static var title: LocalizedStringResource = "add to dino gratitude jar"
    static var description = IntentDescription("drops a spoken gratitude into your dino jar.")

    @Parameter(title: "gratitude", requestValueDialog: "what are you grateful for?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("add \(\.$text) to the dino jar")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: SiriReplies.emptyCaptureLine))
        }
        SharedDataManager.shared.addGratitudeNote(trimmed)
        let rotation = SharedDataManager.shared.gratitudeNotes.count
        return .result(dialog: IntentDialog(stringLiteral: SiriReplies.gratitudeLine(rotation: rotation)))
    }
}

// MARK: - App shortcuts (work out of the box; auto-donated on use)

struct DinoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "tell \(.applicationName) i'm feeling \(\.$mood)",
                "log my mood in \(.applicationName)",
            ],
            shortTitle: "log mood",
            systemImageName: "cloud.sun"
        )
        AppShortcut(
            intent: JournalThoughtIntent(),
            phrases: [
                "add to my \(.applicationName) journal",
                "journal in \(.applicationName)",
            ],
            shortTitle: "journal a thought",
            systemImageName: "book"
        )
        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "breathe with \(.applicationName)",
                "i need to breathe with \(.applicationName)",
            ],
            shortTitle: "breathe",
            systemImageName: "wind"
        )
        AppShortcut(
            intent: GratitudeIntent(),
            phrases: [
                "add to my \(.applicationName) gratitude jar",
                "gratitude in \(.applicationName)",
            ],
            shortTitle: "gratitude",
            systemImageName: "heart"
        )
    }
}
