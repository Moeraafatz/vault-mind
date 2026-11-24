import AppKit
import SwiftUI
import VaultMindCore

public struct RootVaultView: View {
    @Bindable var state: VaultAppState
    public let width: CGFloat

    public init(state: VaultAppState, width: CGFloat = 510) {
        self.state = state
        self.width = width
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            VStack(spacing: 11) {
                headerBar
                tabBar

                Group {
                    switch state.selectedTab {
                    case .ask:
                        AnalystView(state: state)
                    case .compare:
                        CompareMatrixView(state: state)
                    case .folders:
                        VaultFoldersView(state: state)
                    case .privacy:
                        VaultPrivacyView(state: state)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                footerBar
            }
            .padding(14)

            if let toast = state.statusToast {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(VaultTheme.mint))
                    .padding(.bottom, 16)
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(VaultTheme.cardBorderStrong, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [VaultTheme.canvasTop, VaultTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [VaultTheme.indigo.opacity(0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [VaultTheme.mint.opacity(0.14), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 310
            )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [VaultTheme.indigo.opacity(0.42), VaultTheme.mint.opacity(0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(VaultTheme.mint.opacity(0.55), lineWidth: 1)
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VaultTheme.mint)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Vault Mind")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VaultTheme.textPrimary)
                    Text("v1.0.0")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(VaultTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                Text("Local Multi-File Analyst Brain · FSEvents + FTS5 + vDSP")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VaultTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(state.isIndexing ? VaultTheme.gold : VaultTheme.emerald)
                    .frame(width: 7, height: 7)
                Text(state.isIndexing ? "INDEXING" : "LIVE WATCH")
                    .font(.system(size: 9.2, weight: .bold, design: .monospaced))
                    .foregroundStyle(state.isIndexing ? VaultTheme.gold : VaultTheme.emerald)
            }
            .padding(.horizontal, 8.5)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill((state.isIndexing ? VaultTheme.gold : VaultTheme.emerald).opacity(0.14))
                    .overlay(Capsule().strokeBorder((state.isIndexing ? VaultTheme.gold : VaultTheme.emerald).opacity(0.32), lineWidth: 0.75))
            )
        }
    }

    private var tabBar: some View {
        let tabs = VaultTab.allCases
        return HStack(spacing: 5) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let active = state.selectedTab == tab
                Button {
                    state.selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10.8, weight: active ? .bold : .medium))
                        Text(tab.shortcut)
                            .font(.system(size: 8.8, weight: .medium, design: .monospaced))
                            .foregroundStyle(active ? Color.black.opacity(0.65) : VaultTheme.textTertiary)
                    }
                    .foregroundStyle(active ? Color.black : VaultTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(active ? VaultTheme.textPrimary : Color.white.opacity(0.055))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var footerBar: some View {
        HStack(spacing: 9) {
            Text("⌥⇧B Toggle Brain")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(VaultTheme.textTertiary)
            Text("·")
                .foregroundStyle(VaultTheme.textTertiary)
            Text("\(state.totalFiles) files · \(VaultTheme.formatBytes(state.databaseBytes))")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(VaultTheme.mint)
            Spacer()
            Text("100% Local RAG")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(VaultTheme.emerald)
            if !state.isPreviewSnapshot {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(VaultTheme.textTertiary)
            }
        }
        .padding(.top, 2)
    }
}
