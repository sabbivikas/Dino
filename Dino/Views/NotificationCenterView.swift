//
//  NotificationCenterView.swift
//  Dino
//
//  Pixel-faithful port of the v8 “Letters from Dino” design (V6_Letters).
//  Source: /tmp/dino_design_v8/notifications/notifications.jsx
//

import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotificationStore.shared
    @State private var filter: FilterOption = .all
    @State private var hasAppeared = false
    @State private var showClearConfirm = false

    // ── Spec colors (exact, from notifications.jsx) ─────────────────────
    private let pageBG       = Color(hex: "#FAF6EC")
    private let titleInk     = Color(hex: "#2E2A24")
    private let dateInk      = Color(hex: "#9A9085")
    private let mutedInk     = Color(hex: "#857C70")
    private let veryMutedInk = Color(hex: "#B8B0A4")
    private let pillActiveBG = Color(hex: "#3D3A35")
    private let pillInactiveText = Color(hex: "#7A7266")
    private let pillBorder   = Color(red: 60/255, green: 55/255, blue: 50/255, opacity: 0.16)
    private let emptyTitle   = Color(hex: "#857C70")
    private let emptySub     = Color(hex: "#A8A29A")

    // ── Filter options ─────────────────────────────────────────────────
    enum FilterOption: String, CaseIterable, Identifiable {
        case all, growth, world, creative, dino
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "all"
            case .growth: return "growth"
            case .world: return "world"
            case .creative: return "creative"
            case .dino: return "dino says"
            }
        }
        var category: DinoNotificationCategory? {
            switch self {
            case .all: return nil
            case .growth: return .growth
            case .world: return .world
            case .creative: return .creative
            case .dino: return .dinoSays
            }
        }
    }

    var body: some View {
        ZStack {
            pageBG.ignoresSafeArea()
            PaperGrain().ignoresSafeArea().allowsHitTesting(false).opacity(0.05)

            VStack(spacing: 0) {
                header
                pills

                if filtered.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                hasAppeared = true
            }
        }
        .alert("clear all notifications?", isPresented: $showClearConfirm) {
            Button("cancel", role: .cancel) { }
            Button("clear", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    store.clearAll()
                }
            }
        } message: {
            Text("this can't be undone.")
        }
    }

    // MARK: - Header — “from dino” + date + “mark all read”
    // Spec: padding 14px 22px 6px, fontSize 28 dino, date 12 italic Georgia, button 11 rounded
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("from dino")
                    .font(.custom(DinoTheme.customFontName, size: 28))
                    .foregroundColor(titleInk)
                    .lineSpacing(0)
                Text(formattedDate())
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(dateInk)
                    .tracking(0.12)
            }
            Spacer()
            HStack(spacing: 14) {
                if store.unreadCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.markAllRead() }
                    } label: {
                        Text("mark all read")
                            .font(.system(size: 11))
                            .tracking(0.44)
                            .foregroundColor(dateInk)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                if !store.notifications.isEmpty {
                    Button { showClearConfirm = true } label: {
                        Text("clear all")
                            .font(.system(size: 11))
                            .tracking(0.44)
                            .foregroundColor(dateInk)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            // Back chevron — present in app context, not in design (which is in a phone shell).
            // Provide a tiny back affordance below the title for navigation.
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(dateInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -2)
            .opacity(0.6)
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date()).lowercased()
    }

    // MARK: - Pills — horizontally scrollable filter row
    // Spec: padding 12px 22px 10px, gap 8, pill padding 7px 14px, fontSize 14 dino, radius 999
    private var pills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases) { opt in
                    pillButton(opt)
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func pillButton(_ opt: FilterOption) -> some View {
        let active = filter == opt
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { filter = opt }
        } label: {
            Text(opt.label)
                .font(.custom(DinoTheme.customFontName, size: 14))
                .tracking(0.14)
                .foregroundColor(active ? pageBG : pillInactiveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(active ? pillActiveBG : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(active ? pillActiveBG : pillBorder, lineWidth: 1)
                )
                .fixedSize()
        }
        .buttonStyle(.plain)
    }

    // MARK: - List
    // Spec: padding 8px 18px 24px, gap 12, animation letter-in 420ms staggered
    private var filtered: [DinoNotification] {
        guard let cat = filter.category else { return store.notifications }
        return store.notifications.filter { $0.category == cat }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, note in
                    LetterCard(
                        note: note,
                        rotate: stableRotation(for: note.id),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.18)) { store.markRead(note.id) }
                        },
                        onDelete: {
                            withAnimation { store.delete(note.id) }
                        }
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 8)
                    .animation(
                        .timingCurve(0.2, 0.7, 0.2, 1.05, duration: 0.42)
                            .delay(Double(min(index, 12)) * 0.06),
                        value: hasAppeared
                    )
                }
                // signed-off footer
                Text("— end of letters —")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundColor(veryMutedInk)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func stableRotation(for id: UUID) -> Double {
        // deterministic -0.5..0.5 deg per id
        var h: Int = 0
        for ch in id.uuidString.utf8 { h = h &* 31 &+ Int(ch) }
        let mod = abs(h) % 100
        return Double(mod) / 100.0 - 0.5
    }

    // MARK: - Empty state
    // Spec: title 22 dino #857C70, sub 13 italic Georgia #A8A29A maxWidth 240
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("all quiet here")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(emptyTitle)
            Text("dino will write when something's worth saying.")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(emptySub)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - LetterCard
