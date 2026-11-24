import SwiftUI
import VaultMindCore

public struct VaultFoldersView: View {
    @Bindable var state: VaultAppState

    public init(state: VaultAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            metricsRow
            watchedFoldersCard
            kindDistributionCard
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            statTile(title: "FILES", value: "\(state.totalFiles)", tint: VaultTheme.mint)
            statTile(title: "CHUNKS", value: formatK(state.totalChunks), tint: VaultTheme.indigo)
            statTile(title: "VAULT DB", value: VaultTheme.formatBytes(state.databaseBytes), tint: VaultTheme.emerald)
        }
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VaultGlassCard(padding: 9, cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(VaultTheme.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var watchedFoldersCard: some View {
        VaultGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("FSEvents Live-Watched Folders", systemImage: "folder.badge.gearshape")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VaultTheme.textPrimary)
                    Spacer()
                    Button {
                        state.addAndIndexFolder()
                    } label: {
                        Label("Add Folder", systemImage: "plus")
                            .font(.system(size: 9.8, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 8.5)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(VaultTheme.mint))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(state.watchedFolders.prefix(3)) { folder in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(folder.isWatching ? VaultTheme.emerald : VaultTheme.textTertiary)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(folder.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VaultTheme.textPrimary)
                            Text(folder.path)
                                .font(.system(size: 9.2, design: .monospaced))
                                .foregroundStyle(VaultTheme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(folder.indexedFiles) files · \(folder.indexedChunks) chunks")
                            .font(.system(size: 9.2, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VaultTheme.textSecondary)
                    }
                    .padding(.vertical, 2.5)
                }
            }
        }
    }

    private var kindDistributionCard: some View {
        let maxChunks = max(state.kindBreakdown.map(\.chunkCount).max() ?? 1, 1)
        return VaultGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Indexed Chunks by File Type (SHA-256 Incremental)")
                    .font(.system(size: 10.8, weight: .bold))
                    .foregroundStyle(VaultTheme.textPrimary)

                ForEach(state.kindBreakdown.prefix(5)) { bucket in
                    let tint = VaultTheme.kindTint(bucket.kind)
                    let frac = Double(bucket.chunkCount) / Double(maxChunks)
                    HStack(spacing: 8) {
                        Text(bucket.kind.rawValue)
                            .font(.system(size: 9.8, weight: .bold, design: .monospaced))
                            .foregroundStyle(tint)
                            .frame(width: 44, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(tint.opacity(0.88))
                                    .frame(width: max(8, geo.size.width * CGFloat(frac)))
                            }
                        }
                        .frame(height: 6)

                        Text("\(bucket.fileCount)f / \(bucket.chunkCount)c")
                            .font(.system(size: 9.2, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VaultTheme.textSecondary)
                            .frame(width: 78, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func formatK(_ n: Int) -> String {
        n >= 1_000 ? String(format: "%.1fK", Double(n) / 1000.0) : "\(n)"
    }
}
