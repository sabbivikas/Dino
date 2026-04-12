//
//  SignInView.swift
//  Dino
//

import SwiftUI
import AVKit

struct SignInView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showCreateAccount: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Video header
                ZStack {
                    LoopingVideoPlayer(videoName: "dino_walking", videoExtension: "mp4")
                        .frame(height: 280)
                        .clipped()
                        .cornerRadius(0)

                    // Gradient overlay at bottom
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                }
                .frame(height: 280)

                VStack(spacing: 28) {
                    // Title
                    VStack(spacing: 8) {
                        Text("welcome to dino")
                            .font(DinoTheme.largeFont())
                            .foregroundColor(DinoTheme.textPrimary)

                        Text("your calm, personal space")
                            .font(DinoTheme.subheadlineFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }

                    // Form
                    VStack(spacing: 14) {
                        DinoTextField(
                            placeholder: "email",
                            text: $email,
                            icon: "envelope",
                            isSecure: false
                        )

                        DinoTextField(
                            placeholder: "password",
                            text: $password,
                            icon: "lock",
                            isSecure: true
                        )
                    }

                    // Sign in button
                    Button(action: signIn) {
                        Text("sign in")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DinoTheme.sageGreen)
                            .cornerRadius(DinoTheme.cornerRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(DinoTheme.divider)
                            .frame(height: 1)
                        Text("or")
                            .font(DinoTheme.captionFont())
                            .foregroundColor(DinoTheme.textSecondary)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(DinoTheme.divider)
                            .frame(height: 1)
                    }

                    // Continue with Apple
                    Button(action: signIn) {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .medium))
                            Text("continue with apple")
                                .font(DinoTheme.headlineFont())
                        }
                        .foregroundColor(DinoTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(DinoTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                                .stroke(DinoTheme.divider, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Create account link
                    Button(action: { showCreateAccount = true }) {
                        Text("new here? ")
                            .foregroundColor(DinoTheme.textSecondary)
                        + Text("create account")
                            .foregroundColor(DinoTheme.sageGreen)
                            .fontWeight(.semibold)
                    }
                    .font(DinoTheme.subheadlineFont())
                    .sheet(isPresented: $showCreateAccount) {
                        CreateAccountSheet(onDismiss: { showCreateAccount = false }, onSignIn: signIn)
                            .environmentObject(dataManager)
                    }
                }
                .padding(.horizontal, DinoTheme.padding)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    private func signIn() {
        dataManager.isSignedIn = true
    }
}

// MARK: - Reusable TextField
struct DinoTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
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
                .stroke(DinoTheme.divider, lineWidth: 1)
        )
    }
}

// MARK: - Create Account Sheet
struct CreateAccountSheet: View {
    @EnvironmentObject var dataManager: SharedDataManager
    let onDismiss: () -> Void
    let onSignIn: () -> Void

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("create account")
                        .font(DinoTheme.titleFont())
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("start your wellness journey")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 14) {
                    DinoTextField(placeholder: "your name", text: $name, icon: "person", isSecure: false)
                    DinoTextField(placeholder: "email", text: $email, icon: "envelope", isSecure: false)
                    DinoTextField(placeholder: "password", text: $password, icon: "lock", isSecure: true)
                }

                Button(action: {
                    if !name.isEmpty {
                        dataManager.userName = name
                    }
                    onDismiss()
                    onSignIn()
                }) {
                    Text("create account")
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.sageGreen)
                        .cornerRadius(DinoTheme.cornerRadius)
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()
            }
            .padding(.horizontal, DinoTheme.padding)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel", action: onDismiss)
                        .foregroundColor(DinoTheme.textSecondary)
                }
            }
        }
    }
}
