import SwiftUI
import VaultMindCore

public struct CompareMatrixView: View {
    @Bindable var state: VaultAppState

    public init(state: VaultAppState) {
        self.state = state
    }

    public var body: some View {
        if let answer = state.currentAnswer, !answer.comparisonRows.isEmpty {
            VStack(spacing: 10) {
                headerStrip(answer)
                matrixTable(answer)
                exportFooter
            }
        } else {
            VaultGlassCard(padding: 20) {
                Text("Run a cross-document question in Ask (⌘1) to auto-build a comparison matrix.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(VaultTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func headerStrip(_ answer: AnalystAnswer) -> some View {
        VaultGlassCard(padding: 10, cornerRadius: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Extracted Cross-File Matrix")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VaultTheme.textPrimary)
                    Text("Prices, terms, SLAs & page citations extracted locally from \(answer.comparisonRows.count) files")
                        .font(.system(size: 9.8))
                        .foregroundStyle(VaultTheme.textSecondary)
                }
                Spacer()
                Text("LOCAL RAG")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(VaultTheme.mint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(VaultTheme.mint.opacity(0.16)))
            }
        }
    }

    private func matrixTable(_ answer: AnalystAnswer) -> some View {
        VaultGlassCard(padding: 10, cornerRadius: 13) {
            VStack(spacing: 7) {
                HStack {
                    Text("SOURCE FILE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("VALUE")
                        .frame(width: 72, alignment: .trailing)
                    Text("TERMS / SLA")
                        .frame(width: 145, alignment: .trailing)
                }
                .font(.system(size: 8.8, weight: .bold, design: .monospaced))
                .foregroundStyle(VaultTheme.textTertiary)
                .padding(.horizontal, 4)

                Divider().overlay(Color.white.opacity(0.10))

                ForEach(answer.comparisonRows.prefix(5)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1.5) {
                                HStack(spacing: 5) {
                                    Text("[\(row.citationIndex)] \(row.fileName)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(VaultTheme.textPrimary)
                                        .lineLimit(1)
                                    if row.isHighlightedBest {
                                        Text("★ BEST")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(VaultTheme.emerald))
                                    }
                                }
                                Text("\(row.kind.rawValue) · \(row.locationLabel) · \(row.relevancePercent)% match")
                                    .font(.system(size: 9.2, design: .monospaced))
                                    .foregroundStyle(VaultTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(row.extractedValueLabel)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(row.isHighlightedBest ? VaultTheme.emerald : VaultTheme.gold)
                                .frame(width: 72, alignment: .trailing)

                            Text(row.termsSummary)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(VaultTheme.mint)
                                .lineLimit(1)
                                .frame(width: 145, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(row.isHighlightedBest ? VaultTheme.emerald.opacity(0.10) : Color.white.opacity(0.03))
                    )
                }
            }
        }
    }

    private var exportFooter: some View {
        HStack(spacing: 8) {
            Button {
                state.copyCSVMatrix()
            } label: {
                Label("Export CSV Matrix", systemImage: "tablecells.fill")
                    .font(.system(size: 10.8, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7.5)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(VaultTheme.emerald))
            }
            .buttonStyle(.plain)

            Button {
                state.copyMarkdownReport()
            } label: {
                Label("Copy Cited Markdown", systemImage: "doc.richtext.fill")
                    .font(.system(size: 10.8, weight: .bold))
                    .foregroundStyle(VaultTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7.5)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(VaultTheme.indigo.opacity(0.65)))
            }
            .buttonStyle(.plain)
        }
    }
}
