//
//  RhythmsView.swift
//  Dino
//
//  Flat SwiftUI screens for the "rhythms" (Emotional DNA) feature, bound to
//  the verified PatternEngine output (RhythmsAnalysis). Three states:
//    • learning  — hasEnoughData == false ("N more days")
//    • forecast  — today/tomorrow/day-after weather + insight cards
//    • the dark "about tomorrow" card — only when tomorrow is likelyHard
//  No 3D, no AI, no networking. Insights only render when their underlying
//  stat is confident / non-nil — honesty over filler.
//
//  Design tokens mirror the rhythms design export (frame.jsx) and Dino's
//  lowercase voice. Not wired to the home grid / navigation yet.
//

import SwiftUI

// MARK: - Tokens (rhythms-local, fixed — matches the design export)

private enum RH {
    static let cream = Color(hex: "#FAF6EC")
    static let card = Color(hex: "#FEFBF3")
    static let ink = Color(hex: "#3D3A35")
    static let ink2 = Color(hex: "#7A7266")
    static let ink3 = Color(hex: "#A8A29A")
    static let sage = Color(hex: "#7BA872")
    static let sageSoft = Color(hex: "#A8C5A0")
    static let hard = Color(hex: "#E8889A")
    static let growing = Color(hex: "#C4B8D4")
    static let breakthrough = Color(hex: "#FFE066")
    static let sun = Color(hex: "#F5D97A")
    static let rain = Color(hex: "#7B8CDE")
}

// MARK: - Weather mapping (mood score 1...4 → glyph)

private enum WeatherKind {
    case clear, clearing, lightRain

    var symbol: String {
        switch self {
        case .clear:     return "sun.max.fill"
        case .clearing:  return "cloud.sun.fill"
        case .lightRain: return "cloud.rain.fill"
        }
    }
    var label: String {
        switch self {
        case .clear:     return "clear"
        case .clearing:  return "clearing"
        case .lightRain: return "light rain"
        }
    }
    var tint: Color {
        switch self {
        case .clear:     return RH.sun
        case .clearing:  return RH.sageSoft
        case .lightRain: return RH.rain
        }
    }
    static func from(score: Double) -> WeatherKind {
        if score >= 3.3 { return .clear }
        if score >= 2.4 { return .clearing }
        return .lightRain
    }
}

// MARK: - Weekday names (Calendar: 1 = Sunday … 7 = Saturday)

private let weekdayNames = ["", "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
private func weekdayName(_ wd: Int) -> String { weekdayNames.indices.contains(wd) ? weekdayNames[wd] : "" }
private func weekdayShort(_ wd: Int) -> String { String(weekdayName(wd).prefix(3)) }

// MARK: - Root

struct RhythmsView: View {
    let analysis: RhythmsAnalysis
    var moodSequence: [HelixMood] = []   // oldest → newest, one per recent day
    var calendar: Calendar = .current
    var now: Date = Date()

    var body: some View {
        ZStack {
            RH.cream.ignoresSafeArea()
            if analysis.hasEnoughData {
                RhythmsForecastView(analysis: analysis, moodSequence: moodSequence,
                                    calendar: calendar, now: now)
            } else {
                RhythmsLearningView(daysAvailable: analysis.daysOfDataAvailable)
            }
        }
    }
}

// MARK: - Learning state

private struct RhythmsLearningView: View {
    let daysAvailable: Int
    private var needed: Int { PatternEngine.minDaysToSpeak }
    private var remaining: Int { max(0, needed - daysAvailable) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("your rhythms")
                    .font(DinoTheme.dinoFont(size: 13)).foregroundColor(RH.ink2)
                Text("dino is learning\nyour rhythms")
                    .font(DinoTheme.dinoFont(size: 26)).foregroundColor(RH.ink)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24).padding(.top, 14)

            // Dusk panel with a faint half-formed strand (placeholder for the helix).
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#1C2742"), Color(hex: "#101524")],
                                         startPoint: .top, endPoint: .bottom))
                LearningStrandPlaceholder(progress: needed > 0 ? Double(daysAvailable) / Double(needed) : 0)
                VStack {
                    Spacer()
                    Text("✦ still forming")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 20).padding(.top, 12)

            // Progress: N more days + count + bar.
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(remaining == 1 ? "1 more day" : "\(remaining) more days")
                        .font(DinoTheme.dinoFont(size: 15)).foregroundColor(RH.ink)
                    Spacer()
                    Text("\(daysAvailable) of \(needed) days gathered")
                        .font(DinoTheme.dinoFont(size: 13)).foregroundColor(RH.ink3)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(LinearGradient(colors: [RH.sageSoft, RH.sage],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(needed > 0 ? min(1, Double(daysAvailable) / Double(needed)) : 0))
                    }
                }
                .frame(height: 8)

                Text("keep checking in — every day adds a firefly. once i’ve watched you for three weeks, i’ll start to see your patterns. \u{1F331}")
                    .font(DinoTheme.dinoFont(size: 15)).foregroundColor(RH.ink2)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24).padding(.top, 18)

            Spacer(minLength: 0)
            PrivacyLineView().padding(.bottom, 18)
        }
    }
}

