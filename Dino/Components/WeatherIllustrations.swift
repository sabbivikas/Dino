//
//  WeatherIllustrations.swift
//  Dino
//
//  Animated cartoon weather illustrations for mood cards.
//  Replaces static emoji with hand-drawn SwiftUI Canvas animations.
//

import SwiftUI

// MARK: - Router

struct AnimatedWeatherIllustration: View {
    let weather: EmotionalWeather
    let size: CGFloat

    var body: some View {
        Group {
            switch weather {
            case .clear:
                SunnyIllustration()
            case .partlyCloudy:
                PartlyCloudyIllustration()
            case .overwhelmed:
                RainyIllustration()
            case .drained:
                StormyIllustration()
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sunny: Bouncing sun with rotating rays and face

private struct SunnyIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let cx = w * 0.5
                let cy = h * 0.48
                let sunR = w * 0.22

                // --- Rays (rotating) ---
                let rayAngle = t.remainder(dividingBy: 6.0) / 6.0 * 2 * .pi
                let innerR = sunR + w * 0.04
                let outerR = sunR + w * 0.14
                for i in 0..<8 {
                    let angle = rayAngle + Double(i) * .pi / 4
                    var ray = Path()
                    ray.move(to: CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
                    ray.addLine(to: CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
                    context.stroke(ray, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                // --- Sun body (squash-stretch bounce) ---
                let bounceT = t.remainder(dividingBy: 2.2) / 2.2
                let normalizedBounce = bounceT < 0 ? bounceT + 1 : bounceT
                let (scaleX, scaleY) = sunBounceScale(normalizedBounce)

                context.drawLayer { ctx in
                    ctx.translateBy(x: cx, y: cy)
                    ctx.scaleBy(x: scaleX, y: scaleY)
                    ctx.translateBy(x: -cx, y: -cy)

                    // Fill
                    let sunCircle = Path(ellipseIn: CGRect(x: cx - sunR, y: cy - sunR, width: sunR * 2, height: sunR * 2))
                    ctx.fill(sunCircle, with: .color(Color(hex: "#FFD89B")))
                    ctx.stroke(sunCircle, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

                    // Blush
                    let blushR = w * 0.04
                    let blushY = cy + sunR * 0.25
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - sunR * 0.55 - blushR, y: blushY - blushR, width: blushR * 2, height: blushR * 2)),
                             with: .color(Color(hex: "#F5C6AA").opacity(0.7)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + sunR * 0.55 - blushR, y: blushY - blushR, width: blushR * 2, height: blushR * 2)),
                             with: .color(Color(hex: "#F5C6AA").opacity(0.7)))

                    // Eyes (blink)
                    let eyeR: CGFloat = w * 0.025
                    let eyeY = cy - sunR * 0.15
                    let blinkPhase = t.remainder(dividingBy: 4.0) / 4.0
                    let normalizedBlink = blinkPhase < 0 ? blinkPhase + 1 : blinkPhase
                    let eyeScaleY: CGFloat = (normalizedBlink > 0.93 && normalizedBlink < 0.95) ? 0.15 : 1.0

                    ctx.drawLayer { eyeCtx in
                        eyeCtx.translateBy(x: 0, y: eyeY)
                        eyeCtx.scaleBy(x: 1, y: eyeScaleY)
                        eyeCtx.translateBy(x: 0, y: -eyeY)

                        eyeCtx.fill(Path(ellipseIn: CGRect(x: cx - sunR * 0.28 - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)),
                                    with: .color(Color(hex: "#D4920A")))
                        eyeCtx.fill(Path(ellipseIn: CGRect(x: cx + sunR * 0.28 - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)),
                                    with: .color(Color(hex: "#D4920A")))
                    }

                    // Smile
                    var smile = Path()
                    let smileY = cy + sunR * 0.15
                    smile.move(to: CGPoint(x: cx - sunR * 0.30, y: smileY))
                    smile.addQuadCurve(to: CGPoint(x: cx + sunR * 0.30, y: smileY),
                                       control: CGPoint(x: cx, y: smileY + sunR * 0.25))
                    ctx.stroke(smile, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
            }
        }
    }

    private func sunBounceScale(_ t: Double) -> (CGFloat, CGFloat) {
        if t < 0.35 {
            let p = t / 0.35
            return (1 + 0.12 * CGFloat(p), 1 - 0.10 * CGFloat(p))
        } else if t < 0.50 {
            let p = (t - 0.35) / 0.15
            return (1.12 - 0.17 * CGFloat(p), 0.90 + 0.20 * CGFloat(p))
        } else if t < 0.70 {
            let p = (t - 0.50) / 0.20
            return (0.95 + 0.10 * CGFloat(p), 1.10 - 0.15 * CGFloat(p))
        } else {
            let p = (t - 0.70) / 0.30
            return (1.05 - 0.05 * CGFloat(p), 0.95 + 0.05 * CGFloat(p))
        }
    }
}

// MARK: - Partly Cloudy: Sun peeking behind drifting cloud

private struct PartlyCloudyIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // --- Sun (behind cloud, upper left) ---
                let sunPhase = sin(t * 2 * .pi / 3.0)  // 3s cycle
                let sunScale = 1.0 + 0.08 * sunPhase
                let sunOpacity = 0.9 + 0.1 * sunPhase
                let sunCx = w * 0.30
                let sunCy = h * 0.30
                let sunR = w * 0.16

                context.drawLayer { ctx in
                    ctx.opacity = sunOpacity
                    ctx.translateBy(x: sunCx, y: sunCy)
                    ctx.scaleBy(x: sunScale, y: sunScale)
                    ctx.translateBy(x: -sunCx, y: -sunCy)

                    // Rays
                    for i in 0..<4 {
                        let angle = Double(i) * .pi / 4 + .pi  // upper-left rays only
                        let rInner = sunR + w * 0.02
                        let rOuter = sunR + w * 0.08
                        if angle > .pi * 0.4 && angle < .pi * 1.6 {
                            var ray = Path()
                            ray.move(to: CGPoint(x: sunCx + rInner * cos(angle), y: sunCy + rInner * sin(angle)))
                            ray.addLine(to: CGPoint(x: sunCx + rOuter * cos(angle), y: sunCy + rOuter * sin(angle)))
                            ctx.stroke(ray, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                    }

                    let sunPath = Path(ellipseIn: CGRect(x: sunCx - sunR, y: sunCy - sunR, width: sunR * 2, height: sunR * 2))
                    ctx.fill(sunPath, with: .color(Color(hex: "#FFD89B")))
                    ctx.stroke(sunPath, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }

                // --- Cloud (drifting) ---
                let cloudPhase = sin(t * 2 * .pi / 4.0)  // 4s cycle
                let cloudOffsetX = -3 + 7 * cloudPhase
                let cloudOffsetY = cloudPhase * 1

                context.drawLayer { ctx in
                    ctx.translateBy(x: CGFloat(cloudOffsetX), y: CGFloat(cloudOffsetY))
                    drawCloud(in: ctx, size: size, x: w * 0.35, y: h * 0.50, scale: 1.0,
                              fillColor: Color(hex: "#F5FAFC"), strokeColor: Color(hex: "#3E6B80"))
                }
            }
        }
    }
}

// MARK: - Rainy: Jiggling cloud with falling drops

private struct RainyIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // --- Cloud (jiggling) ---
                let jiggle = sin(t * 2 * .pi / 0.8) * 1.5  // 0.8s cycle
                context.drawLayer { ctx in
                    ctx.translateBy(x: 0, y: CGFloat(jiggle))
                    drawCloud(in: ctx, size: size, x: w * 0.32, y: h * 0.28, scale: 1.0,
                              fillColor: Color(hex: "#C7CDD8"), strokeColor: Color(hex: "#4A5868"))
                }

                // --- Rain drops ---
                let dropXPositions: [CGFloat] = [0.28, 0.40, 0.52, 0.64, 0.76]
                let dropDelays: [Double] = [0, 0.35, 0.70, 0.20, 0.55]

                for i in 0..<5 {
                    let dropT = (t + dropDelays[i]).truncatingRemainder(dividingBy: 1.1) / 1.1
                    let dropX = w * dropXPositions[i]
                    let startY = h * 0.42
                    let endY = h * 0.82

                    let dropY = startY + CGFloat(dropT) * (endY - startY)
                    let dropOpacity: Double = dropT < 0.15 ? dropT / 0.15 : (dropT > 0.85 ? (1.0 - dropT) / 0.15 : 1.0)

                    var drop = Path()
                    drop.move(to: CGPoint(x: dropX, y: dropY - 4))
                    drop.addLine(to: CGPoint(x: dropX, y: dropY + 2))
                    context.stroke(drop, with: .color(Color(hex: "#6B8FA8").opacity(dropOpacity)),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                // --- Splashes ---
                let splashXPositions: [CGFloat] = [0.35, 0.65]
                let splashDelays: [Double] = [0.1, 0.6]
                for i in 0..<2 {
                    let sT = (t + splashDelays[i]).truncatingRemainder(dividingBy: 1.1) / 1.1
                    if sT > 0.75 {
                        let sProgress = (sT - 0.75) / 0.25
                        let sScale = 0.8 + sProgress * 0.6
                        let sOpacity = sProgress < 0.4 ? sProgress / 0.4 * 0.8 : 0.8 * (1.0 - (sProgress - 0.4) / 0.6)
                        let sX = w * splashXPositions[i]
                        let sY = h * 0.84
                        let sR = w * 0.04 * sScale

                        var splash = Path()
                        splash.addEllipse(in: CGRect(x: sX - sR, y: sY - sR * 0.5, width: sR * 2, height: sR))
                        context.stroke(splash, with: .color(Color(hex: "#6B8FA8").opacity(sOpacity)),
                                       style: StrokeStyle(lineWidth: 1.5))
                    }
                }
            }
        }
    }
}

