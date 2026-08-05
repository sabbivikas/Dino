import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor protocol MonthlyStoryPlaybackEngine: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    func prepareToPlay()
    func play()
    func pause()
    func stop()
}

@MainActor final class AVMonthlyStoryPlaybackEngine: MonthlyStoryPlaybackEngine {
    private let player: AVAudioPlayer
    init(url: URL) throws { player = try AVAudioPlayer(contentsOf: url) }
    var isPlaying: Bool { player.isPlaying }
    var currentTime: TimeInterval { get { player.currentTime } set { player.currentTime = newValue } }
    var duration: TimeInterval { player.duration }
    func prepareToPlay() { player.prepareToPlay() }
    func play() { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }
}

@MainActor
final class MonthlyStoryAudioPlayer: ObservableObject {
    enum State: Equatable { case disabled, readyToCreate, generating, loading, ready, playing, paused, failed, deleted }
    @Published private(set) var state: State
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var story: MonthlyStoryDocument

    private let service: any MonthlyStoryAudioService
    private var player: (any MonthlyStoryPlaybackEngine)?
    private let engineFactory: @MainActor (URL) throws -> any MonthlyStoryPlaybackEngine
    private var progressTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(story: MonthlyStoryDocument, audioOptIn: Bool, service: any MonthlyStoryAudioService,
         engineFactory: @escaping @MainActor (URL) throws -> any MonthlyStoryPlaybackEngine = {
            try AVMonthlyStoryPlaybackEngine(url: $0)
         }) {
        self.story = story; self.service = service
        self.engineFactory = engineFactory
        state = !audioOptIn && story.audioState != .ready ? .disabled :
            (story.audioState == .ready ? .ready : story.audioState == .generating ? .generating :
                story.audioState == .failed ? .failed : .readyToCreate)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
        })
    }

    deinit {
        progressTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func createAudio() async {
        guard state == .readyToCreate || state == .failed else { return }
        state = .generating
        do { story = try await service.requestAudio(for: story); try await load(); state = .ready }
        catch { state = .failed }
    }

    func load() async throws {
        guard story.audioState == .ready else { throw MonthlyStoryAudioClientError.unavailable }
        state = .loading
        let url = try await service.playableURL(for: story)
        let audio = try engineFactory(url); audio.prepareToPlay()
        player = audio; duration = audio.duration; elapsed = audio.currentTime; state = .ready
    }

    func togglePlayback() async {
        if player == nil { do { try await load() } catch { state = .failed; return } }
        guard let player else { return }
        if player.isPlaying { pause() } else {
            do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true) } catch { state = .failed; return }
            player.play(); state = .playing; startProgress()
        }
    }
    func pause() { guard let player, player.isPlaying else { return }; player.pause(); elapsed = player.currentTime; state = .paused }
    func seek(to value: TimeInterval) { player?.currentTime = min(max(0, value), duration); elapsed = player?.currentTime ?? value }
    func replay() {
        seek(to: 0)
        if player?.isPlaying == true {
            state = .playing
            startProgress()
        } else {
            Task { await togglePlayback() }
        }
    }
    func markDeleted() { player?.stop(); player = nil; progressTask?.cancel(); state = .deleted }
    private func startProgress() {
        progressTask?.cancel(); progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                guard self.player?.isPlaying == true else {
                    if self.elapsed >= max(0, self.duration - 0.25) { self.elapsed = self.duration; self.state = .ready }
                    return
                }
                self.elapsed = self.player?.currentTime ?? 0
            }
        }
    }
}
