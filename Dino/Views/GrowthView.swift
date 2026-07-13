//
//  GrowthView.swift
//  Dino
//

import SwiftUI
import UIKit

// MARK: - File-private helpers

private func smoothstep(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = max(0, min(1, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func hexRGB(_ hex: String) -> (Double, Double, Double) {
    let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: trimmed).scanHexInt64(&value)
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return (r, g, b)
}

private func mixHex(_ a: String, _ b: String, _ t: Double) -> Color {
    let clamped = max(0, min(1, t))
    let (ar, ag, ab) = hexRGB(a)
    let (br, bg, bb) = hexRGB(b)
    return Color(
        .sRGB,
        red: lerp(ar, br, clamped),
        green: lerp(ag, bg, clamped),
        blue: lerp(ab, bb, clamped),
        opacity: 1.0
    )
}

private func phyllotaxis(count: Int, scale: Double) -> [CGPoint] {
    let golden = 137.5 * .pi / 180.0
    return (0..<count).map { i in
        let r = scale * sqrt(Double(i) / Double(max(count - 1, 1)))
        let theta = Double(i) * golden
        return CGPoint(x: cos(theta) * r, y: sin(theta) * r)
    }
}

private enum GardenScene {
    case morning, afternoon, evening, night, rainy, cloudy
}

private func sceneKey(theme: DinoAppTheme, date: Date) -> GardenScene {
    switch theme {
    case .rainy, .storm: return .rainy
    case .cloudy:        return .cloudy
    case .night:         return .night
    default:
        break
    }
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 6...11:  return .morning
    case 12...16: return .afternoon
    case 17...19: return .evening
    default:      return .night
    }
}

// MARK: - GrowthView

struct GrowthView: View {

    @StateObject private var vm = GrowthViewModel.shared
    @ObservedObject private var shared = SharedDataManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // initialized at struct init so the very first scene configure already
    // knows she carries a letter — otherwise she starts ordinary garden life
    // and the delivery never begins
    @State private var letterUnread = GardenLetterStore.isUnreadToday()
    @State private var letterLeftForLater = false
    // share my garden — postcard composition
    @State private var composingShare = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var shareFailedToast = false
    #if DEBUG
    @State private var showRenderDiag = false
    @State private var renderDiagImage: UIImage?
    #endif
    #if DEBUG
    @State private var showShareQAGallery = false
    #endif

    /// Night + unread → she waits for first light; the status line says so.
    private var letterWaitsForMorning: Bool {
        let hour = GardenDebug.forcedHour ?? Calendar.current.component(.hour, from: Date())
        return letterUnread && GardenCreatureRegime.from(hour: hour) != .day
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GrowthHeader()
                ProgressCard(vm: vm)
                Garden3DPanel(vm: vm, reduceMotion: reduceMotion,
                              letterUnread: $letterUnread,
                              letterLeftForLater: $letterLeftForLater)
                    .overlay(alignment: .topTrailing) {
                        // quiet share affordance — availability, never a nag
                        Button { shareGarden() } label: {
                            // cream chip: the bare glyph vanished against bright
                            // noon and night skies on device — the chip reads on
                            // every scene without shouting
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#3D3A35").opacity(0.70))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color(hex: "#FFFDF6").opacity(0.85)))
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(GardenShare.shareButtonLabel)
                        .padding(6)
                    }
                StatusLine(vm: vm, letterWaiting: letterWaitsForMorning,
                           letterLeftForLater: letterLeftForLater)
                PracticePillsRow(vm: vm)
                WeeklyBloomLog(blooms: vm.weeklyBlooms)
                XPCard(vm: vm)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .onAppear { letterUnread = GardenLetterStore.isUnreadToday() }
        .task { await vm.refreshMovementBonus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            letterUnread = GardenLetterStore.isUnreadToday()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Explicitly blank principal slot — prevents any ancestor title
            // (e.g. streak count "13") from leaking into the back-button area.
            ToolbarItem(placement: .principal) {
                Text("")
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackScreen("growth_garden")
            #if DEBUG
            // -gardenShareQA: postcard fixture gallery for loop screenshots.
            if ProcessInfo.processInfo.arguments.contains("-gardenShareQA") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showShareQAGallery = true }
            }
            // -gardenRenderQA: compose via the REAL composer and display the raw
            // UIImage on magenta — isolates render (black/cream/nil) from sharing.
            if ProcessInfo.processInfo.arguments.contains("-gardenShareAuto") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { shareGarden() }
            }
            if ProcessInfo.processInfo.arguments.contains("-gardenRenderQA") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let snap = SunflowerSnapshot(
                        stage: vm.growthStage, careState: vm.careState,
                        sproutP: vm.sproutP, stemP: vm.stemP, leafP: vm.leafP,
                        budP: vm.budP, bloomP: vm.bloomP, care: vm.care)
                    // EXACT real-share scene computation
                    let realScene = sceneKey(theme: themeManager.currentTheme, date: Date())
                    renderDiagImage = GardenPostcardComposer.compose(
                        snap: snap, scene: realScene, day: 30, uid: "render-diag")
                    showRenderDiag = true
                }
            }
            #endif
        }
        .overlay {
            if composingShare {
                Text(GardenShare.composingLine)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(DinoTheme.textPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#FFFDF6")).shadow(color: .black.opacity(0.12), radius: 8, y: 3))
                    .transition(.opacity)
            } else if shareFailedToast {
                Text("couldn't make your postcard just now. try again 🌱")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#FFFDF6")).shadow(color: .black.opacity(0.12), radius: 8, y: 3))
                    .padding(.horizontal, 30)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                GardenShareSheet(items: [image, GardenShare.shareText, ShareDino.appStoreURL])
            }
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showShareQAGallery) {
            GardenPostcardQAGallery()
        }
        .fullScreenCover(isPresented: $showRenderDiag) {
            ZStack {
                Color(red: 1, green: 0, blue: 1).ignoresSafeArea()  // magenta backdrop
                if let img = renderDiagImage {
                    VStack(spacing: 8) {
                        Text("composed \(Int(img.size.width))x\(Int(img.size.height)) @\(Int(img.scale))x")
                            .font(.system(size: 12)).foregroundColor(.white)
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 420)
                            .border(Color.white, width: 2)
                    }
                } else {
                    Text("RENDER RETURNED NIL").font(.system(size: 20)).foregroundColor(.white)
                }
            }
        }
        #endif
    }

    // MARK: - Share my garden

    private func shareGarden() {
        AnalyticsManager.shared.trackGardenShareOpened()
        HapticManager.shared.light()
        withAnimation(.easeInOut(duration: 0.2)) { composingShare = true }
        // next runloop beat: let the composing line paint before the render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let snap = SunflowerSnapshot(
                stage: vm.growthStage, careState: vm.careState,
                sproutP: vm.sproutP, stemP: vm.stemP, leafP: vm.leafP,
                budP: vm.budP, bloomP: vm.bloomP, care: vm.care)
            let scene = sceneKey(theme: themeManager.currentTheme, date: Date())
            let day = GardenShare.age(firstPractice: vm.firstPracticeDate)
            let image = GardenPostcardComposer.compose(
                snap: snap, scene: scene, day: day, uid: GardenShare.currentUID())
            withAnimation(.easeInOut(duration: 0.2)) { composingShare = false }
            // never open the share sheet with a nil or black render
            if let image, !GardenPostcardComposer.isMostlyDark(image) {
                shareImage = image
                showShareSheet = true
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { shareFailedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { shareFailedToast = false }
                }
            }
        }
    }
}

// MARK: - Share my garden — the postcard
// Lives in this file on purpose: the card reuses the hand-drawn 2D garden
// (drawBackground/drawSunflower) that the 3D panel replaced on screen —
// on paper, the drawing IS the better garden.

