import SwiftUI

/// The strip of washi tape that holds a paper card down.
///
/// Named `Story...` rather than plain `WashiTape` because `ResourcesView` already declares a
/// file-private `WashiTape` and the two collide at module scope. That one is shipping and this
/// is not a refactor, so the new surface takes the qualified name. `ComfortSlipView` keeps its
/// own inline copy for the same reason.
struct StoryWashiTape: View {
    var tint: Color = Color(hex: "#A8C5A0").opacity(0.70)
    var width: CGFloat = 116
    var height: CGFloat = 27
    var angle: Double = -3

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tint)
            .overlay(StoryWashiTapeStripes().clipShape(RoundedRectangle(cornerRadius: 2)))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(angle))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 15 / 255).opacity(0.10),
                    radius: 1.5, y: 1)
            .accessibilityHidden(true)
    }
}

private struct StoryWashiTapeStripes: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            while x < size.width + size.height {
                context.fill(Path(CGRect(x: x, y: -2, width: 5, height: size.height + 4)),
                             with: .color(.white.opacity(0.22)))
                x += 10
            }
        }
    }
}

/// Full-bleed warm paper with a faint speckle.
///
/// The grain uses a fixed seed rather than `random()`: a Canvas redraws on every layout pass,
/// and re-rolled noise would make the page shimmer while the scrubber moves.
struct StoryPaperBackground: View {
    var body: some View {
        Color(hex: "#FEFBF3")
            .overlay {
                Canvas { context, size in
                    var seed: UInt64 = 0x5EED
                    for _ in 0..<420 {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let x = CGFloat((seed >> 16) % 10_000) / 10_000 * size.width
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let y = CGFloat((seed >> 16) % 10_000) / 10_000 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)),
                                     with: .color(Color(hex: "#B9A580").opacity(0.13)))
                    }
                }
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
