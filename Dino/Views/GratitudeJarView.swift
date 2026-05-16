//
//  GratitudeJarView.swift
//  Dino
//
//  Phase 5 — v6 rebuild. Places the jar inside the grandma's room
//  backdrop, arranges tokens inside the jar interior, animates new
//  drops, and presents the redesigned `AddGratitudeSheet` bottom sheet.
//  Preserves the Phase-3 `dataManager.presentAddGratitude` observer so
//  the streak FAB can open the composer.
//

import SwiftUI

// MARK: - Token asset mapping

enum GratitudeIconType: Int, CaseIterable {
    case dino = 0
    case heart = 1
    case leaf = 2

    var assetName: String {
        switch self {
        case .dino:  return "jar-dino"
        case .heart: return "jar-heart"
        case .leaf:  return "jar-leaf"
        }
    }
}

// MARK: - Main view

struct GratitudeJarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: GratitudeViewModel = GratitudeViewModel(dataManager: SharedDataManager.shared)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tracks which note (by id) should play the drop animation on its next
    // render. Cleared ~1.1s after it's set so tokens settle into idle state.
    @State private var justAddedId: UUID?
    @State private var lastKnownNoteIds: [UUID] = []

    // Jar wobble animation state
    @State private var jarWobbleAnimating = false

    var body: some View {
        NavigationStack {
            ZStack {
                GrandmasRoomBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("gratitude jar")
                                .font(.custom(DinoTheme.customFontName, size: 28))
                                .foregroundColor(DinoTheme.ink)
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

                            Text(subNote)
                                .font(.custom(DinoTheme.customFontName, size: 13))
                                .italic()
                                .foregroundColor(DinoTheme.jarMuted)
                        }
                        Spacer()
                        if dataManager.streakData.currentStreak > 0 {
                            StreakChip(days: dataManager.streakData.currentStreak)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer(minLength: 8)

                    // Jar + contents + halo
                    // Offset down so the jar's bottom edge rests on the
                    // wooden shelf / doily of the grandma's-room backdrop.
                    ZStack {
                        // Halo behind jar
                        JarHaloView(reduceMotion: reduceMotion)
                            .frame(width: 360, height: 360)

                        // Jar image + tokens
                        JarStackView(
                            notes: viewModel.notes,
                            justAddedId: justAddedId
                        )
                        .frame(width: 300)
                        .rotationEffect(.degrees(jarWobbleAnimating ? 0.6 : -0.6))
                        .offset(y: jarWobbleAnimating ? -2 : 0)
                        .shadow(color: Color(hex: "#2A1A0C").opacity(0.32), radius: 20, x: 0, y: 8)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(
                                .easeInOut(duration: 7)
                                .repeatForever(autoreverses: true)
                            ) {
                                jarWobbleAnimating = true
                            }
                        }
                    }
                    .offset(y: 70)

                    // Count caption under jar
                    if viewModel.totalCount > 0 {
                        Text("\(viewModel.totalCount) keepsakes · this year")
                            .font(.custom(DinoTheme.customFontName, size: 13))
                            .foregroundColor(DinoTheme.jarMuted)
                            .padding(.top, -8)
                    }

                    // 30-note milestone banner
                    if viewModel.showCongrats {
                        HStack(spacing: 8) {
                            Text("🎉")
                            Text("30 notes milestone!")
                                .font(.custom(DinoTheme.customFontName, size: 14))
                                .foregroundColor(DinoTheme.ink)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule().fill(DinoTheme.paper)
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        )
                    }

                    Spacer(minLength: 8)

                    // Write Gratitude button
                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Text("+ add a keepsake")
                            .font(.custom(DinoTheme.customFontName, size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DinoTheme.streakSage)
                            )
                            .shadow(color: DinoTheme.streakSage.opacity(0.40), radius: 12, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddGratitudeSheet(viewModel: viewModel, onSaved: {
                    // The new note is at index 0 (SharedDataManager inserts at 0).
                    if let newest = viewModel.notes.first {
                        justAddedId = newest.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                            if justAddedId == newest.id {
                                justAddedId = nil
                            }
                        }
                    }
                })
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(DinoTheme.paper)
            }
            .sheet(isPresented: $viewModel.showNoteDetail) {
                if let note = viewModel.selectedNote {
                    GratitudeNoteDetail(note: note)
                }
            }
            // Phase-3 wiring preserved: streak FAB flips presentAddGratitude
            // and we forward it to the composer sheet.
            .onChange(of: dataManager.presentAddGratitude) { _, newValue in
                if newValue {
                    viewModel.showAddSheet = true
                    dataManager.presentAddGratitude = false
                }
            }
            .onAppear {
                lastKnownNoteIds = viewModel.notes.map(\.id)
                AnalyticsManager.shared.trackGratitudeJarOpened()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private var subNote: String {
        "a little shelf for little joys."
    }
}

// MARK: - Streak chip

private struct StreakChip: View {
    let days: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 13))
            Text("\(days) day")
                .font(.custom(DinoTheme.customFontName, size: 13))
                .foregroundColor(DinoTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(DinoTheme.paper)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

// MARK: - Jar halo (soft breathing glow behind the jar)

private struct JarHaloView: View {
    let reduceMotion: Bool
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: DinoTheme.jarHalo.opacity(0.38), location: 0.0),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .scaleEffect(animating ? 1.05 : 1.0)
            .opacity(animating ? 0.5 : 0.35)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 9).repeatForever(autoreverses: true)
                ) {
                    animating = true
                }
            }
    }
}

