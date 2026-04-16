//
//  FloatingAddButton.swift
//  Dino
//

import SwiftUI

struct FloatingAddButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(DinoTheme.sageGreen)
                .clipShape(Circle())
                .shadow(color: DinoTheme.sageGreen.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
