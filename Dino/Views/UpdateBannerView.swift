//
//  UpdateBannerView.swift
//  Dino
//

import SwiftUI

struct UpdateBannerView: View {
    @ObservedObject private var service = AppUpdateService.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        if service.updateAvailable && !service.bannerDismissed {
            HStack(spacing: 12) {
                Image.cached("DinoMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("dino got an update")
                        .font(.custom(DinoTheme.customFontName, size: 14))
                        .foregroundColor(Color(hex: "#2E2A24"))
                    Text("new features waiting for you")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(Color(hex: "#7A7266"))
                }

                Spacer()

                Button {
                    HapticManager.shared.light()
                    if let url = service.appStoreURL {
                        openURL(url)
                    }
                } label: {
                    Text("update")
                        .font(.custom(DinoTheme.customFontName, size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#A8C5A0"), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        service.dismissBanner()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#A8A29A"))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#FAF6EC"))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 84)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
