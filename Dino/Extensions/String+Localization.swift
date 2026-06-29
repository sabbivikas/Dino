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
