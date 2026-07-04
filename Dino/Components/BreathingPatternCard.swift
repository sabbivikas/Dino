//
//  BreathingPatternCard.swift
//  Dino
//
//  The four pattern cards, each with a quiet motif in its accent.
//  Long press previews one cycle of the rhythm, compressed 2x.
//

import SwiftUI

struct BreathingPatternPicker: View {
    let selected: BreathingPattern
    let onSelect: (BreathingPattern) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("choose a rhythm")
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BreathingPattern.library) { pattern in
                    BreathingPatternCard(
                        pattern: pattern,
                        isSelected: pattern == selected,
                        reduceMotion: reduceMotion,
                        onSelect: { onSelect(pattern) }
                    )
                }
            }
        }
    }
}

struct BreathingPatternCard: View {
    let pattern: BreathingPattern
    let isSelected: Bool
    let reduceMotion: Bool
    let onSelect: () -> Void

    @State private var previewing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Text(pattern.name)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                motif
                    .frame(width: 34, height: 20)
            }

            Text(pattern.tagline)
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(pattern.timingSummary)
                .font(DinoTheme.numericFont(size: 12))
                .foregroundColor(DinoTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                .fill(isSelected ? pattern.accent.opacity(0.08) : DinoTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                .stroke(isSelected ? pattern.accent : DinoTheme.divider, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
        .animation(.easeInOut(duration: 0.35), value: isSelected)
        .onTapGesture {
            HapticManager.shared.light()
            onSelect()
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !reduceMotion else { return }
            HapticManager.shared.light()
            previewing = true
        } onPressingChanged: { pressing in
            if !pressing { previewing = false }
        }
    }

    @ViewBuilder
    private var motif: some View {
        switch pattern.id {
        case BreathingPattern.bigSigh.id:
            SighMotif(accent: pattern.accent, previewing: previewing, reduceMotion: reduceMotion)
        case BreathingPattern.sleepyCloud.id:
            CloudMotif(accent: pattern.accent, previewing: previewing, reduceMotion: reduceMotion)
        case BreathingPattern.steadySquare.id:
            SquareMotif(accent: pattern.accent, previewing: previewing, reduceMotion: reduceMotion)
        default:
            WaveMotif(accent: pattern.accent, previewing: previewing, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - big sigh: two ascending dots, one long soft dash

private struct SighMotif: View {
    let accent: Color
    let previewing: Bool
    let reduceMotion: Bool

    @State private var dashTrim: CGFloat = 1
    @State private var dot1Lit = true
    @State private var dot2Lit = true

    var body: some View {
        ZStack(alignment: .leading) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .opacity(dot1Lit ? 0.9 : 0.25)
                .scaleEffect(dot1Lit ? 1.0 : 0.7)
                .offset(x: 1, y: 4)
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .opacity(dot2Lit ? 0.9 : 0.25)
                .scaleEffect(dot2Lit ? 1.0 : 0.7)
                .offset(x: 9, y: -3)
            SighDash()
                .trim(from: 0, to: dashTrim)
                .stroke(accent.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 6)
                .offset(x: 17, y: 4)
        }
        .frame(width: 34, height: 20, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            // the dash exhales once on arrival
            dashTrim = 0
            withAnimation(.easeOut(duration: 2.2).delay(0.4)) { dashTrim = 1 }
        }
        .onChange(of: previewing) { _, active in
            guard !reduceMotion else { return }
            if active {
                // one full sigh, compressed 2x: 2s sip, 1s sip, 3s release
                dot1Lit = false
                dot2Lit = false
                dashTrim = 0
                withAnimation(.easeOut(duration: 2.0)) { dot1Lit = true }
                withAnimation(.easeOut(duration: 1.0).delay(2.0)) { dot2Lit = true }
                withAnimation(.easeOut(duration: 3.0).delay(3.0)) { dashTrim = 1 }
            } else {
                dot1Lit = true
                dot2Lit = true
                dashTrim = 1
            }
        }
    }
}

private struct SighDash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + 2)
        )
        return p
    }
}

