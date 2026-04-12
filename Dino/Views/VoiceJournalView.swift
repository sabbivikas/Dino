//
//  VoiceJournalView.swift
//  Dino
//

import SwiftUI
import UIKit
import AVFoundation

struct VoiceJournalView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: JournalViewModel = JournalViewModel(dataManager: SharedDataManager.shared)
    @State private var pulseScale: CGFloat = 1.0
    @State private var showPermissionAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("your voice journal")
                        .font(DinoTheme.largeFont())
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("speak your thoughts freely")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Record button
                VStack(spacing: 16) {
                    ZStack {
                        // Pulse rings
                        if viewModel.isRecording {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseScale)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                    value: pulseScale
                                )

                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 115, height: 115)
                                .scaleEffect(pulseScale * 0.9)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2),
                                    value: pulseScale
                                )
                        }

                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : DinoTheme.sageGreen)
                                    .frame(width: 90, height: 90)
                                    .shadow(
                                        color: (viewModel.isRecording ? Color.red : DinoTheme.sageGreen).opacity(0.4),
                                        radius: 16, y: 4
                                    )

                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .frame(height: 160)
                    .onAppear {
                        if viewModel.isRecording { pulseScale = 1.2 }
                    }
                    .onChange(of: viewModel.isRecording) { _, recording in
                        pulseScale = recording ? 1.2 : 1.0
                    }

                    if viewModel.isRecording {
                        Text(viewModel.formattedRecordingDuration)
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    } else {
                        Text("tap to record")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                }
                .padding(.bottom, 28)

                Divider()
                    .padding(.horizontal, DinoTheme.padding)

                // Journal entries
                if dataManager.journalEntries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("🎙")
                            .font(.system(size: 50))
                        Text("no entries yet")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)
                        Text("record your first voice note above")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(dataManager.journalEntries) { entry in
                            JournalEntryRow(
                                entry: entry,
                                isPlaying: viewModel.playingEntryId == entry.id,
                                onPlay: { viewModel.playEntry(entry) },
                                onFavorite: { viewModel.toggleFavorite(entry) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.white)
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.toggleFavorite(entry)
                                } label: {
                                    Label(entry.isFavorite ? "Unfavorite" : "Favorite",
                                          systemImage: entry.isFavorite ? "star.slash" : "star.fill")
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.white.ignoresSafeArea())
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

// MARK: - Journal Entry Row
struct JournalEntryRow: View {
    let entry: JournalEntry
    let isPlaying: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Play button
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(isPlaying ? DinoTheme.sageGreen : DinoTheme.sageGreen.opacity(0.15))
                        .frame(width: 46, height: 46)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPlaying ? .white : DinoTheme.sageGreen)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)

                    Text("•")
                        .foregroundColor(DinoTheme.textSecondary)
                        .font(DinoTheme.captionFont())

                    Text(entry.formattedDuration)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)

                    Text("•")
                        .foregroundColor(DinoTheme.textSecondary)
                        .font(DinoTheme.captionFont())

                    Text(entry.moodTag)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.lavender)
                        .fontWeight(.semibold)
                }
            }

            Spacer()

            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
            }
        }
        .padding(14)
        .background(DinoTheme.cardBackground)
        .cornerRadius(DinoTheme.cornerRadius)
    }
}
