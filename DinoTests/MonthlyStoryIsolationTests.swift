import XCTest

final class MonthlyStoryIsolationTests: XCTestCase {
    func testFoundationSourcesHaveNoExternalServiceImportsOrCalls() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        let sourceDirectories = [root.appendingPathComponent("Dino/Models"), root.appendingPathComponent("Dino/Services")]
        let files = try sourceDirectories.flatMap { directory in
            try FileManager.default.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("MonthlyStory") && $0.pathExtension == "swift" }
        }
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
