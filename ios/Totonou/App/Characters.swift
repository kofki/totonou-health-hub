import SwiftUI
import TotonouCore

// The cast. Four figures, all drawn in code on a 100×100 grid with the same
// hairline strokes as the rest of the app:
//
//   HumanFigure    you, on Status. The aura grows with your rank.
//   OniMask        a boss, on Arcs. Its eyes dim as its HP drops.
//   KitsuneMask    the coach, on Coach.
//   Daruma         an arc's goal, on Arcs. The second eye fills in as the arc
//                  runs, the way a real daruma gets its eye when the wish is met.
//
// Each is a ZStack of small shapes, so any part can be animated on its own.

/// A shape described by a closure, so each body part does not need its own type.
struct Drawn: Shape {
    let draw: @Sendable (DrawingGrid) -> Path

    func path(in rect: CGRect) -> Path {
        draw(DrawingGrid(rect: rect, unit: 100))
    }
}

func hairline(_ side: CGFloat, _ weight: CGFloat = 1) -> StrokeStyle {
    StrokeStyle(lineWidth: max(1, side / 90) * weight, lineCap: .round, lineJoin: .round)
}

// MARK: Human

struct HumanFigure: View {
    let rank: Rank
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 for F- rank up to 1 for S rank.
    private var power: Double {
        Double(Rank.allCases.firstIndex(of: rank) ?? 0) / Double(Rank.allCases.count - 1)
    }

    private var tint: Color { rank >= .a ? rank.tint : Ink.ai }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                aura
                InkMist(count: 8 + Int(power * 30), tint: tint)
                    .mask(Ellipse().padding(side * 0.08))

                // Blade on the back.
                Drawn { g in
                    var p = Path()
                    p.polyline(g(64, 70), g(90, 14))
                    p.polyline(g(77.5, 27.9), g(86.5, 32.1))
                    return p
                }
                .stroke(Ink.mute, style: hairline(side, 1.4))

                Drawn(draw: Self.cloak).fill(Ink.raised)
                Drawn(draw: Self.cloak).stroke(Ink.washi.opacity(0.55), style: hairline(side))
                Drawn { g in
                    var p = Path()
                    p.polyline(g(40, 66), g(50, 82), g(60, 66))
                    return p
                }
                .stroke(Ink.washi.opacity(0.35), style: hairline(side))

                Drawn(draw: Self.hood).fill(Ink.sumi)
                Drawn(draw: Self.hood).stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))
                Drawn { g in
                    Path(ellipseIn: CGRect(origin: g(35, 28), size: CGSize(width: g.length(30), height: g.length(34))))
                }
                .fill(.black.opacity(0.7))

                eyes(side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(rank.rawValue) rank human")
    }

    private var aura: some View {
        Ellipse()
            .fill(tint)
            .scaleEffect(x: 0.62, y: 0.9)
            .blur(radius: 26)
            // Blur once into a texture, then only fade it (see GlowLayer).
            .padding(52)
            .drawingGroup()
            .padding(-52)
            // phaseAnimator loops through the listed values for as long as the
            // view is on screen. One value means it stays put.
            .phaseAnimator(reduceMotion ? [0.5] : [0.0, 1.0]) { content, phase in
                content.opacity(0.08 + power * 0.14 + phase * 0.08)
            } animation: { _ in
                .easeInOut(duration: 2.8)
            }
    }

    private func eyes(_ side: CGFloat) -> some View {
        Drawn { g in
            var p = Path()
            p.polyline(g(40, 46), g(47, 48))
            p.polyline(g(60, 46), g(53, 48))
            return p
        }
        .stroke(tint, style: hairline(side, 2))
        .shadow(color: tint, radius: side / 22)
        .phaseAnimator(reduceMotion ? [1.0] : [0.6, 1.0]) { content, phase in
            content.opacity(phase)
        } animation: { _ in
            .easeInOut(duration: 1.9)
        }
    }

    nonisolated private static let hood: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path()
        p.move(to: g(50, 6))
        p.addCurve(to: g(78, 52), control1: g(66, 10), control2: g(80, 30))
        p.addQuadCurve(to: g(66, 66), control: g(78, 62))
        p.addLine(to: g(34, 66))
        p.addQuadCurve(to: g(22, 52), control: g(22, 62))
        p.addCurve(to: g(50, 6), control1: g(20, 30), control2: g(34, 10))
        return p
    }

    nonisolated private static let cloak: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path()
        p.move(to: g(8, 100))
        p.addCurve(to: g(34, 62), control1: g(10, 78), control2: g(20, 66))
        p.addLine(to: g(66, 62))
        p.addCurve(to: g(92, 100), control1: g(80, 66), control2: g(90, 78))
        p.closeSubpath()
        return p
    }
}

