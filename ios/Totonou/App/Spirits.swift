import SwiftUI
import TotonouCore

// More of the cast, drawn the same way as Characters.swift: hairlines on a
// 100×100 grid, the app's palette, motion that stops under Reduce Motion.
//
//   KitsuneSpirit  the system's messenger. Its tails grow with your rank (1 → 9).
//   ManekiNeko     the beckoning cat. Screen-time rewards and chests.
//   Omamori        a protective charm. A streak freeze.
//   Koi            the fish that swims upstream. Streaks.
//   Lantern        a paper lantern. The end-of-day recap.
//   ToriiLogo      the app's mark.

// MARK: Kitsune spirit

struct KitsuneSpirit: View {
    var tails = 3
    var tint: Color = Ink.ai
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tails for a human rank: one at F- and E, nine at S.
    static func tails(for rank: Rank) -> Int {
        [1, 1, 2, 3, 5, 7, 9][Rank.allCases.firstIndex(of: rank) ?? 0]
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                tailFan(side)
                    // The tails sway slowly, pivoting at the base of the spine.
                    .phaseAnimator(reduceMotion ? [0.0] : [-1.0, 1.0]) { content, phase in
                        content.rotationEffect(.degrees(phase * 3), anchor: UnitPoint(x: 0.5, y: 0.8))
                    } animation: { _ in .easeInOut(duration: 2.2) }

                Drawn(draw: Self.body).fill(Ink.sumi)
                Drawn(draw: Self.body).stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))
                Drawn(draw: Self.head).fill(Ink.sumi)
                Drawn(draw: Self.head).stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))
                Drawn(draw: Self.markings).stroke(Ink.shu, style: hairline(side, 1.4))
                Drawn { g in
                    var p = Path()
                    p.polyline(g(41, 39), g(46, 41))
                    p.polyline(g(59, 39), g(54, 41))
                    return p
                }
                .stroke(tint, style: hairline(side, 2))
                .shadow(color: tint, radius: side / 24)

                foxFire(side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Kitsune with \(tails) tails")
    }

    private func tailFan(_ side: CGFloat) -> some View {
        let count = max(1, min(tails, 9))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                // Alternate sides, fanning outwards from 40° to 110° off vertical,
                // so no tail hides behind the head.
                let side: Double = index.isMultiple(of: 2) ? 1 : -1
                let perSide = Double((count + 1) / 2)
                let angle = side * (40 + 70 * (Double(index / 2) + 0.5) / perSide)
                let shape = Drawn { g in Self.tail(g, degrees: angle) }
                shape.fill(Ink.raised)
                shape.stroke(Ink.washi.opacity(0.6), style: hairline(side, 1.1))
                Drawn { g in Self.tailTip(g, degrees: angle) }
                    .stroke(tint, style: hairline(side, 2))
            }
        }
    }

    /// Wisps of fox-fire (kitsunebi) bobbing beside the fox.
    private func foxFire(_ side: CGFloat) -> some View {
        ZStack {
            Circle().fill(tint).frame(width: side * 0.06).position(x: side * 0.16, y: side * 0.30)
            Circle().fill(tint).frame(width: side * 0.045).position(x: side * 0.86, y: side * 0.22)
        }
        .shadow(color: tint, radius: side / 18)
        .phaseAnimator(reduceMotion ? [0.0] : [0.0, 1.0]) { content, phase in
            content.offset(y: -phase * side * 0.04).opacity(0.6 + phase * 0.4)
        } animation: { _ in .easeInOut(duration: 1.6) }
    }

    /// One tail, built pointing straight up from the base and then turned.
    private static func tail(_ g: DrawingGrid, degrees: Double) -> Path {
        // Plump at the base, curling to a point: a brush stroke, not a wing.
        var p = Path()
        p.move(to: g(45, 82))
        p.addCurve(to: g(56, 34), control1: g(30, 66), control2: g(38, 40))
        p.addCurve(to: g(55, 82), control1: g(66, 46), control2: g(64, 66))
        return p.applying(turn(g, degrees))
    }

    private static func tailTip(_ g: DrawingGrid, degrees: Double) -> Path {
        var p = Path()
        p.move(to: g(50, 42))
        p.addQuadCurve(to: g(58, 38), control: g(52, 34))
        return p.applying(turn(g, degrees))
    }

    /// Rotation about the base of the spine, (50, 80) on the grid.
    private static func turn(_ g: DrawingGrid, _ degrees: Double) -> CGAffineTransform {
        let base = g(50, 80)
        return CGAffineTransform(translationX: base.x, y: base.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -base.x, y: -base.y)
    }

    nonisolated private static let body: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path()
        p.move(to: g(34, 94))
        p.addCurve(to: g(42, 56), control1: g(30, 76), control2: g(36, 62))
        p.addLine(to: g(58, 56))
        p.addCurve(to: g(66, 94), control1: g(64, 62), control2: g(70, 76))
        p.closeSubpath()
        return p
    }

    nonisolated private static let head: @Sendable (DrawingGrid) -> Path = { g in
        var half = Path()
        half.move(to: g(50, 26))
        half.addQuadCurve(to: g(36, 34), control: g(40, 26))
        half.addCurve(to: g(50, 58), control1: g(35, 44), control2: g(42, 52))
        var p = half
        p.addPath(half.mirrored(in: g.rect))
        var ears = Path()
        ears.polyline(g(38, 31), g(33, 13), g(46, 26))
        p.addPath(ears)
        p.addPath(ears.mirrored(in: g.rect))
        return p
    }

    nonisolated private static let markings: @Sendable (DrawingGrid) -> Path = { g in
        var half = Path()
        half.polyline(g(37, 33), g(40, 28))
        half.polyline(g(38, 48), g(44, 49))
        var p = half
        p.addPath(half.mirrored(in: g.rect))
        p.polyline(g(50, 30), g(52, 33), g(50, 36), g(48, 33), g(50, 30))
        p.polyline(g(48, 52), g(52, 52), g(50, 55), g(48, 52))
        return p
    }
}

