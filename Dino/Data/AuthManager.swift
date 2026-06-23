//
//  AuthManager.swift
//  Dino
//
//  Firebase Authentication manager — handles Google Sign-In, Apple Sign-In, and auth state.
//

import SwiftUI
import Combine
import CryptoKit
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import PostHog

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
    private var appleCoordinator: AppleSignInCoordinator?

    // MARK: - Init

    private init() {
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

    // MARK: - Apple Sign-In helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        #if DEBUG
        print("[Auth] Apple Sign-In started")
        #endif

        let nonce = randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        do {
            let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { continuation in
                let coordinator = AppleSignInCoordinator(continuation: continuation)
                self.appleCoordinator = coordinator
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = coordinator
                controller.presentationContextProvider = coordinator
                controller.performRequests()
            }
            self.appleCoordinator = nil

            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Failed to get Apple identity token"
                isLoading = false
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            let uid = result.user.uid
            AnalyticsManager.shared.identify(uid: uid)
            AnalyticsManager.shared.trackSignIn(method: "apple")
            #if DEBUG
            print("[Auth] Apple Sign-In succeeded")
            #endif

        } catch {
            self.appleCoordinator = nil
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Auth] Apple Sign-In failed: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
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

            let appleResult = try await Auth.auth().signIn(with: credential)
            let uid = appleResult.user.uid
            AnalyticsManager.shared.identify(uid: uid)
            AnalyticsManager.shared.trackSignIn(method: "google")
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
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            AnalyticsManager.shared.identify(uid: uid)
            AnalyticsManager.shared.trackSignUp(method: "email")
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
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let uid = result.user.uid
            AnalyticsManager.shared.identify(uid: uid)
            AnalyticsManager.shared.trackSignIn(method: "email")
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

    /// Returns the provider ID for the current user, e.g. "password", "google.com", or "apple.com".
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

    /// Reauthenticate an Apple user by triggering a fresh Apple sign-in flow.
    func reauthenticateAppleUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.noProvider
        }

        let nonce = randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        do {
            let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { continuation in
                let coordinator = AppleSignInCoordinator(continuation: continuation)
                self.appleCoordinator = coordinator
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = coordinator
                controller.presentationContextProvider = coordinator
                controller.performRequests()
            }
            self.appleCoordinator = nil

            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                throw AccountDeletionError.reauthFailed
            }
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            _ = try await user.reauthenticate(with: firebaseCredential)
            #if DEBUG
            print("[Auth] Apple reauthentication succeeded")
            #endif
        } catch {
            self.appleCoordinator = nil
            #if DEBUG
            print("[Auth] Apple reauthentication failed")
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
            AnalyticsManager.shared.trackAccountDeleted()
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
            // Capture the sign_out event while still identified, then clear the
            // PostHog identity BEFORE Firebase signOut so any subsequent
            // background events route to a fresh anonymous distinct id.
            AnalyticsManager.shared.trackSignOut()
            AnalyticsManager.shared.reset()
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

// MARK: - Apple Sign-In Coordinator

private class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: NSError(
                domain: "AppleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"]
            ))
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}
