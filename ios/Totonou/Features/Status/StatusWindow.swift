import SwiftUI
import TotonouCore

extension Stat {
    /// Three letters for tight places, like a game's stat sheet.
    var short: String {
        switch self {
        case .strength: "STR"
        case .endurance: "END"
        case .intellect: "INT"
        case .discipline: "DIS"
        case .recovery: "REC"
        }
    }
}

/// The status sheet: who you are, your level, every stat with its XP bonus,
/// and the points you can still spend. Points are spent right here with +.
struct StatusWindow: View {
    let player: Player
    /// The arcs running now.
    let arcs: [Arc]
    let rename: () -> Void

    @Environment(QuestEngine.self) private var engine
    @State private var spends = 0

    var body: some View {
        let progress = player.progress
        SystemWindow(title: "Status", leading: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: rename) { field("Name", player.name) }.buttonStyle(.plain)
                    field(arcs.count > 1 ? "Arcs" : "Arc", arcs.isEmpty ? "None" : arcs.map(\.title).joined(separator: ", "))
                    field("Title", player.activeTitle ?? "None")
                }
                Spacer(minLength: 8)
                VStack(spacing: 0) {
                    Text("\(progress.level)").font(.number(60, weight: .heavy))
                        .contentTransition(.numericText(value: Double(progress.level)))
                    Text("LEVEL").font(.hud(16))
                }
                .shadow(color: Ink.ai, radius: 12)
            }

            rule

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    RankBadge(rank: Rank.forLevel(progress.level), size: 28)
                    Text(Rank.forLevel(progress.level).label).font(.text(16, weight: .semibold))
                    Spacer()
                    Text("\(progress.needed - progress.into) XP to next level").font(.text(14, weight: .medium))
                }
                MeterBar(value: progress.fraction, tint: .white, segments: 0)
            }

            rule

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                ForEach(Stat.allCases) { stat in cell(stat) }
            }

            rule

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MINUTES").font(.hud(13))
                    HStack(spacing: 6) {
                        GlyphIcon(.hourglass, size: 18, tint: .white)
                        Text("\(player.bankedMinutes)").font(.number(22, weight: .bold))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Available points").font(.text(13, weight: .medium))
                    Text("\(player.unspentStatPoints)").font(.number(30, weight: .heavy))
                        .foregroundStyle(player.unspentStatPoints > 0 ? Ink.kin : .white)
                }
            }
        }
        .sensoryFeedback(.increase, trigger: spends)
    }

    private func field(_ label: String, _ value: String) -> some View {
        (Text("\(label.uppercased()): ").font(.hud(16)) + Text(value).font(.text(17, weight: .medium)))
            .lineLimit(2)
    }

    private var rule: some View {
        Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
    }

    private func cell(_ stat: Stat) -> some View {
        let value = player.value(for: stat)
        let canSpend = player.unspentStatPoints > 0
        return HStack(spacing: 6) {
            GlyphIcon(stat.glyph, size: 16, tint: stat.tint)
            Text("\(stat.short):").font(.hud(16))
            Text("\(value)").font(.number(19, weight: .bold))
                .contentTransition(.numericText(value: Double(value)))
            Text("(+\((value / 10) * 5)%)").font(.text(12, weight: .semibold)).foregroundStyle(Ink.jade)
            Spacer(minLength: 0)
            if canSpend {
                Button {
                    withAnimation(.snappy) { engine.spendStatPoint(on: stat, player: player) }
                    spends += 1
                } label: {
                    GlyphIcon(.plus, size: 13, tint: Ink.sumi)
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Add a point to \(stat.title)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