// MARK: Oni

struct OniMask: View {
    /// 1 at full health, 0 when beaten.
    var hp: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var defeated: Bool { hp <= 0 }
    private var tint: Color { defeated ? Ink.mute : Ink.shu }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Drawn { g in
                    var p = Path()
                    // Face
                    p.move(to: g(22, 30))
                    p.addQuadCurve(to: g(78, 30), control: g(50, 18))
                    p.addQuadCurve(to: g(70, 78), control: g(86, 56))
                    p.addQuadCurve(to: g(50, 92), control: g(62, 90))
                    p.addQuadCurve(to: g(30, 78), control: g(38, 90))
                    p.addQuadCurve(to: g(22, 30), control: g(14, 56))
                    // Left horn, brow and fang, then the same again mirrored.
                    var half = Path()
                    half.move(to: g(26, 27))
                    half.addQuadCurve(to: g(16, 4), control: g(13, 20))
                    half.addQuadCurve(to: g(38, 24), control: g(26, 12))
                    half.polyline(g(26, 40), g(46, 47))
                    half.polyline(g(37, 71), g(40, 62), g(44, 74))
                    p.addPath(half)
                    p.addPath(half.mirrored(in: g.rect))
                    // Mouth
                    p.move(to: g(30, 68))
                    p.addQuadCurve(to: g(70, 68), control: g(50, 82))
                    return p
                }
                .stroke(tint, style: hairline(side, 1.3))