private struct LearningStrandPlaceholder: View {
    let progress: Double   // 0...1 — how much of the strand has "filled in"
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // faint full strand
                strand(w: w, h: h, color: Color.white.opacity(0.10), filled: 1.0)
                // filled-so-far fireflies
                strand(w: w, h: h, color: RH.breakthrough.opacity(0.7), filled: progress)
            }
        }
    }
    private func strand(w: CGFloat, h: CGFloat, color: Color, filled: Double) -> some View {
        let dots = 24
        let shown = Int((Double(dots) * max(0, min(1, filled))).rounded())
        return ZStack {
            ForEach(0..<dots, id: \.self) { i in
                if i < shown {
                    let t = CGFloat(i) / CGFloat(dots - 1)
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: w * (0.5 + 0.28 * sin(t * .pi * 4)),
                                  y: h * (0.88 - 0.76 * t))
                }
            }
        }
    }
}

// MARK: - Forecast state

private struct RhythmsForecastView: View {
    let analysis: RhythmsAnalysis
    let moodSequence: [HelixMood]
    let calendar: Calendar
    let now: Date
    @State private var shape: HelixShape = .helix

    private var todayWeekday: Int { calendar.component(.weekday, from: now) }
    private var tomorrowWeekday: Int { wd(offset: 1) }
    private var dayAfterWeekday: Int { wd(offset: 2) }
    private func wd(offset: Int) -> Int {
        let d = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        return calendar.component(.weekday, from: d)
    }

    private func score(forWeekday wd: Int) -> Double {
        analysis.weekdayBaseline[wd]?.mean ?? analysis.overallBaseline
    }

