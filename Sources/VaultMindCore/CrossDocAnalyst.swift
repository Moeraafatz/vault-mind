import Foundation

/// Zero-cloud cross-document analyst that synthesizes cited answers, extracts prices/SLAs/terms
/// across multiple local files, highlights the best numeric offer, and exports Markdown & CSV matrices.
public enum CrossDocAnalyst {
    public static func analyze(question: String, hits: [VaultSearchHit]) -> AnalystAnswer {
        let start = CFAbsoluteTimeGetCurrent()
        guard !hits.isEmpty else {
            return AnalystAnswer(
                question: question,
                executiveSummary: "No indexed local files matched \"\(question)\". Add a folder or re-index in the Folders tab.",
                citations: [],
                comparisonRows: [],
                markdownReport: "# Vault Mind Analysis\n\nNo matches found.",
                csvComparison: "Citation,File,Location,ExtractedValue,Terms,KeyClause\n",
                durationMs: (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            )
        }

        // Deduplicate to best highest-scoring chunk per unique source file for cross-file comparison
        var bestByFile: [VaultSearchHit] = []
        var seenFiles = Set<String>()
        for hit in hits {
            if seenFiles.insert(hit.chunk.filePath).inserted {
                bestByFile.append(hit)
            }
            if bestByFile.count >= 8 { break }
        }

        var draftRows: [(hit: VaultSearchHit, valueLabel: String, numeric: Double?, terms: String, clause: String)] = []
        for hit in bestByFile {
            let (valLabel, num) = extractPrimaryPrice(from: hit.chunk.text)
            let terms = extractTermsSummary(from: hit.chunk.text)
            let clause = extractBestSentence(from: hit.chunk.text, question: question)
            draftRows.append((hit, valLabel, num, terms, clause))
        }

        let lowestNumeric = draftRows.compactMap(\.numeric).min()
        let wantsLowest = question.lowercased().contains("cheap") ||
            question.lowercased().contains("lowest") ||
            question.lowercased().contains("compare") ||
            question.lowercased().contains("quote") ||
            question.lowercased().contains("price")

        var rows: [ComparisonRow] = []
        for (idx, item) in draftRows.enumerated() {
            let isBest = wantsLowest && (item.numeric != nil && item.numeric == lowestNumeric)
            rows.append(ComparisonRow(
                citationIndex: idx + 1,
                fileName: item.hit.chunk.fileName,
                filePath: item.hit.chunk.filePath,
                locationLabel: item.hit.chunk.locationLabel,
                kind: item.hit.chunk.kind,
                extractedValueLabel: item.valueLabel,
                numericAmountUSD: item.numeric,
                termsSummary: item.terms,
                keyClause: item.clause,
                relevancePercent: Int((item.hit.combinedScore * 100.0).rounded()),
                isHighlightedBest: isBest
            ))
        }

        let summary = buildExecutiveSummary(question: question, rows: rows)
        let markdown = buildMarkdownReport(question: question, summary: summary, rows: rows)
        let csv = buildCSVComparison(rows: rows)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        return AnalystAnswer(
            question: question,
            executiveSummary: summary,
            citations: bestByFile,
            comparisonRows: rows,
            markdownReport: markdown,
            csvComparison: csv,
            durationMs: elapsed
        )
    }

    public static func extractPrimaryPrice(from text: String) -> (String, Double?) {
        // Match $4,200.00 / $18,500 / 4,200 USD / USD 3,600
        let patterns = [
            #"\$\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)"#,
            #"\b([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]{3,}(?:\.[0-9]{1,2})?)\s*(?:USD|usd)\b"#
        ]
        var found: [(String, Double)] = []
        for pat in patterns {
            guard let regex = try? NSRegularExpression(pattern: pat) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for m in regex.matches(in: text, range: range) {
                if let numRange = Range(m.range(at: 1), in: text) {
                    let clean = String(text[numRange]).replacingOccurrences(of: ",", with: "")
                    if let val = Double(clean), val > 0 {
                        let formatted = val >= 1000
                            ? String(format: "$%.0f", val)
                            : String(format: "$%.2f", val)
                        found.append((formatted, val))
                    }
                }
            }
        }
        if let maxQuote = found.max(by: { $0.1 < $1.1 }) {
            return maxQuote
        }
        // Fallback: SLA or percentage metric
        if let pctRegex = try? NSRegularExpression(pattern: #"\b([0-9]{2,3}(?:\.[0-9]{1,2})?%)"#),
           let m = pctRegex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let r = Range(m.range(at: 1), in: text) {
            return (String(text[r]), nil)
        }
        return ("—", nil)
    }

    public static func extractTermsSummary(from text: String) -> String {
        let lower = text.lowercased()
        var pills: [String] = []
        if lower.contains("net-30") || lower.contains("net 30") { pills.append("Net-30") }
        if lower.contains("net-60") || lower.contains("net 60") { pills.append("Net-60") }
        if lower.contains("annual") || lower.contains("/yr") || lower.contains("per year") { pills.append("Annual") }
        else if lower.contains("monthly") || lower.contains("/mo") { pills.append("Monthly") }

        if let slaRegex = try? NSRegularExpression(pattern: #"\b(99\.\d+%\s*SLA|99\.\d+%)"#),
           let m = slaRegex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let r = Range(m.range(at: 1), in: text) {
            pills.append(String(text[r]))
        }
        if let noticeRegex = try? NSRegularExpression(pattern: #"(?i)\b(\d{1,2}-day\s+notice|\d{1,2}\s+days?\s+notice)\b"#),
           let m = noticeRegex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let r = Range(m.range(at: 1), in: text) {
            pills.append(String(text[r]))
        }
        return pills.isEmpty ? "Standard Terms" : pills.prefix(3).joined(separator: " · ")
    }

    private static func extractBestSentence(from text: String, question: String) -> String {
        let qTokens = Set(question.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
        let lines = text
            .components(separatedBy: CharacterSet(charactersIn: ".\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 16 }

        var bestLine = lines.first ?? String(text.prefix(120))
        var bestScore = -1
        for line in lines {
            let lower = line.lowercased()
            var score = qTokens.reduce(0) { $0 + (lower.contains($1) ? 2 : 0) }
            if lower.contains("$") || lower.contains("usd") || lower.contains("notice") || lower.contains("sla") {
                score += 2
            }
            if score > bestScore {
                bestScore = score
                bestLine = line
            }
        }
        return bestLine.count > 130 ? String(bestLine.prefix(127)) + "…" : bestLine
    }

    private static func buildExecutiveSummary(question: String, rows: [ComparisonRow]) -> String {
        let fileCount = rows.count
        let priced = rows.filter { $0.numericAmountUSD != nil }
        if let best = rows.first(where: \.isHighlightedBest), priced.count >= 2 {
            let maxRow = priced.max(by: { ($0.numericAmountUSD ?? 0) < ($1.numericAmountUSD ?? 0) })
            let savingsText: String
            if let hi = maxRow?.numericAmountUSD, let lo = best.numericAmountUSD, hi > lo {
                savingsText = String(format: " — saves $%.0f vs %@ [%d].", hi - lo, maxRow?.fileName ?? "", maxRow?.citationIndex ?? 0)
            } else {
                savingsText = "."
            }
            return "Synthesized \(fileCount) local sources for \"\(question)\". Lowest extracted figure is \(best.extractedValueLabel) in \(best.fileName) (\(best.locationLabel)) [\(best.citationIndex)] (\(best.termsSummary))\(savingsText)"
        }
        let topCite = rows.first.map { "\($0.fileName) (\($0.locationLabel)) [1]" } ?? "local vault"
        return "Found \(fileCount) distinct cited sources across your local vault. Top match: \(topCite) — \(rows.first?.keyClause ?? "")"
    }

    private static func buildMarkdownReport(question: String, summary: String, rows: [ComparisonRow]) -> String {
        var md = "# Vault Mind Analysis: \(question)\n\n"
        md += "> \(summary)\n\n"
        md += "| # | Source File | Location | Extracted Value | Terms | Key Evidence |\n"
        md += "| :---: | :--- | :--- | ---: | :--- | :--- |\n"
        for r in rows {
            let badge = r.isHighlightedBest ? " ★" : ""
            let safeClause = r.keyClause.replacingOccurrences(of: "|", with: "\\|")
            md += "| [\(r.citationIndex)] | `\(r.fileName)` | \(r.locationLabel) | **\(r.extractedValueLabel)**\(badge) | \(r.termsSummary) | \(safeClause) |\n"
        }
        md += "\n## Exact File Citations\n"
        for r in rows {
            md += "- **[\(r.citationIndex)]** `\(r.filePath)` (`\(r.locationLabel)`)\n"
        }
        return md
    }

    private static func buildCSVComparison(rows: [ComparisonRow]) -> String {
        func esc(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        var lines = ["Citation,File,Location,Kind,ExtractedValue,Terms,RelevancePercent,BestMatch,KeyClause"]
        for r in rows {
            lines.append([
                "[\(r.citationIndex)]",
                esc(r.fileName),
                esc(r.locationLabel),
                esc(r.kind.rawValue),
                esc(r.extractedValueLabel),
                esc(r.termsSummary),
                "\(r.relevancePercent)",
                r.isHighlightedBest ? "YES" : "NO",
                esc(r.keyClause)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