//
// Spec breakdown (LetterCard):
//   border-radius: 3
//   padding: 14px 100px 14px 18px  (right reserved for stamp area)
//   minHeight: 96
//   bg: cardUnread (per-category) when unread, #FFFFFF when read
//   shadow unread: 0 1 2 rgba(60,40,20,.04), 0 6 18 rgba(60,40,20,.10)
//   shadow read:   0 1 2 rgba(60,40,20,.03), 0 3 10 rgba(60,40,20,.05)
//   address line: 10pt dino, color #B8B0A4 ("to: you · from: dino")
//   title: 17pt dino, #2E2A24 unread / #5A544B read
//   body: 12pt italic Georgia, #857C70
//   timestamp: 9.5pt rounded, #B8B0A4
//   airmail border (dino category): repeating 45deg red/blue stripes
//
private struct LetterCard: View {
    let note: DinoNotification
    let rotate: Double
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var dx: CGFloat = 0
    @GestureState private var dragX: CGFloat = 0

    var body: some View {
        let cat = LettersCat.from(note.category)
        let unread = !note.isRead
        let cardBG: Color = unread ? cat.cardUnread : DinoTheme.cardBackground
        let titleColor: Color = unread ? Color(hex: "#2E2A24") : Color(hex: "#5A544B")
        let isAirmail = note.category == .dinoSays

        return ZStack(alignment: .trailing) {
            // delete reveal (revealed when swiped left)
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color(hex: "#E89B95")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .opacity((dx + dragX) < -10 ? 1 : 0)
                .overlay(alignment: .trailing) {
                    Text("remove")
                        .font(.custom(DinoTheme.customFontName, size: 14))
                        .foregroundColor(.white)
                        .padding(.trailing, 22)
                }
                .animation(.easeOut(duration: 0.12), value: dx + dragX)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    // address line
                    addressLine(cat: cat)
                        .padding(.bottom, 4)

                    // title
                    Text(stripEmoji(note.title))
                        .font(.custom(DinoTheme.customFontName, size: 17))
                        .lineSpacing(17 * 0.25)
                        .foregroundColor(titleColor)
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                        .fixedSize(horizontal: false, vertical: true)

                    // body
                    Text(stripEmoji(note.subtitle))
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundColor(Color(hex: "#857C70"))
                        .lineSpacing(12 * 0.45)
                        .fixedSize(horizontal: false, vertical: true)

                    // timestamp
                    Text(relativeTimeString(note.timestamp))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .tracking(0.57) // 0.06em
                        .foregroundColor(Color(hex: "#B8B0A4"))
                        .padding(.top, 6)
                }
                .padding(.top, 14)
                .padding(.bottom, 14)
                .padding(.leading, 18)
                .padding(.trailing, 100) // reserved for postage stamp area
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 96, alignment: .topLeading)

