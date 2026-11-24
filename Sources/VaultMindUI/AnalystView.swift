import SwiftUI
import VaultMindCore

public struct AnalystView: View {
    @Bindable var state: VaultAppState

    public init(state: VaultAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            queryBar
            if let answer = state.currentAnswer {
                synthesisCard(answer)
                citationsSection(answer)
            }
        }
    }

    private var queryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(VaultTheme.mint)

            if state.isPreviewSnapshot {
                HStack(spacing: 2) {
                    Text(state.questionInput)
                        .font(.system(size: 12.6, weight: .semibold))
                        .foregroundStyle(VaultTheme.textPrimary)
                        .lineLimit(1)
                    Rectangle()
                        .fill(VaultTheme.mint)
                        .frame(width: 1.5, height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Ask across all PDFs, screenshots, notes & code…", text: $state.questionInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.6, weight: .semibold))
                    .foregroundStyle(VaultTheme.textPrimary)
                    .onSubmit {
                        Task { await state.runAnalystQuery() }
                    }
            }

            Button {
                Task { await state.runAnalystQuery() }
            } label: {
                Text("Ask")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(VaultTheme.mint))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8.5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(VaultTheme.indigo.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private func synthesisCard(_ answer: AnalystAnswer) -> some View {
        VaultGlassCard(padding: 11, cornerRadius: 14, borderColor: VaultTheme.mint.opacity(0.32)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Cross-Document Synthesis", systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VaultTheme.mint)
                    Spacer()
                    Text(String(format: "%d files · %.1f ms", answer.comparisonRows.count, max(0.8, answer.durationMs)))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(VaultTheme.emerald)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(VaultTheme.emerald.opacity(0.15)))
                }

                Text(answer.executiveSummary)
                    .font(.system(size: 11.4, weight: .medium))
                    .foregroundStyle(VaultTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Button {
                        state.selectedTab = .compare
                    } label: {
                        Label("Open Matrix", systemImage: "tablecells")
                            .font(.system(size: 10.2, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(VaultTheme.mint))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.copyMarkdownReport()
                    } label: {
                        Label("Copy MD", systemImage: "doc.on.doc")
                            .font(.system(size: 10.2, weight: .semibold))
                            .foregroundStyle(VaultTheme.textPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.copyCSVMatrix()
                    } label: {
                        Label("Copy CSV", systemImage: "tablecells.badge.ellipsis")
                            .font(.system(size: 10.2, weight: .semibold))
                            .foregroundStyle(VaultTheme.emerald)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(VaultTheme.emerald.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func citationsSection(_ answer: AnalystAnswer) -> some View {
        VStack(spacing: 6.5) {
            ForEach(answer.comparisonRows.prefix(4)) { row in
                let tint = VaultTheme.kindTint(row.kind)
                Button {
                    state.revealFile(row.filePath)
                } label: {
                    VaultGlassCard(
                        padding: 9,
                        cornerRadius: 11,
                        borderColor: row.isHighlightedBest ? VaultTheme.emerald.opacity(0.45) : VaultTheme.cardBorder
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("[\(row.citationIndex)]")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(VaultTheme.mint)
                                Text(row.fileName)
                                    .font(.system(size: 11.2, weight: .bold))
                                    .foregroundStyle(VaultTheme.textPrimary)
                                    .lineLimit(1)
                                Text(row.locationLabel)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(tint)
                                    .padding(.horizontal, 5.5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(tint.opacity(0.16)))
                                Spacer()
                                if row.isHighlightedBest {
                                    Text("LOWEST")
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(VaultTheme.emerald))
                                }
                                Text(row.extractedValueLabel)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(row.isHighlightedBest ? VaultTheme.emerald : VaultTheme.gold)
                            }
                            Text(row.keyClause)
                                .font(.system(size: 10.2, design: .monospaced))
                                .foregroundStyle(VaultTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
