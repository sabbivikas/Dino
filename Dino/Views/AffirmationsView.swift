//
//  AffirmationsView.swift
//  Dino
//
//  "your mirror" — month-long affirmation collection presented inside an
//  oval mirror frame. Each calendar day deposits one sticky note; on day 30
//  a celebration overlay invites the user to photograph the screen and
//  start a fresh month.
//

import SwiftUI
import UIKit
import Combine
import PostHog

// MARK: - Storage

@MainActor
final class MirrorStore: ObservableObject {
    @Published private(set) var monthKey: String
    @Published private(set) var favorites: Set<String>
    @Published private(set) var monthCompleted: Bool

    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter
    private let shortDateFormatter: DateFormatter
    private let todayFormatter: DateFormatter

    private static let favoritesKey = "affirmation.favorites"
    private static let completedPrefix = "affirmation.completed."

    init() {
        let m = DateFormatter(); m.dateFormat = "yyyy-MM"
        self.monthFormatter = m
        let s = DateFormatter(); s.dateFormat = "MM/dd"
        self.shortDateFormatter = s
        let t = DateFormatter(); t.dateFormat = "MMM d"
        self.todayFormatter = t
        let key = m.string(from: Date())
        self.monthKey = key
        self.favorites = Set(UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? [])
        self.monthCompleted = UserDefaults.standard.bool(forKey: Self.completedPrefix + key)
    }

    // MARK: Day math

    let totalSlots: Int = 30

    /// Day-of-month, capped to totalSlots so the layout never exceeds 30 slots.
    var currentDay: Int {
        min(calendar.component(.day, from: Date()), totalSlots)
    }

    var pastNotesCount: Int { max(0, currentDay - 1) }

    var todayLabel: String {
        todayFormatter.string(from: Date()).lowercased()
    }

    var shouldShowCelebration: Bool {
        currentDay >= totalSlots && !monthCompleted
    }

    func dateLabel(forDay day: Int) -> String {
        guard let date = dateForDay(day) else { return "\(day)" }
        return shortDateFormatter.string(from: date)
    }

    func affirmation(forDay day: Int) -> String {
        let date = dateForDay(day) ?? Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let count = AffirmationsData.all.count
        let idx = ((dayOfYear - 1) % count + count) % count
        return AffirmationsData.all[idx]
    }

    private func dateForDay(_ day: Int) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        var c = DateComponents(); c.year = comps.year; c.month = comps.month; c.day = day
        return calendar.date(from: c)
    }

    // MARK: Favorites

    func isFavorite(_ text: String) -> Bool { favorites.contains(text) }

    func toggleFavorite(_ text: String) {
        if favorites.contains(text) {
            favorites.remove(text)
        } else {
            favorites.insert(text)
            AnalyticsManager.shared.trackAffirmationFavorited()
        }
        UserDefaults.standard.set(Array(favorites), forKey: Self.favoritesKey)
    }

    // MARK: Month completion

    func completeCurrentMonth() {
        UserDefaults.standard.set(true, forKey: Self.completedPrefix + monthKey)
        monthCompleted = true
    }
}

// MARK: - Main view

