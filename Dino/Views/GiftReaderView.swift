//
//  GiftReaderView.swift
//  Dino
//
//  Read inside dino: the gift's source opens in an in app safari view,
//  reader mode preferred, bars in dino's paper palette — the whole piece
//  readable without leaving the app. The card itself stays excerpt only
//  (copyright: 40 words + the link, never the full text).
//

import SwiftUI
import SafariServices

/// Identifiable wrapper so a url can drive a .sheet(item:).
struct ReaderLink: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

struct GiftReaderView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = UIColor(Color(hex: "#FAF6EC"))     // dino paper
        vc.preferredControlTintColor = UIColor(Color(hex: "#5E8A56")) // dino sage
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
