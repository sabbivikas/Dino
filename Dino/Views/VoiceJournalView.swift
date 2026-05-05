//
//  VoiceJournalView.swift
//  Dino
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - Root View
struct VoiceJournalView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: JournalViewModel = JournalViewModel(dataManager: SharedDataManager.shared)
    @State private var showPermissionAlert: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                JournalPaperBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        Text("journal")
                            .font(.custom(DinoTheme.customFontName, size: 30))
                            .foregroundColor(DinoTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)

                        // Hero record button
                        HeroRecordButton(viewModel: viewModel)

                        // Timer caption
                        Group {
                            if viewModel.isRecording {
                                Text(viewModel.formattedRecordingDuration)
                                    .font(DinoTheme.numericFont(size: 22))
                                    .foregroundColor(.red)
                            } else {
                                Text("tap to record")
                                    .font(.custom(DinoTheme.customFontName, size: 16))
                                    .foregroundColor(DinoTheme.muted)
                            }
                        }

                        // Composer card
                        JournalComposerCard(
                            onMic: { toggleRecording() },
                            onDevelop: { toggleRecording() }
                        )

                        // Timeline header
                        HStack {
                            Text("recent memories")
                                .font(.custom(DinoTheme.customFontName, size: 14))
                                .foregroundColor(Color(hex: "#7A7266"))
                            Spacer()
                            Text("tap a card to flip")
                                .font(.system(size: 11))
                                .italic()
                                .foregroundColor(Color(hex: "#A8A29A"))
                        }
                        .padding(.top, 4)

                        JournalTimelineStrip(
                            entries: dataManager.journalEntries,
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .alert("Microphone Access Needed", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Dino needs microphone access to record your voice journal entries.")
            }
            .onChange(of: viewModel.permissionDenied) { _, denied in
                if denied { showPermissionAlert = true }
            }
        }
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
}

// MARK: - Paper Backdrop
private struct JournalPaperBackdrop: View {
    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC")