                // postage stamp
                PostageStamp(category: note.category, unread: unread)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(cardBG)
                    if isAirmail {
                        // airmail par-avion border (red+blue diagonal stripes)
                        AirmailBorder()
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(
                color: Color(red: 60/255, green: 40/255, blue: 20/255, opacity: unread ? 0.04 : 0.03),
                radius: 1, x: 0, y: 1
            )
            .shadow(
                color: Color(red: 60/255, green: 40/255, blue: 20/255, opacity: unread ? 0.10 : 0.05),
                radius: unread ? 9 : 5, x: 0, y: unread ? 6 : 3
            )
            .rotationEffect(.degrees(rotate))
            .offset(x: dx + dragX)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragX) { value, state, _ in
                        state = max(value.translation.width, -120)
                            .clamped(min: -120, max: 0)
                    }
                    .onEnded { value in
                        if value.translation.width < -80 {
                            withAnimation(.easeOut(duration: 0.16)) { dx = -400 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onDelete() }
                        } else {
                            withAnimation(.timingCurve(0.2, 0.7, 0.2, 1.1, duration: 0.26)) { dx = 0 }
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func addressLine(cat: LettersCat) -> some View {
        HStack(spacing: 0) {
            Text("to: ")
                .foregroundColor(Color(hex: "#B8B0A4"))
            Text("you")
                .foregroundColor(Color(hex: "#857C70"))
            Text("  ·  ")
                .foregroundColor(Color(hex: "#B8B0A4").opacity(0.5))
            Text("from: ")
                .foregroundColor(Color(hex: "#B8B0A4"))
            Text("dino")
                .foregroundColor(cat.deep)
        }
        .font(.custom(DinoTheme.customFontName, size: 10))
        .tracking(0.4) // 0.04em
    }

    private func relativeTimeString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        if abs(Date().timeIntervalSince(date)) < 60 { return "just now" }
        return f.localizedString(for: date, relativeTo: Date()).lowercased()
    }
}

// MARK: - LettersCat (per-category palette from spec LETTERS_CAT)
private struct LettersCat {
    let stripe: Color
    let deep: Color
    let cardUnread: Color

    static func from(_ c: DinoNotificationCategory) -> LettersCat {
        switch c {
        case .growth:
            return LettersCat(stripe: Color(hex: "#A8C5A0"), deep: Color(hex: "#5C7E54"), cardUnread: Color(hex: "#F4F8EE"))
        case .world:
            return LettersCat(stripe: Color(hex: "#A8C0D8"), deep: Color(hex: "#4F7B9C"), cardUnread: Color(hex: "#F0F4FA"))
        case .creative:
            return LettersCat(stripe: Color(hex: "#BAA9DB"), deep: Color(hex: "#6E5DA0"), cardUnread: Color(hex: "#F4EFFA"))
        case .dinoSays:
            return LettersCat(stripe: Color(hex: "#F5C4A8"), deep: Color(hex: "#A06848"), cardUnread: Color(hex: "#FFF6EE"))
        }
    }
}

// MARK: - PostageStamp
//
// Spec: 56pt square at top:8 right:8, perforated edge, inner border, glyph, denomination text.
// We render a simplified version — colored stamp face with thin inner border, glyph, and
// a subtle perforation outline. Postmark overlay only when unread.
private struct PostageStamp: View {
    let category: DinoNotificationCategory
    let unread: Bool

    private let stampSize: CGFloat = 56