fileprivate struct GardenPostcardView: View {
    let snap: SunflowerSnapshot
    let scene: GardenScene
    let day: Int
    let uid: String
    /// one fixed instant — a postcard is a still, not a boil
    var time: TimeInterval = 12_000

    var body: some View {
        VStack(spacing: 0) {
            Canvas { ctx, size in
                var c = ctx
                drawBackground(ctx: &c, size: size, scene: scene, t: time, reduceMotion: true)
                drawSunflower(ctx: &c, size: size, snap: snap, t: time,
                              reduceMotion: true, appearScale: 1.0)
            }
            .frame(width: 484, height: 424)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
            .padding(.top, 30)

            Spacer(minLength: 0)

            Text(GardenShare.caption(day: day))
                .font(DinoTheme.dinoFont(size: 25))
                .foregroundColor(Color(hex: "#3D3A35"))

            Spacer(minLength: 0)

            Text(GardenShare.footer)
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(Color(hex: "#A8A29A"))
                .padding(.bottom, 22)
        }
        .frame(width: 540, height: 675)
        .background(PostcardPaper())
        .overlay(alignment: .topTrailing) {
            // the stamp — theirs, forever — with its cancellation mark
            ZStack(alignment: .topTrailing) {
                GardenPostmarkView(day: day)
                    .offset(x: -38, y: 62)   // hangs off the stamp's lower-left corner
                GardenStampView(uid: uid)
                    .rotationEffect(.degrees(2))
                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            }
            .padding(.top, 14)
            .padding(.trailing, 16)
        }
    }
}

/// cream stock with raster grain — ImageRenderer cannot run Metal shader
/// effects, so the postcard uses the drawn-line grain (renders identically
/// offline), near-square corners, hairline edge
fileprivate struct PostcardPaper: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(hex: "#FFFDF6"))
            .overlay(
                Canvas { ctx, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)),
                                 with: .color(Color(hex: "#3D3A35").opacity(0.012)))
                        y += 4
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
    }
}

@MainActor
fileprivate enum GardenPostcardComposer {
    /// 540×675pt at 2x → 1080×1350px — instagram story friendly 4:5.
    ///
    /// Renders by hosting the SwiftUI view in the key window and snapshotting
    /// via UIKit (drawHierarchy). SwiftUI's ImageRenderer returns a BLACK image
    /// for Canvas content on some physical devices (Metal-backed path) even
    /// though it works in the simulator — this path avoids that entirely. The
    /// colorScheme is pinned light so the postcard is always cream.
    static func compose(snap: SunflowerSnapshot, scene: GardenScene, day: Int, uid: String) -> UIImage? {
        let target = CGSize(width: 540, height: 675)
        let content = GardenPostcardView(snap: snap, scene: scene, day: day, uid: uid)
            .environment(\.colorScheme, .light)
            .frame(width: target.width, height: target.height)

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            // no window (unlikely) — fall back to ImageRenderer
            let r = ImageRenderer(content: content); r.scale = 2
            return r.uiImage
        }

        let host = UIHostingController(rootView: content)
        host.view.frame = CGRect(origin: .zero, size: target)
        host.view.backgroundColor = .clear
        host.view.layer.zPosition = -1
        window.addSubview(host.view)
        window.sendSubviewToBack(host.view)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        host.view.removeFromSuperview()
        return image
    }

    /// The hard guard: never share a failed (mostly-dark) render. Samples a
    /// 20×20 grid of the composed image.
    static func isMostlyDark(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0,
              let data = cg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return true }
        let w = cg.width, h = cg.height
        let bpp = cg.bitsPerPixel / 8, bpr = cg.bytesPerRow
        let stepX = max(1, w / 20), stepY = max(1, h / 20)
        var dark = 0, total = 0, y = 0
        while y < h {
            var x = 0
            while x < w {
                let i = y * bpr + x * bpp
                if Int(ptr[i]) < 40 && Int(ptr[i + 1]) < 40 && Int(ptr[i + 2]) < 40 { dark += 1 }
                total += 1; x += stepX
            }
            y += stepY
        }
        return total > 0 && Double(dark) / Double(total) > 0.85
    }
}

/// house activity-sheet wrapper (same iPad popover anchor fix as journal share)
fileprivate struct GardenShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
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
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
// MARK: - Postcard QA gallery (-gardenShareQA)
// Fixture postcards for loop screenshots: young day, grown night, and the
// two-uid stamp proof. View-local fixtures — writes nothing.

fileprivate struct GardenPostcardQAGallery: View {
    @Environment(\.dismiss) private var dismiss

    private static let young = SunflowerSnapshot(
        stage: .sprout, careState: .healthy,
        sproutP: 1.0, stemP: 0.15, leafP: 0.10, budP: 0, bloomP: 0, care: 1.0)
    private static let grown = SunflowerSnapshot(
        stage: .thriving, careState: .healthy,
        sproutP: 1.0, stemP: 1.0, leafP: 1.0, budP: 1.0, bloomP: 1.0, care: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("postcard qa").font(DinoTheme.dinoFont(size: 14))
                HStack(spacing: 10) {
                    GardenPostcardView(snap: Self.young, scene: .morning, day: 6, uid: "stamp-proof-a")
                        .scaleEffect(0.32).frame(width: 178, height: 220)
                    GardenPostcardView(snap: Self.grown, scene: .night, day: 84, uid: "stamp-proof-a")
                        .scaleEffect(0.32).frame(width: 178, height: 220)
                }
                Text("same uid above · different uids below").font(DinoTheme.dinoFont(size: 12))
                HStack(spacing: 10) {
                    GardenPostcardView(snap: Self.grown, scene: .afternoon, day: 30, uid: "stamp-proof-a")
                        .scaleEffect(0.32).frame(width: 178, height: 220)
                    GardenPostcardView(snap: Self.grown, scene: .afternoon, day: 30, uid: "stamp-proof-b")
                        .scaleEffect(0.32).frame(width: 178, height: 220)
                }
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        GardenStampView(uid: "stamp-proof-a").scaleEffect(1.6).frame(width: 110, height: 130)
                        Text("uid a").font(DinoTheme.dinoFont(size: 11))
                    }
                    VStack(spacing: 4) {
                        GardenStampView(uid: "stamp-proof-b").scaleEffect(1.6).frame(width: 110, height: 130)
                        Text("uid b").font(DinoTheme.dinoFont(size: 11))
                    }
                }
                Button("close") { dismiss() }.padding(.bottom, 30)
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "#EFE9DC").ignoresSafeArea())
    }
}
#endif

// MARK: - GrowthHeader

