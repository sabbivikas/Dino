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

enum AccountDeletionError: LocalizedError {
    case requiresReauthentication
    case noProvider
    case reauthFailed

    var errorDescription: String? {
        switch self {
        case .requiresReauthentication: return "please sign in again to confirm account deletion."
        case .noProvider: return "couldn't determine your sign-in method."
        case .reauthFailed: return "reauthentication failed. please try again."
        }
    }
}

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
                #if DEBUG
                print("[Auth] state changed — signed in: \(user != nil)")
                #endif

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
        #if DEBUG
        print("[Auth] Google Sign-In started")
        #endif

        guard let app = FirebaseApp.app() else {
            errorMessage = "Firebase not configured"
            isLoading = false
            #if DEBUG
            print("[Auth] ERROR: FirebaseApp not configured")
            #endif
            return
        }

        guard let clientID = app.options.clientID else {
            errorMessage = "Missing Google client ID — check GoogleService-Info.plist has CLIENT_ID"
            isLoading = false
            #if DEBUG
            print("[Auth] ERROR: Firebase clientID missing")
            #endif
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot find root view controller"
            isLoading = false
            #if DEBUG
            print("[Auth] ERROR: no root view controller")
            #endif
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                isLoading = false
                #if DEBUG
                print("[Auth] ERROR: no ID token from Google")
                #endif
                return
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            _ = try await Auth.auth().signIn(with: credential)
            #if DEBUG
            print("[Auth] Google Sign-In succeeded")
            #endif

        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Auth] Google Sign-In failed")
            #endif
        }

        isLoading = false
    }

    // MARK: - Email Sign Up

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        #if DEBUG
        print("[Auth] email sign-up started")
        #endif

        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            #if DEBUG
            print("[Auth] email sign-up succeeded")
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Auth] email sign-up failed")
            #endif
        }

        isLoading = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        #if DEBUG
        print("[Auth] email sign-in started")
        #endif

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            #if DEBUG
            print("[Auth] email sign-in succeeded")
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Auth] email sign-in failed")
            #endif
        }

        isLoading = false
    }

    // MARK: - Delete Account

    /// Returns the provider ID for the current user, e.g. "password" or "google.com".
    var currentProviderID: String? {
        Auth.auth().currentUser?.providerData.first?.providerID
    }

    /// Reauthenticate an email/password user. Throws on failure.
    func reauthenticateEmailUser(password: String) async throws {
        guard let user = Auth.auth().currentUser, let userEmail = user.email else {
            throw AccountDeletionError.noProvider
        }
        let credential = EmailAuthProvider.credential(withEmail: userEmail, password: password)
        do {
            _ = try await user.reauthenticate(with: credential)
            #if DEBUG
            print("[Auth] reauthentication succeeded")
            #endif
        } catch {
            #if DEBUG
            print("[Auth] reauthentication failed")
            #endif
            throw AccountDeletionError.reauthFailed
        }
    }

    /// Reauthenticate a Google user by triggering a fresh Google sign-in flow.
    func reauthenticateGoogleUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.noProvider
        }
        guard let app = FirebaseApp.app(), let clientID = app.options.clientID else {
            throw AccountDeletionError.reauthFailed
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AccountDeletionError.reauthFailed
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AccountDeletionError.reauthFailed
            }
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            _ = try await user.reauthenticate(with: credential)
            #if DEBUG
            print("[Auth] Google reauthentication succeeded")
            #endif
        } catch {
            #if DEBUG
            print("[Auth] Google reauthentication failed")
            #endif
            throw AccountDeletionError.reauthFailed
        }
    }

    /// Deletes the Firebase Auth account ONLY. Caller is responsible for
    /// deleting Firestore + local data ONLY after this succeeds.
    /// Throws AccountDeletionError.requiresReauthentication if Firebase
    /// requires a recent login — caller should reauthenticate and retry.
    func deleteAuthAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            #if DEBUG
            print("[Auth] deleteAuthAccount — no user")
            #endif
            return
        }
        do {
            try await user.delete()
            #if DEBUG
            print("[Auth] auth account deleted")
            #endif
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                #if DEBUG
                print("[Auth] reauthentication required")
                #endif
                throw AccountDeletionError.requiresReauthentication
            }
            throw error
        }
    }

    /// Clear local auth-related session state. Call AFTER auth + data deletes succeed.
    func clearLocalAuthSession() {
        GIDSignIn.sharedInstance.signOut()
        Task { try? await GIDSignIn.sharedInstance.disconnect() }
        isSignedIn = false
        currentUser = nil
        displayName = ""
        email = ""
        photoURL = nil
    }

    /// Legacy entry point kept for compatibility — prefer the new ordered flow in ProfileView.
    func deleteAccount() async throws {
        try await deleteAuthAccount()
        clearLocalAuthSession()
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            Task { try? await GIDSignIn.sharedInstance.disconnect() }
            isSignedIn = false
            currentUser = nil
            displayName = ""
            email = ""
            photoURL = nil
            #if DEBUG
            print("[Auth] signed out")
            #endif
        } catch {
            #if DEBUG
            print("[Auth] sign out error")
            #endif
        }
    }
}
