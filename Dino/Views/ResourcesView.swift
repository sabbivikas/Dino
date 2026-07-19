//
//  ResourcesView.swift
//  Dino
//
//  Regional crisis resources, redesigned as warm paper cards (approved
//  concept 1): sticky-note geometry, paper grain, soft warm shadows — the
//  comfort slip's material language. The crisis card comes FIRST and wears
//  the only tape (always sage: dino's own color means "this one first").
//  Designed for a shaking hand: 64pt call button with the number as its
//  label, whole-card tap targets, no confirmation sheets, understated hour
//  badges. Data lives in CrisisResources.swift and changes only by review —
//  this file is presentation.
//

import SwiftUI
import UIKit

// MARK: - Screen model (pure → unit-tested)

enum ResourceScreen {
    static let regionalHeader = String(localized: "support is always close 🌿")
    static let regionalSub = String(localized: "real people, ready to listen. any hour, any reason.")
    static let fallbackHeader = String(localized: "wherever you are, help exists 🌍")
    static let fallbackSub = String(localized: "these directories can find a line close to you, in your language.")
    static let badge247 = "24/7"
    static let badgeVaries = String(localized: "hours vary")

    /// Every tilt stays under 1.2°, alternating down the list — paper warmth
    /// without wobbling the eye's path.
    static let heroTilt: Double = -0.9
    private static let rowTilts: [Double] = [0.7, -0.6, 0.5, -0.55]   // even count: alternates across cycles

    struct Model {
        let hero: RegionalResource?
        let rows: [RegionalResource]
        let isFallback: Bool

        var header: String { isFallback ? ResourceScreen.fallbackHeader : ResourceScreen.regionalHeader }
        var sub: String { isFallback ? ResourceScreen.fallbackSub : ResourceScreen.regionalSub }
    }

    /// Regional: the first entry (the national crisis line, first by
    /// construction) becomes the taped hero. Fallback: three equal bare
    /// directory cards — no hero, no tape.
    static func model(for regionCode: String?) -> Model {
        let (list, isFallback) = CrisisResources.resources(for: regionCode)
        if isFallback { return Model(hero: nil, rows: list, isFallback: true) }
        return Model(hero: list.first, rows: Array(list.dropFirst()), isFallback: false)
    }

    static func badge(is24h: Bool) -> String { is24h ? badge247 : badgeVaries }

    static func rowTilt(index: Int) -> Double { rowTilts[index % rowTilts.count] }

    static func voCallLabel(name: String, contact: String) -> String {
        String(localized: "call \(name) at \(contact)")
    }

    static func emoji(for kind: RegionalResource.Kind) -> String {
        switch kind {
        case .call: return "📞"
        case .text, .whatsapp: return "💬"
        case .link: return "🌍"
        }
    }

    static var allFixedStrings: [String] {
        [regionalHeader, regionalSub, fallbackHeader, fallbackSub,
         badge247, badgeVaries, voCallLabel(name: "x", contact: "1")]
    }
}

// MARK: - The screen

struct ResourcesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let model = ResourceScreen.model(for: Locale.current.region?.identifier)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text(model.header)
                            .font(DinoTheme.dinoDisplayFont(size: 26))
                            .foregroundColor(DinoTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(model.sub)
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, DinoTheme.padding)

                    if let hero = model.hero {
                        HeroCrisisCard(resource: hero)
                            .padding(.horizontal, DinoTheme.padding)
                            .padding(.top, 8)
                            .accessibilitySortPriority(10)   // voiceover reads the crisis card first
                    }

                    VStack(spacing: 12) {
                        ForEach(Array(model.rows.enumerated()), id: \.element.name) { index, resource in
                            PaperResourceRow(resource: resource,
                                             tilt: ResourceScreen.rowTilt(index: index))
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)
                    .padding(.top, model.isFallback ? 6 : 0)

                    Text(CrisisResources.emergencyFooter)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DinoTheme.largePadding)
                        .padding(.bottom, 32)
                        .padding(.top, 8)
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close") { dismiss() }
                        .foregroundColor(DinoTheme.sageGreen)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Hero crisis card (taped, always sage: "this one first")

private struct HeroCrisisCard: View {
    let resource: RegionalResource
    @ScaledMetric(relativeTo: .title3) private var actionFontSize: CGFloat = 21

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(resource.name)
                    .font(DinoTheme.dinoFont(size: 19))
                    .foregroundColor(Color(hex: "#3D3A35"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HourBadge(is24h: resource.is24h)
            }
            Text(resource.detail)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(Color(hex: "#7A7266"))
                .padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)

