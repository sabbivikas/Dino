//
//  DinoDesignSystem.swift
//  Dino
//
//  Additional design-system tokens from the Dino brand guide.
//  These supplement DinoTheme — all existing theme colors, fonts,
//  and reactive tokens remain the canonical source.
//

import SwiftUI

// MARK: - Design System Constants

@MainActor
enum DinoDesignSystem {

    // MARK: - Brand Colors (fixed — stable across every theme)
    // Primary accent colors live in DinoTheme (sageGreen, lavender, peach, skyBlue, warmRose).
    // sageDeep (#7BA872) is DinoTheme.navIconSelected (theme-reactive).
    // These are the hex literals for reference when needed outside the theme system.

    static let brandSageGreen = Color(hex: "#A8C5A0")
    static let brandSageDeep  = Color(hex: "#7BA872")
    static let brandLavender  = Color(hex: "#C4B8D4")
    static let brandPeach     = Color(hex: "#F5C6AA")
    static let brandSkyBlue   = Color(hex: "#A8D4E6")
    static let brandWarmRose  = Color(hex: "#E8B4B8")

    // MARK: - Corner Radii
    // DinoTheme already has cornerRadius (16) and largeCornerRadius (20).

    static let radiusXS: CGFloat = 6     // gratitude slips, tiny elements
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16    // = DinoTheme.cornerRadius
    static let radiusLG: CGFloat = 20    // = DinoTheme.largeCornerRadius
    static let radiusPill: CGFloat = 999

    // MARK: - Spacing (4pt-aligned)
    // DinoTheme already has padding (20) and largePadding (24).

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 14    // grid gap
    static let space5: CGFloat = 16
    static let space6: CGFloat = 20    // = DinoTheme.padding
    static let space7: CGFloat = 24    // = DinoTheme.largePadding
    static let space8: CGFloat = 32

    // MARK: - Shadows

    /// Standard card shadow: 0 4px 12px rgba(0,0,0,0.06)
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowY: CGFloat = 4
    static let cardShadowOpacity: Double = 0.06

    /// Elevated/lift shadow: 0 8px 20px rgba(0,0,0,0.08)
    static let liftShadowRadius: CGFloat = 20
    static let liftShadowY: CGFloat = 8
    static let liftShadowOpacity: Double = 0.08

    /// FAB colored shadow: 0 4px 12px rgba(168,197,160,0.40)
    static let fabShadowColor = Color(hex: "#A8C5A0").opacity(0.40)
    static let fabShadowRadius: CGFloat = 12

    /// Press-state colored shadow: 0 4px 16px rgba(168,197,160,0.15)
    static let pressShadowRadius: CGFloat = 16
    static let pressShadowOpacity: Double = 0.15

    // MARK: - Motion

    /// Press scale factor (0.94–0.96)
    static let pressScale: CGFloat = 0.96
    static let pressScaleDeep: CGFloat = 0.94

    /// Duration tokens
    static let durationFast: Double = 0.15   // 150ms
    static let durationMed: Double = 0.30    // 300ms
    static let durationSlow: Double = 1.5    // 1500ms (theme crossfade)

    /// Spring for interactive elements (card tap, pill select)
    static let interactiveSpringResponse: Double = 0.35
    static let interactiveSpringDamping: Double = 0.6

    // MARK: - Icon Circle

    /// Icon circle background opacity (accent.opacity)
    static let iconCircleBgOpacity: Double = 0.20

    /// Standard icon circle size
    static let iconCircleSize: CGFloat = 44
}

// MARK: - View Modifiers

extension View {

    /// Design-system card: frosted glass bg, sage-tinted 1px border, soft shadow, 20pt corners.
    func dsCardLarge() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous)
                    .strokeBorder(DinoTheme.accent.opacity(0.18), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: DinoDesignSystem.cardShadowRadius,
                y: DinoDesignSystem.cardShadowY
            )
    }

    /// Design-system card: frosted glass bg, 1px colored border, soft shadow, continuous corners.
    /// Uses `cornerRadius` (16pt) — the action card style.
    func dsCardAction(borderColor: Color, isPressed: Bool = false) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .strokeBorder(borderColor.opacity(0.30), lineWidth: 1.5)
            )
            .shadow(
                color: isPressed ? borderColor.opacity(DinoDesignSystem.pressShadowOpacity) : Color.black.opacity(DinoDesignSystem.cardShadowOpacity),
                radius: isPressed ? DinoDesignSystem.pressShadowRadius : DinoDesignSystem.cardShadowRadius,
                y: DinoDesignSystem.cardShadowY
            )
            .scaleEffect(isPressed ? DinoDesignSystem.pressScaleDeep : 1.0)
            .animation(.spring(response: DinoDesignSystem.interactiveSpringResponse, dampingFraction: DinoDesignSystem.interactiveSpringDamping), value: isPressed)
    }
}
