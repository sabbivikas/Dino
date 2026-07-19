//
//  VoiceJournalView.swift
//  Dino
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - Root View
struct VoiceJournalView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: JournalViewModel = JournalViewModel(dataManager: SharedDataManager.shared)
    @State private var showAllMemories: Bool = false
    @State private var previewEntry: JournalEntry? = nil
    @State private var entryDate: Date = Date()
    @State private var showDatePicker: Bool = false

    var selectedTab: Binding<Int>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                JournalPaperBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        Text("journal".localized)
                            .font(DinoTheme.dinoDisplayFont(size: 30))
                            .foregroundColor(DinoTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)

                        // Composer card
                        JournalComposerCard(
                            entryDate: entryDate,
                            onHeaderTap: {
                                HapticManager.shared.light()
                                showDatePicker = true
                            },
                            onDevelop: { text, mood, image in
                                saveTextEntry(text: text, mood: mood, image: image)
                            }
                        )

                        // Timeline header
                        HStack {
                            Text("recent memories".localized)
                                .font(DinoTheme.dinoFont(size: 14))
                                .foregroundColor(Color(hex: "#7A7266"))
                            Spacer()
                            Text("tap a card to flip".localized)
                                .font(DinoTheme.dinoFont(size: 11))
                                .italic()
                                .foregroundColor(Color(hex: "#A8A29A"))
                        }
                        .padding(.top, 4)

                        JournalTimelineStrip(
                            entries: JournalEntry.sortedForDisplay(dataManager.journalEntries),
                            viewModel: viewModel,
                            onSeeAll: {
                                HapticManager.shared.light()
                                AnalyticsManager.shared.trackSeeAllMemoriesTapped(count: dataManager.journalEntries.count)
                                showAllMemories = true
                            },
                            onTap: { entry in
                                previewEntry = entry
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack {
                    HStack {
                        Button {
                            HapticManager.shared.light()
                            if let selectedTab = selectedTab {
                                selectedTab.wrappedValue = 0
                            } else {
                                dismiss()
                            }
                        } label: {
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
            .navigationBarHidden(true)
            .onAppear {
                AnalyticsManager.shared.trackJournalOpened()
                AnalyticsManager.shared.trackScreen("journal")
            }
            .fullScreenCover(isPresented: $showAllMemories) {
                JournalAllEntriesView(viewModel: viewModel)
                    .environmentObject(dataManager)
            }
            .sheet(item: $previewEntry) { entry in
                JournalEntryDetailView(entry: entry, viewModel: viewModel)
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $entryDate)
            }
            .onChange(of: entryDate) { _, newDate in
                viewModel.entryDate = newDate   // voice notes share the chosen day
            }
            .task {
                // Cloud durability: upload any local photos the cloud doesn't
                // have yet (covers photos that predate storage sync).
                JournalPhotoStore.backfillUploads(entries: dataManager.journalEntries)
            }
        }
    }

    private func saveTextEntry(text: String, mood: String?, image: UIImage?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateStr = dateFormatter.string(from: Date())
        let title = String(localized: "journal entry \u{2014} \(dateStr)")

        let photoFileName = saveComposerPhoto(image)

        let entry = JournalEntry(
            date: entryDate,
            audioFileName: "",
            title: title,
            summary: trimmed,
            moodTag: mood ?? "reflective",
            durationSeconds: 0,
            photoFileName: photoFileName
        )
        dataManager.addJournalEntry(entry)
        AnalyticsManager.shared.trackJournalEntryCreated(type: "text")
        // Fully async cloud copy — never blocks or delays the save.
        JournalPhotoStore.uploadIfNeeded(photoFileName)

        // DinoMind (opt-in): extract a coarse theme from the entry text. Text is
        // sent for classification only — never stored; only the enum is kept.
        if dataManager.journalThemeLearningEnabled {
            let moodSnapshot = dataManager.moodEntries
                .first(where: { Calendar.current.isDateInToday($0.date) })?
                .weatherType.rawValue ?? ""
            Task {
                if let theme = await ThemeExtractionService.extractTheme(from: trimmed) {
                    dataManager.recordThemeTag(theme: theme, mood: moodSnapshot, source: ThemeTag.sourceJournal)
                }
            }
        }

        // Reset entry date to today so the next entry defaults to today again
        entryDate = Date()

        // Dismiss keyboard
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private struct DatePickerSheet: View {
        @Binding var date: Date
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            ZStack {
                Color(hex: "#FAF6EC").ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("backdate entry")
                        .font(DinoTheme.dinoHeaderFont(size: 22))
                        .foregroundColor(DinoTheme.ink)
                        .padding(.top, 24)

                    Text("pick the day you want this memory to belong to")
                        .font(DinoTheme.dinoFont(size: 12))
                        .italic()
                        .foregroundColor(Color(hex: "#7A7266"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    DatePicker(
                        "",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .tint(Color(hex: "#A8C5A0"))

                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Text("done".localized)
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#A8C5A0"), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func saveComposerPhoto(_ image: UIImage?) -> String? {
        guard let image = image,
              let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let name = "journal_photo_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        var mutableURL = url
        var resVals = URLResourceValues()
        resVals.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resVals)
        return name
    }
}

// MARK: - Paper Backdrop
private struct JournalPaperBackdrop: View {
    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC")

            // Top-left warm glow
            RadialGradient(
                colors: [Color(hex: "#F5C6AA").opacity(0.25), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            .frame(width: 400, height: 400)
            .offset(x: -80, y: -80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Bottom-right sage glow
            RadialGradient(
                colors: [Color(hex: "#A8C5A0").opacity(0.2), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .frame(width: 400, height: 400)
            .offset(x: 80, y: 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Noise grain overlay
            Image("noise-grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.04)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Journal Composer Card
private struct JournalComposerCard: View {
    let entryDate: Date
    let onHeaderTap: () -> Void
    let onDevelop: (String, String?, UIImage?) -> Void

    @State private var promptIndex: Int = 0
    @State private var composerText: String = ""
    @State private var micPulse: CGFloat = 1.0
    @State private var selectedImage: UIImage? = nil
    @State private var selectedMood: String? = nil
    @State private var showPhotoPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showCameraDialog: Bool = false
    @State private var showMoodSheet: Bool = false
    @State private var isTranscribing: Bool = false
    // Journaling suggestions (iOS 17.2+): invitation lives ONLY in the empty
    // composer, once per composer session, quiet for the day after an x.
    @State private var showMomentsConsent: Bool = false
    @State private var momentsDoneThisSession: Bool = false
    @State private var momentsInviteTracked: Bool = false

    @StateObject private var transcriber = SpeechTranscriber()

    // MARK: - Journaling suggestions

    private var momentsInviteEligible: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        if #available(iOS 17.2, *) {
            return JournalMoments.shouldInvite(
                composerEmpty: composerText.isEmpty && selectedImage == nil,
                dismissedDayKey: UserDefaults.standard.string(forKey: JournalMoments.dismissedDayKeyKey),
                todayKey: JournalMoments.todayKey(),
                shownThisSession: momentsDoneThisSession,
                available: true)
        }
        return false
    }

    @available(iOS 17.2, *)
    private var momentsInviteRow: some View {
        // Single clean line, sitting ON the paper: sibling rows pad leading 60
        // to clear the diary's punched holes and red margin line.
        HStack(spacing: 8) {
            Text("🌿").font(.system(size: 13))
            Text(JournalMoments.inviteLine)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(Color(hex: "#7A7266"))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            momentsShowMeAffordance
            Button {
                HapticManager.shared.light()
                JournalMoments.markDismissedToday()
                withAnimation(.easeInOut(duration: 0.2)) { momentsDoneThisSession = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "#A8A29A"))
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 60)
        .padding(.trailing, 16)
        .onAppear {
            if !momentsInviteTracked {
                momentsInviteTracked = true
                AnalyticsManager.shared.trackJournalMomentsInviteShown()
            }
        }
        .sheet(isPresented: $showMomentsConsent) {
            #if canImport(JournalingSuggestions)
            JournalMomentsConsentSheet(
                onMoment: { image, line in
                    showMomentsConsent = false
                    applyMoment(image: image, line: line)
                },
                onLater: {
                    showMomentsConsent = false
                    JournalMoments.markDismissedToday()
                    withAnimation { momentsDoneThisSession = true }
                }
            )
            #endif
        }
    }

    @available(iOS 17.2, *)
    @ViewBuilder
    private var momentsShowMeAffordance: some View {
        #if canImport(JournalingSuggestions)
        if JournalMoments.consentSeen {
            JournalMomentsPickerButton(onMoment: { image, line in
                applyMoment(image: image, line: line)
            }) {
                momentsShowMeLabel
            }
        } else {
            Button {
                JournalMoments.consentSeen = true   // they've read the explainer
                showMomentsConsent = true
            } label: {
                momentsShowMeLabel
            }
            .buttonStyle(.plain)
        }
        #else
        EmptyView()
        #endif
    }

    private var momentsShowMeLabel: some View {
        Text(JournalMoments.inviteAction)
            .font(DinoTheme.dinoFont(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color(hex: "#7BA872")))
    }

    /// One moment becomes at most one photo + ONE seeded line — then the
    /// cursor is theirs. Nothing about the moment is stored or logged.
    private func applyMoment(image: UIImage?, line: String?) {
        if let image { selectedImage = image }
        if let line, composerText.isEmpty { composerText = line + "\n" }
        withAnimation(.easeInOut(duration: 0.2)) { momentsDoneThisSession = true }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let prompts = [
        String(localized: "what's been on your mind?"),
        String(localized: "one small thing that went well today…"),
        String(localized: "what does your body need right now?")
    ]

    private var metaText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let dateStr = formatter.string(from: entryDate).uppercased()
        return String(localized: "\(dateStr) · DEAR DIARY")
    }

    private var isBackdated: Bool {
        !Calendar.current.isDateInToday(entryDate)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base card
            RoundedRectangle(cornerRadius: 14)
                .fill(DinoTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#A8C5A0").opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#3C2814").opacity(0.08), radius: 22, x: 0, y: 8)

            // Ruled horizontal lines
            GeometryReader { geo in
                Canvas { ctx, size in
                    let startY: CGFloat = 60
                    var y = startY
                    while y < size.height - 8 {
                        var path = Path()
                        path.move(to: CGPoint(x: 56, y: y))
                        path.addLine(to: CGPoint(x: size.width - 16, y: y))
                        ctx.stroke(path, with: .color(Color(hex: "#A8D4E6").opacity(0.25)), lineWidth: 1)
                        y += 28
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)

            // Vertical red margin line at x = 42
            Rectangle()
                .fill(Color(hex: "#E8B4B8").opacity(0.5))
                .frame(width: 1)
                .padding(.leading, 42)
                .padding(.vertical, 12)

            // 3 punched holes on left edge
            VStack {
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
                Circle()
                    .fill(Color(hex: "#FAF6EC"))
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.vertical, 24)

            // Content
            VStack(alignment: .leading, spacing: 14) {
                // Meta row — tappable to backdate
                Button {
                    onHeaderTap()
                } label: {
                    HStack(spacing: 6) {
                        Text(metaText)
                            .font(DinoTheme.dinoFont(size: 11))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "#A67074"))
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#A67074").opacity(0.7))
                        if isBackdated {
                            Text("\u{21A9}\u{FE0E}")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#A8C5A0"), in: Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 60)
                .padding(.top, 4)

                // Rotating prompt
                HStack {
                    Text(prompts[promptIndex])
                        .font(.system(size: 15))
                        .italic()
                        .foregroundColor(Color(hex: "#7A7266"))
                    Spacer()
                    Button {
                        promptIndex = (promptIndex + 1) % prompts.count
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#7A7266"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 60)
                .padding(.trailing, 16)

                // Moments invitation — the blank page, softened (iOS 17.2+ only;
                // on older iOS the row never exists).
                if #available(iOS 17.2, *), momentsInviteEligible {
                    momentsInviteRow
                        .padding(.bottom, 6)
                }

                // Text editor
                ZStack(alignment: .topLeading) {
                    if composerText.isEmpty {
                        Text("today I...".localized)
                            .font(DinoTheme.inputFont(size: 17))
                            .foregroundColor(Color(hex: "#A8A29A"))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $composerText)
                        .font(DinoTheme.inputFont(size: 17))
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 140, maxHeight: 240)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)

                // Photo preview thumbnail
                if let image = selectedImage {
                    HStack {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#E8E4D5"), lineWidth: 1)
                                )

                            Button {
                                HapticManager.shared.light()
                                selectedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                        Spacer()
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
                }

                // Dashed divider
                DashedDivider()
                    .padding(.leading, 56)
                    .padding(.trailing, 16)

                // Action row
                HStack(alignment: .center, spacing: 14) {
                    // Mic — toggles live speech-to-text into composerText
                    ComposerActionButton(
                        system: isTranscribing ? "stop.fill" : "mic.fill",
                        bg: isTranscribing ? Color(hex: "#F5C6AA") : Color(hex: "#C7DEBB"),
                        stroke: isTranscribing ? Color.red : Color(hex: "#7BA872"),
                        disabled: false,
                        action: { toggleTranscription() }
                    )
                    .scaleEffect(micPulse)
                    .contentShape(Circle())

                    // Camera — opens action sheet (camera vs library)
                    ComposerActionButton(
                        system: "camera.fill",
                        bg: DinoTheme.paper,
                        stroke: DinoTheme.peach,
                        disabled: false,
                        action: { showCameraDialog = true }
                    )
                    .contentShape(Circle())

                    // Mood
                    ComposerActionButton(
                        system: selectedMood == nil ? "face.smiling" : "face.smiling.inverse",
                        bg: DinoTheme.paper,
                        stroke: DinoTheme.warmRose,
                        disabled: false,
                        action: { showMoodSheet = true }
                    )

                    Spacer()

                    // Develop pill — saves composerText as a journal entry
                    Button(action: {
                        // Stop transcription if running so we capture the
                        // final text before saving.
                        if isTranscribing {
                            transcriber.stop()
                            isTranscribing = false
                        }
                        let textToSave = composerText
                        let moodToSave = selectedMood
                        let imageToSave = selectedImage
                        let trimmed = textToSave.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            #if DEBUG
                            print("[Develop] Skipped: composer empty")
                            #endif
                            return
                        }
                        #if DEBUG
                        print("[Develop] Saving entry, chars=\(trimmed.count)")
                        #endif
                        HapticManager.shared.success()
                        onDevelop(textToSave, moodToSave, imageToSave)
                        composerText = ""
                        selectedMood = nil
                        selectedImage = nil
                    }) {
                        HStack(spacing: 6) {
                            Text("develop".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#2D4A2A"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#C7DEBB"), Color(hex: "#A8C5A0")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)
                .padding(.bottom, 4)
            }
            .padding(.vertical, 18)
        }
        .onAppear {
            startMicPulse()
        }
        .onDisappear {
            if isTranscribing {
                transcriber.stop()
                isTranscribing = false
            }
        }
        .onChange(of: transcriber.transcript) { _, newValue in
            // Stream live partial results into the composer text field.
            if isTranscribing {
                composerText = newValue
            }
        }
        .confirmationDialog(
            "add a photo",
            isPresented: $showCameraDialog,
            titleVisibility: .visible
        ) {
            Button("take photo".localized) { showCamera = true }
            Button("choose from library".localized) { showPhotoPicker = true }
            Button("cancel".localized, role: .cancel) { }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showCamera) {
            JournalCameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodSheet(selected: $selectedMood)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
    }

    private func toggleTranscription() {
        if isTranscribing {
            transcriber.stop()
            isTranscribing = false
            AnalyticsManager.shared.trackVoiceTranscriptionCompleted()
        } else {
            isTranscribing = true
            AnalyticsManager.shared.trackVoiceRecordingStarted()
            transcriber.start(initialText: composerText)
        }
    }

    private func startMicPulse() {
        guard !reduceMotion else { micPulse = 1.0; return }
        micPulse = 1.0
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            micPulse = 1.06
        }
    }
}

// MARK: - Composer Action Button
private struct ComposerActionButton: View {
    let system: String
    let bg: Color
    let stroke: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bg)
                    .overlay(
                        Circle().stroke(stroke, lineWidth: 1.5)
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: system)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(stroke)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Dashed Divider helper
private struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(Color(hex: "#7A7266").opacity(0.3))
        }
        .frame(height: 1)
    }
}

// MARK: - Timeline Strip
private struct JournalTimelineStrip: View {
    let entries: [JournalEntry]
    @ObservedObject var viewModel: JournalViewModel
    let onSeeAll: () -> Void
    var onTap: ((JournalEntry) -> Void)? = nil

    var body: some View {
        if entries.isEmpty {
            EmptyMemoriesCard()
        } else {
            ScrollView(.horizontal) {
                ZStack(alignment: .top) {
                    // String curve overlay
                    GeometryReader { geo in
                        Canvas { ctx, size in
                            var path = Path()
                            path.move(to: CGPoint(x: 20, y: 30))
                            path.addQuadCurve(
                                to: CGPoint(x: size.width - 20, y: 30),
                                control: CGPoint(x: size.width / 2, y: 60)
                            )
                            ctx.stroke(
                                path,
                                with: .color(Color(hex: "#8B5A3C").opacity(0.45)),
                                lineWidth: 1.5
                            )
                        }
                        .frame(width: geo.size.width, height: 60)
                    }
                    .frame(height: 60)
                    .allowsHitTesting(false)

                    HStack(spacing: 16) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                            JournalPolaroidCard(
                                entry: entry,
                                index: i,
                                viewModel: viewModel,
                                onTap: onTap
                            )
                        }

                        // See all card
                        SeeAllCard(count: entries.count, onTap: onSeeAll)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }
            .scrollIndicators(.hidden)
            .frame(minHeight: 260)
        }
    }
}

// MARK: - Empty memories
private struct EmptyMemoriesCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("no memories yet".localized)
                .font(DinoTheme.dinoHeaderFont(size: 18))
                .foregroundColor(DinoTheme.ink)
            Text("tap the mic to record your first")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(DinoTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DinoTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundColor(Color(hex: "#A8A29A").opacity(0.4))
                )
        )
    }
}

// MARK: - See All Card
private struct SeeAllCard: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundColor(Color(hex: "#A8A29A").opacity(0.4))
                .frame(width: 180, height: 228)
                .overlay(
                    Text("see all —\n\(count) memories →")
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(Color(hex: "#7A7266"))
                        .multilineTextAlignment(.center)
                )
                .rotationEffect(.degrees(1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Polaroid Card
struct JournalPolaroidCard: View {
    let entry: JournalEntry
    let index: Int
    @ObservedObject var viewModel: JournalViewModel
    var onTap: ((JournalEntry) -> Void)? = nil
    var preloadedPhoto: UIImage? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flipped: Bool = false  // front face shows first
    @State private var visible: Bool = false
    @State private var loadedPhoto: UIImage? = nil

    private var rotation: Double {
        let v = Double((entry.id.hashValue % 80) - 40) / 10.0
        return max(-4, min(4, v))
    }

    private var tapeRotation: Double {
        // Deterministic small tape rotation
        let v = Double((entry.id.hashValue % 14) - 7) * 0.5
        return v
    }

    /// Journal text truncated to ~80 chars for the vellum snippet bar
    private var snippetText: String {
        let summary = entry.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary.count > 80 ? String(summary.prefix(80)) + "\u{2026}" : summary
        }
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title.count > 80 ? String(title.prefix(80)) + "\u{2026}" : title
        }
        return String(localized: "voice note recorded")
    }

    /// Friendly lowercase caption with a decorative floral/seasonal suffix
    private var friendlyCaption: String {
        let base = entry.title.lowercased()
        let hour = Calendar.current.component(.hour, from: entry.date)
        let suffix: String
        switch hour {
        case 5..<12:  suffix = " ✿"
        case 12..<17: suffix = " ☀︎"
        case 17..<21: suffix = " ⋆"
        default:      suffix = " ◦"
        }
        return base + suffix
    }

    var body: some View {
        ZStack {
            // Front
            polaroidFront
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(flipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Back
            JournalPolaroidBack(entry: entry)
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(flipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(width: 180, height: 240)   // room for the boosted caption, photo + date included
        .rotationEffect(.degrees(rotation))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -30)
        .scaleEffect(visible ? 1 : 0.9)
        .onAppear {
            loadPhotoIfNeeded()
            if reduceMotion {
                visible = true
            } else {
                withAnimation(
                    .timingCurve(0.2, 0.9, 0.3, 1.15, duration: 0.9)
                    .delay(0.2 + Double(index) * 0.12)
                ) {
                    visible = true
                }
            }
        }
        .onTapGesture {
            HapticManager.shared.light()
            onTap?(entry)
        }
        .contextMenu {
            Button {
                viewModel.toggleFavorite(entry)
            } label: {
                Label(entry.isFavorite ? String(localized: "unfavorite") : String(localized: "favorite"),
                      systemImage: entry.isFavorite ? "star.slash" : "star")
            }
            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    private var polaroidFront: some View {
        ZStack(alignment: .top) {
            // Paper base
            RoundedRectangle(cornerRadius: 10)
                .fill(DinoTheme.paper)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)

            VStack(spacing: 10) {
                // Washi tape
                WashiTape(baseColor: moodTapeColor(entry.moodTag), width: 120, height: 22, rotation: tapeRotation)
                    .padding(.top, 6)

                // Photo region
                photoArea
                    .frame(width: 140, height: 140)

                // Caption — friendly lowercase title with floral accent
                Text(friendlyCaption)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#3D3A35"))
                    .lineLimit(loadedPhoto == nil ? 2 : 1)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                if loadedPhoto != nil {
                    Text(shortDate)
                        .font(DinoTheme.numericFont(size: 10))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "#A8A29A"))
                }

                Spacer(minLength: 0)
            }

            // Pushpin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#FF8C42"), Color(hex: "#B05A1F")],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .offset(y: -4)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            // Favorite star
            if entry.isFavorite {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DinoTheme.sunYellow)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
    }

    private var photoArea: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                if let photo = preloadedPhoto ?? loadedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipped()
                    // Soft vignette to match polaroid feel
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.22)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 95
                    )
                    .allowsHitTesting(false)

                    // Vellum overlay with journal summary
                    if !snippetText.isEmpty {
                        VStack {
                            Spacer()
                            Text(snippetText)
                                .font(DinoTheme.dinoFont(size: 11))
                                .foregroundColor(Color(hex: "#2E2A24"))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#FEFBF3").opacity(0.88))
                        }
                        .allowsHitTesting(false)
                    }
                } else {
                    ZStack {
                        moodPhotoGradient(entry.moodTag)
                        MoodVignette(kind: moodVignetteKind(entry.moodTag))
                    }

                    // Vellum snippet bar — shows truncated journal text (no-photo state)
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(DinoTheme.paper.opacity(0.82))
                            .frame(height: 24)
                            .overlay(
                                Text(snippetText)
                                    .font(DinoTheme.dinoFont(size: 11))
                                    .foregroundColor(Color(hex: "#3D3A35"))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 6),
                                alignment: .center
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.bottom, 4)
                            .padding(.horizontal, 0)
                    }
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#3C2814").opacity(0.08), lineWidth: 1)
            )

            // Mood emoji badge (only on photo state)
            if loadedPhoto != nil {
                Text(moodEmoji(entry.moodTag))
                    .font(.system(size: 15))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(DinoTheme.paper.opacity(0.92))
                            .overlay(Circle().stroke(Color(hex: "#3C2814").opacity(0.08), lineWidth: 1))
                            .shadow(color: Color(hex: "#3C2814").opacity(0.25), radius: 1.5, y: 1)
                    )
                    .padding(8)
            }
        }
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: entry.date).lowercased()
    }

    private func loadPhotoIfNeeded() {
        guard loadedPhoto == nil, let name = entry.photoFileName else { return }
        // Local first, then cloud — old photos reappear once storage sync has them.
        Task {
            if case .loaded(let img) = await JournalPhotoStore.fetchPhoto(name) {
                loadedPhoto = img
            }
        }
    }
}

// MARK: - Polaroid Back
private struct JournalPolaroidBack: View {
    let entry: JournalEntry

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: entry.date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#F4ECD8"))

            // Airmail stripe border (approximate)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.5),
                            Color.white.opacity(0.6),
                            Color.blue.opacity(0.5),
                            Color.red.opacity(0.5),
                            Color.white.opacity(0.6),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    // Postmark circle
                    Circle()
                        .stroke(Color(hex: "#A67074").opacity(0.4), lineWidth: 1)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("DINO")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Color(hex: "#A67074").opacity(0.5))
                        )

                    Spacer()

                    // Postage stamp
                    RoundedRectangle(cornerRadius: 2)
                        .fill(moodTapeColor(entry.moodTag))
                        .frame(width: 40, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                                )
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }

                Spacer().frame(height: 4)

                Text(dateString)
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(Color(hex: "#3D3A35"))

                HStack(spacing: 8) {
                    Text("mood: \(entry.moodTag.localized)")
                    if entry.durationSeconds > 0 {
                        Text("\u{00B7}")
                        Text(formatDuration(entry.durationSeconds))
                    } else {
                        Text("\u{00B7}")
                        Text("text entry")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#7A7266"))

                ScrollView {
                    Text(entry.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? String(localized: "voice note recorded")
                         : entry.summary)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .scrollIndicators(.hidden)

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(width: 180, height: 228)
    }
}

// MARK: - Mood Vignette
private struct MoodVignette: View {
    enum Kind { case sunny, partly, cloudy }
    let kind: Kind

    var body: some View {
        switch kind {
        case .sunny:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFD966"), Color(hex: "#F0A858")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Rays
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 3, height: 30)
                            .offset(y: -36)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                }
                Circle()
                    .fill(Color(hex: "#FFF2B3"))
                    .frame(width: 40, height: 40)
                // Layered hills (back: lighter sage, front: darker sage)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.75))
                        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.72),
                                       control: CGPoint(x: w * 0.25, y: h * 0.68))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.70),
                                       control: CGPoint(x: w * 0.75, y: h * 0.76))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#A8C5A0"))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.85))
                        p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.83),
                                       control: CGPoint(x: w * 0.30, y: h * 0.80))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.82),
                                       control: CGPoint(x: w * 0.80, y: h * 0.86))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#7BA872"))
                }
            }
        case .partly:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C0D4")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Small sun peeking
                Circle()
                    .fill(Color(hex: "#FFE9B8"))
                    .frame(width: 32, height: 32)
                    .offset(x: -30, y: -22)
                // Cloud
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 80, height: 34)
                    .offset(x: 12, y: 4)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 50, height: 24)
                    .offset(x: -8, y: 18)
                // Earthy horizons (back: warm tan, front: deeper umber)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.72))
                        p.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.68),
                                       control: CGPoint(x: w * 0.20, y: h * 0.65))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.66),
                                       control: CGPoint(x: w * 0.60, y: h * 0.71))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#C68B5B").opacity(0.55))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.82))
                        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.80),
                                       control: CGPoint(x: w * 0.25, y: h * 0.78))
                        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.78),
                                       control: CGPoint(x: w * 0.75, y: h * 0.82))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#8B5A3C").opacity(0.7))
                }
            }
        case .cloudy:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#B8C4D0"), Color(hex: "#8FA0B0")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Ellipse()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 70, height: 30)
                    .offset(x: -18, y: -14)
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 80, height: 34)
                    .offset(x: 14, y: 6)
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 60, height: 26)
                    .offset(x: -6, y: 24)
                // Dark green horizon strip
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.80))
                        p.addLine(to: CGPoint(x: w, y: h * 0.80))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "#6B8577").opacity(0.85))
                }
            }
        }
    }
}

