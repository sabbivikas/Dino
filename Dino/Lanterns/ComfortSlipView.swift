//
//  ComfortSlipView.swift
//  Dino
//
//  Concept 3a — "a slip under washi tape": the new presentation for a
//  gentle recommendation. One component, variants as props; the tape tint
//  is decorative, never a legend. Titles NEVER truncate. "not tonight"
//  feeds the exact same ignore signal as leaving did. All GentleRecEngine
//  gates are unchanged — this is presentation only.
//

import SwiftUI

enum ComfortSlip {
    // strings (owner-approved verbatim; lowercase, zero dashes)
    static let takeALook = "take a look"
    static let notTonight = "not tonight"

    /// "a small comfort · for tonight" — daypart by hour.
    static func kicker(hour: Int) -> String {
        let when: String
        switch hour {
        case 21..., ..<5: when = "for tonight"
        case 17..<21:     when = "for this evening"
        case 5..<12:      when = "for this morning"
        default:          when = "for today"
        }
        return "a small comfort · \(when)"
    }

    static func tapeTint(type: String) -> Color {
        switch type {
        case "music": return Color(red: 196/255, green: 184/255, blue: 212/255).opacity(0.72)
        case "film":  return Color(red: 232/255, green: 136/255, blue: 154/255).opacity(0.60)
        default:      return Color(red: 168/255, green: 212/255, blue: 230/255).opacity(0.72)
        }
    }

    static func iconTint(type: String) -> Color {
        switch type {
        case "music": return Color(red: 196/255, green: 184/255, blue: 212/255).opacity(0.30)
        case "film":  return Color(red: 232/255, green: 136/255, blue: 154/255).opacity(0.26)
        default:      return Color(red: 168/255, green: 212/255, blue: 230/255).opacity(0.32)
        }
    }

    static func icon(type: String) -> String {
        switch type {
        case "music": return "🎧"
        case "film":  return "🎬"
        default:      return "🍵"
        }
    }

    static func source(link: String) -> String {
        guard let host = URL(string: link)?.host else { return "from somewhere gentle" }
        return "from \(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)"
    }

    static var allFixedStrings: [String] {
        [takeALook, notTonight,
         kicker(hour: 22), kicker(hour: 18), kicker(hour: 8), kicker(hour: 14),
         source(link: "")]
    }
}

struct ComfortSlipView: View {
    let rec: GentleRec
    var hour: Int = Calendar.current.component(.hour, from: Date())
    let onTake: () -> Void
    let onNotTonight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ComfortSlip.kicker(hour: hour))
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "#A8A29A"))
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 14) {
                Text(ComfortSlip.icon(type: rec.type))
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ComfortSlip.iconTint(type: rec.type)))
                    .rotationEffect(.degrees(3))
                VStack(alignment: .leading, spacing: 5) {
                    // the title NEVER truncates — twelve-word titles wrap
                    Text(rec.title)
                        .font(DinoTheme.dinoFont(size: 23))
                        .lineSpacing(4)
                        .foregroundColor(Color(hex: "#3D3A35"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ComfortSlip.source(link: rec.link))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "#A8A29A"))
                }
            }
            .padding(.top, 16)

            HStack(alignment: .top, spacing: 10) {
                Image("jar-dino")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 26)
                Text(rec.line)
                    .font(DinoTheme.dinoFont(size: 16.5))
                    .lineSpacing(5)
                    .foregroundColor(Color(hex: "#7A7266"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 15)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
                    .overlay(DashedRule())
                    .padding(.top, 7)
            }

            HStack(spacing: 10) {
                Button(action: onTake) {
                    Text(ComfortSlip.takeALook)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#7BA872")))
                        .shadow(color: Color(hex: "#7BA872").opacity(0.30), radius: 7, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
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
                // same fiber as the resources cards — static, never boils
                .colorEffect(ShaderLibrary.dinoPaperGrain(.float(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(hex: "#EFE7D2"), lineWidth: 1))
                .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.10), radius: 13, y: 10)
        )
        .overlay(alignment: .top) {
            // washi tape — decorative type tint, striped
            RoundedRectangle(cornerRadius: 2)
                .fill(ComfortSlip.tapeTint(type: rec.type))
                .overlay(TapeStripes().clipShape(RoundedRectangle(cornerRadius: 2)))
                .frame(width: 116, height: 27)
                .rotationEffect(.degrees(-3))
                .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.10), radius: 1.5, y: 1)
                .offset(y: -13)
        }
        .rotationEffect(.degrees(-1.1))
    }
}

private struct TapeStripes: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            while x < size.width + size.height {
                ctx.fill(Path(CGRect(x: x, y: -2, width: 5, height: size.height + 4)),
                         with: .color(.white.opacity(0.22)))
                x += 10
            }
        }
    }
}

private struct DashedRule: View {
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
