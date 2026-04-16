//
//  SignInView.swift
//  Dino
//

import SwiftUI

struct SignInView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var authManager: AuthManager

    @State private var heartOffset1: CGFloat = 0
    @State private var heartOffset2: CGFloat = 0
    @State private var heartOpacity1: Double = 0.7
    @State private var heartOpacity2: Double = 0.7

    var body: some View {
        ZStack {
            DinoTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App name + subtitle
                VStack(spacing: 8) {
                    Text("dino")
                        .font(DinoTheme.dinoDisplayFont(size: 44))
                        .foregroundColor(DinoTheme.textPrimary)

                    Text("your one stop mental wellness app ❤️")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Dino mascot with floating hearts
                ZStack {
                    Text("💜")
                        .font(.system(size: 24))
                        .offset(x: -55, y: heartOffset1 - 30)
                        .opacity(heartOpacity1)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: heartOffset1
                        )

                    Text("❤️")
                        .font(.system(size: 20))
                        .offset(x: 60, y: heartOffset2 - 20)
                        .opacity(heartOpacity2)
                        .animation(
                            .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                            value: heartOffset2
                        )

                    Image("DinoMascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                }
                .frame(height: 160)
                .onAppear {
                    heartOffset1 = -20
                    heartOffset2 = -15
                    heartOpacity1 = 0.4
                    heartOpacity2 = 0.4
                }

                Spacer()

                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.bottom, 8)
                }

                // Sign-in buttons
                VStack(spacing: 14) {
                    // Continue with Google
                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                            // Small delay to let auth state listener fire
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            if authManager.isSignedIn {
                                dataManager.userName = authManager.displayName
                                dataManager.isSignedIn = true
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(DinoTheme.textSecondary)
                                    .scaleEffect(0.8)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 22, height: 22)
                                    Text("G")
                                        .font(DinoTheme.dinoFont(size: 13))
                                        .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                                }
                            }
                            Text("continue with google")
                                .font(DinoTheme.headlineFont())
                                .foregroundColor(DinoTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(DinoTheme.surfacePrimary)
                        .cornerRadius(DinoTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                .stroke(DinoTheme.cardBorder, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(authManager.isLoading)

                    // Continue without account (skip)
                    Button {
                        dataManager.isSignedIn = true
                    } label: {
                        Text("continue without signing in")
                            .font(DinoTheme.subheadlineFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, DinoTheme.padding)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Reusable TextField (kept for other uses in the app)
struct DinoTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(DinoTheme.textSecondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(DinoTheme.bodyFont())
            } else {
                TextField(placeholder, text: $text)
                    .font(DinoTheme.bodyFont())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DinoTheme.cardBackground)
        .cornerRadius(DinoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                .stroke(DinoTheme.cardBorder, lineWidth: 1)
        )
    }
}
