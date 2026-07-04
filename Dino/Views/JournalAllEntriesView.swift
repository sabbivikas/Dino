//
//  JournalAllEntriesView.swift
//  Dino
//

import SwiftUI

struct JournalAllEntriesView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @ObservedObject var viewModel: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewEntry: JournalEntry? = nil

    private var entries: [JournalEntry] {
        JournalEntry.sortedForDisplay(dataManager.journalEntries)
    }

    var body: some View {
        ZStack {
            DinoTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                                JournalPolaroidCard(
                                    entry: entry,
                                    index: i,
                                    viewModel: viewModel,
                                    onTap: { entry in
                                        previewEntry = entry
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear { AnalyticsManager.shared.trackScreenViewed("all_memories") }
        .sheet(item: $previewEntry) { entry in
            JournalEntryDetailView(entry: entry, viewModel: viewModel)
                .environmentObject(dataManager)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#8B7A6A"))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: "#F5F0E8")))
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(entries.count) memories")
                .font(DinoTheme.dinoHeaderFont(size: 22))
                .foregroundColor(DinoTheme.ink)

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("no memories yet")
                .font(DinoTheme.dinoFont(size: 20))
                .foregroundColor(DinoTheme.muted)
            Text("your journal entries will live here once you start writing.")
                .font(.system(size: 13))
                .italic()
                .foregroundColor(Color(hex: "#A8A29A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
