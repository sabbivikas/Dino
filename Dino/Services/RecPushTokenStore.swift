//
//  RecPushTokenStore.swift
//  Dino
//
//  Rec delivery F3 — the device's FCM registration token, mirrored to
//  pushTokens/{uid} so the delivery sweep's announcement can reach a closed
//  app. THE PREFS CONTRACT: the token exists server-side ONLY while the
//  user both grants system notification permission and keeps dino's master
//  notifications toggle on; any other state deletes the doc — that delete
//  IS the server-side mute (no token → sendRecAnnouncement skips silently,
//  and the rec still waits in-app for F4's reveal).
//
//  Privacy: the doc is three fields — an opaque FCM token, 'ios', and a
//  server-stamped time. firestore.rules rejects anything else, and no
//  client can ever read it back (not even its owner).
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
enum RecPushTokenStore {

    static let defaultsKey = "dino.push.fcmToken"
    static let collection = "pushTokens"   // recAnnounce.ts twin

    /// Pure gate — tested. Uploads only when every consent holds at once.
    nonisolated static func shouldStoreToken(signedIn: Bool,
                                             hasPermission: Bool,
                                             masterEnabled: Bool) -> Bool {
        signedIn && hasPermission && masterEnabled
    }

    /// FCM delegate entry — remember the token locally, then reconcile.
    static func tokenDidRefresh(_ token: String?) {
        if let token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: defaultsKey)
        }
        sync()
    }

    /// Reconcile the server doc with the current prefs. Fire and forget —
    /// a missed sync self-heals on the next app open / toggle / refresh.
    static func sync() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = Firestore.firestore().collection(collection).document(uid)
        let token = UserDefaults.standard.string(forKey: defaultsKey)
        let manager = NotificationManager.shared
        if let token, !token.isEmpty,
           shouldStoreToken(signedIn: true,
                            hasPermission: manager.hasPermission,
                            masterEnabled: manager.notificationsEnabled) {
            doc.setData([
                "token": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp(),
            ]) { _ in }   // silent — the next sync retries
        } else {
            doc.delete { _ in }   // the mute — silent either way
        }
    }
}
