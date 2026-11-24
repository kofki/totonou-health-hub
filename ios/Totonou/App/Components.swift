import SwiftUI
import TotonouCore

// The handful of pieces every screen is built from. Colours and fonts live in
// TotonouCore/Theme.swift so the widget can share them.

enum Radius {
    static let card: CGFloat = 18
    static let control: CGFloat = 14
}

/// A card. With `glow` it is the one thing on the screen asking for attention.
struct SystemPanel<Content: View>: View {
    var tint: Color = Ink.ai
    var glow = false
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.raised, in: shape)
            .overlay(shape.strokeBorder(tint.opacity(glow ? 0.55 : 0.14), lineWidth: 1))
            // A glowing card breathes. phaseAnimator loops through the listed
            // values for as long as the view is on screen.
            .phaseAnimator(glow && !reduceMotion ? [0.0, 1.0] : [0.5]) { panel, phase in
                panel.shadow(color: glow ? tint.opacity(0.14 + phase * 0.16) : .clear, radius: 16 + phase * 10)
            } animation: { _ in
                .easeInOut(duration: 2.6)
            }
    }
}

/// A section title with an optional control on the right.
struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.text(22, weight: .bold))
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Rank letter in a tile.
struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 38
    var dimmed = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.28, style: .continuous) }

    var body: some View {
        Text(rank.rawValue)
            .font(.number(size * 0.5, weight: .bold))
            .foregroundStyle(dimmed ? Ink.mute : Ink.washi)
            .frame(width: size, height: size)
            .background(rank.tint.opacity(dimmed ? 0.05 : 0.16), in: shape)
            .overlay(shape.strokeBorder(rank.tint.opacity(dimmed ? 0.25 : 0.8), lineWidth: 1))
            .accessibilityLabel("Rank \(rank.rawValue)")
    }
}

/// 円相 — an open brush circle used as a progress ring.
struct EnsoRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var tint: Color = Ink.ai

    /// What is on screen right now. It starts at zero so the ring draws itself.
    @State private var drawn: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Ink.faint, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, min(drawn, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { drawn = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.snappy(duration: 0.6)) { drawn = new }
        }
    }
}

/// The red stamp on finished work. クリア is "clear", as in clearing a stage.
struct ClearStamp: View {
    var text = "クリア"

    var body: some View {
        Text(text)
            .font(.text(13, weight: .heavy))
            .foregroundStyle(Ink.shu)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.shu, lineWidth: 1.5))
            .rotationEffect(.degrees(-8))
            .accessibilityLabel("Done")
    }
}

/// A progress bar.
struct ProgressLine: View {
    var value: Double
    var tint: Color = Ink.ai
    var height: CGFloat = 6

    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.faint)
                Capsule().fill(tint)
                    .frame(width: max(height, proxy.size.width * max(0, min(shown, 1))))
                    .shadow(color: tint.opacity(0.6), radius: 4)
                    .opacity(shown > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { shown = value }
        }
        .onChange(of: value) { _, new in
            withAnimation(.snappy(duration: 0.5)) { shown = new }
        }
    }
}