// MARK: - Washi Tape
private struct WashiTape: View {
    let baseColor: Color
    let width: CGFloat
    let height: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseColor.opacity(0.85))
            Canvas { ctx, size in
                let spacing: CGFloat = 4
                let darker = baseColor.opacity(0.35)
                // diagonal lines at 45 deg
                let total = size.width + size.height
                var x: CGFloat = -size.height
                while x < total {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(path, with: .color(darker), lineWidth: 1)
                    x += spacing
                }
            }
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Mood helpers (file scope)
@MainActor
fileprivate func moodTapeColor(_ tag: String) -> Color {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright": return DinoTheme.peach
    case "calm", "peaceful", "reflective": return DinoTheme.skyBlue
    case "grateful", "warm": return DinoTheme.sunYellow
    case "anxious", "thoughtful", "dreamy": return DinoTheme.lavender
    case "sad", "low", "cloudy": return Color(hex: "#B8C4D0")
    default: return DinoTheme.streakSage
    }
}

@MainActor
fileprivate func moodPhotoGradient(_ tag: String) -> LinearGradient {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright":
        return LinearGradient(
            colors: [Color(hex: "#FFD966"), Color(hex: "#F5C6AA")],
            startPoint: .top, endPoint: .bottom
        )
    case "calm", "peaceful", "reflective":
        return LinearGradient(
            colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C5A0")],
            startPoint: .top, endPoint: .bottom
        )
    case "grateful", "warm":
        return LinearGradient(
            colors: [Color(hex: "#FFF2B3"), Color(hex: "#FFD966")],
            startPoint: .top, endPoint: .bottom
        )
    case "anxious", "thoughtful", "dreamy":
        return LinearGradient(
            colors: [Color(hex: "#C4B8D4"), Color(hex: "#A8D4E6")],
            startPoint: .top, endPoint: .bottom
        )
    case "sad", "low", "cloudy":
        return LinearGradient(
            colors: [Color(hex: "#B8C4D0"), Color(hex: "#8FA0B0")],
            startPoint: .top, endPoint: .bottom
        )
    default:
        return LinearGradient(
            colors: [Color(hex: "#C8D9E6"), Color(hex: "#A8C0D4")],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Journal Camera Picker (UIImagePickerController wrapper, .camera source)
private struct JournalCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: JournalCameraPicker
        init(_ parent: JournalCameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Picker (PHPickerViewController wrapper)
private struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.parent.image = image }
            }
        }
    }
}