private struct GrowthHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THIS SEASON")
                .font(DinoTheme.dinoFont(size: 12))
                .tracking(1.2)
                .foregroundColor(Color(hex: "#6B7280"))
            Text("your garden 🌻")
                .font(DinoTheme.dinoFont(size: 32))
                .foregroundColor(Color(hex: "#2D3142"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ProgressCard

private struct ProgressCard: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("day")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
                Text("\(vm.dayNumber)")
                    .font(DinoTheme.numericFont(size: 28))
                    .foregroundColor(Color(hex: "#2D3142"))
                Spacer()
            }

            PhaseBar(
                totalSessions: vm.totalSessions,
                growthStage: vm.growthStage
            )

            // Stage-milestone labels matching the 5 tick positions on the bar.
            HStack {
                phaseLabel("seed")
                Spacer()
                phaseLabel("sprout")
                Spacer()
                phaseLabel("growing")
                Spacer()
                phaseLabel("budding")
                Spacer()
                phaseLabel("bloom")
            }

            // Narrative next-stage line beneath the bar.
            nextStageLine

            Spacer().frame(height: 2)

            CareBar(care: vm.care, daysSince: vm.daysSinceAny)

            HStack {
                phaseLabel("today")
                Spacer()
                phaseLabel("3d")
                Spacer()
                phaseLabel("7d")
                Spacer()
                phaseLabel("10d")
                Spacer()
                phaseLabel("14d+")
            }

            wateringLine
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#FFFDF5"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#E8E0CC"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private func phaseLabel(_ text: String) -> some View {
        Text(text)
            .font(DinoTheme.dinoFont(size: 10))
            .foregroundColor(Color(hex: "#6B7280"))
    }

    @ViewBuilder
    private var nextStageLine: some View {
        HStack(spacing: 4) {
            Text("your sunflower is \(vm.growthStage.displayName)")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(Color(hex: "#2D3142"))
            if let remain = vm.sessionsToNextStage, let next = vm.nextStageName {
                Text(" · \(remain) more \(remain == 1 ? "session" : "sessions") to \(next)")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var wateringLine: some View {
        HStack(spacing: 6) {
            if vm.wateredToday {
                Text("watered today 💧")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#2D3142"))
            } else if let d = vm.lastWateredDaysAgo {
                Text("last watered \(d)d ago")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            } else {
                Text("waiting to be watered")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            Spacer()
        }
    }
}

// MARK: - PhaseBar (5 stage milestones + current progress)

private struct PhaseBar: View {
    let totalSessions: Int
    let growthStage: GrowthStage

    /// Normalized milestone tick positions.
    /// 0/62, 3/62, 11/62, 21/62, 51/62  — last 1.0 handled by bar terminus.
    private let tickFractions: [Double] = [
        0.0,
        3.0 / 62.0,
        11.0 / 62.0,
        21.0 / 62.0,
        51.0 / 62.0
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = min(1.0, Double(totalSessions) / 62.0)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color(hex: "#E8DFCF"))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)

                // Filled segment up to current progress
                Capsule()
                    .fill(Color(hex: "#6B9E44"))
                    .frame(width: max(0, w * progress), height: 6)

                // 5 milestone dots at stage boundaries
                ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, frac in
                    Circle()
                        .fill(Color(hex: "#D6C7A8"))
                        .frame(width: 6, height: 6)
                        .offset(x: max(0, w * frac - 3))
                }

                // Accent dot at current progress
                Circle()
                    .fill(Color(hex: "#F5C842"))
                    .overlay(Circle().stroke(Color(hex: "#D49020"), lineWidth: 1))
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, w * progress - 6))
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

// MARK: - CareBar

private struct CareBar: View {
    let care: Double
    let daysSince: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(0, min(1, care))
            let careColor = mixHex("#7BA872", "#9C7C50", 1 - clamped)
            let fillW = max(0, w * clamped)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#E8DFCF"))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)

                Capsule()
                    .fill(careColor)
                    .frame(width: fillW, height: 6)

                HStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(Color(hex: "#D6C7A8"))
                            .frame(width: 6, height: 6)
                        if i < 4 { Spacer(minLength: 0) }
                    }
                }

                // Left = healthy (today, care=1), right = wilted (14d+, care=0)
                let dotOffset = max(0, (1 - clamped) * w - 6)
                Circle()
                    .fill(careColor)
                    .overlay(Circle().stroke(careColor.opacity(0.7), lineWidth: 1))
                    .frame(width: 12, height: 12)
                    .offset(x: dotOffset)
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

// MARK: - Plant snapshot (value captured on MainActor, safe to read in Canvas)

private struct SunflowerSnapshot {
    let stage: GrowthStage
    let careState: CareState
    let sproutP: Double
    let stemP: Double
    let leafP: Double
    let budP: Double
    let bloomP: Double
    let care: Double
}

// MARK: - GardenPanel

private struct GardenPanel: View {
    @ObservedObject var vm: GrowthViewModel
    let scene: GardenScene
    let reduceMotion: Bool

    @State private var appeared: Bool = false

    var body: some View {
        let snap = SunflowerSnapshot(
            stage: vm.growthStage,
            careState: vm.careState,
            sproutP: vm.sproutP,
            stemP: vm.stemP,
            leafP: vm.leafP,
            budP: vm.budP,
            bloomP: vm.bloomP,
            care: vm.care
        )

        return TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15.0 : nil, paused: false)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawBackground(ctx: &ctx, size: size, scene: scene, t: t, reduceMotion: reduceMotion)
                drawSunflower(
                    ctx: &ctx,
                    size: size,
                    snap: snap,
                    t: t,
                    reduceMotion: reduceMotion,
                    appearScale: appeared ? 1.0 : 0.0
                )
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#A8C5A0").opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appeared = true
            }
            AnalyticsManager.shared.trackGrowthGardenOpened()
        }
    }
}

// MARK: - Garden3DPanel (SceneKit garden — GardenPanel above is kept, unused, for instant revert)

private struct Garden3DPanel: View {
    @ObservedObject var vm: GrowthViewModel
    let reduceMotion: Bool
    @Binding var letterUnread: Bool
    @Binding var letterLeftForLater: Bool
    @State private var showLetter = false

    var body: some View {
        GardenSceneView(
            stage: GardenDebug.forceBloomed ? .bloomed : vm.growthStage,
            careState: vm.careState,
            reduceMotion: reduceMotion,
            letterPending: letterUnread,
            onLetterOpen: {
                GardenLetterStore.markReadToday()
                letterUnread = false
                letterLeftForLater = false
                showLetter = true
            },
            onLetterTucked: {
                letterLeftForLater = true
            }
        )
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .fullScreenCover(isPresented: $showLetter) {
            GardenLetterView(onDismiss: { showLetter = false })
        }
        .onAppear {
            AnalyticsManager.shared.trackGrowthGardenOpened()
            #if DEBUG
            // Dev shortcut: present the letter immediately for layout QA.
            if ProcessInfo.processInfo.arguments.contains("-gardenLetterOpen") {
                showLetter = true
            }
            #endif
        }
    }
}

// MARK: - Care mapping (discrete -> drawing params)

private struct CareParams {
    let bendDeg: Double
    let leafYellow: Double    // 0..1 toward amber
    let leafBrown: Double     // 0..1 toward brown (beyond yellow)
    let droopDeg: Double      // extra per-leaf droop
    let fallenPetals: Int
    let collapsed: Bool       // true when .dead (stem lies down)
    let headDroop: Double     // degrees head falls forward
    let saturation: Double    // multiplicative color vividness
    let careColorMin: Double  // wiltColor clamp tweak
}

private func careParams(for state: CareState) -> CareParams {
    switch state {
    case .healthy:
        return CareParams(
            bendDeg: 0, leafYellow: 0, leafBrown: 0,
            droopDeg: 0, fallenPetals: 0, collapsed: false,
            headDroop: 0, saturation: 1.0, careColorMin: 0.25
        )
    case .tired:
        return CareParams(
            bendDeg: 4, leafYellow: 0.05, leafBrown: 0,
            droopDeg: 12, fallenPetals: 0, collapsed: false,
            headDroop: 2, saturation: 0.9, careColorMin: 0.22
        )
    case .struggling:
        return CareParams(
            bendDeg: 15, leafYellow: 0.3, leafBrown: 0,
            droopDeg: 22, fallenPetals: 2, collapsed: false,
            headDroop: 8, saturation: 0.8, careColorMin: 0.18
        )
    case .wilting:
        return CareParams(
            bendDeg: 30, leafYellow: 0.7, leafBrown: 0.1,
            droopDeg: 34, fallenPetals: 4, collapsed: false,
            headDroop: 18, saturation: 0.7, careColorMin: 0.15
        )
    case .dying:
        return CareParams(
            bendDeg: 50, leafYellow: 0.8, leafBrown: 0.5,
            droopDeg: 48, fallenPetals: 7, collapsed: false,
            headDroop: 90, saturation: 0.55, careColorMin: 0.12
        )
    case .dead:
        return CareParams(
            bendDeg: 85, leafYellow: 1.0, leafBrown: 1.0,
            droopDeg: 60, fallenPetals: 10, collapsed: true,
            headDroop: 90, saturation: 0.4, careColorMin: 0.08
        )
    }
}

