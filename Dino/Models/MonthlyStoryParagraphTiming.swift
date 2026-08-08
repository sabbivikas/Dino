import Foundation

/// Where a paragraph is estimated to fall inside the spoken story.
struct MonthlyStoryParagraphSpan: Equatable, Sendable {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval

    func contains(_ time: TimeInterval) -> Bool { time >= start && time < end }
}

/// Maps a story's paragraphs onto its audio duration by share of word count.
///
/// This is an ESTIMATE and there is no way to make it exact today: neither the story document
/// nor the Hume response carries per-paragraph timing, so the only inputs are the paragraph text
/// and one total duration. A seek therefore lands near a paragraph's first sentence rather than
/// precisely on it.
///
/// That inaccuracy is why the UI has no chapter list with timestamps: a printed "2:14" claims a
/// precision this cannot deliver. Used only to move a highlight down the transcript and to let a
/// tap start playback around the right place, the same estimate reads as approximate — which is
/// what it is. If timing marks ever arrive from the provider, only this file changes.
enum MonthlyStoryParagraphTiming {

    static func spans(paragraphs: [String], duration: TimeInterval) -> [MonthlyStoryParagraphSpan] {
        guard duration.isFinite, duration > 0, !paragraphs.isEmpty else { return [] }

        let weights = paragraphs.map { max(wordCount($0), 1) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }

        var spans: [MonthlyStoryParagraphSpan] = []
        var consumed = 0
        for (index, weight) in weights.enumerated() {
            let start = duration * Double(consumed) / Double(total)
            consumed += weight
            // The last paragraph is pinned to the exact duration so the spans always tile the
            // whole track with no floating-point gap at the end.
            let end = index == weights.count - 1 ? duration : duration * Double(consumed) / Double(total)
            spans.append(MonthlyStoryParagraphSpan(index: index, start: start, end: end))
        }
        return spans
    }

    /// The paragraph being read at `time`, or nil when there is nothing to highlight.
    static func index(at time: TimeInterval, in spans: [MonthlyStoryParagraphSpan]) -> Int? {
        guard let last = spans.last else { return nil }
        if time >= last.end { return last.index }
        return spans.first { $0.contains(time) }?.index
    }

    private static func wordCount(_ paragraph: String) -> Int {
        paragraph.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }
}