            // Top-left warm glow
            RadialGradient(
                colors: [Color(hex: "#F5C6AA").opacity(0.25), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            .frame(width: 400, height: 400)
            .offset(x: -80, y: -80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Bottom-right sage glow
            RadialGradient(
                colors: [Color(hex: "#A8C5A0").opacity(0.2), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .frame(width: 400, height: 400)
            .offset(x: 80, y: 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Noise grain overlay
            Image("noise-grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.04)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Hero Record Button (preserved UX)
private struct HeroRecordButton: View {
    @ObservedObject var viewModel: JournalViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.6
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring2Opacity: Double = 0.6

    var body: some View {
        ZStack {
            if viewModel.isRecording {
                if reduceMotion {
                    // Static single ring
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(1.2)
                        .opacity(0.3)
                } else {
                    // Ring 1
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(ring1Scale)
                        .opacity(ring1Opacity)
                    // Ring 2 (delayed)
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(ring2Scale)
                        .opacity(ring2Opacity)
                }
            }

            Button(action: toggle) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : DinoTheme.sageGreen)
                        .frame(width: 90, height: 90)
                        .shadow(
                            color: (viewModel.isRecording ? Color.red : DinoTheme.sageGreen).opacity(0.4),
                            radius: 16, y: 4
                        )

                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(height: 160)
        .onAppear {
            if viewModel.isRecording { startPulse() }
        }
        .onChange(of: viewModel.isRecording) { _, recording in
            if recording {
                startPulse()
            } else {
                stopPulse()
            }
        }
    }

    private func toggle() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        ring1Scale = 1.0
        ring1Opacity = 0.6
        ring2Scale = 1.0
        ring2Opacity = 0.6
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            ring1Scale = 2.0
            ring1Opacity = 0.0
        }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(0.7)) {
            ring2Scale = 2.0
            ring2Opacity = 0.0
        }
    }

    private func stopPulse() {
        ring1Scale = 1.0
        ring1Opacity = 0.6
        ring2Scale = 1.0
        ring2Opacity = 0.6
    }
}

// MARK: - Journal Composer Card
private struct JournalComposerCard: View {
    let onMic: () -> Void
    let onDevelop: () -> Void

    @State private var promptIndex: Int = 0
    @State private var composerText: String = ""
    @State private var micPulse: CGFloat = 1.0
    @State private var selectedImage: UIImage? = nil
    @State private var selectedMood: String? = nil
    @State private var showPhotoPicker: Bool = false
    @State private var showMoodSheet: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let prompts = [
        "what's been on your mind?",
        "one small thing that went well today…",
        "what does your body need right now?"
    ]

    private var metaText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date()).uppercased() + " · DEAR DIARY"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base card
            RoundedRectangle(cornerRadius: 14)
                .fill(DinoTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#A8C5A0").opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#3C2814").opacity(0.08), radius: 22, x: 0, y: 8)

            // Ruled horizontal lines
            GeometryReader { geo in
                Canvas { ctx, size in
                    let startY: CGFloat = 60
                    var y = startY
                    while y < size.height - 8 {
                        var path = Path()
                        path.move(to: CGPoint(x: 56, y: y))
                        path.addLine(to: CGPoint(x: size.width - 16, y: y))
                        ctx.stroke(path, with: .color(Color(hex: "#A8D4E6").opacity(0.25)), lineWidth: 1)
                        y += 28
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)

            // Vertical red margin line at x = 42
            Rectangle()
                .fill(Color(hex: "#E8B4B8").opacity(0.5))
                .frame(width: 1)
                .padding(.leading, 42)
                .padding(.vertical, 12)

            // 3 punched holes on left edge
            VStack {
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.vertical, 24)

            // Content
            VStack(alignment: .leading, spacing: 14) {
                // Meta row
                Text(metaText)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "#A67074"))
                    .padding(.leading, 60)
                    .padding(.top, 4)

                // Rotating prompt
                HStack {
                    Text(prompts[promptIndex])
                        .font(.system(size: 15))
                        .italic()
                        .foregroundColor(Color(hex: "#7A7266"))
                    Spacer()
                    Button {
                        promptIndex = (promptIndex + 1) % prompts.count
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#7A7266"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 60)
                .padding(.trailing, 16)

                // Text editor
                ZStack(alignment: .topLeading) {
                    if composerText.isEmpty {
                        Text("today I...")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "#A8A29A"))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $composerText)
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 140, maxHeight: 240)
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)

                // Dashed divider
                DashedDivider()
                    .padding(.leading, 56)
                    .padding(.trailing, 16)

                // Action row
                HStack(alignment: .center, spacing: 14) {
                    // Mic
                    ComposerActionButton(
                        system: "mic.fill",
                        bg: Color(hex: "#C7DEBB"),
                        stroke: Color(hex: "#7BA872"),
                        disabled: false,
                        action: onMic
                    )
                    .scaleEffect(micPulse)

                    // Camera
                    ComposerActionButton(
                        system: "camera.fill",
                        bg: DinoTheme.paper,
                        stroke: DinoTheme.peach,
                        disabled: false,
                        action: { showPhotoPicker = true }
                    )

                    // Mood
                    ComposerActionButton(
                        system: selectedMood == nil ? "face.smiling" : "face.smiling.inverse",
                        bg: DinoTheme.paper,
                        stroke: DinoTheme.warmRose,
                        disabled: false,
                        action: { showMoodSheet = true }
                    )

                    Spacer()

                    // Develop pill
                    Button(action: onDevelop) {
                        HStack(spacing: 6) {
                            Text("develop")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#2D4A2A"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#C7DEBB"), Color(hex: "#A8C5A0")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)
                .padding(.bottom, 4)
            }
            .padding(.vertical, 18)
        }
        .onAppear {
            startMicPulse()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodSheet(selected: $selectedMood)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
    }

    private func startMicPulse() {
        guard !reduceMotion else { micPulse = 1.0; return }
        micPulse = 1.0
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            micPulse = 1.06
        }
    }
}

// MARK: - Composer Action Button
private struct ComposerActionButton: View {
    let system: String
    let bg: Color
    let stroke: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bg)
                    .overlay(
                        Circle().stroke(stroke, lineWidth: 1.5)
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: system)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(stroke)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Dashed Divider helper
private struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(Color(hex: "#7A7266").opacity(0.3))
        }
        .frame(height: 1)
    }
}

// MARK: - Timeline Strip
private struct JournalTimelineStrip: View {
    let entries: [JournalEntry]
    @ObservedObject var viewModel: JournalViewModel

    var body: some View {
        if entries.isEmpty {
            EmptyMemoriesCard()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .top) {
                    // String curve overlay
                    GeometryReader { geo in
                        Canvas { ctx, size in
                            var path = Path()
                            path.move(to: CGPoint(x: 20, y: 30))
                            path.addQuadCurve(
                                to: CGPoint(x: size.width - 20, y: 30),
                                control: CGPoint(x: size.width / 2, y: 60)
                            )
                            ctx.stroke(
                                path,
                                with: .color(Color(hex: "#8B5A3C").opacity(0.45)),
                                lineWidth: 1.5
                            )
                        }
                        .frame(width: geo.size.width, height: 60)
                    }
                    .frame(height: 60)
                    .allowsHitTesting(false)

                    HStack(spacing: 16) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                            JournalPolaroidCard(
                                entry: entry,
                                index: i,
                                viewModel: viewModel
                            )
                        }

                        // See all card
                        SeeAllCard(count: entries.count)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }
            .frame(minHeight: 260)
        }
    }
}