            // the call button — unmissable, never alarming: sage, 64pt, the
            // number IS the label (readable aloud without tapping). shrinks
            // before it ever truncates a digit.
            Button { open(resource.actionURL) } label: {
                HStack(spacing: 12) {
                    Text(ResourceScreen.emoji(for: resource.kind))
                        .font(.system(size: 19))
                    Text(resource.actionLabel)
                        .font(.system(size: actionFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#7BA872")))
                .shadow(color: Color(hex: "#7BA872").opacity(0.38), radius: 9, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 16)
            .accessibilityLabel(resource.kind == .call
                ? ResourceScreen.voCallLabel(name: resource.name, contact: resource.contact)
                : resource.actionLabel)

            if let secondaryLabel = resource.secondaryLabel, let secondaryURL = resource.secondaryURL {
                Button { UIApplication.shared.open(secondaryURL) } label: {
                    HStack(spacing: 8) {
                        Text("💬").font(.system(size: 14))
                        Text(secondaryLabel)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(Color(hex: "#7BA872"))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "#7BA872").opacity(0.45), lineWidth: 1.5))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 10)
            }
        }
        .padding(EdgeInsets(top: 24, leading: 18, bottom: 18, trailing: 18))
        .background(PaperSurface(cornerRadius: 10, shadowRadius: 11, shadowY: 8))
        .overlay(alignment: .top) { WashiTape().offset(y: -12) }
        .rotationEffect(.degrees(ResourceScreen.heroTilt))
        .contentShape(Rectangle())
        .onTapGesture { open(resource.actionURL) }   // the whole card is the target
        .accessibilityElement(children: .contain)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)   // no confirmation sheets — friction is the enemy here
    }
}

// MARK: - Quiet paper row

private struct PaperResourceRow: View {
    let resource: RegionalResource
    let tilt: Double

    var body: some View {
        Button {
            if let url = resource.actionURL { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 13) {
                Text(ResourceScreen.emoji(for: resource.kind))
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.name)
                        .font(DinoTheme.dinoFont(size: 16.5))
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(resource.detail)
                            .font(DinoTheme.dinoFont(size: 12.5))
                            .foregroundColor(Color(hex: "#7A7266"))
                            .fixedSize(horizontal: false, vertical: true)
                        HourBadge(is24h: resource.is24h, compact: true)
                    }
                }
                Spacer(minLength: 8)
                Text(resource.actionLabel)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#7BA872"))
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#7BA872").opacity(0.14)))
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 12))
            .frame(minHeight: 64)
            .background(PaperSurface(cornerRadius: 8, shadowRadius: 7, shadowY: 4))
        }
        .buttonStyle(ScaleButtonStyle())
        .rotationEffect(.degrees(tilt))
        .accessibilityLabel(resource.kind == .call
            ? ResourceScreen.voCallLabel(name: resource.name, contact: resource.contact)
            : "\(resource.name), \(resource.actionLabel)")
    }
}

// MARK: - Shared paper bits

private struct PaperSurface: View {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hex: "#FFFDF6"))
            .overlay(PaperGrain().clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
            .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.09),
                    radius: shadowRadius, y: shadowY)
    }
}

private struct PaperGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)),
                         with: .color(Color(hex: "#3D3A35").opacity(0.012)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

/// The one piece of tape — always sage in every region: dino's own color
/// means "this one first", kept distinct from the comfort slip's type tints.
private struct WashiTape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 168/255, green: 197/255, blue: 160/255).opacity(0.78))
            .overlay(
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width + size.height {
                        ctx.fill(Path(CGRect(x: x, y: -2, width: 5, height: size.height + 4)),
                                 with: .color(.white.opacity(0.25)))
                        x += 10
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            )
            .frame(width: 104, height: 24)
            .rotationEffect(.degrees(-3))
            .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.12), radius: 1.5, y: 1)
            .accessibilityHidden(true)
    }
}

private struct HourBadge: View {
    let is24h: Bool
    var compact: Bool = false

    var body: some View {
        Text(ResourceScreen.badge(is24h: is24h))
            .font(.system(size: compact ? 9.5 : 10.5, weight: is24h ? .bold : .semibold, design: .rounded))
            .tracking(0.5)
            .foregroundColor(is24h ? Color(hex: "#7BA872") : Color(hex: "#A8A29A"))
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 2 : 4)
            .background(Capsule().fill(is24h
                ? Color(hex: "#7BA872").opacity(0.14)
                : Color(hex: "#A8A29A").opacity(0.14)))
            .fixedSize()
    }
}
