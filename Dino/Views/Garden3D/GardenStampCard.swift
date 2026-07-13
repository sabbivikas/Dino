//
//  GardenStampCard.swift
//  Dino
//
//  The garden share as a postage stamp (ported from share-kit.jsx): the live
//  garden printed on cream paper clipped to a perforated outline, a hairline
//  frame, a sage day-count denomination, and a multiply-blended postmark.
//  Pure SwiftUI (Image + gradients + shapes + text) — captures reliably.
//

import SwiftUI
import UIKit

// MARK: - Perforated stamp outline (port of stampPath)

/// Rect with semicircular notches punched inward along every edge, evenly
/// spaced (~`target` apart). Corners stay square.
struct StampPerforationShape: Shape {
    var notchRadius: CGFloat = 5.5
    var target: CGFloat = 19

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r = notchRadius
        func seg(_ len: CGFloat) -> CGFloat { len / CGFloat(max(1, (len / target).rounded())) }
        let sx = seg(w), sy = seg(h)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        // top edge — notches dip down (inward)
        var x = sx
        while x < w - 1 {
            p.addArc(center: CGPoint(x: x, y: 0), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            x += sx
        }
        p.addLine(to: CGPoint(x: w, y: 0))
        // right edge — notches dip left (inward)
        var y = sy
        while y < h - 1 {
            p.addArc(center: CGPoint(x: w, y: y), radius: r,
                     startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
            y += sy
        }
        p.addLine(to: CGPoint(x: w, y: h))
        // bottom edge — notches dip up (inward)
        x = w - sx
        while x > 1 {
            p.addArc(center: CGPoint(x: x, y: h), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            x -= sx
        }
        p.addLine(to: CGPoint(x: 0, y: h))
        // left edge — notches dip right (inward)
        y = h - sy
        while y > 1 {
            p.addArc(center: CGPoint(x: 0, y: y), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            y -= sy
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Postmark cancel waves (port of the q/t wave path)

struct StampCancelWaves: Shape {
    /// viewBox 52 x 36, three wavy rows
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 52, sy = rect.height / 36
        var p = Path()
        for row in [CGFloat(8), 18, 28] {
            let y = row * sy
            p.move(to: CGPoint(x: 0, y: y))
            // first quad: control (6.5,-4), end (13,0); then reflect alternating
            var cx: CGFloat = 6.5, cyOff: CGFloat = -4, ex: CGFloat = 13
            var curX: CGFloat = 0
            for _ in 0..<4 {
                let cp = CGPoint(x: (curX + cx) * sx, y: y + cyOff * sy)
                let end = CGPoint(x: (curX + ex) * sx, y: y)
                p.addQuadCurve(to: end, control: cp)
                curX += ex
                cyOff = -cyOff        // reflect up/down
                cx = 6.5             // symmetric control offset each segment
            }
        }
        return p
    }
}

struct GardenPostmark: View {
    let date: String
    var size: CGFloat = 62

    private let ink = Color(red: 93/255, green: 85/255, blue: 74/255).opacity(0.72)

    var body: some View {
        HStack(spacing: -size * 0.10) {
            StampCancelWaves()
                .stroke(ink, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: size * 0.85, height: size * 0.6)
            VStack(spacing: 1) {
                Text(GardenShare.postmarkTop)
                    .font(DinoTheme.dinoFont(size: size * 0.16))
                    .tracking(1.2)
                    .textCase(.uppercase)
                Text(date)
                    .font(DinoTheme.numericFont(size: size * 0.19))
                    .fontWeight(.bold)
                Text("\u{1F995}")
                    .font(.system(size: size * 0.19))
            }
            .foregroundColor(ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: "#FEFBF3").opacity(0.25)))
            .overlay(Circle().stroke(ink, lineWidth: 1.6))
        }
        .rotationEffect(.degrees(-9))
        .blendMode(.multiply)
        .accessibilityHidden(true)
    }
}

// MARK: - The stamp card

struct GardenStampCard: View {
    let gardenImage: UIImage
    let stage: String
    let day: Int
    let date: String
    var width: CGFloat = 600

    /// deterministic composed size (mirrors the instance geometry)
    static func size(width w: CGFloat) -> CGSize {
        let pad = 15.0 / 280 * w, frameGap = 6.0 / 280 * w
        let snapW = w - 2 * (pad + frameGap + 1)
        let snapH = (401.0 * (snapW / 344.0)).rounded()
        let capH = 66.0 / 280 * w
        return CGSize(width: w, height: snapH + capH + 2 * (pad + frameGap + 1))
    }

    private let paper = Color(hex: "#FEFBF3")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")

    // geometry (ported from StampCard)
    private var pad: CGFloat { 15.0 / 280 * width }
    private var frameGap: CGFloat { 6.0 / 280 * width }
    private var snapW: CGFloat { width - 2 * (pad + frameGap + 1) }
    private var snapH: CGFloat { (401.0 * (snapW / 344.0)).rounded() }
    private var capH: CGFloat { 66.0 / 280 * width }
    private var height: CGFloat { snapH + capH + 2 * (pad + frameGap + 1) }

    var body: some View {
        ZStack(alignment: .top) {
            // paper, clipped to the perforated outline
            RadialGradient(gradient: Gradient(colors: [Color(hex: "#FFFEF9"), paper]),
                           center: .init(x: 0.30, y: 0.20), startRadius: 0, endRadius: width * 0.9)
                .clipShape(StampPerforationShape(notchRadius: 5.5 / 280 * width, target: 19.0 / 280 * width))

            VStack(spacing: 0) {
                // printed hairline frame containing garden + caption
                VStack(spacing: 0) {
                    Image(uiImage: gardenImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: snapW, height: snapH)
                        .clipShape(RoundedRectangle(cornerRadius: 24 * (snapW / 344), style: .continuous))

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage)
                                .font(DinoTheme.dinoFont(size: width * 0.068))
                                .foregroundColor(ink)
                            Text(GardenShare.footer)
                                .font(DinoTheme.dinoFont(size: width * 0.042))
                                .foregroundColor(ink2)
                        }
                        Spacer(minLength: 8)
                        VStack(spacing: 0) {
                            Text("\(day)")
                                .font(DinoTheme.numericFont(size: width * 0.1))
                                .fontWeight(.bold)
                                .foregroundColor(sage)
                            Text(GardenShare.daysLabel)
                                .font(DinoTheme.dinoFont(size: width * 0.036))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundColor(ink3)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .frame(height: capH, alignment: .bottom)
                    .padding(.bottom, 3)
                }
                .padding(frameGap)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(hex: "#7A7266").opacity(0.32), lineWidth: 1))
                .padding(pad)
            }

            // tiny top label, like a country line on a stamp
            Text(GardenShare.topLabel)
                .font(DinoTheme.dinoFont(size: width * 0.036))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "#7A7266").opacity(0.7))
                .padding(.top, pad + 3)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topTrailing) {
            GardenPostmark(date: date, size: width * 0.23)
                .padding(.top, pad - 6)
                .padding(.trailing, pad - 12)
        }
        .shadow(color: Color(red: 60/255, green: 50/255, blue: 30/255).opacity(0.22), radius: 22, y: 10)
    }
}

// MARK: - Stamp composer (device-reliable UIKit snapshot)

@MainActor
enum GardenStampComposer {
    /// Render the stamp card to a UIImage via a hosted UIView snapshot — the
    /// card is Image + gradients + shapes + text (no Canvas/SceneKit), so this
    /// captures reliably on device.
    static func render(_ card: GardenStampCard, scale: CGFloat = 2) -> UIImage? {
        let target = GardenStampCard.size(width: card.width)
        let content = card.environment(\.colorScheme, .light)

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            let r = ImageRenderer(content: content); r.scale = scale; return r.uiImage
        }
        let host = UIHostingController(rootView: content)
        host.view.frame = CGRect(origin: .zero, size: target)
        host.view.backgroundColor = .clear
        host.view.layer.zPosition = -1
        window.addSubview(host.view)
        window.sendSubviewToBack(host.view)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        host.view.removeFromSuperview()
        return image
    }
}
