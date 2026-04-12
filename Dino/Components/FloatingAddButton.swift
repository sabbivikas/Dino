//
//  FloatingAddButton.swift
//  Dino
//

import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(DinoTheme.sageGreen)
                .clipShape(Circle())
                .shadow(color: DinoTheme.sageGreen.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
