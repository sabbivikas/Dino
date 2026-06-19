//
//  FocusRoomScene.swift
//  Dino
//
//  Native port of the design-system "Today's Focus Card" cozy living-room
//  scene (preview/focus-card.html). One stickman in a warm room that
//  follows the device clock through four states — morning (coffee), midday
//  (desk), evening (couch + TV), night (asleep in bed). Slow ambient motion
//  only: TV glow + flicker, lamp glow breathing, idle body breathing, coffee
//  steam (morning), drifting z's (night), twinkling stars (night). Adjacent
//  states crossfade across the clock boundary. Freezes under reduce-motion.
//
//  Rendered with SwiftUI Canvas + TimelineView (same pattern as the previous
//  FocusCardScene). The 420×158 design viewBox is scaled to fit width.
//

import SwiftUI

struct FocusRoomScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum TimeOfDay: CaseIterable {
        case morning, midday, evening, night

        /// Spec boundaries: morning 5–11, midday 11–17, evening 17–21, night 21–5.
        static func at(_ date: Date) -> TimeOfDay {
            switch Calendar.current.component(.hour, from: date) {
            case 5..<11:  return .morning
            case 11..<17: return .midday
            case 17..<21: return .evening
            default:      return .night
            }
        }
    }

    /// Ambient caption shown under the card, tied to the clock.
    static func hint(at date: Date) -> String {
        switch TimeOfDay.at(date) {
        case .morning: return "a slow morning coffee"
        case .midday:  return "heads-down for the afternoon"
        case .evening: return "a cozy evening in"
        case .night:   return "resting up for tomorrow"
        }
    }

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    render(&context, size: size, time: 0, animated: false)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        render(&context, size: size, time: t, animated: true)
                    }
                }
            }
        }
        .aspectRatio(420.0 / 158.0, contentMode: .fit)
        .drawingGroup()
    }

    // MARK: - State weighting (clock-driven crossfade)

    /// Up to two adjacent states with weights summing to 1. Within a 90s
    /// window straddling each hour boundary the two states blend; otherwise
    /// a single state has weight 1. Fully deterministic from the clock.
    private func stateWeights(time: Date) -> [(TimeOfDay, Double)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: time)
        let s = time.timeIntervalSince(start)   // seconds since midnight
        let window = 90.0
        let boundaries: [(sec: Double, prev: TimeOfDay, next: TimeOfDay)] = [
            (5 * 3600,  .night,   .morning),
            (11 * 3600, .morning, .midday),
            (17 * 3600, .midday,  .evening),
            (21 * 3600, .evening, .night)
        ]
        for b in boundaries where s >= b.sec - window / 2 && s <= b.sec + window / 2 {
            let p = (s - (b.sec - window / 2)) / window   // 0..1 prev→next
            return [(b.prev, 1 - p), (b.next, p)]
        }
        return [(TimeOfDay.at(time), 1.0)]
    }

    // MARK: - Render

    private func render(_ ctx: inout GraphicsContext, size: CGSize,
                        time t: TimeInterval, animated: Bool) {
        let scale = size.width / 420.0
        // Cream wall fills any vertical letterbox invisibly (wall IS cream).
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(hex(0xFAF6EC)))
        ctx.scaleBy(x: scale, y: scale)

        let weights = animated ? stateWeights(time: Date(now: t))
                               : [(TimeOfDay.at(Date()), 1.0)]
        var lampLevel = 0.0, tvLevel = 0.0
        for (state, w) in weights {
            if state == .evening || state == .night { lampLevel += w }
            if state == .evening { tvLevel += w }
        }

        drawRoomBase(&ctx)
        drawGlows(&ctx, t: t, animated: animated, lampLevel: lampLevel, tvLevel: tvLevel)
        drawWindowFrame(&ctx)
        for (state, w) in weights { drawSky(&ctx, state: state, weight: w, t: t, animated: animated) }
        drawWindowMuntins(&ctx)
        drawPlant(&ctx)
        drawLamp(&ctx)
        drawRug(&ctx)
        drawCouch(&ctx)
        drawTV(&ctx, t: t, animated: animated, tvLevel: tvLevel)
        for (state, w) in weights { drawStage(&ctx, state: state, weight: w, t: t, animated: animated) }
    }

    // MARK: - Primitive helpers

    private func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255)
    }
    private func rrect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }
    private func ell(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }
    private func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Path {
        var p = Path(); p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2)); return p
    }
    private func stroke(_ c: inout GraphicsContext, _ p: Path, _ color: Color, _ w: Double,
                        cap: CGLineCap = .round, join: CGLineJoin = .round) {
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: join))
    }
    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }

    // MARK: - Static room

    private func drawRoomBase(_ c: inout GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: 124, width: 420, height: 34)), with: .color(hex(0xECE1CC)))
        c.fill(Path(CGRect(x: 0, y: 122, width: 420, height: 3)), with: .color(hex(0xDCCDAE)))
    }

    private func drawGlows(_ c: inout GraphicsContext, t: TimeInterval, animated: Bool,
                           lampLevel: Double, tvLevel: Double) {
        // Warm lamp glow (breathing) + cool TV glow (flicker), radial fades.
        let lampPulse = animated ? (0.62 + 0.30 * sin(t * 0.9)) : 0.70
        let lampOp = lampLevel * lampPulse
        if lampOp > 0.001 {
            var lc = c; lc.opacity = lampOp
            lc.fill(ell(372, 74, 70, 78),
                    with: .radialGradient(
                        Gradient(stops: [.init(color: hex(0xFFE2A0).opacity(0.8), location: 0),
                                         .init(color: hex(0xFFE2A0).opacity(0), location: 0.7)]),
                        center: CGPoint(x: 372, y: 74), startRadius: 0, endRadius: 78))
        }
        let tvPulse = animated
            ? clamp(0.55 + 0.32 * sin(t * 2.4) + 0.16 * sin(t * 5.7 + 1) + 0.09 * sin(t * 11.3), 0.18, 0.95)
            : 0.60
        let tvOp = tvLevel * tvPulse
        if tvOp > 0.001 {
            var tc = c; tc.opacity = tvOp
            tc.fill(ell(116, 110, 62, 46),
                    with: .radialGradient(
                        Gradient(stops: [.init(color: hex(0xD2EEE8).opacity(0.75), location: 0),
                                         .init(color: hex(0xD2EEE8).opacity(0), location: 0.7)]),
                        center: CGPoint(x: 116, y: 110), startRadius: 0, endRadius: 62))
        }
    }

    private func drawWindowFrame(_ c: inout GraphicsContext) {
        c.fill(rrect(14, 14, 66, 50, 3), with: .color(hex(0xC9A98C)))
    }

    private func drawWindowMuntins(_ c: inout GraphicsContext) {
        stroke(&c, line(47, 18, 47, 60), hex(0xFAF6EC), 2.4)
        stroke(&c, line(18, 39, 76, 39), hex(0xFAF6EC), 2.4)
        c.fill(rrect(11, 62, 72, 4, 2), with: .color(hex(0xC9A98C)))
    }

    private func drawPlant(_ c: inout GraphicsContext) {
        func leaf(_ d: String, _ fill: Color) {
            let p = Path(svg: d)
            c.fill(p, with: .color(fill))
            stroke(&c, p, hex(0x5E9A6B), 2.2)
        }
        leaf("M 40 104 C 30 96 28 84 33 76 C 37 86 40 92 40 104 Z", hex(0xA8C5A0))
        leaf("M 40 106 C 50 96 54 86 50 77 C 45 87 42 94 40 106 Z", hex(0x9DBE94))
        leaf("M 40 108 C 36 98 30 92 22 90 C 30 96 34 100 40 108 Z", hex(0xB6CFAE))
        let pot = Path(svg: "M 31 106 L 49 106 L 46 122 L 34 122 Z")
        c.fill(pot, with: .color(hex(0xF0B492))); stroke(&c, pot, hex(0xD99B7E), 2)
        let rim = rrect(29, 103, 22, 5, 2.5)
        c.fill(rim, with: .color(hex(0xF5C4A8))); stroke(&c, rim, hex(0xD99B7E), 2)
    }

    private func drawLamp(_ c: inout GraphicsContext) {
        stroke(&c, line(372, 70, 372, 123), hex(0xB98A63), 3)
        c.fill(ell(372, 123, 13, 3.4), with: .color(hex(0xC9A98C)))
        let shade = Path(svg: "M 358 54 L 386 54 L 390 71 L 354 71 Z")
        c.fill(shade, with: .color(hex(0xF3DCA6))); stroke(&c, shade, hex(0xD9B978), 2)
        c.fill(ell(372, 71, 18, 3), with: .color(hex(0xFBEBB8)))
    }

    private func drawRug(_ c: inout GraphicsContext) {
        var rc = c; rc.opacity = 0.92
        rc.fill(ell(210, 138, 158, 14),
                with: .linearGradient(Gradient(colors: [hex(0xB6CFAE), hex(0x9DBE94)]),
                                      startPoint: CGPoint(x: 210, y: 124), endPoint: CGPoint(x: 210, y: 152)))
        var ic = c; ic.opacity = 0.55
        ic.fill(ell(210, 137, 120, 9), with: .color(hex(0xC7DCC0)))
    }

    private func drawCouch(_ c: inout GraphicsContext) {
        c.fill(rrect(168, 120, 8, 8, 2), with: .color(hex(0xB98A63)))
        c.fill(rrect(300, 120, 8, 8, 2), with: .color(hex(0xB98A63)))
        let back = rrect(158, 82, 156, 30, 11)
        c.fill(back, with: .color(hex(0xF5C4A8))); stroke(&c, back, hex(0xD99B7E), 2)
        var sc = c; sc.opacity = 0.7
        stroke(&sc, line(210, 85, 210, 108), hex(0xD99B7E), 1.6)
        stroke(&sc, line(262, 85, 262, 108), hex(0xD99B7E), 1.6)
        let seat = rrect(156, 104, 160, 20, 9)
        c.fill(seat, with: .color(hex(0xEFB597))); stroke(&c, seat, hex(0xD99B7E), 2)
        for x in [146.0, 306.0] {
            let arm = rrect(x, 92, 20, 34, 9)
            c.fill(arm, with: .color(hex(0xF2BB9C))); stroke(&c, arm, hex(0xD99B7E), 2)
        }
        let pillow = Path(svg: "M 146 96 Q 156 92 166 96 L 166 116 Q 156 120 146 116 Z")
        c.fill(pillow, with: .color(hex(0xA8C5A0))); stroke(&c, pillow, hex(0x8AAE82), 1.6)
        var pc = c; pc.opacity = 0.6
        stroke(&pc, line(150, 100, 162, 100), hex(0x8AAE82), 1.2)
        stroke(&pc, line(150, 106, 162, 106), hex(0x8AAE82), 1.2)
    }

    private func drawTV(_ c: inout GraphicsContext, t: TimeInterval, animated: Bool, tvLevel: Double) {
        c.fill(rrect(98, 120, 36, 4, 2), with: .color(hex(0xB98A63)))
        stroke(&c, line(106, 124, 104, 130), hex(0xB98A63), 3)
        stroke(&c, line(126, 124, 128, 130), hex(0xB98A63), 3)
        stroke(&c, line(112, 98, 104, 84), hex(0x3C4A43), 2)
        stroke(&c, line(120, 98, 128, 86), hex(0x3C4A43), 2)
        c.fill(ell(104, 84, 1.6, 1.6), with: .color(hex(0x3C4A43)))
        c.fill(ell(128, 86, 1.6, 1.6), with: .color(hex(0x3C4A43)))
        let bodyR = rrect(92, 96, 50, 26, 5)
        c.fill(bodyR, with: .color(hex(0x3C4A43))); stroke(&c, bodyR, hex(0x2A332E), 2)
        c.fill(rrect(97, 100, 34, 18, 3),
               with: .radialGradient(Gradient(colors: [hex(0xEAF5F2), hex(0xA6CAC6)]),
                                     center: CGPoint(x: 114, y: 108), startRadius: 0, endRadius: 20))
        // Flicker overlay
        let flick = animated
            ? clamp(0.14 + 0.12 * sin(t * 7.3 + 2) + 0.07 * sin(t * 13.1), 0.02, 0.34)
            : 0.10
        let flickOp = tvLevel * flick
        if flickOp > 0.001 {
            var fc = c; fc.opacity = flickOp
            fc.fill(rrect(97, 100, 34, 18, 3), with: .color(.white))
        }
        var dc = c; dc.opacity = 0.7
        dc.fill(ell(114, 109, 3.4, 3.4), with: .color(hex(0xF5C4A8)))
        c.fill(ell(138, 103, 1.4, 1.4), with: .color(hex(0x9DB0A8)))
        c.fill(ell(138, 109, 1.4, 1.4), with: .color(hex(0x9DB0A8)))
    }

    // MARK: - Per-state sky (clipped to window glass)

    private func drawSky(_ base: inout GraphicsContext, state: TimeOfDay, weight: Double,
                         t: TimeInterval, animated: Bool) {
        guard weight > 0.001 else { return }
        var c = base
        c.opacity = weight
        c.clip(to: Path(CGRect(x: 18, y: 18, width: 58, height: 42)))
        let glass = CGRect(x: 18, y: 18, width: 58, height: 42)
        func grad(_ colors: [(UInt32, Double)]) -> GraphicsContext.Shading {
            .linearGradient(Gradient(stops: colors.map { .init(color: hex($0.0), location: $0.1) }),
                            startPoint: CGPoint(x: 47, y: 18), endPoint: CGPoint(x: 47, y: 60))
        }
        switch state {
        case .morning:
            c.fill(Path(glass), with: grad([(0xFCEAC6, 0), (0xF6DAC2, 0.55), (0xD2E2EC, 1)]))
            c.fill(ell(66, 48, 10, 10), with: .color(hex(0xFFE7AE).opacity(0.28)))
            c.fill(ell(66, 48, 6, 6), with: .color(hex(0xFFE7AE).opacity(0.85)))
        case .midday:
            c.fill(Path(glass), with: grad([(0x8FC6EA, 0), (0xBFE0F2, 0.6), (0xE6F2F8, 1)]))
            c.fill(ell(64, 27, 9, 9), with: .color(hex(0xFFF6D6).opacity(0.35)))
            c.fill(ell(64, 27, 5.5, 5.5), with: .color(hex(0xFFF6D6)))
            var cl = c; cl.opacity = c.opacity * 0.85
            cl.fill(ell(33, 32, 9, 3.4), with: .color(.white))
            cl.fill(ell(40, 30, 6, 3), with: .color(.white))
        case .evening:
            c.fill(Path(glass), with: grad([(0xF4A65E, 0), (0xDD8C78, 0.52), (0x8A7E9E, 1)]))
            c.fill(ell(34, 50, 10, 10), with: .color(hex(0xFFD9A0).opacity(0.3)))
            c.fill(ell(34, 50, 5.5, 5.5), with: .color(hex(0xFFD9A0)))
        case .night:
            c.fill(Path(glass), with: grad([(0x1E2A46, 0), (0x33405F, 1)]))
            c.fill(ell(64, 29, 6, 6), with: .color(hex(0xFCEFCF)))
            c.fill(ell(61, 28, 5, 5), with: .color(hex(0x33405F)))   // crescent bite
            let stars: [(Double, Double, Double, Double)] = [
                (30, 27, 1, 0), (40, 34, 0.9, 1.3), (26, 40, 0.8, 2.6), (48, 24, 0.8, 3.9)
            ]
            for (x, y, r, ph) in stars {
                let tw = animated ? (0.5 + 0.5 * sin((t + ph) * 1.9)) : 0.7
                var sc = c; sc.opacity = c.opacity * tw
                sc.fill(ell(x, y, r, r), with: .color(hex(0xFCEFCF)))
            }
        }
    }

    // MARK: - Per-state stage (one stickman)

    private func drawStage(_ base: inout GraphicsContext, state: TimeOfDay, weight: Double,
                           t: TimeInterval, animated: Bool) {
        guard weight > 0.001 else { return }
        var c = base
        c.opacity = weight
        let ink = hex(0x41505A)
        let headFill = hex(0xFCF7EC)
        let rise = animated ? (sin(t * (2 * .pi / 5.6)) * 0.5 + 0.5) : 0.5

        // Breathing transform for the upper body: tiny lift + scaleY about a pivot.
        func breathe(pivotY: Double, _ body: (inout GraphicsContext) -> Void) {
            var bc = c
            bc.translateBy(x: 0, y: -rise * 0.5)
            bc.translateBy(x: 0, y: pivotY)
            bc.scaleBy(x: 1, y: 1 + rise * 0.035)
            bc.translateBy(x: 0, y: -pivotY)
            body(&bc)
        }
        switch state {
        case .morning:
            stroke(&c, line(232, 132, 232, 150), hex(0xB98A63), 3)
            c.fill(ell(232, 150, 9, 2.4), with: .color(hex(0xC9A98C)))
            let top = ell(232, 131, 16, 4)
            c.fill(top, with: .color(hex(0xD8B58C))); stroke(&c, top, hex(0xB98A63), 1.6)
            let mug = rrect(226, 124, 9, 8, 1.6)
            c.fill(mug, with: .color(hex(0xFCF7EC))); stroke(&c, mug, ink, 1.6)
            stroke(&c, Path(svg: "M 235 126 q 4 1.5 0 4"), ink, 1.4)
            // steam
            let steamPaths = ["M 229 122 q -2 -3 0 -6 q 2 -3 0 -6", "M 233 122 q 2 -3 0 -6 q -2 -3 0 -6"]
            for (i, d) in steamPaths.enumerated() {
                let sp = animated ? ((t * 0.5 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)) : Double(i) * 0.5
                let so = sin(sp * .pi) * 0.7
                var stc = c; stc.opacity = c.opacity * max(0, so)
                stc.translateBy(x: 0, y: -sp * 6)
                stroke(&stc, Path(svg: d), hex(0xC9B8A0), 1.5)
            }
            // legs (static)
            stroke(&c, line(196, 138, 190, 150), ink, 3)
            stroke(&c, line(196, 138, 201, 150), ink, 3)
            breathe(pivotY: 138) { b in
                self.stroke(&b, self.line(196, 120, 196, 138), ink, 3)
                self.stroke(&b, self.line(196, 123, 186, 132), ink, 3)
                self.stroke(&b, self.line(196, 124, 216, 128), ink, 3)
                let h = self.ell(196, 112, 6.4, 6.4)
                b.fill(h, with: .color(headFill)); self.stroke(&b, h, ink, 2.6)
                b.fill(self.ell(198.4, 111, 1.1, 1.1), with: .color(ink))
                self.stroke(&b, Path(svg: "M 197 115 q 2 1.4 3.4 0"), ink, 1.4)
            }
        case .midday:
            stroke(&c, line(183, 120, 183, 138), hex(0xB98A63), 3)
            let desk = rrect(198, 130, 54, 4, 1.5)
            c.fill(desk, with: .color(hex(0xD8B58C))); stroke(&c, desk, hex(0xB98A63), 1.4)
            stroke(&c, line(203, 134, 203, 150), hex(0xB98A63), 3)
            stroke(&c, line(247, 134, 247, 150), hex(0xB98A63), 3)
            let screen = rrect(214, 119, 17, 11, 1.4)
            c.fill(screen, with: .color(hex(0xCFE0E6))); stroke(&c, screen, ink, 1.6)
            let kbd = rrect(212, 129, 21, 3, 1.2)
            c.fill(kbd, with: .color(hex(0x9DB0A8))); stroke(&c, kbd, ink, 1.4)
            stroke(&c, line(190, 134, 200, 137), ink, 3)
            stroke(&c, line(200, 137, 200, 150), ink, 3)
            breathe(pivotY: 134) { b in
                self.stroke(&b, self.line(190, 120, 190, 134), ink, 3)
                self.stroke(&b, self.line(190, 123, 208, 128), ink, 3)
                self.stroke(&b, self.line(190, 123, 206, 130), ink, 3)
                let h = self.ell(190, 113, 6.4, 6.4)
                b.fill(h, with: .color(headFill)); self.stroke(&b, h, ink, 2.6)
                b.fill(self.ell(193, 112.5, 1.1, 1.1), with: .color(ink))
                self.stroke(&b, Path(svg: "M 191 116 q 2 1.4 3.4 0"), ink, 1.4)
            }
        case .evening:
            stroke(&c, line(236, 110, 247, 114), ink, 3)
            stroke(&c, line(247, 114, 248, 124), ink, 3)
            stroke(&c, line(236, 111, 244, 118), ink, 3)
            stroke(&c, line(244, 118, 243, 126), ink, 3)
            breathe(pivotY: 110) { b in
                self.stroke(&b, self.line(236, 96, 236, 110), ink, 3)
                self.stroke(&b, self.line(236, 99, 227, 107), ink, 3)
                self.stroke(&b, self.line(236, 100, 245, 107), ink, 3)
                let h = self.ell(236, 89, 6.6, 6.6)
                b.fill(h, with: .color(headFill)); self.stroke(&b, h, ink, 2.6)
                b.fill(self.ell(232.6, 88, 1.2, 1.2), with: .color(ink))
                self.stroke(&b, Path(svg: "M 230 91.5 q 2.2 1.5 4 0"), ink, 1.4)
            }
        case .night:
            c.fill(rrect(174, 122, 8, 28, 2), with: .color(hex(0xB98A63)))
            let frame = rrect(180, 140, 94, 11, 3)
            c.fill(frame, with: .color(hex(0xC9A98C))); stroke(&c, frame, hex(0xB98A63), 1.4)
            c.fill(rrect(270, 150, 5, 5, 1.5), with: .color(hex(0xA87C56)))
            let sheet = rrect(182, 133, 90, 9, 3)
            c.fill(sheet, with: .color(hex(0xF3ECDD))); stroke(&c, sheet, hex(0xDACFB6), 1.2)
            let pillow = rrect(184, 129, 17, 8, 3)
            c.fill(pillow, with: .color(hex(0xFCF7EC))); stroke(&c, pillow, hex(0xDACFB6), 1.4)
            let blanket = Path(svg: "M 206 134 q 14 -6 30 0 q 15 6 32 0 v6 a3 3 0 0 1 -3 3 h -56 a3 3 0 0 1 -3 -3 Z")
            c.fill(blanket, with: .color(hex(0xA8C5A0))); stroke(&c, blanket, hex(0x8AAE82), 1.6)
            var bc = c; bc.opacity = c.opacity * 0.55
            stroke(&bc, line(208, 140, 266, 140), hex(0x8AAE82), 1.1)
            breathe(pivotY: 136) { b in
                let h = self.ell(196, 130, 6.6, 6.6)
                b.fill(h, with: .color(headFill)); self.stroke(&b, h, ink, 2.6)
                self.stroke(&b, Path(svg: "M 192.6 129.4 q 1.6 1.4 3.2 0"), ink, 1.4)
                self.stroke(&b, Path(svg: "M 197.6 129.6 q 1.6 1.4 3.2 0"), ink, 1.4)
            }
            // drifting z's
            let zs: [(Double, Double, Double, Double)] = [(205, 122, 7, 0), (210, 116, 9, 0.33), (216, 109, 11, 0.66)]
            for (x, y, fs, off) in zs {
                let zp = animated ? ((t * 0.42 + off).truncatingRemainder(dividingBy: 1)) : off
                let zo = zp < 0.15 ? zp / 0.15 : (1 - (zp - 0.15) / 0.85)
                var zc = c; zc.opacity = c.opacity * clamp(zo, 0, 1)
                zc.translateBy(x: zp * 5, y: -zp * 12)
                let sc = 0.7 + zp * 0.5
                zc.translateBy(x: x, y: y); zc.scaleBy(x: sc, y: sc); zc.translateBy(x: -x, y: -y)
                zc.draw(Text("z").font(DinoTheme.dinoFont(size: fs)).foregroundColor(hex(0x7E8A93)),
                        at: CGPoint(x: x, y: y))
            }
        }
    }

}