// MARK: - Jar stack (jar image + tokens inside interior)

private struct JarStackView: View {
    let notes: [GratitudeNote]
    let justAddedId: UUID?

    // Jar image aspect ratio: 1102 × 1247
    private let jarAspect: CGFloat = 1102.0 / 1247.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / jarAspect

            ZStack {
                // Jar drawing
                Image("jar")
                    .resizable()
                    .aspectRatio(jarAspect, contentMode: .fit)
                    .frame(width: w, height: h)

                // Tokens inside the interior rect
                ZStack {
                    ForEach(Array(notes.prefix(30).enumerated()), id: \.element.id) { index, note in
                        let pos = tokenPosition(
                            index: index,
                            total: min(notes.count, 30),
                            containerWidth: w,
                            containerHeight: h
                        )
                        let isNew = note.id == justAddedId
                        let token = JarTokenView(
                            assetName: tokenAssetFor(index: index),
                            indexInJar: index,
                            totalInJar: min(notes.count, 30),
                            isNewDrop: false
                        )

                        Group {
                            if isNew {
                                token.modifier(JarDropKeyframeModifier(dropDistance: pos.y))
                            } else {
                                token
                            }
                        }
                        .position(x: pos.x, y: pos.y)
                    }
                }
                .frame(width: w, height: h)

                // Glass highlight sheen — top layer
                GlassSheen()
                    .frame(width: w * 0.14, height: h * 0.46)
                    .position(x: w * 0.25, y: h * 0.57)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(jarAspect, contentMode: .fit)
    }

    // Cycle dino → heart → leaf by index.
    private func tokenAssetFor(index: Int) -> String {
        let types = GratitudeIconType.allCases
        return types[index % types.count].assetName
    }

