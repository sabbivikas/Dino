//
//  GratitudeJarView.swift
//  Dino
//

import SwiftUI

struct GratitudeJarView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: GratitudeViewModel = GratitudeViewModel(dataManager: SharedDataManager.shared)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 6) {
                            Text("gratitude jar")
                                .font(DinoTheme.largeFont())
                                .foregroundColor(DinoTheme.textPrimary)

                            HStack(spacing: 16) {
                                Label("\(viewModel.totalCount) notes", systemImage: "note.text")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)

                                Text("•")
                                    .foregroundColor(DinoTheme.divider)

                                Text("\(viewModel.todayCount) of \(viewModel.dailyGoal) today")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(viewModel.todayCount >= viewModel.dailyGoal ? DinoTheme.sageGreen : DinoTheme.textSecondary)
                                    .fontWeight(viewModel.todayCount >= viewModel.dailyGoal ? .semibold : .regular)
                            }
                        }
                        .padding(.top, 8)

                        // Congratulations banner
                        if viewModel.showCongrats {
                            HStack(spacing: 12) {
                                Text("🎉")
                                    .font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("30 notes milestone!")
                                        .font(DinoTheme.headlineFont())
                                        .foregroundColor(DinoTheme.textPrimary)
                                    Text("look how far you've come.")
                                        .font(DinoTheme.captionFont())
                                        .foregroundColor(DinoTheme.textSecondary)
                                }
                            }
                            .padding(DinoTheme.padding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DinoTheme.peach.opacity(0.3))
                            .cornerRadius(DinoTheme.cornerRadius)
                            .padding(.horizontal, DinoTheme.padding)
                        }

                        // Jar illustration with slips
                        JarIllustration(
                            notes: viewModel.notes,
                            fillRatio: viewModel.jarFillRatio,
                            onNoteTap: { note in viewModel.selectNote(note) }
                        )
                        .padding(.horizontal, DinoTheme.padding)

                        // Empty state
                        if viewModel.notes.isEmpty {
                            VStack(spacing: 12) {
                                Text("add your first gratitude note")
                                    .font(DinoTheme.bodyFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                                Text("what are you grateful for today?")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                        }

                        // Notes list
                        if !viewModel.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("all notes")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                                    .padding(.horizontal, DinoTheme.padding)

                                ForEach(Array(viewModel.notes.enumerated()), id: \.element.id) { i, note in
                                    GratitudeNoteRow(note: note, index: i, onTap: {
                                        viewModel.selectNote(note)
                                    }, onDelete: {
                                        viewModel.deleteNote(note)
                                    })
                                    .padding(.horizontal, DinoTheme.padding)
                                }
                            }
                            .padding(.bottom, 80)
                        }
                    }
                }
                .background(Color.white.ignoresSafeArea())

                // FAB
                FloatingAddButton { viewModel.showAddSheet = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddGratitudeSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showNoteDetail) {
                if let note = viewModel.selectedNote {
                    GratitudeNoteDetail(note: note)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Jar Illustration
struct JarIllustration: View {
    let notes: [GratitudeNote]
    let fillRatio: Double
    let onNoteTap: (GratitudeNote) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Jar body
            ZStack(alignment: .bottom) {
                // Jar background
                RoundedRectangle(cornerRadius: 20)
                    .fill(DinoTheme.skyBlue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DinoTheme.skyBlue.opacity(0.3), lineWidth: 2)
                    )

                // Fill level
                if fillRatio > 0 {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [DinoTheme.sageGreen.opacity(0.12), DinoTheme.sageGreen.opacity(0.22)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 260 * fillRatio)
                            .cornerRadius(18)
                    }
                }

                // Slips inside jar
                ZStack {
                    ForEach(Array(notes.prefix(12).enumerated()), id: \.element.id) { i, note in
                        GratitudeSlip(note: note, index: i, onTap: { onNoteTap(note) })
                            .offset(
                                x: slipOffsetX(for: i),
                                y: slipOffsetY(for: i, total: min(notes.count, 12))
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                .padding(.horizontal, 12)
            }
            .frame(height: 260)

            // Lid
            VStack(spacing: 0) {
                // Lid top
                RoundedRectangle(cornerRadius: 6)
                    .fill(DinoTheme.sageGreen.opacity(0.5))
                    .frame(width: 60, height: 10)
                    .offset(y: 5)

                // Lid base
                RoundedRectangle(cornerRadius: 4)
                    .fill(DinoTheme.sageGreen.opacity(0.7))
                    .frame(height: 16)
            }
            .offset(y: -260)
        }
        .frame(height: 300)
    }

    private func slipOffsetX(for index: Int) -> CGFloat {
        let positions: [CGFloat] = [-60, 30, -20, 50, -40, 10, -55, 40, -10, 60, -35, 20]
        return index < positions.count ? positions[index] : CGFloat.random(in: -50...50)
    }

    private func slipOffsetY(for index: Int, total: Int) -> CGFloat {
        let row = index / 3
        let positions: [CGFloat] = [40, 0, -40, -80]
        return row < positions.count ? positions[row] : CGFloat(row * -40)
    }
}

// MARK: - Note Row
struct GratitudeNoteRow: View {
    let note: GratitudeNote
    let index: Int
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DinoTheme.pastel(for: index).opacity(0.5))
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .font(DinoTheme.bodyFont())
                        .foregroundColor(DinoTheme.textPrimary)
                        .lineLimit(2)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                }
            }
            .padding(14)
            .background(DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Add Gratitude Sheet
struct AddGratitudeSheet: View {
    @ObservedObject var viewModel: GratitudeViewModel
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("add to your jar")
                        .font(DinoTheme.titleFont())
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("what are you grateful for right now?")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if viewModel.newNoteText.isEmpty {
                        Text("type something you're grateful for...")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            .padding(.top, 12)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $viewModel.newNoteText)
                        .font(DinoTheme.bodyFont())
                        .focused($focused)
                        .frame(height: 120)
                        .onChange(of: viewModel.newNoteText) { _, val in
                            if val.count > 200 {
                                viewModel.newNoteText = String(val.prefix(200))
                            }
                        }
                }
                .padding(12)
                .background(DinoTheme.cardBackground)
                .cornerRadius(DinoTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                        .stroke(DinoTheme.divider, lineWidth: 1)
                )

                HStack {
                    Spacer()
                    Text("\(viewModel.newNoteText.count)/200")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }

                Button(action: { viewModel.addNote() }) {
                    Text("add to jar 🫙")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty ? DinoTheme.textSecondary : DinoTheme.sageGreen)
                        .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, DinoTheme.padding)
            .onAppear { focused = true }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel") {
                        viewModel.newNoteText = ""
                        viewModel.showAddSheet = false
                    }
                    .foregroundColor(DinoTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Note Detail Sheet
struct GratitudeNoteDetail: View {
    let note: GratitudeNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🫙")
                .font(.system(size: 50))
                .padding(.top, 32)

            Text(note.text)
                .font(.system(.title3, design: .rounded))
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
