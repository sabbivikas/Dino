import Foundation

struct MonthlyStorySettings: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let disabled = MonthlyStorySettings()

    var enabled: Bool
    var useJournalThemes: Bool
    var useHealthPatterns: Bool
    var audioEnabled: Bool
    var timezone: String
    var timezoneEffectiveMonth: String
    var settingsVersion: Int

    init(enabled: Bool = false,
         useJournalThemes: Bool = false,
         useHealthPatterns: Bool = false,
         audioEnabled: Bool = false,
         timezone: String = "UTC",
         timezoneEffectiveMonth: String = "2000-01",
         settingsVersion: Int = Self.currentVersion) {
        self.enabled = enabled
        self.useJournalThemes = useJournalThemes
        self.useHealthPatterns = useHealthPatterns
        self.audioEnabled = audioEnabled
        self.timezone = timezone
        self.timezoneEffectiveMonth = timezoneEffectiveMonth
        self.settingsVersion = settingsVersion
    }

    var sanitizedForWrittenOnlyStage: Self {
        var value = self
        value.audioEnabled = false
        if !value.enabled {
            value.useJournalThemes = false
            value.useHealthPatterns = false
        }
        return value
    }

    func sanitized(audioAvailable: Bool) -> Self {
        var value = self
        if !audioAvailable { value.audioEnabled = false }
        if !value.enabled {
            value.useJournalThemes = false
            value.useHealthPatterns = false
            value.audioEnabled = false
        }
        return value
    }
}
