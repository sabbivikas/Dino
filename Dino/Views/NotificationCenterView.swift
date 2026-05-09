//
//  NotificationCenterView.swift
//  Dino
//

import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotificationStore.shared
    @State private var selectedCategory: DinoNotificationCategory? = nil
    @State private var hasAppeared = false
    @State private var pressedID: UUID? = nil

    private let cream = Color(hex: "#FAF6EC")
    private let cardWarm = Color(hex: "#FFF8F0")
    private let inkDark = Color(hex: "#2A2620")
    private let inkMuted = Color(hex: "#8B7A6A")

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            PaperGrain().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                filterStrip

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
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(inkMuted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(cream))
                    .overlay(Circle().strokeBorder(inkMuted.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer().frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("from dino")
                    .font(.custom(DinoTheme.customFontName, size: 28))
                    .foregroundColor(inkDark)
                Text(formattedDate())
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(inkMuted)
            }

            Spacer()

            if store.unreadCount > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.markAllRead()
                    }
                }) {
                    Text("mark all read")
                        .font(.system(size: 11))
                        .foregroundColor(inkMuted)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date()).lowercased()
    }

    // MARK: - Filter strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(label: "all", isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = nil }
                }
                ForEach(DinoNotificationCategory.allCases) { cat in
                    pill(label: cat.displayName, isSelected: selectedCategory == cat) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = cat }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private func pill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(isSelected ? cream : inkDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? inkDark : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(inkMuted.opacity(isSelected ? 0 : 0.32), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    private var filtered: [DinoNotification] {
        guard let cat = selectedCategory else { return store.notifications }
        return store.notifications.filter { $0.category == cat }
    }

    private var list: some View {
        List {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, note in
                NotificationCard(
                    note: note,
                    cardWarm: cardWarm,
                    inkDark: inkDark,
                    inkMuted: inkMuted,
                    isPressed: pressedID == note.id
                )
                .rotationEffect(.degrees(stableRotation(for: note.id)))
                .scaleEffect(hasAppeared ? 1.0 : 0.92)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(Double(min(index, 12)) * 0.03),
                    value: hasAppeared
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                .contentShape(Rectangle())
                .onTapGesture {
                    pressedID = note.id
                    withAnimation(.easeInOut(duration: 0.15)) { /* triggers scaleEffect */ }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            pressedID = nil
                        }
                        store.markRead(note.id)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { store.delete(note.id) }
                    } label: {
                        Text("delete")
                    }
                    .tint(Color(hex: "#D88080"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func stableRotation(for id: UUID) -> Double {
        let h = abs(id.uuidString.hashValue)
        let normalized = Double(h % 1000) / 1000.0
        return (normalized - 0.5) * 1.0 // -0.5...+0.5
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("all quiet here")
                .font(.custom(DinoTheme.customFontName, size: 20))
                .foregroundColor(inkMuted)
            Text("dino will write when something's worth saying")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundColor(inkMuted.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Notification Card

private struct NotificationCard: View {
    let note: DinoNotification
    let cardWarm: Color
    let inkDark: Color
    let inkMuted: Color
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(stripeColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(note.category.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(labelColor)

                Text(stripEmoji(note.title))
                    .font(.custom(DinoTheme.customFontName, size: 17))
                    .foregroundColor(inkDark)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(stripEmoji(note.subtitle))
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundColor(inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Text(relativeTimeString(note.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(inkMuted.opacity(0.85))
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(note.isRead ? Color.white : cardWarm)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }

    private var stripeColor: Color {
        switch note.category {
        case .growth:   return Color(hex: "#A8C5A0")
        case .world:    return Color(hex: "#A8C0D8")
        case .creative: return Color(hex: "#BAA9DB")
        case .dinoSays: return Color(hex: "#F5C4A8")
        }
    }

    private var labelColor: Color {
        switch note.category {
        case .growth:   return Color(hex: "#5C7456")
        case .world:    return Color(hex: "#5A6E84")
        case .creative: return Color(hex: "#665C7E")
        case .dinoSays: return Color(hex: "#8A6A52")
        }
    }

    private func relativeTimeString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        let s = f.localizedString(for: date, relativeTo: Date())
        if abs(Date().timeIntervalSince(date)) < 60 { return "just now" }
        return s.lowercased()
    }
}

// MARK: - Emoji stripping

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
        .opacity(0.9)
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