struct AffirmationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store = MirrorStore()
    @EnvironmentObject var dataManager: SharedDataManager

    @State private var selectedPastDay: Int? = nil
    @State private var todayGlow: Bool = false
    @State private var todayScale: CGFloat = 1.3
    @State private var todayOpacity: Double = 0
    @State private var pastAppeared: Set<Int> = []
    @State private var shimmer: Double = 0.05
    @State private var heartTick: Int = 0   // forces re-render on favorite toggle
    @State private var showCelebration: Bool = false
    @State private var showCamera: Bool = false
    @State private var cameraDevice: UIImagePickerController.CameraDevice = .rear
    @State private var savedToast: Bool = false

    private let palette: [Color] = [
        Color(hex: "#F5C4C4"), Color(hex: "#C4E8D4"), Color(hex: "#D4C4E8"),
        Color(hex: "#F5D4B8"), Color(hex: "#C4D4B8"), Color(hex: "#FEFBF3"),
        Color(hex: "#F5EDD4"), Color(hex: "#F5B8A8"), Color(hex: "#C4D8E8")
    ]

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let mirrorW = W - 40
            let mirrorH = H * 0.78
            let center = CGPoint(x: W / 2, y: H / 2)

            ZStack {
                BackgroundLayer()

                MirrorOval(shimmer: shimmer)
                    .frame(width: mirrorW, height: mirrorH)
                    .position(center)

                // Past notes
                ForEach(0..<store.pastNotesCount, id: \.self) { i in
                    let day = i + 1
                    let text = store.affirmation(forDay: day)
                    let pos = position(for: i, count: store.pastNotesCount, mirrorW: mirrorW, mirrorH: mirrorH, center: center)
                    PastNoteCard(
                        text: text,
                        date: store.dateLabel(forDay: day),
                        color: palette[i % palette.count],
                        isFavorite: store.isFavorite(text),
                        rotation: rotation(for: i),
                        onHeart: {
                            store.toggleFavorite(text)
                            heartTick &+= 1
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )
                    .id("past-\(i)-\(heartTick)")
                    .position(pos)
                    .opacity(pastAppeared.contains(i) ? 1 : 0)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedPastDay = day
                        }
                    }
                    .onAppear {
                        let delay = Double(i) * 0.1
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                _ = pastAppeared.insert(i)
                            }
                        }
                    }
                }

                // Today's note
                let todayText = store.affirmation(forDay: store.currentDay)
                TodayNoteCard(
                    text: todayText,
                    dateLabel: store.todayLabel,
                    isFavorite: store.isFavorite(todayText),
                    glowing: todayGlow,
                    onHeart: {
                        store.toggleFavorite(todayText)
                        heartTick &+= 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
                .id("today-\(heartTick)")
                .scaleEffect(todayScale)
                .opacity(todayOpacity)
                .position(center)
                .onLongPressGesture(minimumDuration: 0.4) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        todayGlow.toggle()
                    }
                }

                // Back button — top-left
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#8B7A6A"))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color(hex: "#F5F0E8")))
                                .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                        .padding(.top, 16)
                        Spacer()
                    }
                    Spacer()
                }

                // Bottom strip
                VStack {
                    Spacer()
                    BottomStrip(count: store.currentDay, total: store.totalSlots) {
                        dismiss()
                    }
                }

                // Selected note overlay
                if let day = selectedPastDay {
                    NoteOverlay(text: store.affirmation(forDay: day)) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedPastDay = nil }
                    }
                }

                // Easter egg
                if showCelebration {
                    CelebrationOverlay(
                        onMirrorPic: {
                            cameraDevice = .rear
                            showCamera = true
                        },
                        onSelfie: {
                            cameraDevice = .front
                            showCamera = true
                        },
                        onClose: { showCelebration = false }
                    )
                }

                // Saved toast
                if savedToast {
                    VStack {
                        Spacer()
                        Text("saved to camera roll ✨")
                            .font(.custom(DinoTheme.customFontName, size: 14))
                            .foregroundColor(Color(hex: "#3D2B18"))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Capsule().fill(Color(hex: "#FEFBF3")))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                            .padding(.bottom, 80)
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                onScreenAppear()
                AnalyticsManager.shared.trackAffirmationsOpened()
                AnalyticsManager.shared.trackScreen("affirmations")
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(device: cameraDevice) { image in
                    showCamera = false
                    if let img = image {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        store.completeCurrentMonth()
                        withAnimation { savedToast = true; showCelebration = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedToast = false }
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Lifecycle

    private func onScreenAppear() {
        if reduceMotion {
            todayScale = 1.0
            todayOpacity = 1
        } else {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                todayScale = 1.0
                todayOpacity = 1
            }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                shimmer = 0.15
            }
        }
        if store.shouldShowCelebration {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showCelebration = true
                }
            }
        }
    }

    // MARK: - Layout helpers

    private func rotation(for index: Int) -> Double {
        let seed = (index &* 2654435761) ^ 0xC0FFEE
        let bucket = Double(abs(seed) % 1000) / 1000.0
        return -10 + bucket * 20
    }

    /// Distribute notes around (and slightly outside) the mirror oval using
    /// a phyllotactic golden-angle spiral. Pushes any landing inside the
    /// today-zone outward so today's card stays unobstructed.
    private func position(for i: Int, count: Int, mirrorW: CGFloat, mirrorH: CGFloat, center: CGPoint) -> CGPoint {
        let goldenDeg = 137.5077640500378
        let angle = Double(i) * goldenDeg * .pi / 180.0
        let t = count <= 1 ? 0 : Double(i) / Double(max(count - 1, 1))
        // Radial fraction grows with index — early notes nestle on mirror,
        // later ones drift to/past the rim.
        let rFrac = 0.42 + sqrt(t) * 0.78 // 0.42..1.20
        let rx = (mirrorW / 2) * rFrac
        let ry = (mirrorH / 2) * rFrac
        var x = center.x + cos(angle) * rx
        var y = center.y + sin(angle) * ry

        // Keep clear of the today card (140×155, give 100pt safe radius).
        let dx = x - center.x
        let dy = y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        let safe: CGFloat = 110
        if dist < safe {
            let s = safe / max(dist, 1)
            x = center.x + dx * s
            y = center.y + dy * s
        }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Background

private struct BackgroundLayer: View {
    var body: some View {
        ZStack {
            Color(hex: "#FAF6F0").ignoresSafeArea()
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.35), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: .center, startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Mirror oval

private struct MirrorOval: View {
    let shimmer: Double
    var body: some View {
        ZStack {
            // Glass fill
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "#C8B89A"), Color(hex: "#D4C4A8"), Color(hex: "#C0AC92")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            // Diagonal specular
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.15), .clear],
                    startPoint: .topLeading, endPoint: .center
                ))
            // Shimmer overlay (animated)
            Ellipse()
                .fill(Color.white.opacity(shimmer))
            // Inner highlight stroke
            Ellipse()
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 2)
                .padding(7)
            // Outer warm-brown frame
            Ellipse()
                .strokeBorder(Color(hex: "#8B6F47"), lineWidth: 12)
        }
    }
}