/// Leaf / stem / bud color shaded toward amber then brown based on care.
private func foliageColor(base: String, cp: CareParams) -> Color {
    // First blend base -> amber by leafYellow
    let yellowed = mixHex(base, "#C4A35A", cp.leafYellow)
    // Then blend toward brown by leafBrown
    let (yr, yg, yb) = rgbFromColor(yellowed)
    let (br, bg, bb) = hexRGB("#9C7C50")
    let t = max(0, min(1, cp.leafBrown))
    return Color(
        .sRGB,
        red: lerp(yr, br, t),
        green: lerp(yg, bg, t),
        blue: lerp(yb, bb, t),
        opacity: 1.0
    )
}

/// Pulls back RGB from a Color via UIColor introspection (iOS only).
private func rgbFromColor(_ color: Color) -> (Double, Double, Double) {
    #if canImport(UIKit)
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
        return (Double(r), Double(g), Double(b))
    }
    #endif
    return (0.5, 0.5, 0.5)
}

// MARK: - Plant rendering

private func drawSunflower(
    ctx: inout GraphicsContext,
    size: CGSize,
    snap: SunflowerSnapshot,
    t: TimeInterval,
    reduceMotion: Bool,
    appearScale: Double
) {
    // Design uses a 400x320 viewBox
    let sx = size.width / 400.0
    let sy = size.height / 320.0

    func px(_ x: Double) -> CGFloat { CGFloat(x * Double(sx)) }
    func py(_ y: Double) -> CGFloat { CGFloat(y * Double(sy)) }

    let cx = 200.0
    // groundY is the soil *surface*. grass strip is drawn above this line in
    // drawBackground; groundY matches the top of the grass strip (h*0.55 - 18
    // in canvas pixels). In 320-design coords this is 320*0.55 - 18 = 158.
    // Keep using 260 for historical stem geometry but anchor drawing above it.
    let groundY = 260.0

    let stage = snap.stage
    let stemP = snap.stemP
    let leafP = snap.leafP
    let budP = snap.budP
    let bloomP = snap.bloomP
    let care = max(0, min(1, snap.care))
    let cp = careParams(for: snap.careState)

    // ----- STAGE 0: SEED (buried / crack lines on soil) -----
    if stage == .seed || stage == .cracking {
        // Soil crack lines around seed
        for dx in [-10.0, 0.0, 8.0] {
            var crack = Path()
            crack.move(to: CGPoint(x: px(cx + dx - 4), y: py(groundY)))
            crack.addLine(to: CGPoint(x: px(cx + dx + 4), y: py(groundY + 1)))
            ctx.stroke(crack, with: .color(Color(hex: "#3F2A1C").opacity(0.3)), lineWidth: 0.8)
        }
        // Buried seed
        let seedRect = CGRect(
            x: px(cx - 6), y: py(groundY - 2),
            width: px(12), height: py(8)
        )
        ctx.fill(Path(ellipseIn: seedRect), with: .color(Color(hex: "#6B4226")))
        ctx.stroke(Path(ellipseIn: seedRect), with: .color(Color(hex: "#3F2610")), lineWidth: 0.8)
    }

    // ----- STAGE 1: CRACKING (seed splits, root emerges) -----
    if stage == .cracking {
        // Crack across the oval
        var split = Path()
        split.move(to: CGPoint(x: px(cx - 5), y: py(groundY)))
        split.addQuadCurve(
            to: CGPoint(x: px(cx + 5), y: py(groundY)),
            control: CGPoint(x: px(cx), y: py(groundY - 2))
        )
        ctx.stroke(split, with: .color(Color(hex: "#3F2610")), lineWidth: 1)

        // Root tip going down
        var root = Path()
        root.move(to: CGPoint(x: px(cx), y: py(groundY + 3)))
        root.addQuadCurve(
            to: CGPoint(x: px(cx - 1), y: py(groundY + 10)),
            control: CGPoint(x: px(cx - 2), y: py(groundY + 7))
        )
        ctx.stroke(root, with: .color(Color(hex: "#F5F0E8")), lineWidth: 1.2)

        // Small soil bump above seed
        let bumpRect = CGRect(
            x: px(cx - 8), y: py(groundY - 4),
            width: px(16), height: py(4)
        )
        ctx.fill(Path(ellipseIn: bumpRect), with: .color(Color(hex: "#5E4220").opacity(0.4)))
    }

    // ----- Above-ground stages begin at .sprout -----
    let aboveGround = stage.rawValue >= GrowthStage.sprout.rawValue

    // Stem geometry per-stage.
    struct StemSpec { let height: Double; let width: Double; let leanBase: Double }
    let spec: StemSpec = {
        switch stage {
        case .sprout:   return StemSpec(height: 22, width: 2.0, leanBase: 4)
        case .seedling: return StemSpec(height: 52, width: 3.0, leanBase: 7)
        case .growing:  return StemSpec(height: 92, width: 5.0, leanBase: 2)
        case .budding:  return StemSpec(height: 120, width: 5.0, leanBase: 2)
        case .opening:  return StemSpec(height: 140, width: 5.0, leanBase: 1)
        case .bloomed:  return StemSpec(height: 160, width: 5.5, leanBase: 1)
        case .thriving: return StemSpec(height: 162, width: 6.0, leanBase: 1)
        default:        return StemSpec(height: 0, width: 0, leanBase: 0)
        }
    }()

    let stemH = spec.height * max(0.6, stemP) // continuous interp for smoothness
    let stemW = spec.width
    // If dead/collapsed, stem lies down. Otherwise bend per care state plus tiny sway/lean.
    let bendDeg = cp.collapsed ? 85.0 : cp.bendDeg
    let leanSway: Double = {
        guard !reduceMotion else { return 0 }
        if stage == .sprout || stage == .seedling {
            return sin(t * 2.0 * .pi / 6.0) * spec.leanBase
        }
        if stage.rawValue >= GrowthStage.bloomed.rawValue && snap.careState == .healthy {
            return sin(t * 2.0 * .pi / 5.5) * 1.5
        }
        return 0
    }()
    let totalRot = bendDeg + leanSway

    let pivotX = px(cx)
    let pivotY = py(groundY)

    // ----- STAGE 2+: STEM -----
    if aboveGround && stemH > 0.1 {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            var stem = Path()
            let bx = cx
            let by = groundY
            let topY = groundY - stemH
            stem.move(to: CGPoint(x: px(bx - stemW / 2), y: py(by)))
            stem.addQuadCurve(
                to: CGPoint(x: px(bx - stemW / 3), y: py(topY + 2)),
                control: CGPoint(x: px(bx + (stage == .sprout ? 2 : 0)),
                                 y: py(by - stemH * 0.6))
            )
            stem.addLine(to: CGPoint(x: px(bx + stemW / 3), y: py(topY + 2)))
            stem.addQuadCurve(
                to: CGPoint(x: px(bx + stemW / 2), y: py(by)),
                control: CGPoint(x: px(bx + (stage == .sprout ? 2 : 0)),
                                 y: py(by - stemH * 0.6))
            )
            stem.closeSubpath()

            let stemBase = stage == .sprout ? "#7AB648" : "#5D8A3C"
            layer.fill(stem, with: .color(foliageColor(base: stemBase, cp: cp)))
        }
    }

    // ----- STAGE 2: SPROUT — cotyledon leaves -----
    if stage == .sprout {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            let topY = groundY - stemH
            let cotFill = foliageColor(base: "#A8D575", cp: cp)
            for side in [-1.0, 1.0] {
                layer.drawLayer { sub in
                    sub.translateBy(x: px(cx + side * 3), y: py(topY - 0.5))
                    sub.rotate(by: .degrees(side * 25))
                    let r = CGRect(x: px(-4), y: py(-2.5), width: px(8), height: py(5))
                    sub.fill(Path(ellipseIn: r), with: .color(cotFill))
                }
            }
        }
    }

    // ----- STAGE 3+: LEAVES -----
    if stage.rawValue >= GrowthStage.seedling.rawValue {
        // Lush scaling at thriving
        let leafScale: Double = stage == .thriving ? 1.1 : 1.0
        let leafLen: Double
        let leafCount: Int
        let leafFracs: [Double]
        let leafSides: [Double]

        switch stage {
        case .seedling:
            leafLen = 14 * leafScale
            leafCount = 2
            leafFracs = [0.55, 0.62]
            leafSides = [-1, 1]
        case .growing:
            leafLen = 20 * leafScale
            leafCount = 4
            leafFracs = [0.30, 0.45, 0.60, 0.75]
            leafSides = [-1, 1, -1, 1]
        case .budding:
            leafLen = 22 * leafScale
            leafCount = 5
            leafFracs = [0.28, 0.42, 0.54, 0.66, 0.78]
            leafSides = [-1, 1, -1, 1, -1]
        default: // .opening, .bloomed, .thriving
            leafLen = 24 * leafScale
            leafCount = 6
            leafFracs = [0.25, 0.38, 0.50, 0.62, 0.74, 0.82]
            leafSides = [-1, 1, -1, 1, -1, 1]
        }

        let leafFill = foliageColor(base: "#6B9E44", cp: cp)
        let leafEdge = foliageColor(base: "#3F6B50", cp: cp)

        for i in 0..<leafCount where leafP > 0.01 {
            let frac = leafFracs[i]
            let side = leafSides[i]
            let baseAngle = 28.0 + Double(i % 2) * 6
            let angle = side * baseAngle + (side * cp.droopDeg)

            let lx = cx
            let ly = groundY - stemH * frac

            ctx.drawLayer { layer in
                layer.translateBy(x: pivotX, y: pivotY)
                layer.rotate(by: .degrees(totalRot))
                layer.translateBy(x: -pivotX, y: -pivotY)

                let attachX = px(lx)
                let attachY = py(ly)
                layer.translateBy(x: attachX, y: attachY)
                layer.rotate(by: .degrees(angle))

                let len = leafLen
                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: 0))
                leaf.addQuadCurve(
                    to: CGPoint(x: px(len), y: 0),
                    control: CGPoint(x: px(len * 0.5), y: py(-len * 0.4))
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: 0, y: 0),
                    control: CGPoint(x: px(len * 0.5), y: py(len * 0.4))
                )
                leaf.closeSubpath()

                layer.fill(leaf, with: .color(leafFill))
                layer.stroke(leaf, with: .color(leafEdge), lineWidth: 0.7)
            }
        }
    }

    // Head base position (used by bud & bloom)
    let hxBase = cx
    let hyBase = groundY - stemH

    // ----- STAGE 5: BUDDING -----
    if stage == .budding && budP > 0.01 {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            let bx = hxBase
            let by = hyBase
            let rxD = 8.0
            let ryD = 11.0
            let rect = CGRect(
                x: px(bx - rxD), y: py(by - ryD),
                width: px(rxD * 2), height: py(ryD * 2)
            )
            let budFill = foliageColor(base: "#4A7A2E", cp: cp)
            layer.fill(Path(ellipseIn: rect), with: .color(budFill))
            layer.stroke(Path(ellipseIn: rect),
                         with: .color(foliageColor(base: "#3F6B50", cp: cp)),
                         lineWidth: 0.8)

            // Yellow tip hint at peak
            let tipRect = CGRect(
                x: px(bx - 3), y: py(by - ryD + 1),
                width: px(6), height: py(4)
            )
            layer.fill(Path(ellipseIn: tipRect),
                       with: .color(foliageColor(base: "#F5C842", cp: cp).opacity(0.85)))
        }
    }

    // ----- STAGE 6: OPENING -----
    if stage == .opening {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)
            layer.translateBy(x: px(hxBase), y: py(hyBase))
            layer.rotate(by: .degrees(cp.headDroop))

            // 5 half-length yellow petals peeking out
            let petalFill = foliageColor(base: "#F5C842", cp: cp)
            let petalCount = 5
            let petalLen = 14.0
            for i in 0..<petalCount {
                let a = (Double(i) / Double(petalCount)) * 360.0
                layer.drawLayer { sub in
                    sub.rotate(by: .degrees(a))
                    let rect = CGRect(
                        x: px(-3), y: py(-petalLen),
                        width: px(6), height: py(petalLen * 0.6)
                    )
                    sub.fill(Path(ellipseIn: rect), with: .color(petalFill))
                }
            }

            // Brown center visible through opening
            let centerR = 6.0
            let centerRect = CGRect(
                x: px(-centerR), y: py(-centerR),
                width: px(centerR * 2), height: py(centerR * 2)
            )
            layer.fill(Path(ellipseIn: centerRect),
                       with: .color(Color(hex: "#8B4513")))
        }
    }

    // ----- STAGE 7+: BLOOMED (full flower head) -----
    if stage.rawValue >= GrowthStage.bloomed.rawValue {
        let headR = stage == .thriving ? 32.0 : 30.0
        let headTilt = stage == .thriving ? -6.0 : -5.0

        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            // Head droop pivot at head base
            let droopPivotX = px(hxBase)
            let droopPivotY = py(hyBase + 2)
            layer.translateBy(x: droopPivotX, y: droopPivotY)
            layer.rotate(by: .degrees(cp.headDroop + headTilt))
            layer.translateBy(x: -droopPivotX, y: -droopPivotY)

            // Thriving: golden glow behind head
            if stage == .thriving && snap.careState == .healthy {
                let glowR = headR * 1.5
                let glowRect = CGRect(
                    x: px(hxBase - glowR), y: py(hyBase - glowR),
                    width: px(glowR * 2), height: py(glowR * 2)
                )
                let glowShading = GraphicsContext.Shading.radialGradient(
                    Gradient(colors: [
                        Color(hex: "#F5C842").opacity(0.30),
                        Color(hex: "#F5C842").opacity(0.0)
                    ]),
                    center: CGPoint(x: px(hxBase), y: py(hyBase)),
                    startRadius: 0,
                    endRadius: px(glowR)
                )
                layer.fill(Path(ellipseIn: glowRect), with: glowShading)
            }

            // 12 gold petals
            let petalFill = foliageColor(base: "#F5C842", cp: cp)
            let petalEdge = foliageColor(base: "#D49020", cp: cp)
            for i in 0..<12 {
                let a = (Double(i) / 12.0) * 360.0
                let rad = (a - 90) * .pi / 180
                let pxd = hxBase + cos(rad) * headR * 0.55
                let pyd = hyBase + sin(rad) * headR * 0.55
                let petalRX = headR * 0.95 * 0.75
                let petalRY = headR * 0.95 * 0.32

                // Care-driven per-petal offset at struggling+
                let offsetRot = snap.careState == .struggling && (i == 2 || i == 7)
                    ? 8.0 : 0.0

                layer.drawLayer { sub in
                    sub.translateBy(x: px(pxd), y: py(pyd))
                    sub.rotate(by: .degrees(a + offsetRot))
                    let rect = CGRect(
                        x: px(-petalRX / 2), y: py(-petalRY / 2),
                        width: px(petalRX), height: py(petalRY)
                    )
                    sub.fill(Path(ellipseIn: rect), with: .color(petalFill))
                    sub.stroke(Path(ellipseIn: rect), with: .color(petalEdge), lineWidth: 0.7)
                }
            }

            // Center disk
            let centerR = headR * 0.42
            let centerRect = CGRect(
                x: px(hxBase - centerR), y: py(hyBase - centerR),
                width: px(centerR * 2), height: py(centerR * 2)
            )
            let centerGradient = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Color(hex: "#9C5A2A"), Color(hex: "#8B4513")]),
                center: CGPoint(x: px(hxBase), y: py(hyBase)),
                startRadius: 0,
                endRadius: px(centerR)
            )
            layer.fill(Path(ellipseIn: centerRect), with: centerGradient)
            layer.stroke(Path(ellipseIn: centerRect),
                         with: .color(Color(hex: "#4A2810")), lineWidth: 1)

            // Phyllotaxis seed dots
            let pts = phyllotaxis(count: 20, scale: headR * 0.38)
            for p in pts {
                let dotRect = CGRect(
                    x: px(hxBase + p.x - 0.6), y: py(hyBase + p.y - 0.6),
                    width: px(1.2), height: py(1.2)
                )
                layer.fill(Path(ellipseIn: dotRect),
                           with: .color(Color(hex: "#3F2610")))
            }
        }
    }

    // ----- STAGE 8: THRIVING — side bud on a branch -----
    if stage == .thriving {
        ctx.drawLayer { layer in
            layer.translateBy(x: pivotX, y: pivotY)
            layer.rotate(by: .degrees(totalRot))
            layer.translateBy(x: -pivotX, y: -pivotY)

            // Branch
            let branchStartY = groundY - stemH * 0.6
            var branch = Path()
            branch.move(to: CGPoint(x: px(cx + 2), y: py(branchStartY)))
            branch.addQuadCurve(
                to: CGPoint(x: px(cx + 28), y: py(branchStartY - 18)),
                control: CGPoint(x: px(cx + 18), y: py(branchStartY - 4))
            )
            layer.stroke(branch,
                         with: .color(foliageColor(base: "#5D8A3C", cp: cp)),
                         lineWidth: 3)

            // Secondary bud
            let bbx = cx + 28.0
            let bby = branchStartY - 18.0
            let budRect = CGRect(
                x: px(bbx - 5), y: py(bby - 7),
                width: px(10), height: py(14)
            )
            layer.fill(Path(ellipseIn: budRect),
                       with: .color(foliageColor(base: "#4A7A2E", cp: cp)))
            // Yellow peeking
            let tipRect = CGRect(
                x: px(bbx - 2.5), y: py(bby - 6),
                width: px(5), height: py(3)
            )
            layer.fill(Path(ellipseIn: tipRect),
                       with: .color(foliageColor(base: "#F5C842", cp: cp)))
        }
    }

    // ----- Fallen petals (care-driven) -----
    if cp.fallenPetals > 0 {
        let fallColor = mixHex("#F5C842", "#C4A35A", cp.leafYellow * 0.5)
        // Deterministic pseudo-random placement
        let baseSeeds: [(Double, Double, Double)] = [
            (-32, 6, 15), (26, 4, -22), (-14, 9, 40), (8, 12, -10),
            (-42, 3, 55), (38, 7, 70), (-6, 14, -45), (18, 11, 25),
            (-22, 15, 85), (30, 13, -55)
        ]
        for i in 0..<min(cp.fallenPetals, baseSeeds.count) {
            let (dx, dy, rot) = baseSeeds[i]
            let fx = cx + dx
            let fy = groundY + dy - 4
            ctx.drawLayer { layer in
                layer.translateBy(x: px(fx), y: py(fy))
                layer.rotate(by: .degrees(rot))
                let r = CGRect(
                    x: px(-5), y: py(-2.2),
                    width: px(10), height: py(4.4)
                )
                layer.fill(Path(ellipseIn: r), with: .color(fallColor))
            }
        }
    }

    // ----- DEAD extras: dry cracks, label, fresh seed for restart -----
    if snap.careState == .dead {
        // Dry cracked soil lines
        for i in 0..<4 {
            let offset = Double(i) * 18 - 30
            var crack = Path()
            crack.move(to: CGPoint(x: px(cx + offset), y: py(groundY + 4)))
            crack.addLine(to: CGPoint(x: px(cx + offset + 6), y: py(groundY + 8)))
            crack.addLine(to: CGPoint(x: px(cx + offset + 2), y: py(groundY + 12)))
            ctx.stroke(crack, with: .color(Color(hex: "#3F2A1C").opacity(0.5)), lineWidth: 0.8)
        }
        // Label "dead" — use a system font here because DinoTheme.dinoFont is
        // main-actor isolated and Canvas drawing closures are nonisolated.
        let deadText = Text("dead")
            .font(.system(size: 10, weight: .regular, design: .rounded))
            .foregroundColor(Color(hex: "#9C7C50"))
        ctx.draw(deadText, at: CGPoint(x: px(cx - 20), y: py(groundY + 20)))

        // Fresh seed next to fallen plant (cycle restart)
        let freshRect = CGRect(
            x: px(cx + 24), y: py(groundY - 1),
            width: px(8), height: py(5)
        )
        ctx.fill(Path(ellipseIn: freshRect),
                 with: .color(Color(hex: "#6B4226")))
        ctx.stroke(Path(ellipseIn: freshRect),
                   with: .color(Color(hex: "#3F2610")), lineWidth: 0.7)
    }

    _ = appearScale
    _ = care
    _ = stemP
    _ = leafP
    _ = budP
    _ = bloomP
}