/// The app's button: outlined, or filled for the main action.
struct SystemButtonStyle: ButtonStyle {
    var tint: Color = Ink.ai
    var filled = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .font(.text(17, weight: .semibold))
            .foregroundStyle(filled ? Ink.sumi : tint)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(filled ? tint : tint.opacity(configuration.isPressed ? 0.22 : 0.1), in: shape)
            .overlay(shape.strokeBorder(tint.opacity(filled ? 0 : 0.5), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// The five stats as a pentagon, each corner marked with the stat's icon.
struct StatRadar: View {
    /// One value per `Stat.allCases`, each 0...1.
    let values: [Double]

    @State private var growth: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            ZStack {
                ForEach([0.33, 0.66, 1.0], id: \.self) { scale in
                    RadarShape(values: Array(repeating: scale, count: 5)).stroke(Ink.faint, lineWidth: 1)
                }
                RadarShape(values: values, growth: growth).fill(Ink.ai.opacity(0.16))
                RadarShape(values: values, growth: growth)
                    .stroke(Ink.ai, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .shadow(color: Ink.ai.opacity(0.6), radius: 6)
                ForEach(Array(Stat.allCases.enumerated()), id: \.element) { index, stat in
                    GlyphIcon(stat.glyph, size: 20, tint: Ink.washi)
                        .position(RadarShape.point(index, scale: 1, in: rect, outset: 20))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.25).delay(0.25)) { growth = 1 }
        }
        .accessibilityHidden(true)
    }
}

/// The pentagon itself. Being a `Shape` with `animatableData` is what lets it
/// grow smoothly: SwiftUI redraws the path for every in-between `growth`.
private struct RadarShape: Shape {
    var values: [Double]
    var growth: Double = 1

    var animatableData: Double {
        get { growth }
        set { growth = newValue }
    }

    static func point(_ index: Int, scale: Double, in rect: CGRect, outset: CGFloat = 0) -> CGPoint {
        let radius = min(rect.width, rect.height) / 2 - 30
        let angle = -Double.pi / 2 + Double(index) * 2 * .pi / 5
        let reach = radius * scale + outset
        return CGPoint(x: rect.midX + cos(angle) * reach, y: rect.midY + sin(angle) * reach)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let next = Self.point(index, scale: value * growth, in: rect)
            if index == 0 { path.move(to: next) } else { path.addLine(to: next) }
        }
        path.closeSubpath()
        return path
    }
}

extension Date {
    /// Tuesday, Nov 24
    var dayTitle: String {
        formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(Locale(identifier: "en_US")))
    }

    /// 17:30
    var clock: String {
        formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB")))
    }

    /// One of the few Japanese touches, kept in hiragana so it reads as Japanese.
    var greeting: String {
        switch Calendar.current.component(.hour, from: self) {
        case 5..<11: "おはよう"
        case 11..<18: "こんにちは"
        default: "こんばんは"
        }
    }
}

// MARK: System window

/// A rectangle with two corners cut off, like a game HUD panel.
struct WindowShape: Shape {
    var cut: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

/// The glowing blue "system message" window. Quests, rewards and warnings
/// arrive in one of these; everything else on a screen stays quiet.
struct SystemWindow<Content: View>: View {
    var title: String?
    var tint: Color = Ink.ai
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            if let title {
                Text(title.uppercased()).font(.text(15, weight: .heavy)).tracking(2)
            }
            content
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(WindowShape().fill(
            LinearGradient(colors: [tint.opacity(0.62), tint.opacity(0.30)], startPoint: .top, endPoint: .bottom)
        ))
        .background(WindowShape().fill(Ink.deep.opacity(0.7)))
        .overlay(WindowShape(cut: 10).stroke(.white.opacity(0.3), lineWidth: 1).padding(6))
        .overlay(WindowShape().stroke(.white.opacity(0.85), lineWidth: 1.5))
        .overlay(alignment: .topTrailing) { controls.padding(12) }
        .phaseAnimator(reduceMotion ? [0.5] : [0.0, 1.0]) { window, phase in
            window.shadow(color: tint.opacity(0.45 + phase * 0.3), radius: 16 + phase * 10)
        } animation: { _ in
            .easeInOut(duration: 2.4)
        }
    }

    /// Decoration only: the little window buttons in the corner.
    private var controls: some View {
        HStack(spacing: 4) {
            Rectangle().frame(width: 8, height: 1.5)
            Rectangle().strokeBorder(lineWidth: 1.2).frame(width: 8, height: 8)
            GlyphIcon(.plus, size: 11, tint: .white).rotationEffect(.degrees(45))
        }
        .foregroundStyle(.white.opacity(0.8))
        .accessibilityHidden(true)
    }
}

/// A switch with a label, for the few settings the app has.
struct SettingRow: View {
    let glyph: Glyph
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                GlyphIcon(glyph, size: 20, tint: Ink.washi)
                Text(title).font(.text(17))
            }
        }
        .tint(Ink.ai)
    }
}
