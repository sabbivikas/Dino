//
//  AuthManager.swift
//  Dino
//
//  Firebase Authentication manager — handles Google Sign-In and auth state.
//

import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
class AuthManager: ObservableObject {

    static let shared = AuthManager()

    // MARK: - Published State

    @Published var isSignedIn: Bool = false
    @Published var currentUser: User?
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var photoURL: URL?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    private init() {
        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isSignedIn = user != nil
                self?.displayName = user?.displayName ?? ""
                self?.email = user?.email ?? ""
                self?.photoURL = user?.photoURL
                print("[Auth] state changed — signed in: \(user != nil), user: \(user?.email ?? "none")")

                if let user = user {
                    SharedDataManager.shared.loadDataForUser(user.uid)
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        print("[Auth] Google Sign-In started")

        guard let app = FirebaseApp.app() else {
            errorMessage = "Firebase not configured"
            isLoading = false
            print("[Auth] ERROR: FirebaseApp.app() is nil — FirebaseApp.configure() may not have been called")
            return
        }

        guard let clientID = app.options.clientID else {
            errorMessage = "Missing Google client ID — check GoogleService-Info.plist has CLIENT_ID"
            isLoading = false
            print("[Auth] ERROR: Firebase clientID not found in options. Available keys: \(app.options.googleAppID)")
            return
        }

        print("[Auth] Firebase clientID found: \(clientID.prefix(20))...")

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot find root view controller"
            isLoading = false
            print("[Auth] ERROR: no root view controller")
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                isLoading = false
                print("[Auth] ERROR: no ID token from Google")
                return
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            print("[Auth] Google Sign-In SUCCESS — user: \(authResult.user.email ?? "unknown")")

        } catch {
            errorMessage = error.localizedDescription
            print("[Auth] Google Sign-In FAILED — error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Email Sign Up

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        print("[Auth] email sign-up started for \(email)")

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("[Auth] email sign-up SUCCESS: \(result.user.email ?? "unknown")")
        } catch {
            errorMessage = error.localizedDescription
            print("[Auth] email sign-up FAILED: \(error)")
        }

        isLoading = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        print("[Auth] email sign-in started for \(email)")

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("[Auth] email sign-in SUCCESS: \(result.user.email ?? "unknown")")
        } catch {
            errorMessage = error.localizedDescription
            print("[Auth] email sign-in FAILED: \(error)")
        }

        isLoading = false
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            print("[Auth] deleteAccount — no user")
            return
        }
        print("[Auth] deleting account for \(user.email ?? "unknown")")
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
        GIDSignIn.sharedInstance.disconnect()
        isSignedIn = false
        currentUser = nil
        displayName = ""
        email = ""
        photoURL = nil
        print("[Auth] account deleted")
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            GIDSignIn.sharedInstance.disconnect()
            isSignedIn = false
            currentUser = nil
            displayName = ""
            email = ""
            photoURL = nil
            print("[Auth] signed out and disconnected")
        } catch {
            print("[Auth] sign out error: \(error)")
        }
    }
}
