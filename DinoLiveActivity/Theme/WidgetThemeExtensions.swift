//
//  WidgetTheme.swift  (Widgets/Theme companion)
//  DinoLiveActivity
//
//  Widget-scoped theme additions. The core WidgetTheme struct still lives at
//  /DinoLiveActivity/WidgetTheme.swift and remains unchanged. This file adds
//  gradient helpers, color constants, and a widget-font helper used by the
//  new Mood / Streak / Breathing widgets.
//
//  Color(hex:) is defined in BreathingLiveActivity.swift — do NOT redeclare.
//

import SwiftUI

// MARK: - Widget font helper

extension WidgetTheme {
    /// Convenience wrapper around the bundled Dino hand-drawn font.
    /// Use `WidgetTheme.widgetFont(size:)` in widget views for a single source of truth.
    static func widgetFont(size: CGFloat) -> Font {
        .custom("DinoInitiativeFont-Regular", size: size)
    }
}

// MARK: - Dino palette constants (matches widgets.html --tokens)

enum DinoPalette {
    /// --dino (primary green)
    static let ink = Color(hex: "#0F6F4A")
    /// --dino-ink (deep green)
    static let dinoInk = Color(hex: "#11402D")
    /// --sage
    static let sage = Color(hex: "#A8C5A0")
    /// --cream
    static let cream = Color(hex: "#FBF6EB")
    /// --sky
    static let sky = Color(hex: "#B8D3E8")

    // Streak flame palette
    static let flameOrange = Color(hex: "#F5A245")
    static let flameBrown = Color(hex: "#C26A1E")
    static let flameYellow = Color(hex: "#FCD56B")

    // Streak widget gradient
    static let streakBgTop = Color(hex: "#FFF6E4")
    static let streakBgBottom = Color(hex: "#FCE3C2")
    static let streakInkDeep = Color(hex: "#4A2A10")
    static let streakInkMid = Color(hex: "#8A4A1A")

    // Morning scene palette
    static let morningTop = Color(hex: "#FFE3B6")
    static let morningMid = Color(hex: "#FEC9A0")
    static let morningBottom = Color(hex: "#F9D9BA")
    static let morningInk = Color(hex: "#4A2A10")
    static let morningInkSoft = Color(hex: "#8A4A1A")
    static let sunYellow = Color(hex: "#F5B731")
    static let sunStroke = Color(hex: "#C98A1A")
    static let hillLight = Color(hex: "#8FB578")
    static let hillDark = Color(hex: "#6E9A5A")

    // Day scene palette
    static let dayTop = Color(hex: "#CFE8F4")
    static let dayMid = Color(hex: "#DFF1E4")
    static let dayBottom = Color(hex: "#EFE6C8")
    static let dayHillLight = Color(hex: "#9EC894")
    static let dayHillDark = Color(hex: "#82B271")
    static let treeGreen = Color(hex: "#4A7A4A")
    static let treeTrunk = Color(hex: "#3D5A3D")

    // Night scene palette
    static let nightTop = Color(hex: "#1A1B3D")
    static let nightMid = Color(hex: "#2A2C5A")
    static let nightBottom = Color(hex: "#3F3566")
    static let nightTextPrimary = Color(hex: "#E8E4F5")
    static let nightTextSecondary = Color(hex: "#A8A8C4")
    static let moonCream = Color(hex: "#F5EBC4")
    static let mountainBack = Color(hex: "#1A1B3D")
    static let mountainFront = Color(hex: "#0F0F2A")

    // Breathing petal palette (matches widgets.html 5-petal bloom)
    static let bloomPeach = Color(hex: "#EF9C8E")
    static let bloomYellow = Color(hex: "#FCD56B")
    static let bloomLavender = Color(hex: "#C9B8DE")
    static let bloomSage = Color(hex: "#A8C5A0")
    static let bloomGold = Color(hex: "#F5B731")
    static let bloomCenter = Color(hex: "#FBE2A8")

    // Breathing background
    static let breathingTop = Color(hex: "#E4F0E6")
    static let breathingBottom = Color(hex: "#CDE2D2")

    // Mood pill
    static let moodPillBg = Color.white.opacity(0.55)
    static let moodPillStroke = Color(hex: "#11402D").opacity(0.12)

    // MARK: - v6 Live Activity tokens (mirrors DinoTheme.la*)
    // These are duplicated here because DinoTheme is @MainActor and lives in
    // the main app target; widget-target code cannot reach it.
    static let laInk                = Color(hex: "#11402D")
    static let laSageRing           = Color(hex: "#7BA872")
    static let laCuePeach           = Color(hex: "#E8B4B8")
    static let laCueText            = Color(hex: "#4A6852")
    static let laHillFar            = Color(hex: "#B9D3A8")
    static let laHillNear           = Color(hex: "#9FC291")
    static let laMeadowTop          = Color(hex: "#F4F8EE")
    static let laMeadowMid          = Color(hex: "#E9EFDC")
    static let laMeadowBottom       = Color(hex: "#E3EBD1")
    static let laSunCore            = Color(hex: "#FFE9B8")
    static let laSunEdge            = Color(hex: "#FBD98A")
    static let laNightTop           = Color(hex: "#1D2148")
    static let laNightMid           = Color(hex: "#2E2D5E")
    static let laNightBottom        = Color(hex: "#4B3B78")
    static let laMoonFace           = Color(hex: "#F5E9C4")
    static let laMoonStroke         = Color(hex: "#3A2E5E")
    static let laMoonCrater         = Color(hex: "#E4D4A2")
    static let laNebula             = Color(hex: "#C5ACE2")
    static let laProgressFillStart  = Color(hex: "#C4B8D4")
    static let laProgressFillEnd    = Color(hex: "#F5E9C4")
}

// MARK: - Scene gradients

enum WidgetGradients {
    static var moodMorning: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.morningTop, DinoPalette.morningMid, DinoPalette.morningBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var moodDay: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.dayTop, DinoPalette.dayMid, DinoPalette.dayBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var moodNight: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.nightTop, DinoPalette.nightMid, DinoPalette.nightBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var streak: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.streakBgTop, DinoPalette.streakBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var breathing: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.breathingTop, DinoPalette.breathingBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var flame: LinearGradient {
        LinearGradient(
            colors: [DinoPalette.flameOrange, DinoPalette.flameOrange.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
