//
//  MoodPaintingService.swift
//  Dino
//

import Foundation
import Combine
import UIKit
import FirebaseFunctions

enum MoodPaintingError: Error, LocalizedError {
    case invalidResponse(Int)
    case modelNotReady
    case decodeFailed
    case serviceUnavailable
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let code): return "invalid response from painting service (\(code))"
        case .modelNotReady:       return "painting model is still warming up"
        case .decodeFailed:        return "couldn't decode painting image"
        case .serviceUnavailable:  return "painting service is temporarily unavailable"
        case .network(let m):      return m
        }
    }
}

struct MoodPattern: Equatable {
    var dominantMood: String
    var moodVariety: Double
    var energyLevel: Double
    var monthName: String
    var year: Int
}

@MainActor
final class MoodPaintingService: ObservableObject {
    static let shared = MoodPaintingService()

    @Published var monthlyPaintings: [(date: Date, image: UIImage)] = []

    private init() {
        _ = loadAllPaintings()
    }

    // MARK: - Pure helpers (no UIKit/SwiftUI dependency on logic itself)

    nonisolated func analyzeMoods(entries: [MoodEntry]) -> MoodPattern {
        let cal = Calendar.current
        // Use the latest entry's date as the reference for month/year rather
        // than assuming the array is newest-first.
        let referenceDate = entries.map { $0.date }.max() ?? Date()
        let monthName = Self.monthName(from: referenceDate)
        let year = cal.component(.year, from: referenceDate)

        guard !entries.isEmpty else {
            return MoodPattern(
                dominantMood: "mixed",
                moodVariety: 0,
                energyLevel: 0.5,
                monthName: monthName,
                year: year
            )
        }

        // Map EmotionalWeather -> spec mood label
        let mapped: [String] = entries.map { Self.mapMood($0.weatherType) }

        var counts: [String: Int] = [:]
        for m in mapped { counts[m, default: 0] += 1 }

        let dominant = counts.max { $0.value < $1.value }?.key ?? "mixed"

        let unique = Double(Set(mapped).count)
        let total = Double(mapped.count)
        let variety = total > 0 ? min(1.0, unique / total) : 0

        // Energy is captured on the entry directly (1...5 conceptually) — average and normalize
        let energySum = entries.reduce(0) { $0 + $1.energyLevel }
        let avgEnergy = Double(energySum) / Double(entries.count)
        let normalized = min(1.0, max(0.0, avgEnergy / 5.0))

        return MoodPattern(
            dominantMood: dominant,
            moodVariety: variety,
            energyLevel: normalized,
            monthName: monthName,
            year: year
        )
    }

    nonisolated func buildArtisticPrompt(pattern: MoodPattern) -> String {
        let base: String
        switch pattern.dominantMood {
        case "calm":
            base = "soft watercolor landscape, misty morning hills, pale sage and lavender, gentle flowing brushstrokes, Studio Ghibli inspired, peaceful, dreamy, 4k"
        case "happy":
            base = "vibrant watercolor garden, warm golden hour light, wildflowers blooming, loose expressive brushstrokes, joyful colors, yellow and coral, Ghibli aesthetic, 4k"
        case "low":
            base = "moody watercolor, rain on window, deep indigo and grey, impressionist style, quiet and still, melancholic beauty, soft light, 4k"
        case "stressed":
            base = "abstract expressionist watercolor, bold dark brushstrokes, deep purple and crimson, raw emotion, turbulent sky, 4k"
        default:
            base = "abstract watercolor, warm and cool tones blending beautifully, expressive brushstrokes, emotional depth, complex harmony, 4k"
        }
        return base + ", no text, no words, no letters, painterly, artistic, beautiful"
    }

    // MARK: - Generation

    func generatePainting(for month: Date, moods: [MoodEntry]) async throws -> UIImage {
        let pattern = analyzeMoods(entries: moods)
        let prompt = buildArtisticPrompt(pattern: pattern)

        let image = try await callDALLE(prompt: prompt)
        savePainting(image, for: month)
        _ = loadAllPaintings()
        return image
    }

    private func callDALLE(prompt: String) async throws -> UIImage {
        let functions = Functions.functions(region: "us-central1")
        let callable = functions.httpsCallable("generateMoodPainting")

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(["prompt": prompt])
        } catch let error as NSError {
            #if DEBUG
            print("[Painting] Cloud Function failed: code=\(error.code) domain=\(error.domain) msg=\(error.localizedDescription)")
            #endif
            throw MoodPaintingError.network(error.localizedDescription)
        }

        guard let dict = result.data as? [String: Any],
              let urlString = dict["url"] as? String,
              let imageURL = URL(string: urlString) else {
            throw MoodPaintingError.decodeFailed
        }

        let (imageData, imageResponse): (Data, URLResponse)
        do {
            (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
        } catch {
            throw MoodPaintingError.network(error.localizedDescription)
        }
        guard let imageHTTP = imageResponse as? HTTPURLResponse, imageHTTP.statusCode == 200 else {
            throw MoodPaintingError.invalidResponse((imageResponse as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let image = UIImage(data: imageData) else {
            throw MoodPaintingError.decodeFailed
        }
        AnalyticsManager.shared.trackMoodPaintingCreated()
        return image
    }

    // MARK: - Persistence

    func savePainting(_ image: UIImage, for month: Date) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        var url = paintingURL(for: month)
        try? data.write(to: url, options: .atomic)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)

        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    func loadPainting(for month: Date) -> UIImage? {
        let url = paintingURL(for: month)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    func loadAllPaintings() -> [(date: Date, image: UIImage)] {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else {
            self.monthlyPaintings = []
            return []
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"

        var results: [(date: Date, image: UIImage)] = []
        for f in files {
            let name = f.lastPathComponent
            guard name.hasPrefix("painting_"), name.hasSuffix(".jpg") else { continue }
            let key = String(name.dropFirst("painting_".count).dropLast(".jpg".count))
            guard let date = formatter.date(from: key),
                  let data = try? Data(contentsOf: f),
                  let img = UIImage(data: data) else { continue }
            results.append((date: date, image: img))
        }
        results.sort { $0.date < $1.date }
        self.monthlyPaintings = results
        return results
    }

    func hasPainting(for month: Date) -> Bool {
        FileManager.default.fileExists(atPath: paintingURL(for: month).path)
    }

    // MARK: - Path helpers

    private func paintingURL(for month: Date) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("painting_\(monthKey(month)).jpg")
    }

    func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    // MARK: - Static utilities

    nonisolated private static func monthName(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date).lowercased()
    }

    nonisolated private static func mapMood(_ w: EmotionalWeather) -> String {
        switch w {
        case .clear:        return "happy"
        case .partlyCloudy: return "calm"
        case .overwhelmed:  return "stressed"
        case .drained:      return "low"
        }
    }
}
