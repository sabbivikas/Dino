//
//  JournalEntryDetailView.swift
//  Dino
//
//  Full-screen reader for a single journal entry: full text (no truncation),
//  audio playback, photo, mood, date, share, and favorite/delete. Opens on a
//  tap of a polaroid card. Reuses JournalViewModel's existing playback.
//

import SwiftUI
import UIKit
import Combine

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @ObservedObject var viewModel: JournalViewModel
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    @State private var loadedPhoto: UIImage?
    @State private var photoMissing = false
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var showDateEdit = false
    @State private var editedDate = Date()
    @State private var elapsed: Double = 0

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Palette
    private let cream = Color(hex: "#FAF6EC")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let rose = Color(hex: "#E8B4B8")
    private let peach = Color(hex: "#F5C6AA")

    // Live entry (so favorite state stays current after toggling).
    private var current: JournalEntry {
        dataManager.journalEntries.first(where: { $0.id == entry.id }) ?? entry
    }
    private var hasAudio: Bool { !entry.audioFileName.isEmpty }
    private var isThisPlaying: Bool { viewModel.isPlaying && viewModel.playingEntryId == entry.id }
    private var bodyText: String {
        let t = entry.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "voice note recorded" : t
    }
    private var warmDate: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = "EEEE, MMMM d"
        return df.string(from: current.date).lowercased()   // live — reflects date edits
    }

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let photo = loadedPhoto {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else if entry.photoFileName != nil {
                            // fetching vs permanently missing — honest, never broken
                            VStack(spacing: 8) {
                                Text(photoMissing ? "🌫️" : "🌤️")
                                    .font(.system(size: 30))
                                Text(photoMissing
                                     ? "this photo stayed on an old device"
                                     : "finding this photo…")
                                    .font(DinoTheme.dinoFont(size: 13))
                                    .foregroundColor(ink3)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.5)))
                        }
                        if hasAudio { audioPlayer }
                        Text(bodyText)
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(ink)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                bottomActions
            }
        }
        .onAppear {
            loadPhoto()
            AnalyticsManager.shared.trackJournalEntryViewed()
        }
        .onDisappear {
            if isThisPlaying { viewModel.playEntry(entry) }   // stop on leave
        }
        .onReceive(ticker) { _ in
            guard isThisPlaying else { return }
            elapsed = min(elapsed + 0.1, max(entry.durationSeconds, 0.1))
        }
        .onChange(of: viewModel.isPlaying) { _, playing in
            if !playing { elapsed = 0 }
        }
        .sheet(isPresented: $showShare) {
            JournalDetailShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showDateEdit) {
            VStack(spacing: 14) {
                Text("move this memory")
                    .font(DinoTheme.dinoHeaderFont(size: 22))
                    .foregroundColor(ink)
                    .padding(.top, 22)
                Text("pick the day it belongs to")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(ink3)
                DatePicker("", selection: $editedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(sage)
                    .padding(.horizontal, 16)
                Button {
                    dataManager.updateJournalEntryDate(current, to: editedDate)
                    showDateEdit = false
                } label: {
                    Text("done")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(sage))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(520)])
            .background(cream)
        }
        .confirmationDialog("delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                if isThisPlaying { viewModel.playEntry(entry) }
                viewModel.deleteEntry(entry)
                dismiss()
            }
            Button("cancel", role: .cancel) { }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("journal").font(DinoTheme.dinoFont(size: 15))
                    }
                    .foregroundColor(ink2)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(ink2)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(warmDate)
                    .font(DinoTheme.dinoHeaderFont(size: 24))
                    .foregroundColor(ink)
                Button {
                    editedDate = current.date
                    showDateEdit = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ink3)
                }
                .buttonStyle(.plain)
            }

            Text(entry.moodTag.lowercased())
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(moodColor(entry.moodTag)))
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Audio player

    private var audioPlayer: some View {
        let duration = max(entry.durationSeconds, 0.1)
        let fraction = min(elapsed / duration, 1.0)
        return HStack(spacing: 14) {
            Button {
                if !isThisPlaying { elapsed = 0 }
                viewModel.playEntry(entry)
            } label: {
                ZStack {
                    Circle().fill(sage).frame(width: 48, height: 48)
                    Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isThisPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(sage.opacity(0.2)).frame(height: 5)
                        Capsule().fill(sage).frame(width: geo.size.width * fraction, height: 5)
                    }
                }
                .frame(height: 5)
                HStack {
                    Text(timeLabel(isThisPlaying ? elapsed : 0))
                        .font(DinoTheme.dinoFont(size: 11)).foregroundColor(ink3)
                    Spacer()
                    Text(entry.formattedDuration)
                        .font(DinoTheme.dinoFont(size: 11)).foregroundColor(ink3)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(sage.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack {
            Button {
                HapticManager.shared.light()
                viewModel.toggleFavorite(entry)
            } label: {
                Image(systemName: current.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(current.isFavorite ? rose : ink3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(ink3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(cream)
    }

    // MARK: - Helpers

    private var shareItems: [Any] {
        var items: [Any] = ["\(bodyText)\n\n— dino journal, \(warmDate)"]
        if let photo = loadedPhoto { items.append(photo) }
        return items
    }

    private func loadPhoto() {
        guard loadedPhoto == nil, let name = entry.photoFileName else { return }
        Task {
            switch await JournalPhotoStore.fetchPhoto(name) {
            case .loaded(let img): loadedPhoto = img
            case .missing: photoMissing = true
            case .fetching: break
            }
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func moodColor(_ mood: String) -> Color {
        let m = mood.lowercased()
        let positive = ["happy", "grateful", "calm", "peaceful", "content", "excited", "hopeful", "joyful", "good"]
        let heavy = ["sad", "anxious", "overwhelmed", "drained", "angry", "stressed", "lonely", "tired", "down"]
        if positive.contains(m) { return peach }
        if heavy.contains(m) { return rose }
        return sage
    }
}

// MARK: - iPad-safe share sheet

private struct JournalDetailShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad presents this as a popover and crashes without a non-nil anchor.
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
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
