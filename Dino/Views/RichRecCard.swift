//
//  RichRecCard.swift
//  Dino
//
//  Feature 1 of the 2.1 comfort recs arc: the personalized pick, presented
//  as a slip from the same paper family as ComfortSlipView. Presentation
//  only — every GentleRecEngine gate ran before this card exists. The why
//  line is the heart: dino speaking to this person about this day.
//

import SwiftUI

struct RichRecCard: View {
    let rec: RichRec
    var hour: Int = Calendar.current.component(.hour, from: Date())
    let onOpen: (URL) -> Void
    let onNotTonight: () -> Void
    // feature 2: ask once which music app, then default to their place
    @State private var rememberedApp: String? = RecOpenMemory.remembered()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ComfortRecVoice.header(hour: hour))
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "#A8A29A"))
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 14) {
                Text(ComfortRecVoice.icon(type: rec.type))
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ComfortRecVoice.iconTint(type: rec.type)))
                    .rotationEffect(.degrees(3))
                VStack(alignment: .leading, spacing: 5) {
                    // the title NEVER truncates — long titles wrap
                    Text(rec.title)
                        .font(DinoTheme.dinoFont(size: 23))
                        .lineSpacing(4)
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ComfortRecVoice.metaLine(rec))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "#A8A29A"))
                }
            }
            .padding(.top, 16)

            // why — dino speaking to this person about this day
            HStack(alignment: .top, spacing: 10) {
                Image("jar-dino")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 26)
                Text(rec.why)
                    .font(DinoTheme.dinoFont(size: 16.5))
                    .lineSpacing(5)
                    .foregroundColor(Color(hex: "#7A7266"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 15)
            .overlay(alignment: .top) {
                RecDashedRule().padding(.top, 7)
            }

            // content flags — wellness critical, always visible
            Text(rec.flags.joined(separator: ComfortRecVoice.flagSeparator))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(Color(hex: "#7BA872"))
                .padding(.top, 12)

            // the feel and the ask, one quiet line
            Text(ComfortRecVoice.feelLine(rec))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color(hex: "#A8A29A"))
                .padding(.top, 4)

            VStack(spacing: 10) {
                if rec.type == "music" {
                    musicButtons
                } else {
                    ForEach(rec.searchLinks) { link in
                        filledButton(link.label) { onOpen(link.url) }
                    }
                }
                Button(action: onNotTonight) {
                    Text(ComfortSlip.notTonight)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#7A7266"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#3D3A35").opacity(0.14), lineWidth: 1.5))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.top, 17)
        }
        .padding(EdgeInsets(top: 24, leading: 22, bottom: 20, trailing: 22))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#FFFDF6"))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.10), radius: 13, y: 10)
        )
        .rotationEffect(.degrees(-1.1))
    }

    // MARK: - Feature 2: the open it flow

    /// No memory yet → dino asks which app (two equal doors). A choice is
    /// remembered and becomes the single default next time, with a quiet
    /// switch underneath that re remembers.
    @ViewBuilder private var musicButtons: some View {
        if let app = rememberedApp, let link = rec.musicLink(for: app) {
            filledButton(link.label) { choose(app: app, link: link) }
            let other = RecOpenMemory.other(than: app)
            if let otherLink = rec.musicLink(for: other) {
                Button(action: { choose(app: other, link: otherLink) }) {
                    Text("\(ComfortRecVoice.orPrefix) \(otherLink.label)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#7A7266"))
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(ComfortRecVoice.askWhich)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color(hex: "#A8A29A"))
                .frame(maxWidth: .infinity)
            ForEach(rec.searchLinks) { link in
                filledButton(link.label) {
                    let app = link.label == ComfortRecVoice.openSpotify
                        ? RecOpenMemory.spotify : RecOpenMemory.appleMusic
                    choose(app: app, link: link)
                }
            }
        }
    }

    private func choose(app: String, link: RecLink) {
        RecOpenMemory.remember(app)
        rememberedApp = app
        onOpen(link.url)
    }

    private func filledButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#7BA872")))
                .shadow(color: Color(hex: "#7BA872").opacity(0.30), radius: 7, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct RecDashedRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(Color(hex: "#3D3A35").opacity(0.14),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}