// MARK: - Background rendering

private func drawBackground(
    ctx: inout GraphicsContext,
    size: CGSize,
    scene: GardenScene,
    t: TimeInterval,
    reduceMotion: Bool
) {
    let w = size.width
    let h = size.height

    // 1. Sky gradient (top 55%)
    let skyRect = CGRect(x: 0, y: 0, width: w, height: h * 0.55)
    let skyColors: [Color]
    switch scene {
    case .morning:   skyColors = [Color(hex: "#FFE4B5"), Color(hex: "#87CEEB")]
    case .afternoon: skyColors = [Color(hex: "#8DC9EC"), Color(hex: "#B8D9E8"), Color(hex: "#E6F1EC")]
    case .evening:   skyColors = [Color(hex: "#FF9A5C"), Color(hex: "#FF6B6B"), Color(hex: "#6B4FA0")]
    case .night:     skyColors = [Color(hex: "#1A1A2E"), Color(hex: "#16213E")]
    case .rainy:     skyColors = [Color(hex: "#6B7280"), Color(hex: "#4A5568")]
    case .cloudy:    skyColors = [Color(hex: "#9CA3AF"), Color(hex: "#D1D5DB")]
    }
    let skyShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: skyColors),
        startPoint: CGPoint(x: w / 2, y: 0),
        endPoint: CGPoint(x: w / 2, y: h * 0.55)
    )
    ctx.fill(Path(skyRect), with: skyShading)

    // 2. Celestial
    switch scene {
    case .morning, .afternoon:
        let sunCenter = CGPoint(x: w * 0.78, y: h * 0.18)
        let r: CGFloat = 22
        ctx.drawLayer { layer in
            layer.translateBy(x: sunCenter.x, y: sunCenter.y)
            layer.rotate(by: .radians(t * 0.05))
            for i in 0..<8 {
                let a = Double(i) * (.pi / 4)
                var ray = Path()
                ray.move(to: CGPoint(x: cos(a) * (r + 4), y: sin(a) * (r + 4)))
                ray.addLine(to: CGPoint(x: cos(a) * (r + 14), y: sin(a) * (r + 14)))
                layer.stroke(ray, with: .color(Color(hex: "#F5D28A").opacity(0.75)), lineWidth: 2.5)
            }
        }
        let sunRect = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: sunRect), with: .color(Color(hex: "#F5D28A")))
        ctx.stroke(Path(ellipseIn: sunRect), with: .color(Color(hex: "#D4A55A")), lineWidth: 1)

    case .evening:
        let sunCenter = CGPoint(x: w * 0.80, y: h * 0.30)
        let r: CGFloat = 18
        let sunRect = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: sunRect), with: .color(Color(hex: "#FFCF7A")))
        ctx.stroke(Path(ellipseIn: sunRect), with: .color(Color(hex: "#D4884A")), lineWidth: 1)

    case .night:
        let moonCenter = CGPoint(x: w * 0.78, y: h * 0.18)
        let r: CGFloat = 18
        let moonRect = CGRect(x: moonCenter.x - r, y: moonCenter.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: moonRect), with: .color(Color(hex: "#F5F0D8")))
        ctx.stroke(Path(ellipseIn: moonRect), with: .color(Color(hex: "#BFB88E")), lineWidth: 1)
        let craters: [(Double, Double, Double)] = [(-4, -3, 2), (3, 1, 1.5), (-2, 4, 1.2)]
        for (dx, dy, cr) in craters {
            let cRect = CGRect(
                x: moonCenter.x + dx - cr, y: moonCenter.y + dy - cr,
                width: cr * 2, height: cr * 2
            )
            ctx.fill(Path(ellipseIn: cRect), with: .color(Color(hex: "#BFB88E").opacity(0.5)))
        }

    case .rainy, .cloudy:
        break
    }

    // 3. Stars (night)
    if scene == .night {
        let stars: [(Double, Double, Double, Double)] = [
            (0.08, 0.10, 3.1, 0.0),
            (0.15, 0.18, 2.4, 0.8),
            (0.22, 0.08, 2.9, 1.6),
            (0.30, 0.22, 3.3, 2.4),
            (0.37, 0.14, 2.6, 0.4),
            (0.44, 0.30, 2.8, 1.2),
            (0.50, 0.06, 3.0, 0.2),
            (0.58, 0.24, 2.5, 2.0),
            (0.62, 0.12, 3.2, 0.9),
            (0.70, 0.28, 2.7, 1.8),
            (0.13, 0.32, 3.4, 2.6),
            (0.27, 0.38, 2.3, 0.1),
            (0.42, 0.40, 2.9, 1.5),
            (0.55, 0.36, 3.1, 2.2),
            (0.68, 0.40, 2.4, 0.7),
            (0.82, 0.10, 2.8, 1.4),
            (0.88, 0.24, 3.0, 2.8),
            (0.92, 0.36, 2.5, 0.5),
            (0.05, 0.22, 2.6, 1.1),
            (0.19, 0.26, 3.0, 1.9)
        ]
        let count = reduceMotion ? 10 : 20
        for i in 0..<min(count, stars.count) {
            let (fx, fy, period, phase) = stars[i]
            let alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 2 * .pi / period + phase))
            let r: CGFloat = 1.2
            let rect = CGRect(x: w * fx - r, y: h * fy - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(Color(hex: "#F5F0D8").opacity(alpha)))
        }
    }

    // 4. Clouds (morning / afternoon / cloudy)
    if scene == .morning || scene == .afternoon || scene == .cloudy {
        // y fractions of sky height (h * 0.55)
        let cloudSpecs: [(Double, Double, Double, Double, Double)] = [
            // (yFracOfSky, driftDur, bobPeriod, scale, phase)
            (0.15, 60.0,  8.0, 1.0, 0.0),
            (0.32, 90.0, 10.0, 0.85, 2.1),
            (0.22, 75.0, 12.0, 1.15, 4.7)
        ]
        let skyHeight = h * 0.55
        let travelSpan = w + 200
        for (fy, driftDur, bobPeriod, scale, phase) in cloudSpecs {
            let baseY = skyHeight * fy
            let x: Double
            let bobY: Double
            if reduceMotion {
                // Static positions (use phase to spread them)
                x = Double(travelSpan) * ((phase / 6.28).truncatingRemainder(dividingBy: 1.0)) - 100
                bobY = 0
            } else {
                let drift = ((t + phase * 5) / driftDur).truncatingRemainder(dividingBy: 1.0)
                x = drift * Double(travelSpan) - 100
                bobY = sin((t + phase) * 2 * .pi / bobPeriod) * 4
            }
            let opacity: Double
            let breathScale: Double
            if reduceMotion {
                opacity = 0.92
                breathScale = scale
            } else {
                opacity = 0.85 + 0.15 * (0.5 + 0.5 * sin((t + phase) * 2 * .pi / 6))
                breathScale = scale * (1.0 + 0.03 * sin((t + phase) * 2 * .pi / 10))
            }
            drawCloud(
                ctx: &ctx,
                center: CGPoint(x: CGFloat(x), y: CGFloat(baseY + bobY)),
                scale: breathScale,
                opacity: opacity
            )
        }
    }

    // 5. Rain
    if scene == .rainy {
        let dropCount = reduceMotion ? 60 : 120
        for i in 0..<dropCount {
            let seed = Double(i) * 17.31
            let fx = (sin(seed) * 0.5 + 0.5)
            let phase = (cos(seed * 0.7) * 0.5 + 0.5) * h
            let speed = 180.0 + (sin(seed * 1.3) * 0.5 + 0.5) * 120.0
            let y = (t * speed + phase).truncatingRemainder(dividingBy: Double(h))
            let x = Double(w) * fx
            var drop = Path()
            let dx = 2.0
            let dy = 10.0
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x + dx, y: y + dy))
            ctx.stroke(drop, with: .color(Color(hex: "#B8CFDA").opacity(0.6)), lineWidth: 1)
        }
    }

    // 8. Soil (bottom 45% → y = h*0.55 to h)
    let soilRect = CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45)
    let soilTop: Color
    let soilBottom: Color
    switch scene {
    case .night:
        soilTop = Color(hex: "#6B4A30")
        soilBottom = Color(hex: "#3A2818")
    default:
        soilTop = Color(hex: "#9A7550")
        soilBottom = Color(hex: "#5E4220")
    }
    let soilShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [soilTop, soilBottom]),
        startPoint: CGPoint(x: w / 2, y: h * 0.55),
        endPoint: CGPoint(x: w / 2, y: h)
    )
    ctx.fill(Path(soilRect), with: soilShading)

    // Speckles
    let speckles: [(Double, Double)] = [
        (0.08, 0.70), (0.18, 0.82), (0.26, 0.74), (0.34, 0.88),
        (0.46, 0.78), (0.55, 0.86), (0.62, 0.72), (0.72, 0.80),
        (0.83, 0.84), (0.91, 0.76)
    ]
    for (fx, fy) in speckles {
        let r: CGFloat = 1.2
        let rect = CGRect(x: w * fx - r, y: h * fy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#3F2A1C").opacity(0.35)))
    }

    // 9. Grass strip (18pt tall, just above soil)
    // NOTE: Draw grass BEFORE sprout so sprout (drawn later in drawSunflower)
    // appears in front. Canvas draws later operations on top.
    let grassTop = h * 0.55 - 18
    let grassRect = CGRect(x: 0, y: grassTop, width: w, height: 18)
    let grassShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [Color(hex: "#A8C5A0"), Color(hex: "#7BA872")]),
        startPoint: CGPoint(x: w / 2, y: grassTop),
        endPoint: CGPoint(x: w / 2, y: h * 0.55)
    )
    ctx.fill(Path(grassRect), with: grassShading)

    let tuftCount = 11
    for i in 0..<tuftCount {
        let fx = (Double(i) + 0.5) / Double(tuftCount)
        let x = w * CGFloat(fx)
        var tuft = Path()
        tuft.move(to: CGPoint(x: x - 3, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x, y: grassTop + 4))
        tuft.move(to: CGPoint(x: x, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x + 2, y: grassTop + 6))
        tuft.move(to: CGPoint(x: x + 3, y: h * 0.55 - 1))
        tuft.addLine(to: CGPoint(x: x + 5, y: grassTop + 4))
        ctx.stroke(tuft, with: .color(Color(hex: "#4A8A5C")), lineWidth: 1.5)
    }

    // 6. Fireflies (night)
    if scene == .night {
        let count = reduceMotion ? 4 : 8
        let firefliesBase: [(Double, Double, Double, Double, Double)] = [
            (0.40, 0.45, 2.0, 1.8, 0.0),
            (0.55, 0.50, 2.4, 2.1, 0.7),
            (0.48, 0.55, 1.8, 2.5, 1.3),
            (0.60, 0.42, 2.2, 2.0, 0.4),
            (0.45, 0.62, 2.6, 1.9, 1.1),
            (0.62, 0.58, 2.0, 2.3, 0.9),
            (0.50, 0.40, 2.3, 2.6, 1.6),
            (0.58, 0.52, 2.5, 2.2, 0.2)
        ]
        for i in 0..<min(count, firefliesBase.count) {
            let (fx, fy, p1, p2, phase) = firefliesBase[i]
            let bx = w * fx
            let by = h * fy
            let x = bx + 8 * sin(t * 2 * .pi / p1 + phase)
            let y = by + 6 * cos(t * 2 * .pi / p2 + phase)
            let pulse = 0.2 + 0.8 * (0.5 + 0.5 * sin(t * 2 * .pi / 2.3 + phase))
            let outerRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
            let innerRect = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
            ctx.fill(Path(ellipseIn: outerRect),
                     with: .color(Color(hex: "#FFEB8F").opacity(0.3 * pulse)))
            ctx.fill(Path(ellipseIn: innerRect),
                     with: .color(Color(hex: "#FFEB8F").opacity(pulse)))
        }
    }
}