// MARK: Maneki-neko

struct ManekiNeko: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waves = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                // The raised paw beckons: it rocks back and forth at the elbow.
                Drawn { g in
                    Path(roundedRect: CGRect(origin: g(22, 26), size: CGSize(width: g.length(12), height: g.length(30))),
                         cornerRadius: g.length(6))
                }
                .fill(Ink.sumi)
                .overlay(Drawn { g in
                    Path(roundedRect: CGRect(origin: g(22, 26), size: CGSize(width: g.length(12), height: g.length(30))),
                         cornerRadius: g.length(6))
                }.stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.2)))
                .keyframeAnimator(initialValue: 0.0, trigger: waves) { paw, angle in
                    paw.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.28, y: 0.56))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-16, duration: 0.25)
                        CubicKeyframe(4, duration: 0.3)
                        CubicKeyframe(-12, duration: 0.3)
                        CubicKeyframe(0, duration: 0.3)
                    }
                }

                Drawn(draw: Self.figure).fill(Ink.sumi)
                Drawn(draw: Self.figure).stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))
                Drawn(draw: Self.face).stroke(Ink.washi.opacity(0.85), style: hairline(side, 1.2))
                // Collar and bell.
                Drawn { g in
                    var p = Path()
                    p.move(to: g(36, 58))
                    p.addQuadCurve(to: g(64, 58), control: g(50, 64))
                    return p
                }
                .stroke(Ink.shu, style: hairline(side, 2))
                Circle().fill(Ink.kin).frame(width: side * 0.06).position(x: side * 0.5, y: side * 0.63)
                // The coin it holds: fortune.
                Drawn { g in
                    var p = Path(ellipseIn: CGRect(origin: g(56, 66), size: CGSize(width: g.length(18), height: g.length(24))))
                    p.addRect(CGRect(origin: g(62.5, 74), size: CGSize(width: g.length(5), height: g.length(8))))
                    return p
                }
                .stroke(Ink.kin, style: hairline(side, 1.3))
                .shadow(color: Ink.kin.opacity(0.6), radius: side / 30)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { if !reduceMotion { waves += 1 } }
        .onTapGesture { if !reduceMotion { waves += 1 } }
        .accessibilityLabel("Beckoning cat")
    }

    nonisolated private static let figure: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path(roundedRect: CGRect(origin: g(30, 52), size: CGSize(width: g.length(40), height: g.length(42))),
                     cornerRadius: g.length(16))
        p.addEllipse(in: CGRect(origin: g(26, 18), size: CGSize(width: g.length(48), height: g.length(40))))
        var ear = Path()
        ear.polyline(g(31, 28), g(32, 10), g(43, 20))
        p.addPath(ear)
        p.addPath(ear.mirrored(in: g.rect))
        return p
    }

    nonisolated private static let face: @Sendable (DrawingGrid) -> Path = { g in
        var half = Path()
        half.move(to: g(36, 37))
        half.addQuadCurve(to: g(44, 37), control: g(40, 33))
        half.polyline(g(28, 44), g(38, 45))
        var p = half
        p.addPath(half.mirrored(in: g.rect))
        p.move(to: g(45, 45))
        p.addQuadCurve(to: g(50, 46), control: g(47.5, 48))
        p.addQuadCurve(to: g(55, 45), control: g(52.5, 48))
        return p
    }
}

