//
//  StreakCalendarView.swift
//  Dino
//

import SwiftUI

struct StreakCalendarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayOfWeekLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats cards
                statsSection

                // Calendar
                calendarSection

                // Legend
                legendSection
            }
            .padding(.horizontal, DinoTheme.padding)
            .padding(.top, 12)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                emoji: "🔥",
                value: "\(dataManager.streakData.currentStreak)",
                label: "current"
            )
            statCard(
                emoji: "🏆",
                value: "\(dataManager.streakData.longestStreak)",
                label: "longest"
            )
            statCard(
                emoji: "📅",
                value: "\(dataManager.streakData.activeDates.count)",
                label: "total days"
            )
        }
    }

    private func statCard(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 24))
            Text(value)
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.textPrimary)
            Text(label)
                .font(DinoTheme.caption2Font())
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DinoTheme.sageGreen.opacity(0.08))
        .cornerRadius(DinoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                .stroke(DinoTheme.sageGreen.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation { shiftMonth(-1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.sageGreen)
                }

                Spacer()

                Text(monthYearString)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Spacer()

                Button {
                    withAnimation { shiftMonth(1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(canGoForward ? DinoTheme.sageGreen : DinoTheme.textSecondary.opacity(0.3))
                }
                .disabled(!canGoForward)
            }
            .padding(.horizontal, 4)

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(dayOfWeekLabels, id: \.self) { label in
                    Text(label)
                        .font(DinoTheme.caption2Font())
                        .foregroundColor(DinoTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(16)
        .background(DinoTheme.surfacePrimary)
        .cornerRadius(DinoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date = date {
            let isActive = dataManager.streakData.isActiveDate(date)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()

            ZStack {
                if isActive {
                    Circle()
                        .fill(DinoTheme.sageGreen.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                if isToday && !isActive {
                    Circle()
                        .stroke(DinoTheme.sageGreen, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(DinoTheme.captionFont())
                    .foregroundColor(
                        isActive ? .white :
                        isFuture ? DinoTheme.textSecondary.opacity(0.3) :
                        isToday ? DinoTheme.sageGreen :
                        DinoTheme.textPrimary
                    )
            }
            .frame(height: 36)
        } else {
            Color.clear.frame(height: 36)
        }
    }

    // MARK: - Legend

    private var legendSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(DinoTheme.sageGreen.opacity(0.7))
                    .frame(width: 10, height: 10)
                Text("active day")
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(DinoTheme.textSecondary)
            }

            HStack(spacing: 6) {
                Circle()
                    .stroke(DinoTheme.sageGreen, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text("today")
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(DinoTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var canGoForward: Bool {
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let displayMonth = calendar.component(.month, from: displayedMonth)
        let displayYear = calendar.component(.year, from: displayedMonth)
        return displayYear < currentYear || (displayYear == currentYear && displayMonth < currentMonth)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) - 1  // 0 = Sunday
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}
