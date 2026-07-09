//
//  JournalMomentsPicker.swift
//  Dino
//
//  The only file that touches Apple's JournalingSuggestions framework
//  (iOS 17.2+). The picker runs in a private system process — dino receives
//  ONLY the single moment the user explicitly picks. Nothing here is logged
//  or sent anywhere; the moment collapses to (UIImage?, seed line?) and is
//  immediately handed to the composer.
//

import SwiftUI
import UIKit

#if canImport(JournalingSuggestions)
import JournalingSuggestions

/// A tappable control (Apple's picker IS the button) styled by `label`.
@available(iOS 17.2, *)
struct JournalMomentsPickerButton<Label: View>: View {
    let onMoment: (UIImage?, String?) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        JournalingSuggestionsPicker {
            label()
        } onCompletion: { suggestion in
            let (image, line) = await Self.collapse(suggestion)
            onMoment(image, line)
        }
        .simultaneousGesture(TapGesture().onEnded {
            AnalyticsManager.shared.trackJournalMomentsPickerOpened()
        })
    }

    /// Collapses a picked suggestion to at most one image + one seed line.
    /// Photo attaches silently; the first non-photo content type seeds the
    /// line — priority: place > workout > walk > song > podcast > person.
    static func collapse(_ suggestion: JournalingSuggestion) async -> (UIImage?, String?) {
        var image: UIImage?
        if let photo = await suggestion.content(forType: JournalingSuggestion.Photo.self).first,
           let data = try? Data(contentsOf: photo.photo) {
            image = UIImage(data: data)
        } else if let live = await suggestion.content(forType: JournalingSuggestion.LivePhoto.self).first,
                  let data = try? Data(contentsOf: live.image) {
            image = UIImage(data: data)
        }

        var kind: MomentKind?
        if let loc = await suggestion.content(forType: JournalingSuggestion.Location.self).first {
            let daypart = loc.date.map { JournalMoments.daypart(hour: Calendar.current.component(.hour, from: $0)) } ?? nil
            kind = .location(place: loc.place ?? loc.city, daypart: daypart)
        } else if let group = await suggestion.content(forType: JournalingSuggestion.LocationGroup.self).first {
            kind = .locationGroup(firstPlace: group.locations.first.flatMap { $0.place ?? $0.city })
        } else if !(await suggestion.content(forType: JournalingSuggestion.Workout.self)).isEmpty {
            // activity name via the suggestion title (kept API-minimal); long
            // titles read like sentences, not activities — fall back instead
            let title = suggestion.title
            kind = .workout(activity: title.count <= 20 ? title : nil)
        } else if !(await suggestion.content(forType: JournalingSuggestion.MotionActivity.self)).isEmpty {
            kind = .motion
        } else if let song = await suggestion.content(forType: JournalingSuggestion.Song.self).first {
            kind = .song(title: song.song)
        } else if let podcast = await suggestion.content(forType: JournalingSuggestion.Podcast.self).first {
            kind = .podcast(show: podcast.show)
        } else if let contact = await suggestion.content(forType: JournalingSuggestion.Contact.self).first {
            kind = .contact(name: contact.name)
        } else if image == nil {
            // no photo and nothing recognizable — a gentle generic line
            kind = .genericMedia
        }

        return (image, kind.map { JournalMoments.seedLine(for: $0) })
    }
}

/// The one-time warm explainer. Its primary button IS the system picker
/// (Apple's control must be user-tapped — it cannot be presented in code).
@available(iOS 17.2, *)
struct JournalMomentsConsentSheet: View {
    let onMoment: (UIImage?, String?) -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("🌿")
                .font(.system(size: 44))
                .padding(.top, 28)

            Text(JournalMoments.consentTitle)
                .font(DinoTheme.dinoDisplayFont(size: 24))
                .foregroundColor(DinoTheme.textPrimary)

            Text(JournalMoments.consentBody)
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)

            JournalMomentsPickerButton(onMoment: onMoment) {
                Text(JournalMoments.consentPrimary)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(DinoTheme.sageGreen))
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)

            Button(action: onLater) {
                Text(JournalMoments.consentSecondary)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)
            }
            .padding(.bottom, 24)

            Spacer(minLength: 0)
        }
        .presentationDetents([.medium])
        .background(DinoTheme.background)
    }
}
#endif
