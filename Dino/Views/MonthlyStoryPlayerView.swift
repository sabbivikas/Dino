import SwiftUI

/// The monthly story as a full page rather than a card: paper, a taped record card with one
/// large play button, and the transcript open underneath.
///
/// Deliberately not the system playback look. No `Slider`, no `.borderedProminent`, no
/// `ContentUnavailableView` — those read as iOS chrome dropped into a room that is made of
/// paper and handwriting everywhere else.
///
/// There is no chapter list and no playback speed. Chapters would need per-paragraph timing the
/// pipeline does not produce, so their timestamps would be word-count guesses printed as facts;
/// the transcript highlight does the same navigation without claiming precision. Speed belongs
/// to podcasts you are trying to get through, which is not what this is.
struct MonthlyStoryPlayerView: View {
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MonthlyStoryReaderModel
    @StateObject private var player: MonthlyStoryAudioPlayer
    @State private var showsDeleteConfirmation = false

    private let story: MonthlyStoryDocument

    init(story: MonthlyStoryDocument,
         service: any MonthlyStoryClientService,
         audioService: any MonthlyStoryAudioService = InMemoryMonthlyStoryAudioService(),
         audioOptIn: Bool = false,
         onDeleted: @escaping () -> Void) {
        self.story = story
        self.onDeleted = onDeleted
        _model = StateObject(wrappedValue: MonthlyStoryReaderModel(story: story, service: service,
                                                                   audioService: audioService))
        _player = StateObject(wrappedValue: MonthlyStoryAudioPlayer(story: story,
                                                                    audioOptIn: audioOptIn,
                                                                    service: audioService))
    }

    // MARK: - Derived

    private var spans: [MonthlyStoryParagraphSpan] {
        MonthlyStoryParagraphTiming.spans(paragraphs: story.paragraphs, duration: player.duration)
    }

    private var activeParagraph: Int? {
        guard isPlayable, player.duration > 0 else { return nil }
        return MonthlyStoryParagraphTiming.index(at: player.elapsed, in: spans)
    }

    /// "july 2026" split so the year can be set in a face that actually has digits.
    private var monthWord: String {
        story.displayMonth.lowercased().split(separator: " ").first.map(String.init)
            ?? story.displayMonth.lowercased()
    }

    private var yearWord: String {
        let parts = story.displayMonth.split(separator: " ")
        return parts.count > 1 ? String(parts[1]) : ""
    }

