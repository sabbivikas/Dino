//
//  SpeechTranscriber.swift
//  Dino
//
//  Live speech-to-text using SFSpeechRecognizer + AVAudioEngine.
//  Streams partial results into `transcript` for SwiftUI binding.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRunning: Bool = false
    @Published var authorizationDenied: Bool = false
    @Published var lastError: String? = nil

    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Text that was committed before the current `start()` session began.
    /// New partial results are appended onto this so we don't clobber
    /// existing composer text.
    private var baseText: String = ""

    func start(initialText: String = "") {
        guard !isRunning else { return }
        baseText = initialText

        requestAuthorization { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.authorizationDenied = true
                return
            }
            self.beginSession()
        }
    }

    func stop() {
        guard isRunning else { return }
        // Remove the tap BEFORE stopping the engine so no in-flight buffer
        // callback can race the teardown on the audio I/O thread.
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine.stop()
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
        isRunning = false

        // Reset audio session so we don't leave duck/record state on — but only
        // when ambient audio isn't mid-playback on the shared session.
        if !AudioManager.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Private

    private func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            let speechOK = (speechStatus == .authorized)
            AVAudioSession.sharedInstance().requestRecordPermission { micOK in
                DispatchQueue.main.async {
                    completion(speechOK && micOK)
                }
            }
        }
    }

    private func beginSession() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            self.lastError = "Speech recognizer unavailable"
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.lastError = "Audio session: \(error.localizedDescription)"
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Install tap to feed audio buffers into the recognizer.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.lastError = "Audio engine: \(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            return
        }

        isRunning = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let spoken = result.bestTranscription.formattedString
                Task { @MainActor in
                    let separator = self.baseText.isEmpty ? "" : (self.baseText.hasSuffix(" ") ? "" : " ")
                    self.transcript = self.baseText + separator + spoken
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.stop()
                }
            }
        }
    }
}
