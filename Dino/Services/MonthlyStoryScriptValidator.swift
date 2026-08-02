import Foundation

enum MonthlyStoryScriptValidationError: Equatable, Sendable {
    case empty
    case tooShort(minimumWords: Int)
    case tooLong(maximumWords: Int)
    case percentage
    case exactCount
    case reportingLanguage(String)
    case diagnosisOrMedicalAdvice(String)
    case causalCertainty(String)
    case recommendationBenefitClaim
    case sensitiveNarration(String)
    case missingEvidenceClaims
    case unsupportedEvidenceID(MonthlyStoryEvidenceID)
    case evidenceNotAllowedForNarration(MonthlyStoryEvidenceID)
    case repeatedSection
    case excessiveINoticed
    case therapistFraming(String)
    case motivationalSpeakerFraming(String)
    case appEngagementLanguage(String)
    case rawTechnicalField(String)
    case userIdentifier
}

struct MonthlyStoryScriptValidationResult: Equatable, Sendable {
    let wordCount: Int
    let errors: [MonthlyStoryScriptValidationError]
    var isValid: Bool { errors.isEmpty }
}

enum MonthlyStoryScriptValidator {
    static let minimumWords = 80
    static let maximumWords = 300

    static func validate(script: String,
                         claimedEvidenceIDs: [MonthlyStoryEvidenceID],
                         availableEvidence: [MonthlyStoryEvidence]) -> MonthlyStoryScriptValidationResult {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let normalized = trimmed.lowercased()
        var errors: [MonthlyStoryScriptValidationError] = []

        if trimmed.isEmpty { errors.append(.empty) }
        if !trimmed.isEmpty && words.count < minimumWords { errors.append(.tooShort(minimumWords: minimumWords)) }
        if words.count > maximumWords { errors.append(.tooLong(maximumWords: maximumWords)) }
        if matches(#"\b\d+(?:\.\d+)?\s*%|\bpercent(?:age)?\b"#, in: normalized) { errors.append(.percentage) }
        if matches(#"\b\d+(?:[.,]\d+)?\b|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty)\s+(?:times|days|entries|moods|hours|minutes|recommendations|sessions|check-ins)\b"#, in: normalized) {
            errors.append(.exactCount)
        }

        appendFirstMatch(in: normalized,
                         phrases: ["you logged", "your data shows", "you checked in", "your entries indicate", "your mood decreased", "your activity was lower", "according to your data", "the app noticed"],
                         makeError: MonthlyStoryScriptValidationError.reportingLanguage,
                         to: &errors)
        appendFirstMatch(in: normalized,
                         phrases: ["you have depression", "you are depressed", "you have anxiety", "you are anxious", "diagnosis", "diagnosed", "medical condition", "take medication", "change your medication", "see a doctor", "clinical"],
                         makeError: MonthlyStoryScriptValidationError.diagnosisOrMedicalAdvice,
                         to: &errors)
        appendFirstMatch(in: normalized,
                         phrases: ["definitely because", "clearly because", "this caused", "that caused", "caused every", "proved that", "which is why", "made you feel"],
                         makeError: MonthlyStoryScriptValidationError.causalCertainty,
                         to: &errors)
        if containsAny(normalized, ["recommendation helped", "movie helped", "show helped", "book helped", "this helped you", "it made you feel better"]) {
            errors.append(.recommendationBenefitClaim)
        }
        appendFirstMatch(in: normalized,
                         phrases: ["self-harm", "self harm", "suicide", "suicidal", "crisis", "abuse", "trauma", "traumatic", "grief", "medication", "medical", "diagnosis", "sexual"],
                         makeError: MonthlyStoryScriptValidationError.sensitiveNarration,
                         to: &errors)

        let availableByID = Dictionary(uniqueKeysWithValues: availableEvidence.map { ($0.id, $0) })
        if !trimmed.isEmpty && claimedEvidenceIDs.isEmpty { errors.append(.missingEvidenceClaims) }
        for id in Set(claimedEvidenceIDs) {
            guard let evidence = availableByID[id] else {
                errors.append(.unsupportedEvidenceID(id))
                continue
            }
            if !evidence.allowedForNarration { errors.append(.evidenceNotAllowedForNarration(id)) }
        }

        if containsRepeatedContent(trimmed) { errors.append(.repeatedSection) }
        if occurrences(of: "i noticed", in: normalized) > 2 { errors.append(.excessiveINoticed) }
        appendFirstMatch(in: normalized,
                         phrases: ["as your therapist", "therapeutic journey", "healing journey", "process your emotions", "inner child"],
                         makeError: MonthlyStoryScriptValidationError.therapistFraming,
                         to: &errors)
        appendFirstMatch(in: normalized,
                         phrases: ["best version of yourself", "unlock your potential", "you've got this", "you can achieve anything", "everything happens for a reason", "never give up"],
                         makeError: MonthlyStoryScriptValidationError.motivationalSpeakerFraming,
                         to: &errors)
        appendFirstMatch(in: normalized,
                         phrases: ["in the app", "using dino", "your streak", "engagement", "check-in history", "app usage"],
                         makeError: MonthlyStoryScriptValidationError.appEngagementLanguage,
                         to: &errors)
        appendFirstMatch(in: normalized,
                         phrases: ["schemaVersion", "moodEvidenceDays", "corroboratingEvidenceDays", "allowedForNarration", "uidHash", "generationVersion", "evidenceIds"].map { $0.lowercased() },
                         makeError: MonthlyStoryScriptValidationError.rawTechnicalField,
                         to: &errors)
        if matches(#"\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b|\buid\b|\bdevice[_ -]?id\b|\b[0-9a-f]{8}-[0-9a-f-]{27,}\b"#, in: normalized) {
            errors.append(.userIdentifier)
        }

        return MonthlyStoryScriptValidationResult(wordCount: words.count, errors: unique(errors))
    }

    private static func appendFirstMatch(in text: String,
                                         phrases: [String],
                                         makeError: (String) -> MonthlyStoryScriptValidationError,
                                         to errors: inout [MonthlyStoryScriptValidationError]) {
        if let phrase = phrases.first(where: text.contains) { errors.append(makeError(phrase)) }
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains(where: text.contains)
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return text.components(separatedBy: needle).count - 1
    }

    private static func containsRepeatedContent(_ text: String) -> Bool {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map(normalize)
            .filter { !$0.isEmpty }
        if Set(paragraphs).count != paragraphs.count { return true }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map(normalize)
            .filter { $0.split(separator: " ").count >= 6 }
        return Set(sentences).count != sentences.count
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    private static func unique(_ errors: [MonthlyStoryScriptValidationError]) -> [MonthlyStoryScriptValidationError] {
        errors.reduce(into: []) { result, error in
            if !result.contains(error) { result.append(error) }
        }
    }
}
