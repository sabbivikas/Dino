//
//  GardenShare.swift
//  Dino
//
//  Share my garden: the pure heart of the postcard — voice, the stamp seed,
//  the day count, and the privacy inventory. The postcard's strings are
//  frozen here so a test can sweep them: garden + day + abstract stamp only,
//  never moods, streaks, names, or numbers that mean anything to anyone else.
//

import SwiftUI
import FirebaseAuth

enum GardenShare {

    /// The stable identity behind the stamp — auth uid, with a warm fallback
    /// so signed-out gardens still get a consistent local stamp.
    @MainActor
    static func currentUID() -> String {
        Auth.auth().currentUser?.uid ?? "dino"
    }

    // MARK: - Voice (lowercase, zero dashes — tested)

    static func caption(day: Int) -> String { String(localized: "my little garden \u{00B7} day \(day)") }
    static let footer = String(localized: "grown with dino \u{1F995}")
    static let topLabel = String(localized: "\u{00B7} the dino garden \u{00B7}")
    static let daysLabel = String(localized: "days")
    static let stampFailToast = String(localized: "couldn't make your postcard just now. try again \u{1F331}")

    /// stage-only caption for the stamp — privacy safe (never mood or streak)
    static func stageCaption(_ stage: GrowthStage) -> String {
        switch stage {
        case .seed:     return String(localized: "just planted")
        case .cracking: return String(localized: "breaking ground")
        case .sprout:   return String(localized: "a new sprout")
        case .seedling: return String(localized: "a young seedling")
        case .growing:  return String(localized: "growing tall")
        case .budding:  return String(localized: "about to bloom")
        case .opening:  return String(localized: "opening up")
        case .bloomed:  return String(localized: "in full bloom")
        case .thriving: return String(localized: "thriving")
        }
    }
    static let postmarkTop = String(localized: "dino post")
    static func postmarkDay(day: Int) -> String { String(localized: "day \(day)") }
    static let composingLine = String(localized: "picking the best light...")
    static let shareText = String(localized: "my little garden is growing \u{1F331} i keep it in dino, a tiny gentle companion")
    static let shareButtonLabel = String(localized: "share my garden")

    static var allFixedStrings: [String] {
        [caption(day: 3), footer, postmarkTop, postmarkDay(day: 3), composingLine, shareText, shareButtonLabel,
         topLabel, daysLabel, stampFailToast,
         stageCaption(.seed), stageCaption(.sprout), stageCaption(.growing), stageCaption(.bloomed), stageCaption(.thriving)]
    }

    /// Every string that appears ON the composed card — the privacy sweep
    /// asserts this inventory is complete and clean.
    static func cardStrings(day: Int) -> [String] {
        [caption(day: day), footer, postmarkTop, postmarkDay(day: day)]
    }

    // MARK: - The stamp seed (deterministic, namespaced, permanent)

    /// Same user → the same stamp on every card, forever. Namespaced so the
    /// stamp never collides with other GradientSeed uses of the raw uid.
    static func stampSeed(uid: String) -> String { "garden-stamp|" + uid }

    // MARK: - Garden age (never resets — not the streak)

    /// Days since the earliest recorded practice, day 1 inclusive.
    /// A garden with no sessions yet is on day 1 of its life.
    static func age(firstPractice: Date?, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let first = firstPractice else { return 1 }
        let a = calendar.startOfDay(for: first)
        let b = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: a, to: b).day ?? 0
        return max(days, 0) + 1
    }
}

// MARK: - The stamp

/// A little postage stamp that is unmistakably THEIRS: perforated edges,
/// cream frame, and inside it the user's own seeded gradient with a drawn
/// leaf mark — abstract to everyone, permanent to its owner.
struct GardenStampView: View {
    let uid: String

    var body: some View {
        ZStack {
            SeededMeshGradient(seed: GardenShare.stampSeed(uid: uid), radius: 44)
            // cream inner frame — the classic stamp window
            Rectangle()
                .strokeBorder(Color(hex: "#FFFDF6").opacity(0.85), lineWidth: 2.5)
                .padding(3.5)
            StampLeafMark()
                .stroke(Color(hex: "#3D3A35").opacity(0.52),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 30)
        }
        .frame(width: 64, height: 78)
        .clipShape(StampPerforation(toothRadius: 3.0, spacing: 8.0), style: FillStyle(eoFill: true))
        .accessibilityHidden(true)
    }
}

/// teardrop leaf with a single vein — drawn paths, no emoji
struct StampLeafMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.04))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.02),
                       control: CGPoint(x: rect.maxX + w * 0.14, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.04),
                       control: CGPoint(x: rect.minX - w * 0.14, y: rect.midY))
        // the vein, slightly off true
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.14))
        p.addQuadCurve(to: CGPoint(x: rect.midX - w * 0.04, y: rect.maxY - h * 0.10),
                       control: CGPoint(x: rect.midX + w * 0.06, y: rect.midY))
        return p
    }
}

/// Stamp outline with semicircle notches along every edge — clip with
/// FillStyle(eoFill: true) for real perforation.
struct StampPerforation: Shape {
    var toothRadius: CGFloat = 3.0
    var spacing: CGFloat = 8.0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        func punch(along edge: [CGPoint]) {
            for c in edge {
                p.addEllipse(in: CGRect(x: c.x - toothRadius, y: c.y - toothRadius,
                                        width: toothRadius * 2, height: toothRadius * 2))
            }
        }
        func points(from a: CGPoint, to b: CGPoint) -> [CGPoint] {
            let length = hypot(b.x - a.x, b.y - a.y)
            let n = max(Int(length / spacing), 1)
            return (0...n).map { i in
                let t = CGFloat(i) / CGFloat(n)
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
        }
        punch(along: points(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.minY)))
        punch(along: points(from: CGPoint(x: rect.maxX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY)))
        punch(along: points(from: CGPoint(x: rect.maxX, y: rect.maxY), to: CGPoint(x: rect.minX, y: rect.maxY)))
        punch(along: points(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.minX, y: rect.minY)))
        return p
    }
}

// MARK: - The postmark

/// A faint circular cancellation mark — "dino post · day n" in a double ring
/// with three thin waves crossing toward the stamp, like real mail.
struct GardenPostmarkView: View {
    let day: Int
    private let ink = Color(hex: "#3D3A35")

    var body: some View {
        ZStack {
            Circle().stroke(ink.opacity(0.30), lineWidth: 1.1)
            Circle().inset(by: 4.5).stroke(ink.opacity(0.16), lineWidth: 0.8)
            VStack(spacing: 1) {
                Text(GardenShare.postmarkTop)
                Text(GardenShare.postmarkDay(day: day))
            }
            .font(.system(size: 7.5, weight: .medium, design: .rounded))
            .foregroundColor(ink.opacity(0.40))
            // cancellation waves reaching toward the stamp
            PostmarkWaves()
                .stroke(ink.opacity(0.22), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                .frame(width: 34, height: 16)
                .offset(x: 40)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }
}

struct PostmarkWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for row in 0..<3 {
            let y = rect.minY + rect.height * (0.2 + 0.3 * CGFloat(row))
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: y - 1.6),
                           control: CGPoint(x: rect.minX + rect.width * 0.25, y: y - 3.2))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: y),
                           control: CGPoint(x: rect.maxX - rect.width * 0.25, y: y + 1.6))
        }
        return p
    }
}