// MARK: - Empty memories
private struct EmptyMemoriesCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("no memories yet")
                .font(.custom(DinoTheme.customFontName, size: 18))
                .foregroundColor(DinoTheme.ink)
            Text("tap the mic to record your first")
                .font(.system(size: 13))
                .foregroundColor(DinoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DinoTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundColor(Color(hex: "#A8A29A").opacity(0.4))
                )
        )
    }
}

// MARK: - See All Card
private struct SeeAllCard: View {
    let count: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundColor(Color(hex: "#A8A29A").opacity(0.4))
            .frame(width: 180, height: 228)
            .overlay(
                Text("see all —\n\(count) memories →")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#7A7266"))
                    .multilineTextAlignment(.center)
            )
            .rotationEffect(.degrees(1.5))
    }
}

// MARK: - Polaroid Card
private struct JournalPolaroidCard: View {
    let entry: JournalEntry
    let index: Int
    @ObservedObject var viewModel: JournalViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flipped: Bool = false
    @State private var visible: Bool = false

    private var rotation: Double {
        let v = Double((entry.id.hashValue % 80) - 40) / 10.0
        return max(-4, min(4, v))
    }

    private var tapeRotation: Double {
        // Deterministic small tape rotation
        let v = Double((entry.id.hashValue % 14) - 7) * 0.5
        return v
    }

