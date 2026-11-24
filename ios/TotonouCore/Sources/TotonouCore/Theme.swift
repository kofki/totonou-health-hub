import SwiftUI

/// The whole palette: deep blue instead of black, off-white text, one bright
/// blue for the "system", one warm red for stamps, bosses and penalties.
/// If a screen needs a colour that is not here, the screen is probably too busy.
public enum Ink {
    /// The base blue. Bars and sheets sit on this.
    public static let sumi = Color(hex: 0x121C3A)
    /// The darkest blue, at the bottom of the backdrop.
    public static let deep = Color(hex: 0x0C1330)
    /// Cards.
    public static let raised = Color(hex: 0x1D2B55)
    /// Primary text.
    public static let washi = Color(hex: 0xF3F5FB)
    /// Secondary text.
    public static let mute = Color(hex: 0xF3F5FB).opacity(0.62)
    /// Hairlines and empty tracks.
    public static let faint = Color(hex: 0xF3F5FB).opacity(0.13)
    /// The system blue.
    public static let ai = Color(hex: 0x4FB0FF)
    /// Stamps, bosses, penalties.
    public static let shu = Color(hex: 0xFF6B57)
    /// Reserved for the top ranks.
    public static let kin = Color(hex: 0xF2C66D)
}

/// The app's background: a blue gradient with a soft glow at the top.
public struct Backdrop: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B2C5E), Ink.sumi, Ink.deep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Ink.ai.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

public extension Font {
    /// The text face: the system font (SF Pro). Plain, and easy to read at a glance.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Rounded digits for levels, XP, minutes and other game numbers.
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

public extension View {
    /// Secondary text: smaller and muted. Use it sparingly — if a screen needs
    /// many captions, it is saying too much.
    func caption(_ color: Color = Ink.mute, size: CGFloat = 14) -> some View {
        self.font(.text(size, weight: .medium)).foregroundStyle(color)
    }
}

public extension Rank {
    var tint: Color {
        switch self {
        case .e, .d: Ink.mute
        case .c, .b: Ink.ai
        case .a: Ink.kin
        case .s: Ink.shu
        }
    }
}