// MARK: - Stormy: Shaking cloud with lightning bolt

private struct StormyIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // --- Flash background ---
                let flashT = t.truncatingRemainder(dividingBy: 1.8) / 1.8
                let flashOpacity = flashBgOpacity(flashT)
                if flashOpacity > 0 {
                    let flashRect = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 6)
                    context.fill(flashRect, with: .color(Color(hex: "#FFF3A0").opacity(flashOpacity)))
                }

                // --- Cloud (shaking) ---
                let shake = sin(t * 2 * .pi / 0.3) * 0.5  // 0.3s fast shake
                context.drawLayer { ctx in
                    ctx.translateBy(x: CGFloat(shake), y: 0)
                    drawCloud(in: ctx, size: size, x: w * 0.32, y: h * 0.28, scale: 1.05,
                              fillColor: Color(hex: "#7E8A9A"), strokeColor: Color(hex: "#2D3142"))
                }

                // --- Lightning bolt ---
                let boltOpacity = boltStrikeOpacity(flashT)
                if boltOpacity > 0 {
                    var bolt = Path()
                    bolt.move(to: CGPoint(x: w * 0.50, y: h * 0.40))
                    bolt.addLine(to: CGPoint(x: w * 0.40, y: h * 0.60))
                    bolt.addLine(to: CGPoint(x: w * 0.50, y: h * 0.60))
                    bolt.addLine(to: CGPoint(x: w * 0.42, y: h * 0.85))

                    context.stroke(bolt, with: .color(Color(hex: "#D4920A").opacity(boltOpacity)),
                                   style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                    // Bolt fill for thickness
                    var boltFill = Path()
                    boltFill.move(to: CGPoint(x: w * 0.50, y: h * 0.40))
                    boltFill.addLine(to: CGPoint(x: w * 0.40, y: h * 0.60))
                    boltFill.addLine(to: CGPoint(x: w * 0.50, y: h * 0.60))
                    boltFill.addLine(to: CGPoint(x: w * 0.42, y: h * 0.85))
                    boltFill.addLine(to: CGPoint(x: w * 0.52, y: h * 0.60))
                    boltFill.addLine(to: CGPoint(x: w * 0.42, y: h * 0.60))
                    boltFill.addLine(to: CGPoint(x: w * 0.52, y: h * 0.40))
                    boltFill.closeSubpath()
                    context.fill(boltFill, with: .color(Color(hex: "#FFC94D").opacity(boltOpacity)))
                }
            }
        }
    }

    private func boltStrikeOpacity(_ t: Double) -> Double {
        if t < 0.40 { return 0 }
        if t < 0.45 { return (t - 0.40) / 0.05 }
        if t < 0.48 { return 1.0 }
        if t < 0.52 { return 0.3 + 0.7 * ((t - 0.48) / 0.04) }
        if t < 0.65 { return 1.0 }
        if t < 0.75 { return 1.0 - (t - 0.65) / 0.10 }
        return 0
    }

    // softened per owner review — the storm stays, the screen-flash whispers
    private func flashBgOpacity(_ t: Double) -> Double {
        if t < 0.40 { return 0 }
        if t < 0.47 { return 0.30 * ((t - 0.40) / 0.07) }
        if t < 0.55 { return 0.13 }
        if t < 0.65 { return 0.13 * (1.0 - (t - 0.55) / 0.10) }
        return 0
    }
}