    // Interior bounds inside the jar image (fractions of the drawn image).
    // The jar artwork occupies roughly 12..88% wide, 30..94% tall.
    private func tokenPosition(
        index: Int,
        total: Int,
        containerWidth w: CGFloat,
        containerHeight h: CGFloat
    ) -> CGPoint {
        let interiorLeft = w * 0.16
        let interiorRight = w * 0.84
        let interiorTop = h * 0.32
        let interiorBottom = h * 0.90

        let interiorW = interiorRight - interiorLeft
        let interiorH = interiorBottom - interiorTop

        // Pack in rows from the bottom up, 4 tokens per row.
        let perRow = 4
        // With notes inserted at 0 being the newest, we still visually
        // place newest on top of the pile — show newest at the top row.
        let row = index / perRow
        let col = index % perRow

        // Deterministic jitter seeded by index.
        let hx = jitter(seed: index &* 2654435761 &+ 13, range: 0.06)
        let hy = jitter(seed: index &* 2246822519 &+ 7,  range: 0.03)

        // Horizontal spread across interior.
        let baseX = interiorLeft + interiorW * (CGFloat(col) + 0.5) / CGFloat(perRow)
        let x = baseX + interiorW * CGFloat(hx)

        // Stack from bottom up: row 0 sits near bottom, subsequent rows rise.
        let rowHeight: CGFloat = min(0.14, 1.0 / 7.0)
        let baseY = interiorBottom - interiorH * (rowHeight * CGFloat(row) + 0.08)
        let y = baseY + interiorH * CGFloat(hy)

        // Clamp into interior rect.
        let clampedX = min(max(x, interiorLeft + 18), interiorRight - 18)
        let clampedY = min(max(y, interiorTop + 18), interiorBottom - 18)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func jitter(seed: Int, range: Double) -> Double {
        let bucket = Double((abs(seed) % 1000)) / 1000.0
        return (bucket - 0.5) * 2.0 * range
    }
}

// MARK: - Jar drop keyframe animation

/// Animatable values for the jar-drop sequence.
private struct JarDropValues {
    var opacity: Double = 0
    var translateY: CGFloat = 0
    var rotation: Double = -8
    var scale: CGFloat = 0.85
}

/// Plays a one-shot keyframe animation when the token first appears:
/// opacity 0 → 1, translateY from above the jar to its rest position
/// with a gravity arc + bounce, slight rotation wobble, scale squash.
private struct JarDropKeyframeModifier: ViewModifier {
    /// Final y-position of the token inside the jar, used to compute
    /// how far above the jar the token should start.
    let dropDistance: CGFloat

    func body(content: Content) -> some View {
        let startY = -(dropDistance + 80)
        return content
            .keyframeAnimator(
                initialValue: JarDropValues(translateY: startY)
            ) { view, value in
                view
                    .opacity(value.opacity)
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .offset(y: value.translateY)
            } keyframes: { _ in
                // Opacity: fade in quickly, stay visible.
                KeyframeTrack(\JarDropValues.opacity) {
                    LinearKeyframe(0.0, duration: 0.05)
                    LinearKeyframe(1.0, duration: 0.18)
                    LinearKeyframe(1.0, duration: 0.85)
                }
                // TranslateY: gravity drop from above jar, overshoot below
                // rest, bounce back, settle.
                KeyframeTrack(\JarDropValues.translateY) {
                    CubicKeyframe(startY, duration: 0.05)
                    CubicKeyframe(12, duration: 0.55)   // gravity arc, slight overshoot
                    SpringKeyframe(-4, duration: 0.20)  // bounce up
                    SpringKeyframe(0,  duration: 0.28)  // settle at rest
                }
                // Rotation: arrives slightly tilted, wobbles, settles upright.
                KeyframeTrack(\JarDropValues.rotation) {
                    LinearKeyframe(-8, duration: 0.05)
                    CubicKeyframe(6,  duration: 0.55)
                    SpringKeyframe(-3, duration: 0.20)
                    SpringKeyframe(0,  duration: 0.28)
                }
                // Scale: squash on impact, then settle.
                KeyframeTrack(\JarDropValues.scale) {
                    LinearKeyframe(0.85, duration: 0.05)
                    CubicKeyframe(1.10, duration: 0.55)  // impact squash
                    SpringKeyframe(0.96, duration: 0.20) // recoil
                    SpringKeyframe(1.00, duration: 0.28) // rest
                }
            }
    }
}

// MARK: - Glass sheen highlight

private struct GlassSheen: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(-6))
    }
}

// MARK: - Note Detail Sheet (preserved from previous version)

struct GratitudeNoteDetail: View {
    let note: GratitudeNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🫙")
                .font(.system(size: 50))
                .padding(.top, 32)

            Text(note.text)
                .font(DinoTheme.dinoFont(size: 20))
                .foregroundColor(DinoTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(note.createdAt.formatted(date: .long, time: .omitted))
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)

            Spacer()

            Button("close") { dismiss() }
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textSecondary)
                .padding(.bottom, 32)
        }
    }
}
