import SwiftUI
import VaultMindCore

public struct VaultPrivacyView: View {
    @Bindable var state: VaultAppState

    public init(state: VaultAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            extractorsCard
            exclusionsCard
            wipeCard
        }
    }

    private var extractorsCard: some View {
        VaultGlassCard(padding: 11, cornerRadius: 13) {
            VStack(spacing: 9) {
                toggleRow(
                    title: "Index Multi-Page PDFs (Apple PDFKit)",
                    detail: "Preserves exact page numbers [p. N] for inline citations",
                    isOn: state.config.indexPDFs,
                    accent: VaultTheme.mint
                ) { state.config.indexPDFs.toggle() }

                Divider().overlay(Color.white.opacity(0.08))

                toggleRow(
                    title: "OCR Screenshots & Scans (Apple Vision ANE)",
                    detail: "Extracts text from PNG/JPG/HEIC receipts & slides offline",
                    isOn: state.config.indexImagesOCR,
                    accent: VaultTheme.gold
                ) { state.config.indexImagesOCR.toggle() }

                Divider().overlay(Color.white.opacity(0.08))

                toggleRow(
                    title: "Optional Loopback Ollama Synthesis (127.0.0.1)",
                    detail: "Built-in deterministic Swift analyst runs at 0 external cost",
                    isOn: state.config.enableLoopbackOllama,
                    accent: VaultTheme.emerald
                ) { state.config.enableLoopbackOllama.toggle() }
            }
        }
    }

    private func toggleRow(title: String, detail: String, isOn: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VaultTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(VaultTheme.textSecondary)
            }
            Spacer()
            VaultTogglePill(isOn: isOn, accent: accent, action: action)
        }
    }

    private var exclusionsCard: some View {
        VaultGlassCard(padding: 11, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Auto-Skipped Junk Directories", systemImage: "eye.slash.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VaultTheme.textPrimary)
                HStack(spacing: 5) {
                    ForEach([".git", "node_modules", ".build", "DerivedData", ".venv"], id: \.self) { dir in
                        Text(dir)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VaultTheme.mint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VaultTheme.indigo.opacity(0.20)))
                    }
                }
            }
        }
    }

    private var wipeCard: some View {
        VaultGlassCard(padding: 10, cornerRadius: 13, borderColor: VaultTheme.rose.opacity(0.32)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("100% Private Local SQLite RAG Vault")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VaultTheme.textPrimary)
                    Text("Files never uploaded · Zero cloud embeddings · Single local SQLite WAL")
                        .font(.system(size: 9.5))
                        .foregroundStyle(VaultTheme.textSecondary)
                }
                Spacer()
                Button {
                    state.wipeVault()
                } label: {
                    Label("Wipe Index", systemImage: "trash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(VaultTheme.rose.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
