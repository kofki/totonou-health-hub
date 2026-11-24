import SwiftUI
import TotonouCore

// The icon set. Every icon is a few strokes on a 24×24 grid, drawn in code so it
// scales to any size, takes any `Ink` colour and needs no image files.
//
// To use one:   GlyphIcon(.moon)                      14 pt, muted
//               GlyphIcon(.lock, size: 22, tint: Ink.shu)
// To add one:   add a case to `Glyph`, then a `case` in `path(on:)` below.

enum Glyph: String, CaseIterable {
    // The five stats
    case dumbbell, mountain, book, torii, moon
    // Where a quest's proof comes from
    case tap, watch, heart, calendar
    // Everything else
    case flame, hourglass, lock, sync, plus, chevron, scroll, sword, person, check, cloud, bell, speaker
    // Rewards and system windows
    case notice, chest, freeze, crown, pass, alarm, star, bolt, shield, target, warning, rankUp
}

/// Turns grid coordinates into real points inside a rectangle, so paths can be
/// written as if the canvas were always `unit` wide.
struct DrawingGrid: Sendable {
    let rect: CGRect
    var unit: CGFloat = 24

    // `callAsFunction` lets a value be called like a function: `g(12, 4)`.
    func callAsFunction(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x / unit * rect.width, y: rect.minY + y / unit * rect.height)
    }

    func length(_ value: CGFloat) -> CGFloat { value / unit * rect.width }
}

extension Path {
    /// Adds an open line through the given points.
    mutating func polyline(_ points: CGPoint...) {
        guard let first = points.first else { return }
        move(to: first)
        points.dropFirst().forEach { addLine(to: $0) }
    }

    /// The same path flipped left-to-right, for drawing symmetric things once.
    func mirrored(in rect: CGRect) -> Path {
        applying(CGAffineTransform(translationX: 2 * rect.midX, y: 0).scaledBy(x: -1, y: 1))
    }
}

struct GlyphShape: Shape {
    let glyph: Glyph

    func path(in rect: CGRect) -> Path {
        glyph.path(on: DrawingGrid(rect: rect))
    }
}

struct GlyphIcon: View {
    let glyph: Glyph
    var size: CGFloat = 14
    var tint: Color = Ink.mute

    init(_ glyph: Glyph, size: CGFloat = 14, tint: Color = Ink.mute) {
        self.glyph = glyph
        self.size = size
        self.tint = tint
    }

