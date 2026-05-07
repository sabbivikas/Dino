//
//  NotificationCenterView.swift
//  Dino
//

import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotificationStore.shared
    @State private var selectedCategory: DinoNotificationCategory? = nil

    private let cream = Color(hex: "#F5F0E8")
    private let inkSoft = Color(hex: "#8B7A6A")
    private let inkDark = Color(hex: "#3D2B18")

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterStrip
                Divider().opacity(0.15)

                if filtered.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(inkSoft)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(cream))
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("notifications")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(inkDark)

            Spacer()

            Group {
                if store.unreadCount > 0 {
                    Button("mark all read") {
                        store.markAllRead()
                    }
                    .font(.custom(DinoTheme.customFontName, size: 12))
                    .foregroundColor(inkSoft)
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Filter strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(label: "all", emoji: nil, isSelected: selectedCategory == nil, color: inkSoft) {
                    selectedCategory = nil
                }
                ForEach(DinoNotificationCategory.allCases) { cat in
                    pill(
                        label: cat.displayName,
                        emoji: cat.emoji,
                        isSelected: selectedCategory == cat,
                        color: cat.pillColor
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private func pill(label: String, emoji: String?, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji { Text(emoji) }
                Text(label)
                    .font(.custom(DinoTheme.customFontName, size: 14))
            }
            .foregroundColor(isSelected ? .white : inkDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.18))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.5), lineWidth: 1)
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
            ForEach(filtered) { note in
                row(note)
                    .listRowBackground(cream)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.markRead(note.id)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.delete(note.id)
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(cream)
    }

    private func row(_ note: DinoNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(note.category.pillColor.opacity(0.25))
                    .frame(width: 40, height: 40)
                Text(note.category.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.title)
                        .font(.custom(DinoTheme.customFontName, size: 16))
                        .foregroundColor(inkDark)
                    Spacer()
                    Text(relativeTime(note.timestamp))
                        .font(.custom(DinoTheme.customFontName, size: 11))
                        .foregroundColor(inkSoft)
                }
                Text(note.subtitle)
                    .font(.custom(DinoTheme.customFontName, size: 12))
                    .foregroundColor(inkSoft)
                    .lineLimit(2)
            }

            if !note.isRead {
                Circle()
                    .fill(Color(hex: "#E8746A"))
                    .frame(width: 8, height: 8)
                    .offset(y: 6)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(emptyEmoji)
                .font(.system(size: 44))
            Text(emptyMessage)
                .font(.custom(DinoTheme.customFontName, size: 16))
                .foregroundColor(inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var emptyEmoji: String {
        selectedCategory?.emoji ?? "\u{1F343}"
    }

    private var emptyMessage: String {
        switch selectedCategory {
        case .growth?:   return "no growth notifications yet \u{1F331}\nkeep going — small steps count."
        case .world?:    return "no world notifications yet \u{1F30D}\ncheck back soon."
        case .creative?: return "no creative notifications yet \u{1F3A8}\nmake something small today."
        case .dinoSays?: return "dino has nothing new to share right now \u{1F4E3}"
        case nil:        return "all quiet here.\ncome back after you’ve checked in a few times."
        }
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        let days = s / 86400
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        if weeks < 4 { return "\(weeks)w" }
        let months = days / 30
        return "\(months)mo"
    }
}
