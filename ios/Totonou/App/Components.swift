import SwiftUI
import TotonouCore

// The handful of pieces every screen is built from. Colours and fonts live in
// TotonouCore/Theme.swift so the widget can share them.

enum Radius {
    static let card: CGFloat = 18
    static let control: CGFloat = 14
}

/// A soft light around a shape that slowly breathes.
///
/// Why not `.shadow` with an animated radius: that recomputes a blur every
/// frame, for every window on screen, and drops the frame rate. Here the glow
/// is blurred once into a texture (`drawingGroup`), and the animation only
/// changes its opacity, which the GPU does almost for free.
struct GlowLayer<S: Shape>: View {
    let shape: S
    var tint: Color = Ink.ai
    var radius: CGFloat = 18
    var breathe = true
    var low: Double = 0.45
    var high: Double = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        shape
            .stroke(tint, lineWidth: radius * 0.7)
            .blur(radius: radius)
            // Room for the blur to spread: the texture is larger than the shape.
            .padding(radius * 2)
            .drawingGroup()
            .padding(-radius * 2)
            .phaseAnimator(breathe && !reduceMotion ? [low, high] : [(low + high) / 2]) { glow, phase in
                glow.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 2.4)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
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
            // A glowing card breathes (see GlowLayer for why it is drawn this way).
            .background {
                if glow { GlowLayer(shape: shape, tint: tint, radius: 16, low: 0.2, high: 0.45) }
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

/// The red stamp on finished work, as in clearing a stage.
struct ClearStamp: View {
    var text = "CLEAR"

    var body: some View {
        Text(text)
            .font(.hud(14))
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

    /// 5:30 PM
    var clock: String {
        // "3:00 PM": 12-hour with AM/PM (owner's choice, 2026-11-25), whatever the phone's region.
        formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits).locale(Locale(identifier: "en_US")))
    }

    var greeting: String {
        switch Calendar.current.component(.hour, from: self) {
        case 5..<11: "Good morning"
        case 11..<18: "Good afternoon"
        default: "Good evening"
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

/// The "system message" window, the game's own voice. Quests, rewards and
/// warnings arrive in one of these; everything else on a screen stays quiet.
///
/// Two looks, both common in "system" stories: bright translucent glass for
/// information and rewards, and a dark `notice` panel with a boxed "!" header
/// for warnings and penalties.
struct SystemWindow<Content: View>: View {
    var title: String?
    var tint: Color = Ink.ai
    /// The dark notification look.
    var notice = false
    /// Left-aligned text, for long windows such as the character profile.
    var leading = false
    /// What the X does. Without one, the X closes the window's sheet or the
    /// screen around it (`closeWindow`); a window that cannot close has no X.
    var onClose: (() -> Void)? = nil
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.closeWindow) private var closeWindow
    // True when this view is inside a sheet or full-screen cover; `dismiss` closes it.
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss

    private var close: (() -> Void)? {
        onClose ?? closeWindow ?? (isPresented ? { dismiss() } : nil)
    }

    var body: some View {
        VStack(alignment: leading ? .leading : .center, spacing: 14) {
            if let title { header(title) }
            content
        }
        .multilineTextAlignment(leading ? .leading : .center)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .background(panel)
        .overlay(frame)
        .overlay(alignment: .topTrailing) {
            if let close { closeButton(close) }
        }
        .overlay { PixelBits(tint: notice ? tint : .white) }
        .background { GlowLayer(shape: WindowShape(), tint: tint, radius: 20) }
    }

    @ViewBuilder private func header(_ title: String) -> some View {
        if notice {
            HStack(spacing: 10) {
                GlyphIcon(.notice, size: 24, tint: tint)
                Text(title.uppercased())
                    .font(.hud(18)).tracking(2)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .overlay(Rectangle().strokeBorder(tint.opacity(0.7), lineWidth: 1))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // A title that brings its own brackets, like "<Character profile>", keeps them.
            Text(title.hasPrefix("<") ? title.uppercased() : "[\(title.uppercased())]")
                .font(.hud(19)).tracking(1.5)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var panel: some View {
        if notice {
            WindowShape().fill(LinearGradient(colors: [tint.opacity(0.16), Ink.deep.opacity(0.95)],
                                              startPoint: .top, endPoint: .bottom))
                .background(WindowShape().fill(Ink.deep.opacity(0.9)))
        } else {
            WindowShape().fill(LinearGradient(colors: [tint.opacity(0.62), tint.opacity(0.30)],
                                              startPoint: .top, endPoint: .bottom))
                .background(WindowShape().fill(Ink.deep.opacity(0.6)))
        }
    }

    @ViewBuilder private var frame: some View {
        if notice {
            ZStack {
                WindowShape().stroke(tint, lineWidth: 2)
                // The thick lit edges at top and bottom.
                VStack {
                    Capsule().fill(tint).frame(height: 3).padding(.horizontal, 20)
                    Spacer()
                    Capsule().fill(tint).frame(height: 3).padding(.horizontal, 20)
                }
                .shadow(color: tint, radius: 6)
            }
        } else {
            ZStack {
                WindowShape(cut: 10).stroke(.white.opacity(0.3), lineWidth: 1).padding(6)
                WindowShape().stroke(.white.opacity(0.85), lineWidth: 1.5)
            }
        }
    }

    /// Decoration only: the little window buttons in the corner.
    private func closeButton(_ close: @escaping () -> Void) -> some View {
        Button(action: close) {
            GlyphIcon(.plus, size: 13, tint: .white).rotationEffect(.degrees(45))
                .opacity(0.85)
                // A 44-point target, the smallest Apple recommends for a finger.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Close")
    }
}

extension EnvironmentValues {
    /// How a window closes the screen it is shown on, set by that screen (a
    /// celebration, the quest info overlay). `@Entry` declares an environment
    /// value with its default in one line; nil means "nothing to close".
    @Entry var closeWindow: (() -> Void)? = nil
}

/// Small glowing squares scattered just outside a window's edge, like a
/// hologram that has not quite settled. Decoration only.
struct PixelBits: View {
    var tint: Color = .white

    /// (x, y) as fractions of the window, with a side length in points.
    private static let bits: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-0.012, 0.16, 7), (-0.02, 0.21, 4), (1.012, 0.66, 8), (1.02, 0.72, 4),
        (0.10, -0.012, 5), (0.88, 1.012, 6), (-0.012, 0.82, 5),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Self.bits.indices, id: \.self) { index in
                let bit = Self.bits[index]
                // No shadow per square: seven small blurs per window added up.
                Rectangle()
                    .fill(tint.opacity(0.9))
                    .frame(width: bit.size, height: bit.size)
                    .position(x: proxy.size.width * bit.x, y: proxy.size.height * bit.y)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One line in the system's voice: "[THE UPDATE IS COMPLETE.]"
struct SystemLine: View {
    let text: String
    var tint: Color = .white
    var size: CGFloat = 17

    init(_ text: String, tint: Color = .white, size: CGFloat = 17) {
        self.text = text
        self.tint = tint
        self.size = size
    }

    // Sentence case in the normal face: brackets keep the "system" voice, and
    // the text stays easy to read. Capitals are kept for window titles only.
    var body: some View {
        Text("[\(text)]")
            .font(.text(size, weight: .semibold))
            .foregroundStyle(tint)
    }
}

/// A labelled bar: "STRENGTH · 34 · 4/10 to +20%".
struct MeterBar: View {
    var value: Double
    var tint: Color = Ink.ai
    var height: CGFloat = 8
    /// Tick marks, like a segmented gauge. 0 for a plain bar.
    var segments = 10

    var body: some View {
        ProgressLine(value: value, tint: tint, height: height)
            .overlay {
                if segments > 1 {
                    HStack(spacing: 0) {
                        ForEach(1..<segments, id: \.self) { _ in
                            Spacer()
                            Rectangle().fill(Ink.deep.opacity(0.7)).frame(width: 1.5)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(Capsule())
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
