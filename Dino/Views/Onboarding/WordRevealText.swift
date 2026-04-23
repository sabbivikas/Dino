//
//  WordRevealText.swift
//  Dino
//
//  Reveals a line of text word-by-word with blur-in + rise animation.
//  Uses a custom FlowLayout so words wrap naturally. Gated by reduceMotion.
//

import SwiftUI

public struct WordRevealText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let text: String
    private let font: Font
    private let color: Color
    private let delay: Double

    @State private var appeared: Bool = false

    public init(_ text: String, font: Font, color: Color = .black, delay: Double = 0) {
        self.text = text
        self.font = font
        self.color = color
        self.delay = delay
    }

    public var body: some View {
        let words = text
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        FlowLayout(alignment: .center, spacing: 6, rowSpacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                WordView(
                    word: word,
                    index: idx,
                    baseDelay: delay,
                    font: font,
                    color: color,
                    reduceMotion: reduceMotion,
                    appeared: appeared
                )
            }
        }
        .onAppear {
            appeared = true
        }
    }
}

// Per-word animated view.
private struct WordView: View {
    let word: String
    let index: Int
    let baseDelay: Double
    let font: Font
    let color: Color
    let reduceMotion: Bool
    let appeared: Bool

    var body: some View {
        let wordDelay = baseDelay + Double(index) * 0.09
        if reduceMotion {
            Text(word)
                .font(font)
                .foregroundColor(color)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(wordDelay), value: appeared)
        } else {
            Text(word)
                .font(font)
                .foregroundColor(color)
                .opacity(appeared ? 1 : 0)
                .blur(radius: appeared ? 0 : 6)
                .offset(y: appeared ? 0 : 8)
                .animation(
                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.68).delay(wordDelay),
                    value: appeared
                )
        }
    }
}

// MARK: - FlowLayout (wraps words across lines)
public struct FlowLayout: Layout {
    public var alignment: HorizontalAlignment = .center
    public var spacing: CGFloat = 6
    public var rowSpacing: CGFloat = 6

    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 6, rowSpacing: CGFloat = 6) {
        self.alignment = alignment
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layoutRows(subviews: subviews, maxWidth: width)
        var totalHeight: CGFloat = 0
        for (i, row) in rows.enumerated() {
            totalHeight += row.height
            if i < rows.count - 1 { totalHeight += rowSpacing }
        }
        let usedWidth = rows.map { $0.width }.max() ?? 0
        return CGSize(width: min(usedWidth, width.isFinite ? width : usedWidth), height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowWidth = row.width
            let startX: CGFloat
            switch alignment {
            case .leading:  startX = bounds.minX
            case .trailing: startX = bounds.maxX - rowWidth
            default:        startX = bounds.minX + (bounds.width - rowWidth) / 2
            }
            var x = startX
            for item in row.items {
                let size = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct RowItem { let index: Int; let size: CGSize }
    private struct Row { var items: [RowItem] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func layoutRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let candidate = current.width == 0 ? size.width : current.width + spacing + size.width
            if candidate > maxWidth && !current.items.isEmpty {
                rows.append(current)
                current = Row()
                current.items = [RowItem(index: i, size: size)]
                current.width = size.width
                current.height = size.height
            } else {
                if !current.items.isEmpty { current.width += spacing }
                current.items.append(RowItem(index: i, size: size))
                current.width += size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