// MARK: - sleepy cloud: a drowsy cloud drifting a few points side to side

private struct CloudMotif: View {
    let accent: Color
    let previewing: Bool
    let reduceMotion: Bool

    @State private var drift: CGFloat = 0
    @State private var breath: CGFloat = 1

    var body: some View {
        TinyCloud()
            .fill(accent.opacity(0.8))
            .frame(width: 26, height: 13)
            .scaleEffect(breath)
            .offset(x: drift)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    drift = 2.5
                }
            }
            .onChange(of: previewing) { _, active in
                guard !reduceMotion else { return }
                if active {
                    // one sleepy breath, compressed 2x: 2s in, 3.5s hold, 4s out
                    withAnimation(.easeInOut(duration: 2.0)) { breath = 1.18 }
                    withAnimation(.easeInOut(duration: 4.0).delay(5.5)) { breath = 1.0 }
                } else {
                    breath = 1
                }
            }
    }
}

private struct TinyCloud: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.addEllipse(in: CGRect(x: 0, y: h * 0.35, width: w * 0.45, height: h * 0.65))
        p.addEllipse(in: CGRect(x: w * 0.22, y: 0, width: w * 0.5, height: h * 0.85))
        p.addEllipse(in: CGRect(x: w * 0.5, y: h * 0.3, width: w * 0.5, height: h * 0.7))
        return p
    }
}

// MARK: - steady square: traces its own outline, one side per count

private struct SquareMotif: View {
    let accent: Color
    let previewing: Bool
    let reduceMotion: Bool

    @State private var trimEnd: CGFloat = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .trim(from: 0, to: trimEnd)
            .stroke(accent.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 15, height: 15)
            .rotationEffect(.degrees(-90))
            .onAppear {
                guard !reduceMotion else { return }
                // traces its four sides once on arrival
                trimEnd = 0
                withAnimation(.linear(duration: 1.6).delay(0.3)) { trimEnd = 1 }
            }
            .onChange(of: previewing) { _, active in
                guard !reduceMotion else { return }
                if active {
                    // 4-4-4-4 compressed 2x: four sides, two seconds each
                    trimEnd = 0
                    withAnimation(.linear(duration: 8.0)) { trimEnd = 1 }
                } else {
                    trimEnd = 1
                }
            }
    }
}

// MARK: - calm current: a sine line, barely moving

private struct WaveMotif: View {
    let accent: Color
    let previewing: Bool
    let reduceMotion: Bool

    @State private var slide: CGFloat = 0

    var body: some View {
        // A fixed two-wavelength sine slides one wavelength at a time behind a
        // 30pt window — periodic, so the repeat restart is seamless. The path
        // itself never recomputes; only the offset animates.
        StaticSine()
            .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 60, height: 12)
            .offset(x: slide + 15)
            .frame(width: 30, height: 12)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                startIdleDrift()
            }
            .onChange(of: previewing) { _, active in
                guard !reduceMotion else { return }
                if active {
                    // one full wave crest to crest, compressed 2x: 5s
                    withAnimation(.linear(duration: 5.0)) { slide -= 30 }
                } else {
                    var jump = Transaction()
                    jump.disablesAnimations = true
                    withTransaction(jump) { slide = 0 }
                    startIdleDrift()
                }
            }
    }

    private func startIdleDrift() {
        withAnimation(.linear(duration: 9.0).repeatForever(autoreverses: false)) {
            slide -= 30
        }
    }
}

private struct StaticSine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let amp = rect.height * 0.3
        let midY = rect.midY
        p.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 1
        while x <= rect.width {
            let angle = (x / rect.width) * .pi * 4  // two wavelengths
            p.addLine(to: CGPoint(x: x, y: midY + amp * sin(angle)))
            x += 1
        }
        return p
    }
}
