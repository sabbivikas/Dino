//
//  SignInView.swift
//  Dino
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("hasPassedAuth") private var hasPassedAuth = false

    @State private var heartOffset1: CGFloat = 0
    @State private var heartOffset2: CGFloat = 0
    @State private var heartOpacity1: Double = 0.7
    @State private var heartOpacity2: Double = 0.7
    @State private var showEmailSignUp = false
    @State private var emailText = ""
    @State private var passwordText = ""
    @State private var confirmPasswordText = ""
    @State private var isSignUp = true

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
                    // Continue with Apple
                    Button {
                        Task {
                            await authManager.signInWithApple()
                            if authManager.isSignedIn {
                                dataManager.userName = authManager.displayName
                                hasPassedAuth = true
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(DinoTheme.textSecondary)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "applelogo")
                                    .font(DinoTheme.dinoFont(size: 16))
                                    .foregroundColor(DinoTheme.textPrimary)
                            }
                            Text("continue with apple")
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

                    // Continue with Google
                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                            if authManager.isSignedIn {
                                dataManager.userName = authManager.displayName
                                hasPassedAuth = true
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

                    // Continue with Apple
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authManager.prepareAppleSignInNonce()
                        },
                        onCompletion: { result in
                            Task {
                                switch result {
                                case .success(let authorization):
                                    await authManager.handleSignInWithApple(authorization)
                                    if authManager.isSignedIn {
                                        dataManager.userName = authManager.displayName
                                        hasPassedAuth = true
                                    }
                                case .failure(let error):
                                    authManager.handleSignInWithAppleError(error)
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .cornerRadius(DinoTheme.cornerRadius)
                    .disabled(authManager.isLoading)

                    // Sign up with email
                    Button {
                        withAnimation { showEmailSignUp.toggle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(DinoTheme.dinoFont(size: 14))
                                .foregroundColor(DinoTheme.textSecondary)

                            Text(showEmailSignUp ? "hide email sign up" : "sign up with email")
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

                    // Email form (expandable)
                    if showEmailSignUp {
                        VStack(spacing: 12) {
                            // Toggle between sign up and sign in
                            HStack(spacing: 0) {
                                Button {
                                    withAnimation { isSignUp = true }
                                } label: {
                                    Text("sign up")
                                        .font(DinoTheme.subheadlineFont())
                                        .foregroundColor(isSignUp ? DinoTheme.sageGreen : DinoTheme.textSecondary)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(isSignUp ? DinoTheme.sageGreen.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                }

                                Button {
                                    withAnimation { isSignUp = false }
                                } label: {
                                    Text("sign in")
                                        .font(DinoTheme.subheadlineFont())
                                        .foregroundColor(!isSignUp ? DinoTheme.sageGreen : DinoTheme.textSecondary)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(!isSignUp ? DinoTheme.sageGreen.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                }
                            }
                            .background(DinoTheme.cardBackground)
                            .cornerRadius(8)

                            DinoTextField(placeholder: "email", text: $emailText, icon: "envelope", isSecure: false)

                            DinoTextField(placeholder: "password", text: $passwordText, icon: "lock", isSecure: true)

                            if isSignUp {
                                DinoTextField(placeholder: "confirm password", text: $confirmPasswordText, icon: "lock.fill", isSecure: true)
                            }

                            Button {
                                Task {
                                    if isSignUp {
                                        guard passwordText == confirmPasswordText else {
                                            authManager.errorMessage = "passwords don't match"
                                            return
                                        }
                                        guard passwordText.count >= 6 else {
                                            authManager.errorMessage = "password must be at least 6 characters"
                                            return
                                        }
                                        await authManager.signUpWithEmail(email: emailText, password: passwordText)
                                    } else {
                                        await authManager.signInWithEmail(email: emailText, password: passwordText)
                                    }
                                    if authManager.isSignedIn {
                                        hasPassedAuth = true
                                    }
                                }
                            } label: {
                                Text(isSignUp ? "create account" : "sign in")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DinoTheme.sageGreen)
                                    .cornerRadius(DinoTheme.cornerRadius)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(authManager.isLoading)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
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