    var body: some View {
        let cat = LettersCat.from(category)
        let rotation: Double = {
            switch category {
            case .dinoSays: return 4
            case .creative: return -3
            case .world:    return 2
            case .growth:   return -2
            }
        }()

        ZStack(alignment: .topTrailing) {
            // stamp face
            ZStack {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(cat.cardUnread)
                // perforation effect using stroke of dashed outline
                RoundedRectangle(cornerRadius: 0.5)
                    .strokeBorder(
                        cat.cardUnread,
                        style: StrokeStyle(lineWidth: 2, lineCap: .butt, dash: [2, 2.4])
                    )
                    .blendMode(.destinationOut)
                // inner border
                RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(cat.deep.opacity(0.45), lineWidth: 1)
                    .padding(6)
                // glyph
                StampGlyph(category: category, color: cat.deep, fillColor: cat.stripe)
                    .frame(width: stampSize - 14, height: stampSize - 14)
                    .padding(7)
                // denomination corner text
                VStack {
                    Spacer()
                    HStack {
                        Text("5¢")
                            .font(.custom("Georgia", size: 6))
                            .foregroundColor(cat.deep.opacity(0.7))
                        Spacer()
                        Text("dino")
                            .font(.custom("Georgia", size: 5))
                            .foregroundColor(cat.deep.opacity(0.55))
                    }
                }
                .padding(4)
            }
            .frame(width: stampSize, height: stampSize)
            .compositingGroup()
            .shadow(
                color: Color(red: 60/255, green: 40/255, blue: 20/255, opacity: unread ? 0.10 : 0.06),
                radius: unread ? 4 : 2, x: 0, y: unread ? 2 : 1
            )
            .rotationEffect(.degrees(rotation))

            // postmark overlay (unread only) — simplified concentric circle ink
            if unread {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#3E2A1F"), lineWidth: 0.9)
                        .frame(width: 30, height: 30)
                    Circle()
                        .stroke(Color(hex: "#3E2A1F"), lineWidth: 0.9)
                        .frame(width: 21, height: 21)
                    Text("2026")
                        .font(.custom("Georgia", size: 6))
                        .foregroundColor(Color(hex: "#3E2A1F"))
                }
                .opacity(0.55)
                .rotationEffect(.degrees(-12))
                .offset(x: -2, y: stampSize - 22)
            }
        }
        .frame(width: stampSize + 8, height: stampSize + 16, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

private struct StampGlyph: View {
    let category: DinoNotificationCategory
    let color: Color
    let fillColor: Color

    var body: some View {
        switch category {
        case .growth:
            // sprout: vertical stem with two leaves
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.55))
                    p.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.32), control: CGPoint(x: w * 0.28, y: h * 0.5))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.5))
                    p.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.25), control: CGPoint(x: w * 0.74, y: h * 0.45))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        case .world:
            // little cloud
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.75))
                    p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.55), control: CGPoint(x: w * 0.10, y: h * 0.65))
                    p.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.45), control: CGPoint(x: w * 0.25, y: h * 0.40))
                    p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.45), control: CGPoint(x: w * 0.45, y: h * 0.30))
                    p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.65), control: CGPoint(x: w * 0.85, y: h * 0.45))
                    p.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.78), control: CGPoint(x: w * 0.85, y: h * 0.78))
                    p.closeSubpath()
                }
                .fill(fillColor.opacity(0.8))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.25, y: h * 0.75))
                        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.55), control: CGPoint(x: w * 0.10, y: h * 0.65))
                        p.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.45), control: CGPoint(x: w * 0.25, y: h * 0.40))
                        p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.45), control: CGPoint(x: w * 0.45, y: h * 0.30))
                        p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.65), control: CGPoint(x: w * 0.85, y: h * 0.45))
                        p.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.78), control: CGPoint(x: w * 0.85, y: h * 0.78))
                        p.closeSubpath()
                    }
                    .stroke(color, lineWidth: 1.4)
                )
            }
        case .creative:
            // 5-petal flower
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        Ellipse()
                            .fill(fillColor.opacity(0.85))
                            .overlay(Ellipse().stroke(color, lineWidth: 1.0))
                            .frame(width: w * 0.18, height: h * 0.26)
                            .offset(y: -h * 0.21)
                            .rotationEffect(.degrees(Double(i) * 72))
                    }
                    Circle().fill(color).frame(width: w * 0.16, height: h * 0.16)
                }
                .position(x: w * 0.5, y: h * 0.5)
            }
        case .dinoSays:
            // tiny dino silhouette — simplified
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { p in
                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.78))
                    p.addQuadCurve(to: CGPoint(x: w * 0.46, y: h * 0.50),
                                   control: CGPoint(x: w * 0.20, y: h * 0.55))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.32))
                    p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.30),
                                   control: CGPoint(x: w * 0.54, y: h * 0.22))
                    p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.46))
                    p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.52))
                    p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.74))
                    p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.82))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.74))
                    p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.74))
                    p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.82))
                    p.closeSubpath()
                }
                .fill(fillColor)
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.18, y: h * 0.78))
                        p.addQuadCurve(to: CGPoint(x: w * 0.46, y: h * 0.50),
                                       control: CGPoint(x: w * 0.20, y: h * 0.55))
                        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.32))
                        p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.30),
                                       control: CGPoint(x: w * 0.54, y: h * 0.22))
                        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.40))
                        p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.46))
                        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.52))
                        p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.62))
                        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.74))
                        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.82))
                        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.74))
                        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.74))
                        p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.82))
                        p.closeSubpath()
                    }
                    .stroke(color, lineWidth: 1.2)
                )
                Circle()
                    .fill(color)
                    .frame(width: w * 0.05, height: h * 0.05)
                    .position(x: w * 0.62, y: h * 0.40)
            }
        }
    }
}