// MARK: Omamori

struct Omamori: View {
    var tint: Color = Ink.ai

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Drawn(draw: Self.pouch).fill(Ink.raised)
                Drawn(draw: Self.pouch).stroke(tint, style: hairline(side, 1.5))
                Drawn { g in
                    var p = Path()
                    // The cord, tied in a loop at the top.
                    p.move(to: g(44, 22))
                    p.addQuadCurve(to: g(50, 8), control: g(41, 10))
                    p.addQuadCurve(to: g(56, 22), control: g(59, 10))
                    // Embroidered bands and a diamond.
                    p.polyline(g(36, 40), g(64, 40))
                    p.polyline(g(36, 80), g(64, 80))
                    p.polyline(g(50, 48), g(58, 60), g(50, 72), g(42, 60), g(50, 48))
                    return p
                }
                .stroke(Ink.washi.opacity(0.8), style: hairline(side, 1.2))
                Drawn { g in
                    var p = Path()
                    p.addLines([g(50, 54), g(54, 60), g(50, 66), g(46, 60), g(50, 54)])
                    return p
                }
                .fill(tint)
                .shadow(color: tint, radius: side / 20)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Protective charm")
    }

    nonisolated private static let pouch: @Sendable (DrawingGrid) -> Path = { g in
        Path(roundedRect: CGRect(origin: g(30, 22), size: CGSize(width: g.length(40), height: g.length(70))),
             cornerRadius: g.length(7))
    }
}

// MARK: Koi

struct Koi: View {
    var tint: Color = Ink.shu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Drawn(draw: Self.fish).fill(Ink.raised)
                Drawn(draw: Self.fish).stroke(Ink.washi.opacity(0.9), style: hairline(side, 1.3))
                Drawn { g in
                    var p = Path(ellipseIn: CGRect(origin: g(32, 38), size: CGSize(width: g.length(11), height: g.length(7))))
                    p.addEllipse(in: CGRect(origin: g(47, 50), size: CGSize(width: g.length(10), height: g.length(6))))
                    return p
                }
                .fill(tint)
                Circle().fill(Ink.washi).frame(width: side * 0.03).position(x: side * 0.24, y: side * 0.47)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Swimming: a slow rise and fall with a slight tilt.
            .phaseAnimator(reduceMotion ? [0.0] : [-1.0, 1.0]) { content, phase in
                content.offset(y: phase * side * 0.03).rotationEffect(.degrees(phase * -4))
            } animation: { _ in .easeInOut(duration: 1.8) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Koi")
    }

