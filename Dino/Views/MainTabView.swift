//
//  MainTabView.swift
//  Dino
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var updateService = AppUpdateService.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                HomeView()
                    .environmentObject(dataManager)
                    .tag(0)

                VoiceJournalView(selectedTab: $selectedTab)
                    .environmentObject(dataManager)
                    .tag(1)

                EmotionalWeatherView()
                    .environmentObject(dataManager)
                    .tag(2)

                GratitudeJarView()
                    .environmentObject(dataManager)
                    .tag(3)

                ProfileView()
                    .environmentObject(dataManager)
                    .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedTab)

            // Custom tab bar
            DinoCustomTabBar(selectedTab: $selectedTab)
        }
        .onAppear {
            #if DEBUG
            // -moodTabQA: land on the mood tab for shader screenshots.
            if ProcessInfo.processInfo.arguments.contains("-moodTabQA") {
                selectedTab = 2
            }
            #endif
        }
        .onReceive(dataManager.$deepLinkTab) { tab in
            guard let tab, (0...4).contains(tab) else {
                return
            }
            selectedTab = tab
            dataManager.deepLinkTab = nil
        }
        .overlay(alignment: .bottom) {
            UpdateBannerView()
        }
        .task {
            await updateService.checkForUpdate()
        }
    }
}

// MARK: - Custom Tab Bar

private struct DinoCustomTabBar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatingTab: Int? = nil

    private let tabs: [(label: String, tag: Int)] = [
        ("Home", 0), ("Journal", 1), ("Mood", 2), ("Jar", 3), ("Profile", 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Subtle top border
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(tabs, id: \.tag) { tab in
                    Spacer()
                    TabIconButton(
                        index: tab.tag,
                        label: tab.label,
                        isSelected: selectedTab == tab.tag,
                        isAnimating: animatingTab == tab.tag
                    )
                    .onTapGesture {
                        guard selectedTab != tab.tag else { return }
                        HapticManager.shared.light()
                        selectedTab = tab.tag
                        guard !reduceMotion else { return }
                        animatingTab = tab.tag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            animatingTab = nil
                        }
                    }
                    Spacer()
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(DinoTheme.navBackground)
    }
}

// MARK: - Tab Icon Button

private struct TabIconButton: View {
    let index: Int
    let label: String
    let isSelected: Bool
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 3) {
            iconView
                .frame(width: 24, height: 24)

            Text(label)
                .font(DinoTheme.dinoFont(size: 11))
        }
        .foregroundColor(isSelected ? DinoTheme.accent : DinoTheme.textSecondary.opacity(0.5))
    }

    @ViewBuilder
    private var iconView: some View {
        switch index {
        case 0:
            DinoHomeIcon()
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 10 : 0))
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isAnimating)
        case 1:
            DinoBookIcon()
                .scaleEffect(x: isAnimating ? 1.05 : 1.0, y: isAnimating ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.45), value: isAnimating)
        case 2:
            DinoCloudSunIcon()
                .scaleEffect(isAnimating ? 1.15 : 1.0)
                .offset(y: isAnimating ? -3 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isAnimating)
        case 3:
            ZStack {
                DinoJarIcon()
                if isAnimating {
                    DinoJarHeartOverlay()
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.25)
                        .opacity(0.6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isAnimating ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.45), value: isAnimating)
        case 4:
            ZStack {
                if isAnimating {
                    Circle()
                        .strokeBorder(lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        .opacity(0.4)
                        .scaleEffect(1.3)
                        .transition(.scale.combined(with: .opacity))
                }
                DinoProfileIcon()
            }
            .scaleEffect(isAnimating ? 1.15 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isAnimating)
        default:
            EmptyView()
        }
    }
}

// MARK: - Static Icon Shapes (hand-drawn style)

/// Soft rounded house outline
private struct DinoHomeIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            // Roof
            path.move(to: CGPoint(x: w * 0.12, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.08))
            path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.45))
            // Walls
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.88))
            path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.88),
                              control: CGPoint(x: w * 0.5, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.42))
            // Door
            path.move(to: CGPoint(x: w * 0.40, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.62))
            path.addQuadCurve(to: CGPoint(x: w * 0.60, y: h * 0.62),
                              control: CGPoint(x: w * 0.50, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.88))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Open book with soft lines
private struct DinoBookIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            // Spine
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.88))
            // Left page curve
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
            path.addQuadCurve(to: CGPoint(x: w * 0.08, y: h * 0.22),
                              control: CGPoint(x: w * 0.25, y: h * 0.10))
            path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.82))
            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.88),
                              control: CGPoint(x: w * 0.25, y: h * 0.90))
            // Right page curve
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
            path.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.22),
                              control: CGPoint(x: w * 0.75, y: h * 0.10))
            path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.82))
            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.88),
                              control: CGPoint(x: w * 0.75, y: h * 0.90))
            // Text lines on left page
            path.move(to: CGPoint(x: w * 0.18, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.40))
            path.move(to: CGPoint(x: w * 0.18, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.55))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Cloud with sun peeking out
