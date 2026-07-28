//
//  FindingsFeature.swift
//  Dino
//
//  EXPERIMENTAL "star findings" demo — the single client gate. Hardcoded to the
//  owner's uid so the whole feature is inert for everyone else even if this
//  branch were ever merged (it must not be). MainTabView reads isEnabled to
//  decide tab slot 3: flag OFF → the byte-identical Gratitude Jar.
//
//  English-only demo (owner decision): new copy in these files is plain string
//  literals, never String(localized:) — localization is a merge prerequisite.
//

import FirebaseAuth

enum FindingsFeature {
    /// The owner's uid, hardcoded. Inert for everyone else.
    static var isEnabled: Bool { Auth.auth().currentUser?.uid == "Enlkbg0saoMqvx24r7ZLsBX8ctp2" }
}