// MARK: - Minimal SVG path-data parser (subset: M m L l C c Q q V v H h A a Z z)

private extension Path {
    /// Parses the SVG path commands used by the focus-room artwork. Supports
    /// absolute + relative M/L/C/Q/V/H/A/Z. Coordinates are in viewBox units.
    init(svg d: String) {
        var path = Path()
        var i = d.startIndex
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var cmd: Character = " "

        func skipSep() {
            while i < d.endIndex, d[i] == " " || d[i] == "," || d[i] == "\n" || d[i] == "\t" { i = d.index(after: i) }
        }
        func num() -> Double {
            skipSep()
            var s = ""
            while i < d.endIndex {
                let ch = d[i]
                if ch.isNumber || ch == "." || ch == "-" || ch == "+" || ch == "e" || ch == "E" {
                    s.append(ch); i = d.index(after: i)
                } else { break }
            }
            return Double(s) ?? 0
        }
        func pt(_ x: Double, _ y: Double, rel: Bool) -> CGPoint {
            rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }

        while i < d.endIndex {
            skipSep()
            guard i < d.endIndex else { break }
            let ch = d[i]
            if ch.isLetter { cmd = ch; i = d.index(after: i) }
            let rel = cmd.isLowercase
            switch Character(cmd.lowercased()) {
            case "m":
                let p = pt(num(), num(), rel: rel); path.move(to: p); cur = p; start = p; cmd = rel ? "l" : "L"
            case "l":
                let p = pt(num(), num(), rel: rel); path.addLine(to: p); cur = p
            case "h":
                let x = num(); let p = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: p); cur = p
            case "v":
                let y = num(); let p = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: p); cur = p
            case "c":
                let c1 = pt(num(), num(), rel: rel); let c2p = pt(num(), num(), rel: rel); let e = pt(num(), num(), rel: rel)
                path.addCurve(to: e, control1: c1, control2: c2p); cur = e
            case "q":
                let cp = pt(num(), num(), rel: rel); let e = pt(num(), num(), rel: rel)
                path.addQuadCurve(to: e, control: cp); cur = e
            case "a":
                // rx ry rot large sweep x y — approximate the small bed corner as a line.
                _ = num(); _ = num(); _ = num(); _ = num(); _ = num()
                let e = pt(num(), num(), rel: rel); path.addLine(to: e); cur = e
            case "z":
                path.closeSubpath(); cur = start
            default:
                i = d.index(after: i)
            }
        }
        self = path
    }
}

// MARK: - Date offset helper (wall-clock time → absolute Date)

private extension Date {
    /// Reconstructs an absolute Date from a `timeIntervalSinceReferenceDate`,
    /// so the clock-driven state weighting reads the real current time.
    init(now timeIntervalSinceReferenceDate: TimeInterval) {
        self = Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate)
    }
}
