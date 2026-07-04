//
//  LanternReceivedCard.swift
//  Dino
//
//  A received lantern drifting down after a heavy mood — the words, the
//  country, a report option, and nothing else. No sender, ever.
//

import SwiftUI

struct LanternReceivedCard: View {
    let lantern: ReceivedLantern
    let onClose: () -> Void

    @State private var visible = false
    @State private var showReportConfirm = false

    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 14) {
                Text("🏮").font(.system(size: 40))
                    .shadow(color: peach.opacity(0.9), radius: 12)

                Text("a dino in \(LanternService.countryName(lantern.countryCode)) left this for you:")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(ink2)
                    .multilineTextAlignment(.center)

                Text("\u{201C}\(lantern.text)\u{201D}")
                    .font(.custom(DinoTheme.customFontName, size: 19))
                    .foregroundColor(ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 6)

                Button { close() } label: {
                    Text("keep it close 🌱")
                        .font(DinoTheme.dinoFont(size: 15)).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 11)
                        .background(Capsule().fill(sage))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { showReportConfirm = true } label: {
                    Text("report this lantern")
                        .font(DinoTheme.dinoFont(size: 11)).foregroundColor(ink3)
                }
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "#FEFBF3")))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(peach.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .offset(y: visible ? 0 : -500)   // drifts down from above
            .opacity(visible ? 1 : 0)
        }
        .animation(.spring(response: 0.9, dampingFraction: 0.8), value: visible)
        .onAppear { visible = true }
        .confirmationDialog("report this lantern?", isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button("report", role: .destructive) {
                Task { await LanternService.report(lantern) }
                close()
            }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("dino will take a look and keep the skies kind")
        }
    }

    private func close() {
        visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onClose() }
    }
}