    var body: some View {
        GlyphShape(glyph: glyph)
            .stroke(tint, style: StrokeStyle(lineWidth: max(1, size / 13), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            // Icons here always sit next to text that says the same thing.
            .accessibilityHidden(true)
    }
}

extension Stat {
    var glyph: Glyph {
        switch self {
        case .strength: .dumbbell
        case .endurance: .mountain
        case .intellect: .book
        case .discipline: .torii
        case .recovery: .moon
        }
    }
}

extension QuestSource {
    var glyph: Glyph {
        switch self {
        case .manual: .tap
        case .garmin: .watch
        case .health: .heart
        case .calendar: .calendar
        case .reminders: .bell
        }
    }
}

extension Glyph {
    func path(on g: DrawingGrid) -> Path {
        var p = Path()
        switch self {
        case .dumbbell:
            p.polyline(g(7, 12), g(17, 12))
            p.polyline(g(7, 7), g(7, 17))
            p.polyline(g(4, 9), g(4, 15))
            p.polyline(g(17, 7), g(17, 17))
            p.polyline(g(20, 9), g(20, 15))

        case .mountain:
            p.polyline(g(2, 19), g(9, 6), g(13, 13), g(16, 9), g(22, 19))

        case .book:
            var page = Path()
            page.move(to: g(12, 7))
            page.addQuadCurve(to: g(3, 6), control: g(8, 4))
            page.addLine(to: g(3, 18))
            page.addQuadCurve(to: g(12, 20), control: g(8, 16))
            p.addPath(page)
            p.addPath(page.mirrored(in: g.rect))
            p.polyline(g(12, 7), g(12, 20))

        case .torii:
            p.move(to: g(3, 5))
            p.addQuadCurve(to: g(21, 5), control: g(12, 8))
            p.polyline(g(5, 10), g(19, 10))
            p.polyline(g(8, 7), g(7, 21))
            p.polyline(g(16, 7), g(17, 21))

        case .moon:
            // The long way round the circle, then a shallower curve back.
            p.addArc(center: g(12, 12), radius: g.length(8),
                     startAngle: .degrees(-55), endAngle: .degrees(55), clockwise: true)
            p.addQuadCurve(to: g(16.6, 5.4), control: g(8, 12))

        case .tap:
            p.addEllipse(in: CGRect(origin: g(9.5, 9.5), size: CGSize(width: g.length(5), height: g.length(5))))
            p.addEllipse(in: CGRect(origin: g(4, 4), size: CGSize(width: g.length(16), height: g.length(16))))

        case .watch:
            p.addRoundedRect(in: CGRect(origin: g(6.5, 7), size: CGSize(width: g.length(11), height: g.length(10))),
                             cornerSize: CGSize(width: g.length(2.5), height: g.length(2.5)))
            p.polyline(g(9, 7), g(10, 3), g(14, 3), g(15, 7))
            p.polyline(g(9, 17), g(10, 21), g(14, 21), g(15, 17))
            p.polyline(g(12, 9.5), g(12, 12), g(14, 13))

        case .heart:
            p.move(to: g(12, 20))
            p.addCurve(to: g(4, 10), control1: g(8, 17), control2: g(4, 14))
            p.addCurve(to: g(12, 8), control1: g(4, 5), control2: g(10, 4))
            p.addCurve(to: g(20, 10), control1: g(14, 4), control2: g(20, 5))
            p.addCurve(to: g(12, 20), control1: g(20, 14), control2: g(16, 17))

        case .calendar:
            p.addRect(CGRect(origin: g(4, 6), size: CGSize(width: g.length(16), height: g.length(14))))
            p.polyline(g(4, 10.5), g(20, 10.5))
            p.polyline(g(8, 4), g(8, 7.5))
            p.polyline(g(16, 4), g(16, 7.5))

        case .flame:
            // Yours to draw: Exercises/Exercise8_FlameGlyph.swift.
            p = FlameGlyph.path(on: g)

        case .hourglass:
            p.polyline(g(6, 4), g(18, 4))
            p.polyline(g(6, 20), g(18, 20))
            p.polyline(g(7, 4), g(7, 7), g(17, 17), g(17, 20))
            p.polyline(g(17, 4), g(17, 7), g(7, 17), g(7, 20))

        case .lock:
            p.addRect(CGRect(origin: g(6, 11), size: CGSize(width: g.length(12), height: g.length(9))))
            p.move(to: g(8, 11))
            p.addLine(to: g(8, 8))
            p.addArc(center: g(12, 8), radius: g.length(4),
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: g(16, 11))
            p.polyline(g(12, 14.5), g(12, 17))

        case .sync:
            p.addArc(center: g(12, 12), radius: g.length(7),
                     startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            p.polyline(g(18.9, 5.6), g(18.6, 9.6), g(14.9, 9.2))
            p.move(to: g(18.6, 14.4))
            p.addArc(center: g(12, 12), radius: g.length(7),
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            p.polyline(g(5.1, 18.4), g(5.4, 14.4), g(9.1, 14.8))

        case .plus:
            p.polyline(g(12, 5), g(12, 19))
            p.polyline(g(5, 12), g(19, 12))

        case .chevron:
            p.polyline(g(9, 6), g(15, 12), g(9, 18))

        case .scroll:
            p.addRect(CGRect(origin: g(6, 4), size: CGSize(width: g.length(12), height: g.length(16))))
            p.polyline(g(9, 9), g(15, 9))
            p.polyline(g(9, 12.5), g(15, 12.5))
            p.polyline(g(9, 16), g(13, 16))

        case .person:
            p.addEllipse(in: CGRect(origin: g(8.5, 4), size: CGSize(width: g.length(7), height: g.length(7))))
            p.move(to: g(5, 20))
            p.addQuadCurve(to: g(12, 14), control: g(5, 14))
            p.addQuadCurve(to: g(19, 20), control: g(19, 14))

        case .check:
            p.polyline(g(5, 12.5), g(10, 17.5), g(19, 7))

        case .cloud:
            p.move(to: g(7, 18))
            p.addLine(to: g(17, 18))
            p.addCurve(to: g(17.5, 10), control1: g(20.5, 18), control2: g(21, 11))
            p.addCurve(to: g(7, 9.5), control1: g(16, 4.5), control2: g(8, 4.5))
            p.addCurve(to: g(7, 18), control1: g(2, 10), control2: g(2, 18))

        case .bell:
            p.move(to: g(5, 17))
            p.addLine(to: g(19, 17))
            p.addQuadCurve(to: g(17, 11), control: g(17, 15))
            p.addCurve(to: g(7, 11), control1: g(17, 3), control2: g(7, 3))
            p.addQuadCurve(to: g(5, 17), control: g(7, 15))
            p.polyline(g(10.5, 20), g(13.5, 20))

        case .speaker:
            p.polyline(g(4, 9.5), g(8, 9.5), g(13, 5), g(13, 19), g(8, 14.5), g(4, 14.5), g(4, 9.5))
            p.move(to: g(16.5, 9))
            p.addQuadCurve(to: g(16.5, 15), control: g(19, 12))

        case .sword:
            p.polyline(g(8, 16), g(20, 4))
            p.polyline(g(5, 13), g(11, 19))
            p.polyline(g(8, 16), g(4, 20))

        case .notice:
            // The "!" badge on system windows.
            p.addRoundedRect(in: CGRect(origin: g(4, 4), size: CGSize(width: g.length(16), height: g.length(16))),
                             cornerSize: CGSize(width: g.length(3), height: g.length(3)))
            p.polyline(g(12, 8), g(12, 13.5))
            p.polyline(g(12, 16.4), g(12, 16.6))

        case .chest:
            p.addRect(CGRect(origin: g(4, 10), size: CGSize(width: g.length(16), height: g.length(9))))
            p.move(to: g(4, 10))
            p.addQuadCurve(to: g(20, 10), control: g(12, 3))
            p.polyline(g(4, 13), g(20, 13))
            p.polyline(g(12, 12), g(12, 15.5))

        case .freeze:
            p.polyline(g(12, 3), g(12, 21))
            p.polyline(g(4.2, 7.5), g(19.8, 16.5))
            p.polyline(g(4.2, 16.5), g(19.8, 7.5))
            p.polyline(g(9.5, 4.5), g(12, 7), g(14.5, 4.5))
            p.polyline(g(9.5, 19.5), g(12, 17), g(14.5, 19.5))

        case .crown:
            p.polyline(g(4, 18), g(20, 18), g(18.5, 8), g(14.5, 12), g(12, 6), g(9.5, 12), g(5.5, 8), g(4, 18))

        case .pass:
            p.addRoundedRect(in: CGRect(origin: g(3.5, 7), size: CGSize(width: g.length(17), height: g.length(10))),
                             cornerSize: CGSize(width: g.length(2), height: g.length(2)))
            p.polyline(g(14, 7), g(14, 9))
            p.polyline(g(14, 11), g(14, 13))
            p.polyline(g(14, 15), g(14, 17))

        case .alarm:
            p.addEllipse(in: CGRect(origin: g(5, 6), size: CGSize(width: g.length(14), height: g.length(14))))
            p.polyline(g(12, 9.5), g(12, 13), g(14.5, 15))
            p.polyline(g(4, 6), g(7, 3.5))
            p.polyline(g(20, 6), g(17, 3.5))

        case .star:
            // Five outer and five inner points, alternating round the centre.
            let points = (0..<10).map { index -> CGPoint in
                let angle = -Double.pi / 2 + Double(index) * .pi / 5
                let radius = index.isMultiple(of: 2) ? 9.0 : 4.0
                return g(12 + radius * cos(angle), 12.5 + radius * sin(angle))
            }
            p.addLines(points + [points[0]])

        case .bolt:
            p.polyline(g(13, 3), g(6, 13), g(11, 13), g(10, 21), g(18, 10), g(13, 10), g(13, 3))

        case .shield:
            p.move(to: g(12, 3))
            p.addLine(to: g(19, 6))
            p.addLine(to: g(19, 11))
            p.addQuadCurve(to: g(12, 21), control: g(19, 18))
            p.addQuadCurve(to: g(5, 11), control: g(5, 18))
            p.addLine(to: g(5, 6))
            p.closeSubpath()

        case .target:
            p.addEllipse(in: CGRect(origin: g(4, 4), size: CGSize(width: g.length(16), height: g.length(16))))
            p.addEllipse(in: CGRect(origin: g(8, 8), size: CGSize(width: g.length(8), height: g.length(8))))
            p.polyline(g(12, 11.8), g(12, 12.2))

        case .warning:
            p.polyline(g(12, 4), g(21, 19.5), g(3, 19.5), g(12, 4))
            p.polyline(g(12, 9.5), g(12, 14))
            p.polyline(g(12, 16.6), g(12, 16.8))

        case .rankUp:
            p.polyline(g(6, 12), g(12, 6), g(18, 12))
            p.polyline(g(6, 18), g(12, 12), g(18, 18))
        }
        return p
    }
}

#Preview("All glyphs") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 26) {
        ForEach(Glyph.allCases, id: \.self) { glyph in
            VStack(spacing: 8) {
                GlyphIcon(glyph, size: 28, tint: Ink.washi)
                Text(glyph.rawValue).caption(size: 10)
            }
        }
    }
    .padding(22)
    .frame(maxHeight: .infinity)
    .background(Ink.sumi)
}
