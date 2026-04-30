//
//  LetterView.swift
//  Dino
//

import SwiftUI

struct LetterView: View {
    var onContinue: () -> Void

    private let audioManager = AudioManager.shared

    @State private var displayedText = ""
    @State private var showCursor = true
    @State private var showButton = false
    @State private var typewriterTask: Task<Void, Never>?
    @State private var cursorTimer: Timer?

    private let fullText = "hey, you.\n\nthe fact that you're here means something.\nmaybe things feel heavy. maybe you're just curious.\neither way, you showed up. that matters.\n\ndino is your space.\nno pressure. no judgment.\njust a place to breathe, reflect, and grow.\n\nlet's take this one step at a time."

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Letter text with typewriter effect
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        (Text(displayedText)
                            .font(DinoTheme.dinoFont(size: 18))
                            .foregroundColor(Color(hex: "2D3142"))
                        + Text(showCursor ? "|" : " ")
                            .font(DinoTheme.dinoFont(size: 18))
                            .foregroundColor(Color(hex: "A8C5A0")))
                        .lineSpacing(8)
                        .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)

                Spacer()

                // Continue button
                if showButton {
                    Button(action: onContinue) {
                        Text("continue")
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(hex: "A8C5A0"))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Skip button (visible immediately)
                if !showButton {
                    Button {
                        typewriterTask?.cancel()
                        displayedText = fullText
                        withAnimation { showButton = true }
                    } label: {
                        Text("skip")
                            .font(DinoTheme.dinoFont(size: 15))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            // Start ambient music with fade in
            audioManager.play(track: "letter_ambient", playback: false)
            audioManager.fadeIn(duration: 3.0)

            startTypewriter()
            // Blinking cursor
            cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                showCursor.toggle()
            }
        }
        .onDisappear {
            audioManager.fadeOut(duration: 2.0)
            cursorTimer?.invalidate()
            cursorTimer = nil
            typewriterTask?.cancel()
        }
    }

    private func startTypewriter() {
        typewriterTask = Task {
            for (i, char) in fullText.enumerated() {
                if Task.isCancelled { return }

                displayedText.append(char)

                // Natural pacing: pause longer on punctuation and line breaks
                if char == "\n" {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s for line breaks
                } else if char == "." || char == "," {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s for punctuation
                } else {
                    try? await Task.sleep(nanoseconds: 55_000_000)  // 0.055s per character
                }
            }

            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showButton = true
                }
            }
        }
    }
}