private struct DinoCloudSunIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            // Sun circle (behind cloud, upper right)
            var sun = Path()
            sun.addArc(center: CGPoint(x: w * 0.72, y: h * 0.30),
                       radius: w * 0.16, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            // Sun rays
            let rayCenter = CGPoint(x: w * 0.72, y: h * 0.30)
            let innerR = w * 0.19
            let outerR = w * 0.26
            for angle in stride(from: 200.0, through: 340.0, by: 35.0) {
                let rad = angle * .pi / 180
                sun.move(to: CGPoint(x: rayCenter.x + innerR * cos(rad), y: rayCenter.y + innerR * sin(rad)))
                sun.addLine(to: CGPoint(x: rayCenter.x + outerR * cos(rad), y: rayCenter.y + outerR * sin(rad)))
            }
            context.stroke(sun, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            // Cloud
            var cloud = Path()
            cloud.move(to: CGPoint(x: w * 0.12, y: h * 0.70))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.42),
                               control: CGPoint(x: w * 0.08, y: h * 0.48))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.35),
                               control: CGPoint(x: w * 0.38, y: h * 0.28))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.50),
                               control: CGPoint(x: w * 0.72, y: h * 0.32))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.70),
                               control: CGPoint(x: w * 0.92, y: h * 0.55))
            cloud.addLine(to: CGPoint(x: w * 0.12, y: h * 0.70))
            cloud.closeSubpath()
            cloud.move(to: CGPoint(x: w * 0.12, y: h * 0.70))
            cloud.addLine(to: CGPoint(x: w * 0.88, y: h * 0.70))
            context.stroke(cloud, with: .foreground, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Jar outline (body only, no heart — used as base)
private struct DinoJarIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            // Lid / rim
            path.move(to: CGPoint(x: w * 0.25, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.18))
            path.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.28),
                              control: CGPoint(x: w * 0.82, y: h * 0.23))
            path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.28))
            path.addQuadCurve(to: CGPoint(x: w * 0.25, y: h * 0.18),
                              control: CGPoint(x: w * 0.18, y: h * 0.23))
            // Body
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.28))
            path.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.50),
                              control: CGPoint(x: w * 0.22, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.78))
            path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.78),
                              control: CGPoint(x: w * 0.50, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.50))
            path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.28),
                              control: CGPoint(x: w * 0.78, y: h * 0.35))
            // Heart inside
            let heartCenter = CGPoint(x: w * 0.50, y: h * 0.55)
            let hs: CGFloat = w * 0.10
            var heart = Path()
            heart.move(to: CGPoint(x: heartCenter.x, y: heartCenter.y + hs))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x - hs, y: heartCenter.y - hs * 0.2),
                               control: CGPoint(x: heartCenter.x - hs * 1.2, y: heartCenter.y + hs * 0.3))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x, y: heartCenter.y - hs * 0.4),
                               control: CGPoint(x: heartCenter.x - hs * 0.6, y: heartCenter.y - hs * 1.0))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x + hs, y: heartCenter.y - hs * 0.2),
                               control: CGPoint(x: heartCenter.x + hs * 0.6, y: heartCenter.y - hs * 1.0))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x, y: heartCenter.y + hs),
                               control: CGPoint(x: heartCenter.x + hs * 1.2, y: heartCenter.y + hs * 0.3))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            context.stroke(heart, with: .foreground, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Heart-only overlay for jar pulse animation
private struct DinoJarHeartOverlay: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let heartCenter = CGPoint(x: w * 0.50, y: h * 0.55)
            let hs: CGFloat = w * 0.10
            var heart = Path()
            heart.move(to: CGPoint(x: heartCenter.x, y: heartCenter.y + hs))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x - hs, y: heartCenter.y - hs * 0.2),
                               control: CGPoint(x: heartCenter.x - hs * 1.2, y: heartCenter.y + hs * 0.3))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x, y: heartCenter.y - hs * 0.4),
                               control: CGPoint(x: heartCenter.x - hs * 0.6, y: heartCenter.y - hs * 1.0))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x + hs, y: heartCenter.y - hs * 0.2),
                               control: CGPoint(x: heartCenter.x + hs * 0.6, y: heartCenter.y - hs * 1.0))
            heart.addQuadCurve(to: CGPoint(x: heartCenter.x, y: heartCenter.y + hs),
                               control: CGPoint(x: heartCenter.x + hs * 1.2, y: heartCenter.y + hs * 0.3))
            context.stroke(heart, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Person circle outline
private struct DinoProfileIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            // Outer circle
            path.addEllipse(in: CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84))
            // Head
            path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.20, width: w * 0.32, height: h * 0.30))
            // Shoulders
            path.move(to: CGPoint(x: w * 0.18, y: h * 0.82))
            path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.82),
                              control: CGPoint(x: w * 0.50, y: h * 0.55))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}