    var body: some View {
        ZStack {
            // Front
            polaroidFront
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(flipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Back
            JournalPolaroidBack(entry: entry)
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(flipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(width: 180, height: 228)
        .rotationEffect(.degrees(rotation))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -30)
        .scaleEffect(visible ? 1 : 0.9)
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(
                    .timingCurve(0.2, 0.9, 0.3, 1.15, duration: 0.9)
                    .delay(0.2 + Double(index) * 0.12)
                ) {
                    visible = true
                }
            }
        }
        .onTapGesture {
            if reduceMotion {
                flipped.toggle()
            } else {
                withAnimation(.timingCurve(0.34, 1.1, 0.4, 1, duration: 0.8)) {
                    flipped.toggle()
                }
            }
        }
        .contextMenu {
            Button {
                viewModel.toggleFavorite(entry)
            } label: {
                Label(entry.isFavorite ? "unfavorite" : "favorite",
                      systemImage: entry.isFavorite ? "star.slash" : "star")
            }
            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    private var polaroidFront: some View {
        ZStack(alignment: .top) {
            // Paper base
            RoundedRectangle(cornerRadius: 10)
                .fill(DinoTheme.paper)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)

            VStack(spacing: 10) {
                // Washi tape
                WashiTape(baseColor: moodTapeColor(entry.moodTag), width: 120, height: 22, rotation: tapeRotation)
                    .padding(.top, 6)

                // Photo region
                ZStack(alignment: .bottom) {
                    ZStack {
                        moodPhotoGradient(entry.moodTag)
                        MoodVignette(kind: moodVignetteKind(entry.moodTag))
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Vellum snippet bar
                    Rectangle()
                        .fill(DinoTheme.paper.opacity(0.82))
                        .frame(width: 140, height: 24)
                        .overlay(
                            Text(entry.summary)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#3D3A35"))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 6),
                            alignment: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.bottom, 4)
                }
                .frame(width: 140, height: 140)

                // Caption
                Text(entry.title)
                    .font(.custom(DinoTheme.customFontName, size: 14))
                    .foregroundColor(Color(hex: "#3D3A35"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }

            // Pushpin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#FF8C42"), Color(hex: "#B05A1F")],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .offset(y: -4)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            // Favorite star
            if entry.isFavorite {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DinoTheme.sunYellow)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Polaroid Back
private struct JournalPolaroidBack: View {
    let entry: JournalEntry

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: entry.date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#F4ECD8"))

            // Airmail stripe border (approximate)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.5),
                            Color.white.opacity(0.6),
                            Color.blue.opacity(0.5),
                            Color.red.opacity(0.5),
                            Color.white.opacity(0.6),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    // Postmark circle
                    Circle()
                        .stroke(Color(hex: "#A67074").opacity(0.4), lineWidth: 1)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("DINO")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Color(hex: "#A67074").opacity(0.5))
                        )

                    Spacer()

                    // Postage stamp
                    RoundedRectangle(cornerRadius: 2)
                        .fill(moodTapeColor(entry.moodTag))
                        .frame(width: 40, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                                )
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }

                Spacer().frame(height: 4)

                Text(dateString)
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(Color(hex: "#3D3A35"))

                Text("mood: \(entry.moodTag)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#7A7266"))

                Text("duration: \(formatDuration(entry.durationSeconds))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#7A7266"))

                Spacer()
            }
            .padding(14)
        }
        .frame(width: 180, height: 228)
    }
}

// MARK: - Mood Vignette
private struct MoodVignette: View {
    enum Kind { case sunny, partly, cloudy }
    let kind: Kind

    var body: some View {
        switch kind {
        case .sunny:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFD966"), Color(hex: "#F0A858")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Rays
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 3, height: 30)
                            .offset(y: -36)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                }
                Circle()
                    .fill(Color(hex: "#FFF2B3"))
                    .frame(width: 40, height: 40)
                // Layered hills (back: lighter sage, front: darker sage)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.75))
                        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.72),
                                       control: CGPoint(x: w * 0.25, y: h * 0.68))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.70),
                                       control: CGPoint(x: w * 0.75, y: h * 0.76))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#A8C5A0"))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.85))
                        p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.83),
                                       control: CGPoint(x: w * 0.30, y: h * 0.80))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.82),
                                       control: CGPoint(x: w * 0.80, y: h * 0.86))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#7BA872"))
                }
            }
        case .partly:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C0D4")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Small sun peeking
                Circle()
                    .fill(Color(hex: "#FFE9B8"))
                    .frame(width: 32, height: 32)
                    .offset(x: -30, y: -22)
                // Cloud
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 80, height: 34)
                    .offset(x: 12, y: 4)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 50, height: 24)
                    .offset(x: -8, y: 18)
                // Earthy horizons (back: warm tan, front: deeper umber)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.72))
                        p.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.68),
                                       control: CGPoint(x: w * 0.20, y: h * 0.65))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.66),
                                       control: CGPoint(x: w * 0.60, y: h * 0.71))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#C68B5B").opacity(0.55))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.82))
                        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.80),
                                       control: CGPoint(x: w * 0.25, y: h * 0.78))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.78),
                                       control: CGPoint(x: w * 0.75, y: h * 0.82))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#8B5A3C").opacity(0.7))
                }
            }
        case .cloudy:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#B8C4D0"), Color(hex: "#8FA0B0")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Ellipse()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 70, height: 30)
                    .offset(x: -18, y: -14)
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 80, height: 34)
                    .offset(x: 14, y: 6)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 60, height: 26)
                    .offset(x: -6, y: 24)
                // Dark green horizon strip
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.80))
                        p.addLine(to: CGPoint(x: w, y: h * 0.80))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#6B8577").opacity(0.85))
                }
            }
        }
    }
}

