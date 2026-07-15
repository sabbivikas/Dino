//
//  String+Localization.swift
//  Dino
//
//  Tiny helper so any user-facing literal can localize itself using the
//  English text as its own key: Text("maybe later".localized). The .lproj
//  Localizable.strings files map each English key to its translation; a missing
//  key falls back to the key (English), so nothing is ever blank.
//

import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

/// The app's RESOLVED language — not the device language. While dino ships
/// english only this is always "en", so every surface (ui and ai written
/// content alike) speaks one language. When dino localizes for real, this
/// follows the app's declared localizations automatically.
enum AppLanguage {
    static var current: String {
        Bundle.main.preferredLocalizations.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    }
}
