//
//  PrivacyPolicyView.swift
//  Dino
//

import SwiftUI

struct PrivacyPolicyView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text("privacy policy")
                    .font(DinoTheme.titleFont())
                    .foregroundColor(DinoTheme.textPrimary)
                    .padding(.top, 8)

                Text("last updated: april 2026")
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)

                policySection(
                    title: String(localized: "what dino collects"),
                    body: String(localized: "dino collects only the data you create within the app: mood entries, journal recordings, gratitude notes, breathing and meditation session logs, self assessments, streak data, and your profile info (name, preferences). if you sign in with google, we also store your google display name and email to identify your account.")
                )

                policySection(
                    title: String(localized: "how your data is stored"),
                    body: String(localized: "your data is stored locally on your device and, if you sign in, synced securely to google firebase (firestore). all cloud data is stored under your unique user id and is only accessible by your account. we do not share, sell, or provide your data to any third parties.")
                )

                policySection(
                    title: String(localized: "voice journal entries"),
                    body: String(localized: "audio recordings from voice journaling are stored locally on your device. they are not uploaded to any server or cloud storage. if you delete the app, your recordings are permanently removed.")
                )

                policySection(
                    title: String(localized: "analytics"),
                    body: String(localized: "dino may use firebase analytics to collect anonymous usage data such as which features are used most often. this data contains no personally identifiable information and is used solely to improve the app experience.")
                )

                policySection(
                    title: String(localized: "data deletion"),
                    body: String(localized: "you can delete all your data at any time from settings. if you choose to delete your account, all data associated with your account is permanently removed from both your device and our cloud servers. this action cannot be undone.")
                )

                policySection(
                    title: String(localized: "third party services"),
                    body: String(localized: "dino uses google sign in for authentication and google firebase for secure data storage. these services have their own privacy policies. no other third party services have access to your data.")
                )

                policySection(
                    title: String(localized: "children's privacy"),
                    body: String(localized: "dino is not directed at children under 13. we do not knowingly collect personal information from children under 13. if you believe a child has provided us with personal data, please contact us so we can remove it.")
                )

                policySection(
                    title: String(localized: "changes to this policy"),
                    body: String(localized: "we may update this privacy policy from time to time. any changes will be reflected within the app. continued use of dino after changes constitutes acceptance of the updated policy.")
                )

                policySection(
                    title: String(localized: "contact"),
                    body: String(localized: "if you have any questions about this privacy policy or your data, reach out to us at dinoappsupport@gmail.com")
                )

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.textPrimary)

            Text(body)
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textSecondary)
                .lineSpacing(4)
        }
    }
}
