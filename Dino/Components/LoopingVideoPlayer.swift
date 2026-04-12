//
//  LoopingVideoPlayer.swift
//  Dino
//

import SwiftUI
import UIKit
import AVKit
import AVFoundation

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.setupPlayer(videoName: videoName, videoExtension: videoExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {}
}

class LoopingPlayerView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func setupPlayer(videoName: String, videoExtension: String) {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        self.queuePlayer = queuePlayer

        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.playerLayer = layer

        queuePlayer.isMuted = true
        queuePlayer.play()
    }


}