    private var todayWeather: WeatherKind { .from(score: score(forWeekday: todayWeekday)) }
    private var tomorrowWeather: WeatherKind {
        analysis.risk.likelyHard ? .lightRain : .from(score: score(forWeekday: tomorrowWeekday))
    }
    private var dayAfterWeather: WeatherKind { .from(score: score(forWeekday: dayAfterWeekday)) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // HERO: the emotional-DNA helix, morphing between formations.
                VStack(alignment: .leading, spacing: 2) {
                    Text("your rhythms")
                        .font(DinoTheme.dinoFont(size: 13)).foregroundColor(RH.ink2)
                    Text("emotional dna")
                        .font(DinoTheme.dinoFont(size: 28)).foregroundColor(RH.ink)
                }
                .padding(.bottom, 10)

                RhythmsHelix(moods: moodSequence, ghostCount: 3, shape: shape)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1))

                Picker("formation", selection: $shape) {
                    ForEach(HelixShape.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 12).padding(.bottom, 22)

                // FORECAST
                VStack(alignment: .leading, spacing: 2) {
                    Text("your inner weather")
                        .font(DinoTheme.dinoFont(size: 22)).foregroundColor(RH.ink)
                }
                .padding(.bottom, 14)

                // 3-day forecast.
                HStack(spacing: 10) {
                    ForecastTile(when: "today", weather: todayWeather, accent: nil)
                    ForecastTile(when: "tomorrow", weather: tomorrowWeather,
                                 accent: analysis.risk.likelyHard ? RH.rain : nil, emphasized: true)
                    ForecastTile(when: weekdayShort(dayAfterWeekday), weather: dayAfterWeather, accent: nil)
                }
                .padding(.bottom, 18)

                // Dark "about tomorrow" card — only when tomorrow is likelyHard + confident.
                if analysis.risk.likelyHard && analysis.risk.confident {
                    AboutTomorrowCard(weekday: tomorrowWeekday)
                        .padding(.bottom, 22)
                }

                // Insights (only confident / non-nil).
                let insights = derivedInsights()
                if !insights.isEmpty {
                    Text("what i’ve noticed")
                        .font(DinoTheme.dinoFont(size: 14)).foregroundColor(RH.ink2)
                        .padding(.bottom, 10)
                    VStack(spacing: 10) {
                        ForEach(insights.indices, id: \.self) { i in InsightCardView(vm: insights[i]) }
                    }
                }

                PrivacyLineView().padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    // MARK: Insight derivation (real stats only)

    private func derivedInsights() -> [InsightVM] {
        var out: [InsightVM] = []

        // 1) Hardest weekday — confident weekday meaningfully below baseline.
        let confidentWeekdays = analysis.weekdayBaseline.filter { $0.value.confident }
        if let hardest = confidentWeekdays.min(by: { $0.value.mean < $1.value.mean })?.key,
           let stat = analysis.weekdayBaseline[hardest] {
            let gap = analysis.overallBaseline - stat.mean
            if gap >= 0.3 {
                let strength = gap >= 1.0 ? 3 : (gap >= 0.5 ? 2 : 1)
                out.append(InsightVM(symbol: "cloud.rain.fill", color: RH.hard,
                                     text: "\(weekdayName(hardest))s ask a lot of you", strength: strength))
            }
        }

        // 2) Practice lift — only a real positive lift.
        if let pc = analysis.practiceCorrelation, pc.liftRatio >= 1.1 {
            let strength = pc.liftRatio >= 1.8 ? 3 : (pc.liftRatio >= 1.3 ? 2 : 1)
            out.append(InsightVM(symbol: "pencil.and.outline", color: RH.sage,
                                 text: "journaling lifts you \(ratioText(pc.liftRatio))× the next day",
                                 strength: strength))
        }

        // 3) Recovery time — only when a cycle was observed.
        if let r = analysis.recoveryTimeDays {
            let days = Int(r.rounded())
            let strength = r <= 2 ? 3 : (r <= 4 ? 2 : 1)
            let dayWord = days == 1 ? "day" : "days"
            out.append(InsightVM(symbol: "leaf.fill", color: RH.growing,
                                 text: "you bounce back in about \(days) \(dayWord)", strength: strength))
        }
        return out
    }

    private func ratioText(_ r: Double) -> String {
        let rounded = (r * 10).rounded() / 10
        return abs(rounded - rounded.rounded()) < 0.05
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}

// MARK: - Components

private struct ForecastTile: View {
    let when: String
    let weather: WeatherKind
    var accent: Color?
    var emphasized: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(when).font(DinoTheme.dinoFont(size: 12.5)).foregroundColor(RH.ink3)
            Image(systemName: weather.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: emphasized ? 30 : 26))
                .foregroundStyle(weather.tint)
                .frame(height: 34)
            Text(weather.label)
                .font(DinoTheme.dinoFont(size: 13.5)).foregroundColor(RH.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 6)
        .background(RH.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((accent ?? RH.sageSoft).opacity(accent != nil ? 0.45 : 0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
    }
}

private struct AboutTomorrowCard: View {
    let weekday: Int
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#243150"), Color(hex: "#121830")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 8) {
                Text("about tomorrow — \(weekdayName(weekday))")
                    .font(DinoTheme.dinoFont(size: 13)).foregroundColor(Color.white.opacity(0.55))
                Text("tomorrow might ask a lot of you. \(weekdayName(weekday))s often do.")
                    .font(DinoTheme.dinoFont(size: 21)).foregroundColor(Color(hex: "#F4F1E8"))
                    .lineSpacing(3)
                Text("i’ll be here before it starts. you don’t have to do anything tonight. \u{1F319}")
                    .font(DinoTheme.dinoFont(size: 14.5)).foregroundColor(Color(hex: "#EAF0E8").opacity(0.72))
                    .lineSpacing(4).padding(.top, 2)
                HStack(spacing: 8) {
                    Text("likely a tender day")
                        .font(DinoTheme.dinoFont(size: 12)).foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                    StrengthDotsView(filled: 3, color: RH.hard)
                }
                .padding(.top, 6)
            }
            .padding(22)
        }
        .shadow(color: Color(hex: "#141C2E").opacity(0.3), radius: 13, y: 8)
    }
}

private struct InsightVM {
    let symbol: String
    let color: Color
    let text: String
    let strength: Int
}