                if defeated {
                    Drawn { g in
                        var p = Path()
                        p.polyline(g(58, 18), g(50, 36), g(58, 50), g(46, 70))
                        return p
                    }
                    .stroke(Ink.washi.opacity(0.6), style: hairline(side))
                } else {
                    Drawn { g in
                        var eye = Path()
                        eye.polyline(g(30, 46), g(46, 52), g(32, 55), g(30, 46))
                        var p = eye
                        p.addPath(eye.mirrored(in: g.rect))
                        return p
                    }
                    .fill(Ink.shu)
                    .shadow(color: Ink.shu, radius: side / 14)
                    .phaseAnimator(reduceMotion ? [1.0] : [0.55, 1.0]) { content, phase in
                        // A weaker boss glows less.
                        content.opacity(phase * (0.35 + hp * 0.65))
                    } animation: { _ in
                        .easeInOut(duration: 1.4)
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: Kitsune

struct KitsuneMask: View {
    /// 1 is wide open, 0 is shut. Exercise 9 animates this.
    var eyeOpen: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Drawn { g in
                    var half = Path()
                    // Ear, then one side of the face down to the chin.
                    half.polyline(g(24, 32), g(20, 5), g(42, 23))
                    half.move(to: g(50, 23))
                    half.addQuadCurve(to: g(20, 36), control: g(30, 23))
                    half.addCurve(to: g(50, 95), control1: g(18, 62), control2: g(36, 82))
                    var p = half
                    p.addPath(half.mirrored(in: g.rect))
                    return p
                }
                .stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))

                // Vermilion markings: brow diamond, whiskers, nose.
                Drawn { g in
                    var half = Path()
                    half.polyline(g(26, 63), g(37, 67))
                    half.polyline(g(29, 71), g(38, 72))
                    half.polyline(g(26, 14), g(33, 24))
                    var p = half
                    p.addPath(half.mirrored(in: g.rect))
                    p.polyline(g(50, 30), g(54, 36), g(50, 42), g(46, 36), g(50, 30))
                    p.polyline(g(46, 84), g(54, 84), g(50, 89), g(46, 84))
                    return p
                }
                .stroke(Ink.shu, style: hairline(side, 1.3))

                Drawn { g in
                    var eye = Path()
                    eye.move(to: g(27, 51))
                    eye.addQuadCurve(to: g(46, 55), control: g(38, 44))
                    eye.addQuadCurve(to: g(27, 51), control: g(35, 56))
                    var p = eye
                    p.addPath(eye.mirrored(in: g.rect))
                    return p
                }
                .fill(Ink.washi)
                .scaleEffect(x: 1, y: max(0.08, eyeOpen), anchor: UnitPoint(x: 0.5, y: 0.52))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: Daruma

struct Daruma: View {
    /// 0...1. The right eye is drawn in as this grows, and filled at 1.
    var progress: Double

    @State private var nudges = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Drawn(draw: Self.outline).fill(Ink.shu.opacity(0.14))
                Drawn(draw: Self.outline).stroke(Ink.shu, style: hairline(side, 1.3))

                Drawn { g in
                    var p = Path(ellipseIn: CGRect(origin: g(26, 20), size: CGSize(width: g.length(48), height: g.length(36))))
                    var half = Path()
                    half.move(to: g(32, 30))
                    half.addQuadCurve(to: g(46, 31), control: g(39, 24))
                    half.move(to: g(39, 50))
                    half.addQuadCurve(to: g(50, 50), control: g(45, 54))
                    p.addPath(half)
                    p.addPath(half.mirrored(in: g.rect))
                    return p
                }
                .stroke(Ink.washi.opacity(0.85), style: hairline(side))

                // Left eye: painted the day the goal was set.
                Circle().fill(Ink.washi)
                    .frame(width: side * 0.11, height: side * 0.11)
                    .position(x: side * 0.40, y: side * 0.39)

                // Right eye: an outline that closes as the arc runs.
                Circle()
                    .trim(from: 0, to: max(0.02, min(progress, 1)))
                    .stroke(Ink.washi, style: hairline(side, 1.3))
                    .rotationEffect(.degrees(-90))
                    .frame(width: side * 0.11, height: side * 0.11)
                    .position(x: side * 0.60, y: side * 0.39)
                if progress >= 1 {
                    Circle().fill(Ink.washi)
                        .frame(width: side * 0.07, height: side * 0.07)
                        .position(x: side * 0.60, y: side * 0.39)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        // A daruma is weighted at the base: push it and it rocks back upright.
        // keyframeAnimator plays a fixed sequence of values each time `trigger`
        // changes, which suits a one-shot move like this better than a spring.
        .keyframeAnimator(initialValue: 0.0, trigger: nudges) { content, angle in
            content.rotationEffect(.degrees(angle), anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(9, duration: 0.16)
                CubicKeyframe(-6, duration: 0.28)
                CubicKeyframe(3.5, duration: 0.28)
                CubicKeyframe(-1.5, duration: 0.26)
                CubicKeyframe(0, duration: 0.24)
            }
        }
        .onTapGesture { nudges += 1 }
        .onAppear { nudges += 1 }
        .sensoryFeedback(.impact(weight: .light), trigger: nudges)
        .accessibilityLabel("Daruma, \(Int(progress * 100)) percent of the arc done")
    }

    nonisolated private static let outline: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path()
        p.move(to: g(50, 8))
        p.addCurve(to: g(90, 58), control1: g(74, 8), control2: g(90, 30))
        p.addCurve(to: g(50, 94), control1: g(90, 82), control2: g(72, 94))
        p.addCurve(to: g(10, 58), control1: g(28, 94), control2: g(10, 82))
        p.addCurve(to: g(50, 8), control1: g(10, 30), control2: g(26, 8))
        return p
    }
}

#Preview("Cast") {
    VStack(spacing: 30) {
        HStack(spacing: 24) {
            HumanFigure(rank: .f)
            HumanFigure(rank: .b)
            HumanFigure(rank: .s)
        }
        HStack(spacing: 24) {
            OniMask(hp: 1)
            OniMask(hp: 0)
            KitsuneMask()
            Daruma(progress: 0.4)
        }
    }
    .padding(22)
    .frame(maxHeight: .infinity)
    .background(Ink.sumi)
}
