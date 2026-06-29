//
//  MoodPaintingGeneratorView.swift
//  Dino
//

import SwiftUI
import UIKit

private enum GeneratorPalette {
    static let bg     = Color(hex: "#1A1A2E")
    static let cream  = Color(hex: "#FAF6EC")
    static let sage   = Color(hex: "#A8C5A0")
    static let lav    = Color(hex: "#C4B8D4")
    static let peach  = Color(hex: "#F5C6AA")
    static let rose   = Color(hex: "#E8B4B8")
}

struct MoodPaintingGeneratorView: View {
    let month: Date
    let moods: [MoodEntry]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = MoodPaintingService.shared

    @State private var stageIndex = 0
    @State private var stageTimer: Timer?
    @State private var generatedImage: UIImage?
    @State private var errorText: String?
    @State private var minimumWaitDone = false
    @State private var apiDone = false
    @State private var apiResult: UIImage?
    @State private var showShare = false

    private let stages = [
        "reading your moods...",
        "mixing the colors...",
        "painting your story...",
        "almost done..."
    ]

    var body: some View {
        ZStack {
            GeneratorPalette.bg.ignoresSafeArea()

            if let img = generatedImage {
                completedView(img)
            } else if let err = errorText {
                errorView(err)
            } else {
                loadingView
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { stop(); dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GeneratorPalette.cream)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            startStageCycle()
            kickOffGeneration()
        }
        .onDisappear { stop() }
        .sheet(isPresented: $showShare) {
            if let img = generatedImage {
                ShareSheet(items: [img])
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 28) {
            BrushstrokeLoader()
                .frame(width: 200, height: 120)

            Text("dino is painting your month...")
                .font(.custom(DinoTheme.customFontName, size: 18))
                .foregroundColor(GeneratorPalette.cream)

            Text(stages[stageIndex])
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(GeneratorPalette.cream.opacity(0.7))
                .id(stageIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: stageIndex)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Completed

    private func completedView(_ img: UIImage) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 24)
                .transition(.opacity)

            Text("your \(monthLabel) painting is ready \u{2728}")
                .font(.custom(DinoTheme.customFontName, size: 16))
                .foregroundColor(GeneratorPalette.cream)

            HStack(spacing: 14) {
                Button(action: { dismiss() }) {
                    Text("done")
                        .font(.custom(DinoTheme.customFontName, size: 15))
                        .foregroundColor(GeneratorPalette.bg)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(GeneratorPalette.cream))
                }
                .buttonStyle(.plain)

                Button(action: { showShare = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("share")
                            .font(.custom(DinoTheme.customFontName, size: 15))
                    }
                    .foregroundColor(GeneratorPalette.cream)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(GeneratorPalette.cream.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        Text("painting will be ready soon 🎨")
            .font(.custom(DinoTheme.customFontName, size: 18))
            .foregroundColor(GeneratorPalette.cream)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                dismiss()
            }
    }

    // MARK: - Logic

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: month).lowercased()
    }

    private func startStageCycle() {
        stageIndex = 0
        minimumWaitDone = false
        stageTimer?.invalidate()
        stageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            Task { @MainActor in
                if stageIndex < stages.count - 1 {
                    stageIndex += 1
                } else {
                    minimumWaitDone = true
                    t.invalidate()
                    finalizeIfReady()
                }
            }
        }
    }

    private func kickOffGeneration() {
        apiDone = false
        errorText = nil
        Task { @MainActor in
            do {
                let img = try await service.generatePainting(for: month, moods: moods)
                apiResult = img
                apiDone = true
                finalizeIfReady()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stageTimer?.invalidate()
            }
        }
    }

    private func finalizeIfReady() {
        guard apiDone, minimumWaitDone, let img = apiResult else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            generatedImage = img
        }
    }

    private func stop() {
        stageTimer?.invalidate()
        stageTimer = nil
    }
}

// MARK: - Brushstroke Loader

private struct BrushstrokeLoader: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            stroke(offset: 0,  color: GeneratorPalette.sage,  delay: 0.0)
            stroke(offset: 14, color: GeneratorPalette.lav,   delay: 0.2)
            stroke(offset: 28, color: GeneratorPalette.peach, delay: 0.4)
        }
        .onAppear { animate = true }
    }

    private func stroke(offset: CGFloat, color: Color, delay: Double) -> some View {
        StrokePath()
            .trim(from: 0, to: animate ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .offset(y: offset)
            .animation(
                .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(delay),
                value: animate
            )
    }
}

private struct StrokePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX + 10, y: y))
        p.addCurve(
            to: CGPoint(x: rect.maxX - 10, y: y),
            control1: CGPoint(x: rect.minX + rect.width * 0.30, y: y - 30),
            control2: CGPoint(x: rect.minX + rect.width * 0.70, y: y + 30)
        )
        return p
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad presents this as a popover and crashes without a non-nil anchor.
        if let popover = controller.popoverPresentationController {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window?.bounds.midX ?? UIScreen.main.bounds.midX,
                                        y: window?.bounds.midY ?? UIScreen.main.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