private struct InsightCardView: View {
    let vm: InsightVM
    private var strengthLabel: String {
        vm.strength >= 3 ? "strong pattern" : (vm.strength == 2 ? "a clear lean" : "a gentle hint")
    }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(vm.color.opacity(0.13))
                Image(systemName: vm.symbol).font(.system(size: 18)).foregroundColor(vm.color)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.text).font(DinoTheme.dinoFont(size: 16)).foregroundColor(RH.ink).lineSpacing(2)
                HStack(spacing: 8) {
                    StrengthDotsView(filled: vm.strength, color: vm.color)
                    Text(strengthLabel).font(DinoTheme.dinoFont(size: 11)).foregroundColor(RH.ink3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(RH.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(RH.sageSoft.opacity(0.16), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

private struct StrengthDotsView: View {
    let filled: Int
    var total: Int = 3
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Circle().fill(i < filled ? color : Color.black.opacity(0.10))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

private struct PrivacyLineView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(RH.ink3)
            Text("yours alone — never leaves this device")
                .font(DinoTheme.dinoFont(size: 12)).foregroundColor(RH.ink3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews (fixtures only — no live data, no entry point yet)

#if DEBUG
private func previewWeekdays(_ pairs: [(Int, Double, Int)]) -> [Int: WeekdayStat] {
    Dictionary(uniqueKeysWithValues: pairs.map {
        ($0.0, WeekdayStat(mean: $0.1, count: $0.2, confident: $0.2 >= PatternEngine.minWeekdayCount))
    })
}

private let learningFixture = RhythmsAnalysis(
    overallBaseline: 0, weekdayBaseline: [:],
    trajectory: Trajectory(slope: 0, confident: false),
    recoveryTimeDays: nil, practiceCorrelation: nil,
    risk: RiskAssessment(score: 0, confident: false, likelyHard: false,
                         factors: RiskFactors(weekdayGap: 0, downwardTrajectory: 0, belowBaseline: 0, noPracticeToday: 0)),
    daysOfDataAvailable: 12, hasEnoughData: false)

private let calmFixture = RhythmsAnalysis(
    overallBaseline: 3.0,
    weekdayBaseline: previewWeekdays([(1, 3.2, 6), (2, 2.9, 6), (3, 3.0, 6), (4, 3.1, 7),
                                      (5, 3.0, 7), (6, 3.2, 6), (7, 3.3, 6)]),
    trajectory: Trajectory(slope: 0.1, confident: true),
    recoveryTimeDays: 2.0,
    practiceCorrelation: PracticeCorrelation(withMoodMean: 3.3, withoutMoodMean: 2.2, liftRatio: 1.5),
    risk: RiskAssessment(score: 0.3, confident: true, likelyHard: false,
                         factors: RiskFactors(weekdayGap: 0.1, downwardTrajectory: 0, belowBaseline: 0, noPracticeToday: 1)),
    daysOfDataAvailable: 47, hasEnoughData: true)

private let hardFixture = RhythmsAnalysis(
    overallBaseline: 2.9,
    weekdayBaseline: previewWeekdays([(1, 3.2, 8), (2, 1.6, 8), (3, 3.0, 8), (4, 3.1, 8),
                                      (5, 3.0, 8), (6, 3.3, 8), (7, 3.3, 8)]),
    trajectory: Trajectory(slope: -0.4, confident: true),
    recoveryTimeDays: 2.0,
    practiceCorrelation: PracticeCorrelation(withMoodMean: 3.4, withoutMoodMean: 1.7, liftRatio: 2.0),
    risk: RiskAssessment(score: 0.72, confident: true, likelyHard: true,
                         factors: RiskFactors(weekdayGap: 0.43, downwardTrajectory: 0.4, belowBaseline: 0.2, noPracticeToday: 1)),
    daysOfDataAvailable: 63, hasEnoughData: true)

private let sampleMoods: [HelixMood] = (0..<60).map { i in
    // Varied rise/fall (two sines + jitter), banded into the 5 moods; gold rare.
    let t = Double(i)
    let raw = sin(t * 0.28) * 0.6 + sin(t * 0.11 + 0.7) * 0.4
    let jitter = [0.0, 0.18, -0.16, 0.10, -0.22, 0.07][i % 6]
    let norm = min(1, max(0, (raw + 1) / 2 + jitter))
    if norm > 0.93 { return .breakthrough }
    if norm > 0.66 { return .steady }
    if norm > 0.44 { return .growing }
    if norm > 0.22 { return .tender }
    return .hard
}

#Preview("learning") { RhythmsView(analysis: learningFixture) }
#Preview("forecast — calm") { RhythmsView(analysis: calmFixture, moodSequence: sampleMoods) }
#Preview("forecast — likely hard") { RhythmsView(analysis: hardFixture, moodSequence: sampleMoods) }
#endif