// MARK: - Cloud helper (layered quad-curve puff with soft shadow)

private func drawCloud(
    ctx: inout GraphicsContext,
    center: CGPoint,
    scale: Double,
    opacity: Double
) {
    let s = CGFloat(scale)
    let cx = center.x
    let cy = center.y

    // Soft shadow below
    var shadow = Path()
    shadow.addEllipse(in: CGRect(
        x: cx - 40 * s,
        y: cy + 12 * s,
        width: 80 * s,
        height: 8 * s
    ))
    ctx.fill(shadow, with: .color(Color(hex: "#E8E0D0").opacity(0.35 * opacity)))

    // Cloud body — 4 overlapping bumps with flat bottom
    var cloud = Path()
    let baseY = cy + 10 * s
    cloud.move(to: CGPoint(x: cx - 35 * s, y: baseY))
    cloud.addQuadCurve(
        to: CGPoint(x: cx - 20 * s, y: cy - 14 * s),
        control: CGPoint(x: cx - 40 * s, y: cy - 8 * s)
    )
    cloud.addQuadCurve(
        to: CGPoint(x: cx - 5 * s, y: cy - 18 * s),
        control: CGPoint(x: cx - 18 * s, y: cy - 22 * s)
    )
    cloud.addQuadCurve(
        to: CGPoint(x: cx + 18 * s, y: cy - 16 * s),
        control: CGPoint(x: cx + 8 * s, y: cy - 26 * s)
    )
    cloud.addQuadCurve(
        to: CGPoint(x: cx + 35 * s, y: baseY),
        control: CGPoint(x: cx + 38 * s, y: cy - 4 * s)
    )
    cloud.addLine(to: CGPoint(x: cx - 35 * s, y: baseY))
    cloud.closeSubpath()

    ctx.fill(cloud, with: .color(Color.white.opacity(opacity)))
}