// MARK: - Shared Cloud Drawing Helper

private func drawCloud(in context: GraphicsContext, size: CGSize, x: CGFloat, y: CGFloat, scale: CGFloat, fillColor: Color, strokeColor: Color) {
    let w = size.width * scale
    let baseX = x - w * 0.20
    let baseY = y

    var cloud = Path()
    // Bottom left
    cloud.move(to: CGPoint(x: baseX, y: baseY + w * 0.14))
    // Left bump
    cloud.addQuadCurve(to: CGPoint(x: baseX + w * 0.08, y: baseY - w * 0.04),
                       control: CGPoint(x: baseX - w * 0.04, y: baseY + w * 0.02))
    // Top-left bump
    cloud.addQuadCurve(to: CGPoint(x: baseX + w * 0.22, y: baseY - w * 0.12),
                       control: CGPoint(x: baseX + w * 0.08, y: baseY - w * 0.14))
    // Top bump
    cloud.addQuadCurve(to: CGPoint(x: baseX + w * 0.38, y: baseY - w * 0.06),
                       control: CGPoint(x: baseX + w * 0.30, y: baseY - w * 0.18))
    // Right bump
    cloud.addQuadCurve(to: CGPoint(x: baseX + w * 0.44, y: baseY + w * 0.08),
                       control: CGPoint(x: baseX + w * 0.48, y: baseY - w * 0.04))
    // Bottom right
    cloud.addQuadCurve(to: CGPoint(x: baseX + w * 0.40, y: baseY + w * 0.14),
                       control: CGPoint(x: baseX + w * 0.46, y: baseY + w * 0.12))
    // Bottom
    cloud.addLine(to: CGPoint(x: baseX, y: baseY + w * 0.14))
    cloud.closeSubpath()

    context.fill(cloud, with: .color(fillColor))
    context.stroke(cloud, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
}
