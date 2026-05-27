//
//  WhatsNewView.swift
//  Dino
//

import SwiftUI

// MARK: - Custom Icon Views

private struct CameraIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 18, height: 13)
            Rectangle()
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 6, height: 3)
                .offset(y: -7)
            Circle()
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 6, height: 6)
        }
        .frame(width: 22, height: 22)
    }
}

private struct JarIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 10, height: 3)
                .offset(y: -7)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 14, height: 14)
                .offset(y: 1)
        }
        .frame(width: 22, height: 22)
    }
}

private struct CalendarIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 16, height: 14)
                .offset(y: 1)
            Rectangle()
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 2, height: 4)
                .offset(x: -4, y: -6)
            Rectangle()
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 2, height: 4)
                .offset(x: 4, y: -6)
            Rectangle()
                .fill(Color(hex: "#2A7A6C"))
                .frame(width: 16, height: 1)
                .offset(y: -1)
        }
        .frame(width: 22, height: 22)
    }
}

private struct FlameIconView: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 11, y: 2))
            path.addQuadCurve(to: CGPoint(x: 5, y: 12), control: CGPoint(x: 4, y: 6))
            path.addQuadCurve(to: CGPoint(x: 11, y: 20), control: CGPoint(x: 4, y: 18))
            path.addQuadCurve(to: CGPoint(x: 17, y: 12), control: CGPoint(x: 18, y: 18))
            path.addQuadCurve(to: CGPoint(x: 11, y: 2), control: CGPoint(x: 18, y: 6))
        }
        .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
        .frame(width: 22, height: 22)
    }
}

private struct LeafIconView: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 4, y: 18))
            path.addQuadCurve(to: CGPoint(x: 18, y: 4), control: CGPoint(x: 4, y: 4))
            path.addQuadCurve(to: CGPoint(x: 4, y: 18), control: CGPoint(x: 18, y: 18))
            path.move(to: CGPoint(x: 4, y: 18))
            path.addLine(to: CGPoint(x: 18, y: 4))
        }
        .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
        .frame(width: 22, height: 22)
    }
}

private struct ChartIconView: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 3, y: 19))
                path.addLine(to: CGPoint(x: 19, y: 19))
                path.move(to: CGPoint(x: 3, y: 19))
                path.addLine(to: CGPoint(x: 3, y: 3))
            }
            .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 14))
                path.addLine(to: CGPoint(x: 9, y: 10))
                path.addLine(to: CGPoint(x: 13, y: 12))
                path.addLine(to: CGPoint(x: 18, y: 6))
            }
            .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
        }
        .frame(width: 22, height: 22)
    }
}

private struct BellIconView: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 4, y: 16))
                path.addLine(to: CGPoint(x: 18, y: 16))
                path.addQuadCurve(to: CGPoint(x: 15, y: 6), control: CGPoint(x: 17, y: 12))
                path.addQuadCurve(to: CGPoint(x: 7, y: 6), control: CGPoint(x: 11, y: 3))
                path.addQuadCurve(to: CGPoint(x: 4, y: 16), control: CGPoint(x: 5, y: 12))
            }
            .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
            Circle()
                .stroke(Color(hex: "#2A7A6C"), lineWidth: 1.5)
                .frame(width: 3, height: 3)
                .offset(y: 8)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Confetti

private struct ConfettiView: View {
    let count: Int = 16
    @State private var animate: Bool = false
    private let colors: [Color] = [
        Color(hex: "#A8C5A0"),
        Color(hex: "#F5C6AA"),
        Color(hex: "#D7C8E8")
    ]

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: CGFloat([4, 6, 8].randomElement() ?? 6),
                           height: CGFloat([4, 6, 8].randomElement() ?? 6))
                    .offset(
                        x: CGFloat.random(in: -140...140),
                        y: animate ? -120 : 60
                    )
                    .opacity(animate ? 0 : 0.85)
                    .animation(
                        .easeOut(duration: Double.random(in: 2.0...3.5))
                            .delay(Double(i) * 0.08)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
            }
        }
        .frame(height: 80)
        .onAppear { animate = true }
    }
}

// MARK: - Feature Model

private struct Feature: Identifiable {
    let id = UUID()
    let icon: AnyView
    let title: String
    let description: String
    let tint: Color
}

// MARK: - Feature Card Row

private struct FeatureCardRow: View {
    let feature: Feature
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.tint.opacity(0.3))
                    .frame(width: 36, height: 36)
                feature.icon
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.custom(DinoTheme.customFontName, size: 15))
                    .foregroundColor(Color(hex: "#2E2A24"))
                Text(feature.description)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(Color(hex: "#7A7266"))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#E8E4D5"), lineWidth: 1)
                )
        )
    }
}

// MARK: - What's New

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    fileprivate static let features: [Feature] = [
        Feature(icon: AnyView(CameraIconView()),   title: "photo journals",      description: "attach photos to entries, save as polaroid cards",      tint: Color(hex: "#A8C5A0")),
        Feature(icon: AnyView(JarIconView()),      title: "gratitude slips",     description: "open the jar and see all your little joys scattered out", tint: Color(hex: "#D7C8E8")),
        Feature(icon: AnyView(CalendarIconView()), title: "backdated entries",   description: "write journal entries for any past day",                tint: Color(hex: "#F5C6AA")),
        Feature(icon: AnyView(FlameIconView()),    title: "pause your streak",   description: "hold the streak to pause it anytime. no guilt.",        tint: Color(hex: "#A8C5A0")),
        Feature(icon: AnyView(LeafIconView()),     title: "breathing reminders", description: "gentle nudges to breathe throughout your day",          tint: Color(hex: "#D7C8E8")),
        Feature(icon: AnyView(ChartIconView()),    title: "weekly check-in",     description: "research-backed questions with an AI wellness report",  tint: Color(hex: "#F5C6AA")),
        Feature(icon: AnyView(BellIconView()),     title: "smarter nudges",      description: "notifications that feel like a friend checking on you", tint: Color(hex: "#A8C5A0"))
    ]

    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC").ignoresSafeArea()
            VStack(spacing: 0) {
                ConfettiView()
                    .padding(.top, 16)

                VStack(spacing: 8) {
                    Text("what's new in dino")
                        .font(.custom(DinoTheme.customFontName, size: 26))
                        .foregroundColor(Color(hex: "#2E2A24"))

                    Text("v1.4")
                        .font(.custom(DinoTheme.customFontName, size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#A8C5A0"), in: Capsule())
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Self.features) { f in
                            FeatureCardRow(feature: f)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Text("let's explore")
                            .font(.custom(DinoTheme.customFontName, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#A8C5A0"), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("skip")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#A8A29A"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}