// MARK: - Mood Sheet
private struct MoodSheet: View {
    @Binding var selected: String?
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, emoji: String)] = [
        ("happy", "😊"),
        ("calm", "🌿"),
        ("okay", "😐"),
        ("low", "🌧"),
        ("stressed", "⚡️")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("how are you feeling?".localized)
                .font(DinoTheme.dinoHeaderFont(size: 20))
                .foregroundColor(DinoTheme.ink)
                .padding(.top, 28)

            HStack(spacing: 10) {
                ForEach(options, id: \.label) { option in
                    Button {
                        selected = option.label
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji).font(.system(size: 32))
                            Text(option.label)
                                .font(DinoTheme.dinoFont(size: 12))
                                .foregroundColor(DinoTheme.muted)
                        }
                        .frame(width: 60, height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected == option.label
                                      ? Color(hex: "#C7DEBB").opacity(0.5)
                                      : DinoTheme.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "#A8A29A").opacity(0.25), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DinoTheme.paper)
    }
}

@MainActor
fileprivate func moodEmoji(_ tag: String) -> String {
    switch tag.lowercased() {
    case "happy", "joyful", "bright": return "😊"
    case "calm", "peaceful", "content": return "🌿"
    case "grateful", "warm": return "🌼"
    case "reflective", "thoughtful", "dreamy": return "✨"
    case "anxious", "stressed": return "⚡️"
    case "okay", "flat": return "😐"
    case "sad", "low": return "🌧"
    default: return "🌿"
    }
}