    /// Audio exists and can be scrubbed.
    private var isPlayable: Bool {
        switch player.state {
        case .ready, .playing, .paused: true
        default: false
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            StoryPaperBackground()
            if model.state == .deleted {
                removedBody
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        recordCard
                        transcript
                    }
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 72)
                }
            }
        }
        .overlay(alignment: .top) { navigationBar }
        .task { await model.refreshRemoteAvailability() }
        .confirmationDialog("delete this story?", isPresented: $showsDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("delete story", role: .destructive) {
                Task {
                    await model.deleteStory()
                    if model.state == .deleted { player.markDeleted(); onDeleted() }
                }
            }
            Button("keep story", role: .cancel) {}
        } message: {
            Text("the written story and its private spoken version will be removed. it will not be regenerated for this month in this version of dino.")
        }
        .alert("couldn't delete story", isPresented: $model.showsDeletionError) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("your story is still here. please try again later.")
        }
    }

    // MARK: - Chrome

    private var navigationBar: some View {
        HStack {
            discButton("chevron.left", label: "back") { dismiss() }
            Spacer()
            if model.state != .deleted {
                discButton("trash", label: "delete this monthly story") { showsDeleteConfirmation = true }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func discButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#6B5A3C"))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(hex: "#FFFDF6"))
                    .overlay(Circle().stroke(Color(hex: "#EFE7D2"), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("your monthly story")
                .font(DinoTheme.captionFont())
                .foregroundStyle(Color(hex: "#A8886B"))
                .textCase(.uppercase)
                .tracking(1.4)
            // DinoInitiativeFont has no digits, so a plain "july 2026" at 40pt renders the year
            // in a fallback face and reads as a mistake. Setting the year deliberately in serif,
            // a size down and baseline-aligned, makes the pairing look chosen instead.
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(monthWord)
                    .font(DinoTheme.dinoDisplayFont(size: 40))
                Text(yearWord)
                    .font(DinoTheme.serifFont(size: 29))
            }
            .foregroundStyle(Color(hex: "#4A3520"))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your \(story.displayMonth) monthly story")
    }

    // MARK: - The taped record card

    private var recordCard: some View {
        VStack(spacing: 18) {
            hero
            if isPlayable { scrubber }
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 34, leading: 22, bottom: 26, trailing: 22))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#FFFDF6"))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 15 / 255).opacity(0.10),
                        radius: 13, y: 10)
        )
        .overlay(alignment: .top) {
            StoryWashiTape().offset(y: -13)
        }
        .rotationEffect(.degrees(-1.1))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var hero: some View {
        switch player.state {
        case .disabled:
            quietLine("spoken stories are turned off. you can turn them on in your monthly story choices.")
        case .readyToCreate:
            heroButton(symbol: "waveform", label: "create the spoken version",
                       accessibility: "create the spoken version of this story") {
                await player.createAudio()
            }
        case .generating, .loading:
            VStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: "#7BA872").opacity(0.16))
                    .frame(width: 96, height: 96)
                    .overlay { ProgressView().tint(Color(hex: "#7BA872")) }
                Text(player.state == .generating ? "making your spoken story…" : "opening it…")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundStyle(Color(hex: "#8B7A5C"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("spoken story loading")
        case .ready, .paused:
            heroButton(symbol: "play.fill", label: nil, accessibility: "play spoken story") {
                await player.togglePlayback()
            }
        case .playing:
            heroButton(symbol: "pause.fill", label: nil, accessibility: "pause spoken story") {
                await player.togglePlayback()
            }
        case .failed:
            heroButton(symbol: "arrow.clockwise", label: "try again",
                       accessibility: "try creating the spoken version again") {
                await player.createAudio()
            }
        case .deleted:
            quietLine("the spoken version was removed.")
        }
    }

    private func heroButton(symbol: String, label: String?, accessibility: String,
                            action: @escaping () async -> Void) -> some View {
        VStack(spacing: 12) {
            Button { Task { await action() } } label: {
                Circle()
                    .fill(Color(hex: "#7BA872"))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color(hex: "#FFFDF6"))
                            // play glyphs sit optically left of centre; nudge it back
                            .offset(x: symbol == "play.fill" ? 3 : 0)
                    }
                    .shadow(color: Color(hex: "#7BA872").opacity(0.34), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibility)

            if let label {
                Text(label)
                    .font(DinoTheme.subheadlineFont())
                    .foregroundStyle(Color(hex: "#8B7A5C"))
            }
        }
    }

    private func quietLine(_ text: String) -> some View {
        Text(text)
            .font(DinoTheme.subheadlineFont())
            .foregroundStyle(Color(hex: "#8B7A5C"))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
    }

    private var scrubber: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = player.duration > 0
                    ? min(max(player.elapsed / player.duration, 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#EFE7D2")).frame(height: 5)
                    Capsule().fill(Color(hex: "#7BA872")).frame(width: width * progress, height: 5)
                    Circle()
                        .fill(Color(hex: "#FFFDF6"))
                        .overlay(Circle().stroke(Color(hex: "#7BA872"), lineWidth: 2.5))
                        .frame(width: 16, height: 16)
                        .offset(x: max(0, width * progress - 8))
                        .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 15 / 255).opacity(0.14),
                                radius: 2, y: 1)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard player.duration > 0, width > 0 else { return }
                            player.seek(to: min(max(value.location.x / width, 0), 1) * player.duration)
                        }
                )
            }
            .frame(height: 24)
            .accessibilityElement()
            .accessibilityLabel("spoken story progress")
            .accessibilityValue("\(spoken(player.elapsed)) of \(spoken(player.duration))")
            .accessibilityAdjustableAction { direction in
                let step: TimeInterval = direction == .increment ? 15 : -15
                player.seek(to: player.elapsed + step)
            }

            HStack {
                Text(clock(player.elapsed))
                Spacer()
                Text("−" + clock(max(0, player.duration - player.elapsed)))
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color(hex: "#A8886B"))
            .accessibilityHidden(true)
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("the story")
                .font(DinoTheme.dinoHeaderFont(size: 20))
                .foregroundStyle(Color(hex: "#6B5A3C"))

            ForEach(Array(story.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphRow(index: index, paragraph: paragraph)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func paragraphRow(index: Int, paragraph: String) -> some View {
        let isActive = activeParagraph == index
        return HStack(alignment: .top, spacing: 13) {
            // The sage rule is the only progress marker in the transcript. It moves on an
            // estimate, so it is a soft indicator and never a timestamp.
            Capsule()
                .fill(isActive ? Color(hex: "#7BA872") : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            Text(paragraph)
                .font(DinoTheme.serifFont(size: 19))
                .foregroundStyle(Color(hex: isActive ? "#3D3A35" : "#4A3520").opacity(isActive ? 1 : 0.82))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 2)
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .contentShape(Rectangle())
        .onTapGesture { Task { await startReading(at: index) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paragraph \(index + 1). \(paragraph)")
        .accessibilityHint(canSeek ? "Double tap to listen from here." : "")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var canSeek: Bool {
        switch player.state {
        case .ready, .playing, .paused: true
        default: false
        }
    }

    /// Tapping a paragraph starts the spoken story around it. The landing point is the same
    /// estimate the highlight uses; without a printed timestamp beside it there is nothing
    /// claiming it is exact.
    private func startReading(at index: Int) async {
        guard canSeek else { return }
        guard let span = spans.first(where: { $0.index == index }) else { return }
        if player.state != .playing { await player.togglePlayback() }
        player.seek(to: span.start)
    }

    // MARK: - Removed

    private var removedBody: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(hex: "#7BA872"))
            Text("story removed")
                .font(DinoTheme.dinoHeaderFont(size: 22))
                .foregroundStyle(Color(hex: "#4A3520"))
            Text("this month's story will not be recreated.")
                .font(DinoTheme.subheadlineFont())
                .foregroundStyle(Color(hex: "#8B7A5C"))
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Monthly story removed. It will not be recreated.")
    }

    // MARK: - Formatting

    private func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0 seconds" }
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        if minutes == 0 { return "\(remainder) seconds" }
        return "\(minutes) minutes \(remainder) seconds"
    }
}
