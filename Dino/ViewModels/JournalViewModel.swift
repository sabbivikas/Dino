//
//  JournalViewModel.swift
//  Dino
//

import SwiftUI
import AVFoundation
import Combine
import PostHog

@MainActor
class JournalViewModel: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var playingEntryId: UUID? = nil
    @Published var recordingDuration: TimeInterval = 0
    @Published var permissionDenied: Bool = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Recording
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        let fileName = "journal_\(UUID().uuidString).m4a"
        let url = dataManager.audioFileURL(for: fileName)
        currentRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            // Apply file protection + exclude from iCloud backup for the recording.
            var protectedURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? protectedURL.setResourceValues(values)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.recordingDuration += 1.0
                }
            }
        } catch {
            #if DEBUG
            print("Recording failed")
            #endif
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        guard let url = currentRecordingURL else { return }

        let fileName = url.lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateStr = dateFormatter.string(from: Date())
        let title = "journal entry — \(dateStr)"

        let entry = JournalEntry(
            audioFileName: fileName,
            title: title,
            summary: "voice note recorded",
            moodTag: "reflective",
            durationSeconds: recordingDuration
        )
        dataManager.addJournalEntry(entry)
        AnalyticsManager.shared.trackJournalEntryCreated(type: "voice")
        recordingDuration = 0
        currentRecordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Playback
    func playEntry(_ entry: JournalEntry) {
        if isPlaying && playingEntryId == entry.id {
            stopPlayback()
            return
        }

        let url = dataManager.audioFileURL(for: entry.audioFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            playingEntryId = entry.id
        } catch {
            #if DEBUG
            print("Playback failed")
            #endif
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingEntryId = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func deleteEntry(_ entry: JournalEntry) {
        if playingEntryId == entry.id {
            stopPlayback()
        }
        dataManager.deleteJournalEntry(entry)
    }

    func toggleFavorite(_ entry: JournalEntry) {
        dataManager.toggleFavoriteJournal(entry)
    }

    var formattedRecordingDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

extension JournalViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playingEntryId = nil
        }
    }
}
