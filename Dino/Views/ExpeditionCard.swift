//
//  ExpeditionCard.swift
//  Dino
//
//  F3: the dove's delivery — a small paper card in dino's voice carrying
//  the one thing the expedition found. Same paper family as the rec slip.
//  Presentation only; all gates ran nights ago on the server and on device.
//  Reduce Motion safe: the card enters by opacity only (see the insertion
//  site) and carries no looping animation.
//

import SwiftUI

struct ExpeditionCard: View {
    let gift: ExpeditionGift
    let onOpen: () -> Void
    let onKeep: () -> Void
    let onNotTonight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ExpeditionVoice.cardHeader)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "#A8A29A"))
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text(gift.title)
                    .font(DinoTheme.dinoFont(size: 21))
                    .lineSpacing(4)
                    .foregroundColor(Color(hex: "#3D3A35"))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(ExpeditionVoice.fromPrefix) \(gift.source)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(hex: "#A8A29A"))
            }
            .padding(.top, 14)

            // the found thing — a short excerpt; the link carries the rest.
            // tapping the clipping itself opens the in app reader.
            Text("\u{201C}\(gift.excerpt)\u{201D}")
                .font(DinoTheme.dinoFont(size: 15.5))
                .lineSpacing(5)
                .foregroundColor(Color(hex: "#57524A"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)

            // dino's one warm line
            HStack(alignment: .top, spacing: 10) {
                Image("jar-dino")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 26)
                Text(gift.dinoLine)
                    .font(DinoTheme.dinoFont(size: 16))
                    .lineSpacing(5)
                    .foregroundColor(Color(hex: "#7A7266"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                GiftDashedRule().padding(.top, 7)
            }

            VStack(spacing: 10) {
                Button(action: onKeep) {
                    Text(ExpeditionVoice.keepIt)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#7BA872")))
                        .shadow(color: Color(hex: "#7BA872").opacity(0.30), radius: 7, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
                Button(action: onOpen) {
                    Text(ExpeditionVoice.openLink)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#7A7266"))
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
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
            .padding(.top, 16)
        }
        .padding(EdgeInsets(top: 24, leading: 22, bottom: 20, trailing: 22))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#FFFDF6"))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.10), radius: 13, y: 10)
        )
        .rotationEffect(.degrees(1.1))
    }
}

private struct GiftDashedRule: View {
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
