import XCTest

final class MonthlyStoryIsolationTests: XCTestCase {
    func testFoundationSourcesHaveNoExternalServiceImportsOrCalls() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        let paths = [
            "Dino/Models/MonthlyStoryBudget.swift",
            "Dino/Models/MonthlyStoryEvidence.swift",
            "Dino/Models/MonthlyStoryGenerationKey.swift",
            "Dino/Models/MonthlyStoryNarrativePlan.swift",
            "Dino/Models/MonthlyStorySignal.swift",
            "Dino/Services/MonthlyStoryCalendar.swift",
            "Dino/Services/MonthlyStoryEligibility.swift",
            "Dino/Services/MonthlyStoryScriptValidator.swift"
        ]
        let files = paths.map { root.appendingPathComponent($0) }
        let forbidden = ["import Firebase", "import PostHog", "import HealthKit", "import OpenAI", "URLSession", "https://", "Functions.functions", "Firestore.firestore", "Storage.storage", "AnalyticsManager", "NotificationCenter"]
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(file.lastPathComponent) contains forbidden integration: \(token)")
            }
        }
    }
}