// MARK: - StatusLine

private struct StatusLine: View {
    @ObservedObject var vm: GrowthViewModel
    var letterWaiting: Bool = false
    var letterLeftForLater: Bool = false

    var body: some View {
        let isHealthy = vm.careState == .healthy
        let messageColor: Color = isHealthy
            ? Color(hex: "#2D3142")
            : Color(hex: "#A05030")

        return VStack(spacing: 6) {
            Text(vm.statusMessage)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(messageColor)
                .multilineTextAlignment(.center)
            Text("\(vm.growthPercent)% GROWN")
                .font(DinoTheme.dinoFont(size: 10))
                .tracking(1)
                .foregroundColor(Color(hex: "#6B7280"))
            if letterWaiting {
                Text("your letter arrives with the morning 🌅")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .padding(.top, 2)
            } else if letterLeftForLater {
                Text("she left your letter for later 🌿")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PracticePillsRow

private struct PracticePillsRow: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PracticePill(
                    label: "journal",
                    count: vm.journalSessionCount,
                    dotColor: Color(hex: "#F5C842"),
                    usedToday: vm.usedJournalToday
                )
                PracticePill(
                    label: "mood",
                    count: vm.moodSessionCount,
                    dotColor: Color(hex: "#E8A0A8"),
                    usedToday: vm.usedMoodToday
                )
                PracticePill(
                    label: "gratitude",
                    count: vm.gratitudeSessionCount,
                    dotColor: Color(hex: "#C4A35A"),
                    usedToday: vm.usedGratitudeToday
                )
                PracticePill(
                    label: "breathing",
                    count: vm.breathingSessionCount,
                    dotColor: Color(hex: "#A594C4"),
                    usedToday: vm.usedBreathingToday
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct PracticePill: View {
    let label: String
    let count: Int
    let dotColor: Color
    let usedToday: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(Color(hex: "#2D3142"))
            Text("\(count)")
                .font(DinoTheme.numericFont(size: 13))
                .foregroundColor(Color(hex: "#2D3142"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(usedToday ? dotColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            Capsule().stroke(usedToday ? dotColor : Color(hex: "#6B7280").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - WeeklyBloomLog

private struct WeeklyBloomLog: View {
    let blooms: [DayBloom]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("this week")
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(Color(hex: "#2D3142"))
            HStack(spacing: 0) {
                ForEach(Array(blooms.enumerated()), id: \.offset) { index, day in
                    WeekDayColumn(
                        label: day.dayLabel,
                        practices: day.practices,
                        appearDelay: Double(index) * 0.08
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct WeekDayColumn: View {
    let label: String
    let practices: Set<PracticeType>
    let appearDelay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#6B7280"))
                .tracking(0.8)
            VStack(spacing: 3) {
                ForEach(PracticeType.allCases) { p in
                    Circle()
                        .fill(practices.contains(p) ? p.bloomColor : Color(hex: "#E8E4D5"))
                        .frame(width: 6, height: 6)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - XPCard

private struct XPCard: View {
    @ObservedObject var vm: GrowthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.levelLabel)
                    .font(DinoTheme.titleFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text(vm.xpLabel)
                    .font(DinoTheme.numericFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color(hex: "#E8E4D5"))
                    RoundedRectangle(cornerRadius: 999)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#A8C5A0"), Color(hex: "#A8D4E6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(12, geo.size.width * vm.xpProgress))
                }
            }
            .frame(height: 12)
        }
        .padding(20)
        .background(DinoTheme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DinoTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: DinoTheme.shadowColor, radius: 12, x: 0, y: 4)
    }
}
