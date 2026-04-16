//
//  AudioManager.swift
//  Dino
//
//  Singleton audio manager for ambient background music playback.
//  Uses AVAudioPlayer with .ambient category — mixes with other audio,
//  respects silent mode, and loops seamlessly during sessions.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AudioManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AudioManager()

    // MARK: - Published State
    @Published var isPlaying: Bool = false
    @Published var currentTrack: String?
    @Published var volume: Float = 0.5

    // MARK: - Private
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    private init() {
        configureAudioSession()
    }

    // MARK: - Session Configuration

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal — audio may simply not play if the session fails
            print("[AudioManager] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Playback

    /// Load and play a named MP3 from the main bundle.
    /// - Parameters:
    ///   - track: Filename without extension (e.g. "meditation_ambient")
    ///   - loop: Whether to loop continuously (default: true)
    func play(track: String, loop: Bool = true) {
        // Stop existing playback cleanly before switching tracks
        cancelFade()
        player?.stop()

        guard let url = Bundle.main.url(forResource: track, withExtension: "mp3") else {
            print("[AudioManager] Could not find track: \(track).mp3")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = loop ? -1 : 0
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
            currentTrack = track
            isPlaying = true
        } catch {
            print("[AudioManager] Failed to create player for \(track): \(error)")
        }
    }

    /// Stop playback with a 1-second fade out.
    func stop() {
        guard isPlaying else { return }
        fadeOut(duration: 1.0)
    }

    /// Pause playback immediately.
    func pause() {
        cancelFade()
        player?.pause()
        isPlaying = false
    }

    /// Resume paused playback.
    func resume() {
        guard let player, !player.isPlaying else { return }
        player.play()
        isPlaying = true
    }

    /// Set playback volume (0.0 – 1.0). Updates both stored value and live player.
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }

    // MARK: - Fades

    /// Fade in from silence to current `volume` over `duration` seconds.
    func fadeIn(duration: TimeInterval = 2.0) {
        guard let player, player.isPlaying else { return }
        cancelFade()
        player.volume = 0
        let targetVolume = volume
        let steps: Int = Int(duration * 30)  // ~30fps
        let interval = duration / Double(steps)
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let fraction = Float(step) / Float(steps)
            Task { @MainActor in
                self.player?.volume = targetVolume * fraction
            }
            if step >= steps {
                timer.invalidate()
                Task { @MainActor in
                    self.fadeTimer = nil
                    self.player?.volume = targetVolume
                }
            }
        }
    }

    /// Fade out to silence over `duration` seconds, then stop the player.
    func fadeOut(duration: TimeInterval = 2.0) {
        guard let player, player.isPlaying else {
            player?.stop()
            isPlaying = false
            currentTrack = nil
            return
        }
        cancelFade()
        let startVolume = player.volume
        let steps: Int = max(1, Int(duration * 30))
        let interval = duration / Double(steps)
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let fraction = Float(step) / Float(steps)
            Task { @MainActor in
                self.player?.volume = startVolume * (1.0 - fraction)
            }
            if step >= steps {
                timer.invalidate()
                Task { @MainActor in
                    self.fadeTimer = nil
                    self.player?.stop()
                    self.isPlaying = false
                    self.currentTrack = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