// MARK: - Past sticky note

private struct PastNoteCard: View {
    let text: String
    let date: String
    let color: Color
    let isFavorite: Bool
    let rotation: Double
    let onHeart: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Text(text)
                    .font(.custom(DinoTheme.customFontName, size: 9))
                    .foregroundColor(Color(hex: "#3D3530"))
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(date)
                    .font(.custom(DinoTheme.customFontName, size: 7))
                    .foregroundColor(Color(hex: "#9B8B7A"))
            }
            .padding(6)
            .frame(width: 68, height: 68)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

            Button(action: onHeart) {
                Text(isFavorite ? "♥" : "♡")
                    .font(.system(size: 8))
                    .foregroundColor(isFavorite ? Color(hex: "#E8B86A") : Color(hex: "#9B8B7A"))
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 68, height: 68)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Today's sticky note

private struct TodayNoteCard: View {
    let text: String
    let dateLabel: String
    let isFavorite: Bool
    let glowing: Bool
    let onHeart: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Text(dateLabel)
                    .font(.custom(DinoTheme.customFontName, size: 9))
                    .foregroundColor(Color(hex: "#9B8B7A"))
                    .padding(.top, 8)
                Spacer(minLength: 0)
                Text(text)
                    .font(.custom(DinoTheme.customFontName, size: 17))
                    .foregroundColor(Color(hex: "#3D3530"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                Spacer(minLength: 0)
            }
            .frame(width: 140, height: 155)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#FEFBF3")))
            .shadow(
                color: .black.opacity(glowing ? 0.35 : 0.18),
                radius: glowing ? 12 : 6, x: 0, y: 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "#E8B86A").opacity(glowing ? 0.5 : 0), lineWidth: 1)
            )

            Button(action: onHeart) {
                Text(isFavorite ? "♥" : "♡")
                    .font(.system(size: 12))
                    .foregroundColor(isFavorite ? Color(hex: "#E8B86A") : Color(hex: "#9B8B7A"))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 140, height: 155)
    }
}

// MARK: - Bottom strip

private struct BottomStrip: View {
    let count: Int
    let total: Int
    let onWriteBack: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 70)
            .allowsHitTesting(false)

            HStack {
                Text("your mirror")
                    .font(.custom(DinoTheme.customFontName, size: 12))
                    .foregroundColor(Color(hex: "#8B7A6A"))
                Spacer()
                Text("\(count) of \(total)")
                    .font(.custom(DinoTheme.customFontName, size: 10))
                    .foregroundColor(Color(hex: "#8B7A6A"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color(hex: "#C4B4A4"), lineWidth: 1))
                Spacer()
                Button(action: { AnalyticsManager.shared.trackAffirmationWriteBackTapped(); onWriteBack() }) {
                    Text("write back →")
                        .font(.custom(DinoTheme.customFontName, size: 12))
                        .foregroundColor(Color(hex: "#8B7A6A"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Past note tap overlay

private struct NoteOverlay: View {
    let text: String
    let onDismiss: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            Text(text)
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(Color(hex: "#3D3530"))
                .multilineTextAlignment(.center)
                .padding(28)
                .frame(maxWidth: 320)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#FEFBF3")))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 4)
                .scaleEffect(1.0)
                .transition(.scale(scale: 1.5).combined(with: .opacity))
        }
    }
}

// MARK: - Easter-egg overlay

private struct CelebrationOverlay: View {
    let onMirrorPic: () -> Void
    let onSelfie: () -> Void
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Color(hex: "#1A0E0A").opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("your mirror is full ✨")
                    .font(.custom(DinoTheme.customFontName, size: 22))
                    .foregroundColor(Color(hex: "#3D2B18"))
                    .multilineTextAlignment(.center)
                    .onAppear { AnalyticsManager.shared.trackAffirmationMirrorFull() }
                Text("you showed up every single day.\nnow go stick your notes on your real mirror\nand take a picture 🪞")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(Color(hex: "#6B5040"))
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    CelebrationButton(title: "mirror pic 🪞", action: onMirrorPic)
                    CelebrationButton(title: "selfie 🤳", action: onSelfie)
                }
                Button("maybe later", action: onClose)
                    .font(.custom(DinoTheme.customFontName, size: 12))
                    .foregroundColor(Color(hex: "#8B7A6A"))
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "#FEFBF3")))
            .padding(.horizontal, 32)
        }
    }
}

private struct CelebrationButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(Color(hex: "#3D2B18"))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#F5EDD4")))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C4B4A4"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera picker

struct CameraPicker: UIViewControllerRepresentable {
    let device: UIImagePickerController.CameraDevice
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            p.sourceType = .camera
            if UIImagePickerController.isCameraDeviceAvailable(device) {
                p.cameraDevice = device
            }
        } else {
            p.sourceType = .photoLibrary
        }
        p.delegate = context.coordinator
        p.allowsEditing = false
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { self.parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onCapture(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
        }
    }
}
