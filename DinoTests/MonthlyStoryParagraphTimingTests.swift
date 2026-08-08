import XCTest
@testable import Dino

/// The transcript highlight and tap-to-listen both ride on these spans. They are estimates by
/// construction — no per-paragraph timing exists — so what is worth pinning is not any single
/// value but the shape: the spans must tile the whole track, in order, with no gap, and every
/// lookup must land somewhere sane. A gap would freeze the highlight; an overshoot would seek
/// past the end.
final class MonthlyStoryParagraphTimingTests: XCTestCase {

    private let paragraphs = [
        "july held both hard and lighter moments.",
        "work seemed to carry more pressure than usual. that pressure mattered without needing to explain every other part of the month.",
        "next month, leave one part of the weekend unplanned."
    ]

    func testSpansTileTheWholeDurationInOrder() throws {
        let duration: TimeInterval = 180
        let spans = MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs, duration: duration)

        XCTAssertEqual(spans.count, paragraphs.count)
        XCTAssertEqual(spans.first?.start, 0)
        let finalEnd = try XCTUnwrap(spans.last?.end)
        XCTAssertEqual(finalEnd, duration, accuracy: 0.0001,
                       "the last span must be pinned to the duration, not left short by rounding")

        for (position, span) in spans.enumerated() {
            XCTAssertEqual(span.index, position)
            XCTAssertLessThan(span.start, span.end, "span \(position) is empty or inverted")
            if position > 0 {
                XCTAssertEqual(span.start, spans[position - 1].end, accuracy: 0.0001,
                               "gap between span \(position - 1) and \(position)")
            }
        }
    }

    func testLongerParagraphsGetProportionallyMoreTime() {
        let spans = MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs, duration: 180)
        let lengths = spans.map { $0.end - $0.start }
        // The middle paragraph is by far the longest, so it must hold the largest share.
        XCTAssertEqual(lengths.firstIndex(of: lengths.max()!), 1)
    }

    func testIndexLookupCoversEveryInstantIncludingTheEnd() {
        let duration: TimeInterval = 120
        let spans = MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs, duration: duration)

        XCTAssertEqual(MonthlyStoryParagraphTiming.index(at: 0, in: spans), 0)
        // Walk the whole track: every instant resolves, and never past the last paragraph.
        for tick in stride(from: 0.0, through: duration, by: 0.5) {
            let index = MonthlyStoryParagraphTiming.index(at: tick, in: spans)
            XCTAssertNotNil(index, "no paragraph resolved at \(tick)s")
            XCTAssertTrue((0..<paragraphs.count).contains(index ?? -1))
        }
        // At and beyond the end it pins to the final paragraph rather than going nil, so the
        // highlight does not vanish when playback finishes.
        XCTAssertEqual(MonthlyStoryParagraphTiming.index(at: duration, in: spans), paragraphs.count - 1)
        XCTAssertEqual(MonthlyStoryParagraphTiming.index(at: duration + 30, in: spans), paragraphs.count - 1)
    }

    func testDegenerateInputsProduceNoSpansRatherThanCrashing() {
        XCTAssertTrue(MonthlyStoryParagraphTiming.spans(paragraphs: [], duration: 120).isEmpty)
        XCTAssertTrue(MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs, duration: 0).isEmpty)
        XCTAssertTrue(MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs, duration: -5).isEmpty)
        XCTAssertTrue(MonthlyStoryParagraphTiming.spans(paragraphs: paragraphs,
                                                        duration: .infinity).isEmpty)
        XCTAssertNil(MonthlyStoryParagraphTiming.index(at: 10, in: []))

        // An empty paragraph still gets a slot; it must not collapse to a zero-width span that
        // the lookup would skip over.
        let withBlank = MonthlyStoryParagraphTiming.spans(paragraphs: ["", "words here"], duration: 60)
        XCTAssertEqual(withBlank.count, 2)
        XCTAssertLessThan(withBlank[0].start, withBlank[0].end)
    }

    func testSingleParagraphOwnsTheWholeTrack() {
        let spans = MonthlyStoryParagraphTiming.spans(paragraphs: ["one paragraph only."], duration: 90)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].start, 0)
        XCTAssertEqual(spans[0].end, 90, accuracy: 0.0001)
        XCTAssertEqual(MonthlyStoryParagraphTiming.index(at: 45, in: spans), 0)
    }
}