    nonisolated private static let fish: @Sendable (DrawingGrid) -> Path = { g in
        var p = Path()
        p.move(to: g(16, 50))
        p.addCurve(to: g(66, 50), control1: g(30, 30), control2: g(54, 32))
        p.addCurve(to: g(16, 50), control1: g(54, 68), control2: g(30, 70))
        p.polyline(g(66, 50), g(88, 35), g(81, 50), g(88, 65), g(66, 50))
        p.polyline(g(36, 61), g(30, 74), g(45, 63))
        p.polyline(g(42, 37), g(48, 27), g(54, 36))
        p.polyline(g(17, 52), g(10, 58))
        return p
    }
}

// MARK: Lantern

struct Lantern: View {
    var tint: Color = Ink.kin
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Ellipse().fill(tint)
                    .frame(width: side * 0.5, height: side * 0.62)
                    .blur(radius: side / 8)
                    // A candle inside: the glow flickers.
                    .phaseAnimator(reduceMotion ? [0.3] : [0.2, 0.38, 0.26]) { glow, phase in
                        glow.opacity(phase)
                    } animation: { _ in .easeInOut(duration: 0.7) }
                Drawn(draw: Self.paper).fill(Ink.raised.opacity(0.85))
                Drawn(draw: Self.paper).stroke(tint, style: hairline(side, 1.3))
                Drawn { g in
                    var p = Path()
                    for y in [32.0, 44, 56, 68] {
                        let inset = abs(52 - y) * 0.5
                        p.polyline(g(25 + inset, y), g(75 - inset, y))
                    }
                    p.addRect(CGRect(origin: g(36, 14), size: CGSize(width: g.length(28), height: g.length(6))))
                    p.addRect(CGRect(origin: g(36, 84), size: CGSize(width: g.length(28), height: g.length(6))))
                    p.polyline(g(50, 3), g(50, 14))
                    return p
                }
                .stroke(Ink.washi.opacity(0.7), style: hairline(side, 1.1))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Paper lantern")
    }

    nonisolated private static let paper: @Sendable (DrawingGrid) -> Path = { g in
        Path(ellipseIn: CGRect(origin: g(24, 20), size: CGSize(width: g.length(52), height: g.length(64))))
    }
}

// MARK: Logo

/// The app's mark: a torii gate inside an open brush circle, and the name.
struct ToriiLogo: View {
    var tint: Color = Ink.ai

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .trim(from: 0.04, to: 0.96)
                    .stroke(tint, style: StrokeStyle(lineWidth: max(1.5, side / 26), lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .shadow(color: tint.opacity(0.6), radius: side / 16)
                Drawn { g in
                    var p = Path()
                    p.move(to: g(24, 34))
                    p.addQuadCurve(to: g(76, 34), control: g(50, 42))
                    p.polyline(g(30, 46), g(70, 46))
                    p.polyline(g(36, 37), g(34, 76))
                    p.polyline(g(64, 37), g(66, 76))
                    p.polyline(g(50, 38), g(50, 46))
                    return p
                }
                .stroke(Ink.washi, style: hairline(side, 2.2))
                Circle().fill(Ink.shu).frame(width: side * 0.09).position(x: side * 0.5, y: side * 0.62)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Totonou")
    }
}

/// The mark with the name beside it.
struct AppWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: size * 0.35) {
            ToriiLogo().frame(width: size * 1.3, height: size * 1.3)
            Text("TOTONOU").font(.hud(size)).tracking(size * 0.18)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Spirits") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            KitsuneSpirit(tails: 1)
            KitsuneSpirit(tails: 5)
            KitsuneSpirit(tails: 9, tint: Ink.kin)
        }
        HStack(spacing: 20) {
            ManekiNeko()
            Omamori()
            Koi()
            Lantern()
        }
        AppWordmark()
    }
    .padding(22)
    .frame(maxHeight: .infinity)
    .background(Ink.sumi)
    .foregroundStyle(Ink.washi)
}
