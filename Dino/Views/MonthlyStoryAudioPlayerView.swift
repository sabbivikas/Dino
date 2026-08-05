import SwiftUI

struct MonthlyStoryAudioPlayerView: View {
    @ObservedObject var player: MonthlyStoryAudioPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform").foregroundStyle(DinoTheme.sageGreen).accessibilityHidden(true)
                Text("spoken version").font(DinoTheme.headlineFont()).foregroundStyle(DinoTheme.textPrimary)
                Spacer()
            }
            content
        }
        .padding(18)
        .background(DinoTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(DinoTheme.cardBorder, lineWidth: 1) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var content: some View {
        switch player.state {
        case .disabled:
            Text("turn on spoken stories in your monthly story choices if you would like to create one.")
                .font(DinoTheme.subheadlineFont()).foregroundStyle(DinoTheme.textSecondary)
        case .readyToCreate:
            Button("create spoken version") { Task { await player.createAudio() } }
                .buttonStyle(.borderedProminent).tint(DinoTheme.sageGreen)
                .frame(minHeight: 44).accessibilityHint("Creates private audio from this written story.")
        case .generating, .loading:
            HStack(spacing: 12) { ProgressView(); Text(player.state == .generating ?
                "creating your spoken story…" : "opening your spoken story…") }
                .accessibilityElement(children: .combine).accessibilityLabel("spoken story loading")
        case .ready, .playing, .paused:
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button { Task { await player.togglePlayback() } } label: {
                        Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(player.state == .playing ? "pause spoken story" : "play spoken story")
                    Slider(value: Binding(get: { player.elapsed }, set: { player.seek(to: $0) }),
                           in: 0...max(player.duration, 1))
                        .accessibilityLabel("spoken story progress")
                        .accessibilityValue("\(time(player.elapsed)) of \(time(player.duration))")
                    Button { player.replay() } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                    }.accessibilityLabel("replay spoken story")
                }
                HStack { Text(time(player.elapsed)); Spacer(); Text(time(player.duration)) }
                    .font(.caption.monospacedDigit()).foregroundStyle(DinoTheme.textSecondary)
            }
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                Text("the spoken version is unavailable. your written story is still here.")
                    .font(DinoTheme.subheadlineFont()).foregroundStyle(DinoTheme.textSecondary)
                Button("try spoken version again") { Task { await player.createAudio() } }.frame(minHeight: 44)
            }
        case .deleted:
            Text("spoken story removed").foregroundStyle(DinoTheme.textSecondary)
        }
    }

    private func time(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
