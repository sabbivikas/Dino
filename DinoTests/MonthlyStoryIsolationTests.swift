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

    /// Catches a missing `\` in a `rawValue:` string literal — the defect that made every
    /// `MonthlyStorySignalCoordinator.buildSignal` evidence ID a literal such as
    /// `"mood-shape-(monthKey.rawValue)"`. `MonthlyStoryEvidenceID` (and the server's
    /// `evidenceId`, functions/src/monthlyStorySchema.ts:56-60) reject `(`, so those IDs threw
    /// `.invalidEvidenceID` — but only at runtime, in a path no test had ever executed.
    ///
    /// Scope is deliberately narrow: only literals introduced by `rawValue:`, i.e. the validated
    /// token constructors. A broader "no `(` in any literal" sweep would fire on the script
    /// validator's regexes and ordinary prose, so it would be turned off rather than fixed.
    func testRawValueStringLiteralsInterpolateInsteadOfContainingLiteralParentheses() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        let manager = FileManager.default

        // Every monthly-story source, discovered rather than listed, so a new one is covered
        // the day it lands.
        var sources: [URL] = []
        for directory in ["Dino/Models", "Dino/Services", "Dino/Views"] {
            let url = root.appendingPathComponent(directory)
            let names = try manager.contentsOfDirectory(atPath: url.path)
            sources += names
                .filter { $0.hasPrefix("MonthlyStory") && $0.hasSuffix(".swift") }
                .sorted()
                .map { url.appendingPathComponent($0) }
        }
        XCTAssertGreaterThanOrEqual(sources.count, 10, "monthly-story source discovery found too little")

        let pattern = try NSRegularExpression(pattern: #"rawValue:\s*"((?:[^"\\]|\\.)*)""#)
        var literalsChecked = 0

        for file in sources {
            let source = try String(contentsOf: file, encoding: .utf8)
            let text = source as NSString
            for match in pattern.matches(in: source, range: NSRange(location: 0, length: text.length)) {
                let literal = text.substring(with: match.range(at: 1))
                literalsChecked += 1

                // Walk the literal, stepping over interpolations. `\(` opens one and its body is
                // Swift code, so parentheses inside it are legitimate (`\(x.lowercased())`). Only
                // a `(` sitting in literal text is the defect — a backslash someone dropped.
                var index = literal.startIndex
                var interpolationDepth = 0
                while index < literal.endIndex {
                    let character = literal[index]

                    if interpolationDepth > 0 {
                        if character == "(" { interpolationDepth += 1 }
                        if character == ")" { interpolationDepth -= 1 }
                        index = literal.index(after: index)
                        continue
                    }

                    if character == "\\" {
                        let next = literal.index(after: index)
                        guard next < literal.endIndex else { break }
                        if literal[next] == "(" { interpolationDepth = 1 }
                        index = literal.index(after: next)  // step over the escaped character
                        continue
                    }

                    XCTAssertNotEqual(character, "(", """
                        \(file.lastPathComponent): rawValue literal "\(literal)" contains an \
                        unescaped "(". A missing backslash turns an interpolation into dead text \
                        that the validated token initialisers reject at runtime.
                        """)
                    index = literal.index(after: index)
                }
            }
        }

        XCTAssertGreaterThan(literalsChecked, 0,
                             "no `rawValue:` literals matched — the pattern or the source list has drifted")
    }
}