@MainActor
fileprivate func moodVignetteKind(_ tag: String) -> MoodVignette.Kind {
    switch tag.lowercased() {
    case "happy", "joyful", "sunny", "bright", "grateful", "warm":
        return .sunny
    case "sad", "low", "cloudy":
        return .cloudy
    default:
        return .partly
    }
}

// MARK: - Card Preview Overlay
struct JournalCardPreviewOverlay: View {
    let entry: JournalEntry
    @ObservedObject var viewModel: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: UIImage? = nil
    @State private var showShareSheet: Bool = false
    @State private var toast: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.75).ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                Spacer()
                JournalPolaroidCard(entry: entry, index: 0, viewModel: viewModel)
                    .frame(width: 320, height: 400)
                    .allowsHitTesting(false)

                if let toast = toast {
                    Text(toast)
                        .font(DinoTheme.dinoFont(size: 13))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.black.opacity(0.7), in: Capsule())
                        .foregroundColor(.white)
                }
                Spacer()
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                actionPill(label: String(localized: "save to photos 📸")) {
                    saveToPhotos()
                }
                actionPill(label: String(localized: "share 🔗")) {
                    shareCard()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image, String(localized: "my dino journal entry \u{1F995}\u{1F33F} #dino #mentalhealth #wellness")])
            }
        }
    }

    @ViewBuilder
    private func actionPill(label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            Text(label)
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#A8C5A0"), in: Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func render() -> UIImage? {
        var photoImage: UIImage? = nil
        if let fileName = entry.photoFileName {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            photoImage = UIImage(contentsOfFile: url.path)
        }

        let card = JournalPolaroidCard(
            entry: entry,
            index: 0,
            viewModel: viewModel,
            preloadedPhoto: photoImage
        )
        .frame(width: 320, height: 400)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    private func saveToPhotos() {
        guard let image = render() else { return }
        renderedImage = image
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        toast = String(localized: "saved to photos")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = nil }
    }

    private func shareCard() {
        guard let image = render() else { return }
        renderedImage = image
        showShareSheet = true
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
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