// MARK: - Washi Tape
private struct WashiTape: View {
    let baseColor: Color
    let width: CGFloat
    let height: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseColor.opacity(0.85))
            Canvas { ctx, size in
                let spacing: CGFloat = 4
                let darker = baseColor.opacity(0.35)
                // diagonal lines at 45 deg
                let total = size.width + size.height
                var x: CGFloat = -size.height
                while x < total {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(path, with: .color(darker), lineWidth: 1)
                    x += spacing
                }
            }
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Mood helpers (file scope)
@MainActor
fileprivate func moodTapeColor(_ tag: String) -> Color {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright": return DinoTheme.peach
    case "calm", "peaceful", "reflective": return DinoTheme.skyBlue
    case "grateful", "warm": return DinoTheme.sunYellow
    case "anxious", "thoughtful", "dreamy": return DinoTheme.lavender
    case "sad", "low", "cloudy": return Color(hex: "#B8C4D0")
    default: return DinoTheme.streakSage
    }
}

@MainActor
fileprivate func moodPhotoGradient(_ tag: String) -> LinearGradient {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright":
        return LinearGradient(
            colors: [Color(hex: "#FFD966"), Color(hex: "#F5C6AA")],
            startPoint: .top, endPoint: .bottom
        )
    case "calm", "peaceful", "reflective":
        return LinearGradient(
            colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C5A0")],
            startPoint: .top, endPoint: .bottom
        )
    case "grateful", "warm":
        return LinearGradient(
            colors: [Color(hex: "#FFF2B3"), Color(hex: "#FFD966")],
            startPoint: .top, endPoint: .bottom
        )
    case "anxious", "thoughtful", "dreamy":
        return LinearGradient(
            colors: [Color(hex: "#C4B8D4"), Color(hex: "#A8D4E6")],
            startPoint: .top, endPoint: .bottom
        )
    case "sad", "low", "cloudy":
        return LinearGradient(
            colors: [Color(hex: "#B8C4D0"), Color(hex: "#8FA0B0")],
            startPoint: .top, endPoint: .bottom
        )
    default:
        return LinearGradient(
            colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C0D4")],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Photo Picker (PHPickerViewController wrapper)
private struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.parent.image = image }
            }
        }
    }
}

// MARK: - Mood Sheet
private struct MoodSheet: View {
    @Binding var selected: String?
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, emoji: String)] = [
        ("happy", "😊"),
        ("calm", "🌿"),
        ("okay", "😐"),
        ("low", "🌧"),
        ("stressed", "⚡️")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("how are you feeling?")
                .font(.custom(DinoTheme.customFontName, size: 20))
                .foregroundColor(DinoTheme.ink)
                .padding(.top, 28)

            HStack(spacing: 10) {
                ForEach(options, id: \.label) { option in
                    Button {
                        selected = option.label
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji).font(.system(size: 32))
                            Text(option.label)
                                .font(.system(size: 12))
                                .foregroundColor(DinoTheme.muted)
                        }
                        .frame(width: 60, height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected == option.label
                                      ? Color(hex: "#C7DEBB").opacity(0.5)
                                      : DinoTheme.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "#A8A29A").opacity(0.25), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DinoTheme.paper)
    }
}

@MainActor
fileprivate func moodVignetteKind(_ tag: String) -> MoodVignette.Kind {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright", "grateful", "warm":
        return .sunny
    case "sad", "low", "cloudy":
        return .cloudy
    default:
        return .partly
    }
}
