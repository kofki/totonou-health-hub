import SwiftUI
import TotonouCore

/// Connect Claude: makes the personal link Claude uses to read your game and
/// add quests, and shows where to paste it.
struct ClaudeConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine

    /// Shown once, right after it is made. The database keeps only its hash,
    /// so it cannot be shown again later; making a new one replaces it.
    @State private var token: String?
    @State private var isConnected = false
    @State private var isWorking = false
    @State private var problem: String?
    @State private var copied: String?

    private let link = ClaudeLinks.make()

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemWindow(title: "Claude") {
                        Text("Claude reads your arcs, quests and progress, plans with you, and adds quests. It uses your own Claude account.")
                            .font(.text(17, weight: .medium))
                    }

                    if link == nil {
                        SystemPanel {
                            Text("Cloud backup is not set up in this build, so Claude has nothing to connect to.")
                                .font(.text(16))
                        }
                    } else if let token {
                        steps(token)
                    } else {
                        SystemPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(isConnected ? "Connected." : "Not connected.")
                                    .font(.text(18, weight: .semibold))
                                Text(isConnected
                                     ? "Make another link for another Claude app or the Mac coach relay. Links you made before keep working."
                                     : "Make a link, then paste it into Claude.")
                                    .caption()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(isConnected ? "Make a new link" : "Make a link") { makeLink() }
                            .buttonStyle(SystemButtonStyle(filled: true))
                            .disabled(isWorking)
                    }

                    if isConnected && token == nil {
                        Button("Disconnect Claude") { disconnect() }
                            .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                            .disabled(isWorking)
                    }

                    if let problem {
                        Text(problem).caption()
                    }

                    Button("Done") { dismiss() }
                        .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Ink.washi)
        .task { await refresh() }
    }

    // MARK: Pieces

    @ViewBuilder
    private func steps(_ token: String) -> some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Claude app or claude.ai").font(.text(18, weight: .semibold))
                Text("In Claude, open Settings, then Connectors, and add a custom connector. Name it Totonou and paste this link.")
                    .font(.text(15))
                copyable(ClaudeServer.connectorURL(token: token) ?? "", label: "link")
                Text("Add it once on claude.ai or the Mac app and it shows up in the iPhone app too.")
                    .caption()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        SystemPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Claude Code").font(.text(18, weight: .semibold))
                Text("Run this once in a terminal.").font(.text(15))
                copyable(ClaudeServer.claudeCodeCommand(token: token) ?? "", label: "command")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Text("Anyone with this link can read your game and add quests. Do not share it. It is shown only now.")
            .caption()
        Button("Done, hide it") { self.token = nil }
            .buttonStyle(SystemButtonStyle(filled: true))
    }

    private func copyable(_ text: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(4)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.washi.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button(copied == label ? "Copied" : "Copy \(label)") {
                UIPasteboard.general.string = text
                copied = label
            }
            .font(.text(14, weight: .semibold))
            .foregroundStyle(Ink.ai)
        }
    }

    // MARK: Actions

    private func refresh() async {
        guard let link else { return }
        isConnected = (try? await link.hasToken()) ?? false
    }

    private func makeLink() {
        guard let link else { return }
        isWorking = true
        problem = nil
        Task {
            do {
                // Upload first, so Claude has something to read the moment it connects.
                await engine.shareWithClaude(context: context)
                token = try await link.newToken()
                isConnected = true
            } catch {
                problem = "Could not make a link: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    private func disconnect() {
        guard let link else { return }
        isWorking = true
        Task {
            do {
                try await link.revokeTokens()
                isConnected = false
            } catch {
                problem = "Could not disconnect: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }
}
