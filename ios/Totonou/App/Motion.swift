import SwiftUI
import TotonouCore

// Everything that moves, in one place. The rule for motion in this app: short,
// quiet, and it must mean something (arriving, counting, being struck, breathing).
// Every piece here stands still when the user has Reduce Motion switched on.

// MARK: Entrance

/// Fades and lifts a view into place. `index` delays it, so a column of views
/// arrives one after another.
private struct Appear: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .blur(radius: shown || reduceMotion ? 0 : 3)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(Double(index) * 0.06)) { shown = true }
            }
    }
}

extension View {
    func appear(_ index: Int = 0) -> some View {
        modifier(Appear(index: index))
    }
}

// MARK: Numbers

/// A number that counts up to its value when it appears, and rolls when it changes.
struct RollingNumber: View {
    let value: Int
    @State private var shown: Double = 0

    var body: some View {
        CountingText(value: shown)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { shown = Double(value) }
            }
            .onChange(of: value) { _, new in
                withAnimation(.snappy(duration: 0.5)) { shown = Double(new) }
            }
            .accessibilityLabel("\(value)")
    }
}

/// SwiftUI can only animate values it knows how to interpolate. `Animatable`
/// tells it which number to slide; `body` is then called for every frame.
private struct CountingText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))").monospacedDigit()
    }
}

// MARK: Impact

/// A quick sideways rattle. Increase `animatableData` by one, inside an
/// animation, to play it once.
struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Shrinks a button slightly while it is pressed.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: Atmosphere

/// Slow motes of light drifting upward, like dust in a dungeon gate.
struct InkMist: View {
    var count = 26
    var tint: Color = Ink.ai
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // TimelineView redraws on a clock; Canvas draws without creating a view
        // per particle. Together they are the cheap way to animate many things.
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<count {
                    // No stored particles: each mote's path is a pure function
                    // of its index and the time.
                    let seed = Double(index) * 12.9898
                    let speed = 0.010 + noise(seed) * 0.022
                    let rise = fraction(time * speed + noise(seed * 2.3))
                    let x = noise(seed * 1.7) + sin(time * 0.35 + seed) * 0.025
                    let radius = 0.6 + noise(seed * 3.1) * 1.3
                    let alpha = sin(rise * .pi) * 0.55
                    let dot = CGRect(x: x * size.width, y: (1 - rise) * size.height,
                                     width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fraction(_ value: Double) -> Double { value - value.rounded(.down) }
    private func noise(_ seed: Double) -> Double { fraction(sin(seed) * 43758.5453) }
}

// MARK: Reward notice

/// The message that drops in when a quest pays out.
struct RewardBanner: View {
    let notice: RewardNotice

    var body: some View {
        HStack(spacing: 16) {
            Text("+\(notice.xp) XP").font(.number(17, weight: .bold)).foregroundStyle(Ink.ai)
            if let stat = notice.stat {
                HStack(spacing: 5) {
                    GlyphIcon(stat.glyph, size: 16, tint: Ink.washi)
                    Text("+\(notice.points)").font(.number(17))
                }
            }
            if notice.minutes > 0 {
                HStack(spacing: 5) {
                    GlyphIcon(.hourglass, size: 16, tint: Ink.washi)
                    Text("+\(notice.minutes) min").font(.number(17))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Ink.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(Ink.ai.opacity(0.6), lineWidth: 1))
        .shadow(color: Ink.ai.opacity(0.3), radius: 18)
        .accessibilityElement(children: .combine)
    }
}
