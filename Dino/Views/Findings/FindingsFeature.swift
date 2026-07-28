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
    /// DEBUG builds additionally honor the -findingsQA launch arg (house QA-arg
    /// pattern) so the tab is inspectable on a simulator without owner auth.
    /// Release builds ignore the arg — the uid gate is the only door.
    static var isEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-findingsQA") { return true }
        #endif
        return Auth.auth().currentUser?.uid == "Enlkbg0saoMqvx24r7ZLsBX8ctp2"
    }
}
