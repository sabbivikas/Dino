//
//  DinoMeditationVideoView.swift
//  Dino
//
//  Looping muted video player for the meditation screen,
//  controlled externally via isPlaying and isPaused bindings.
//

import SwiftUI
import AVFoundation

struct DinoMeditationVideoView: UIViewRepresentable {
    let isPlaying: Bool
    let isPaused: Bool

    func makeUIView(context: Context) -> MeditationPlayerView {
        let view = MeditationPlayerView()
        view.setupPlayer()
        return view
    }

    func updateUIView(_ uiView: MeditationPlayerView, context: Context) {
        uiView.syncPlayback(isPlaying: isPlaying, isPaused: isPaused)
    }
}

class MeditationPlayerView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var loopObserver: NSObjectProtocol?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "dino_meditation", withExtension: "mov") else {
            print("[DinoMeditationVideo] dino_meditation.mov not found in bundle")
            return
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        self.player = player

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer

        // Loop: seek back to start when video ends
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // Show first frame as still
        player.seek(to: .zero)
        player.pause()
    }

    func syncPlayback(isPlaying: Bool, isPaused: Bool) {
        guard let player = player else { return }

        if !isPlaying {
            // Session not started or ended — show first frame
            player.pause()
            player.seek(to: .zero)
        } else if isPaused {
            player.pause()
        } else {
            player.play()
        }
    }

    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