// MARK: - AirmailBorder
//
// Spec: repeating-linear-gradient(45deg, transparent 0 8px, #C5544Eaa 8px 14px,
//                                  transparent 14px 22px, #4F7B9Caa 22px 28px)
// rendered as a thin border padding(3) around the card.
private struct AirmailBorder: View {
    var body: some View {
        Canvas { ctx, size in
            // Build a diagonal stripe pattern of red/blue that we then mask to a 3pt-thick frame.
            let stripe: CGFloat = 28
            let red = Color(red: 197/255, green: 84/255, blue: 78/255, opacity: 0.67)
            let blue = Color(red: 79/255, green: 123/255, blue: 156/255, opacity: 0.67)
            let cosA = cos(CGFloat.pi / 4)
            let sinA = sin(CGFloat.pi / 4)
            let diag = (size.width + size.height) * 1.5
            var d: CGFloat = -diag
            while d < diag {
                // red strip 8..14
                let r1 = stripeRect(at: d + 8, width: 6, length: diag * 2, cosA: cosA, sinA: sinA, center: CGPoint(x: size.width/2, y: size.height/2))
                ctx.fill(r1, with: .color(red))
                let b1 = stripeRect(at: d + 22, width: 6, length: diag * 2, cosA: cosA, sinA: sinA, center: CGPoint(x: size.width/2, y: size.height/2))
                ctx.fill(b1, with: .color(blue))
                d += stripe
            }
        }
        .padding(0)
        .mask(
            // Frame mask: full rect minus inner inset of 3pt — only a 3pt border shows.
            Rectangle()
                .overlay(
                    Rectangle()
                        .padding(3)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        )
        .allowsHitTesting(false)
    }

    private func stripeRect(at offset: CGFloat, width: CGFloat, length: CGFloat,
                            cosA: CGFloat, sinA: CGFloat, center: CGPoint) -> Path {
        // Build a thin rectangle rotated 45deg, offset along the perpendicular.
        var path = Path()
        let half = length / 2
        let dx = -sinA * offset
        let dy = cosA * offset
        let p0 = CGPoint(x: center.x + dx + cosA * -half, y: center.y + dy + sinA * -half)
        let p1 = CGPoint(x: center.x + dx + cosA * half,  y: center.y + dy + sinA * half)
        let perpX = -sinA * width
        let perpY = cosA * width
        path.move(to: p0)
        path.addLine(to: p1)
        path.addLine(to: CGPoint(x: p1.x + perpX, y: p1.y + perpY))
        path.addLine(to: CGPoint(x: p0.x + perpX, y: p0.y + perpY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Helpers

private func stripEmoji(_ s: String) -> String {
    let filtered = s.unicodeScalars.filter { scalar in
        !(scalar.properties.isEmojiPresentation
          || scalar.properties.isEmojiModifier
          || scalar.properties.isEmojiModifierBase
          || (scalar.properties.isEmoji && scalar.value > 0x238C))
    }
    return String(String.UnicodeScalarView(filtered))
        .replacingOccurrences(of: "\u{FE0F}", with: "")
        .replacingOccurrences(of: "\u{200D}", with: "")
        .trimmingCharacters(in: .whitespaces)
}

private extension CGFloat {
    func clamped(min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}

// MARK: - Paper grain

private struct PaperGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SystemRandomNumberGeneratorWrapper(seed: 0xD1A0)
            let dotCount = Int((size.width * size.height) / 1400)
            for _ in 0..<dotCount {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let r = Double.random(in: 0.3...0.9, using: &rng)
                let alpha = Double.random(in: 0.015...0.035, using: &rng)
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(alpha)))
            }
        }
        .blendMode(.multiply)
    }
}

private struct SystemRandomNumberGeneratorWrapper: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
