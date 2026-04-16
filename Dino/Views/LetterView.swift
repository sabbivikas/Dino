//
//  LetterView.swift
//  Dino
//

import SwiftUI

struct LetterView: View {
    var onContinue: () -> Void

    @State private var displayedText = ""
    @State private var showCursor = true
    @State private var showButton = false

    private let fullText = "hey, you.\n\nthe fact that you're here means something.\nmaybe things feel heavy. maybe you're just curious.\neither way — you showed up. that matters.\n\ndino is your space.\nno pressure. no judgment.\njust a place to breathe, reflect, and grow.\n\nlet's take this one step at a time."

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Letter text with typewriter effect
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayedText)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundColor(Color(hex: "2D3142"))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                        + Text(showCursor ? "|" : " ")
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundColor(Color(hex: "A8C5A0"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)

                Spacer()

                // Continue button
                if showButton {
                    Button(action: onContinue) {
                        Text("continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                        // Skip typewriter, show full text
                        displayedText = fullText
                        withAnimation { showButton = true }
                    } label: {
                        Text("skip")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            startTypewriter()
            // Blinking cursor
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                showCursor.toggle()
            }
        }
    }

    private func startTypewriter() {
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if index < fullText.count {
                let i = fullText.index(fullText.startIndex, offsetBy: index)
                displayedText.append(fullText[i])
                index += 1
            } else {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.5)) {
                    showButton = true
                }
            }
        }
    }
}
