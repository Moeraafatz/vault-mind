import Foundation
import VaultMindCore

public enum VaultSampleData {
    public static func demoAnswer() -> AnalystAnswer {
        let chunks: [DocumentChunk] = [
            DocumentChunk(
                id: 1,
                filePath: "/Users/docs/quotes/northstar-quote.pdf",
                fileName: "northstar-quote.pdf",
                kind: .pdf,
                locationLabel: "p. 2",
                chunkIndex: 1,
                sha256: "a1",
                text: "Total Annual Subscription: $14,900 USD per year. Payment Terms: Net-30, 99.99% SLA, 15-day notice renewal opt-out."
            ),
            DocumentChunk(
                id: 2,
                filePath: "/Users/docs/quotes/kestrel-quote-scan.png",
                fileName: "kestrel-quote-scan.png",
                kind: .imageOCR,
                locationLabel: "OCR",
                chunkIndex: 0,
                sha256: "b2",
                text: "Kestrel DevOps Annual Quote — Total Price $16,200 USD Net-30 billing with 99.95% SLA guaranteed."
            ),
            DocumentChunk(
                id: 3,
                filePath: "/Users/docs/quotes/acme-cloud-quote.pdf",
                fileName: "acme-cloud-quote.pdf",
                kind: .pdf,
                locationLabel: "p. 2",
                chunkIndex: 1,
                sha256: "c3",
                text: "Annual Enterprise Tier: $18,400 USD per year. Billing Terms: Net-30 with 99.95% SLA and 30-day notice."
            ),
            DocumentChunk(
                id: 4,
                filePath: "/Users/docs/quotes/velox-quote.pdf",
                fileName: "velox-quote.pdf",
                kind: .pdf,
                locationLabel: "p. 2",
                chunkIndex: 1,
                sha256: "d4",
                text: "Annual Contract Value: $22,800 USD per year. Terms: Net-60, 99.9% SLA, 60-day notice auto-renewal."
            )
        ]

        let hits = chunks.enumerated().map { idx, ch in
            VaultSearchHit(
                chunk: ch,
                snippet: ch.text,
                lexicalScore: 0.96 - Double(idx) * 0.04,
                semanticScore: 0.91 - Double(idx) * 0.03,
                combinedScore: 0.94 - Double(idx) * 0.04
            )
        }
        return CrossDocAnalyst.analyze(question: "Compare Q4 vendor quotes and find lowest annual price", hits: hits)
    }

    public static func demoFolders() -> [WatchedFolderInfo] {
        [
            WatchedFolderInfo(path: "~/Documents/VendorQuotes", displayName: "VendorQuotes", indexedFiles: 42, indexedChunks: 618, isWatching: true),
            WatchedFolderInfo(path: "~/Documents/Contracts", displayName: "Contracts", indexedFiles: 28, indexedChunks: 894, isWatching: true),
            WatchedFolderInfo(path: "~/Projects/swift-suite", displayName: "swift-suite", indexedFiles: 196, indexedChunks: 2_840, isWatching: true)
        ]
    }

    public static func demoKindBreakdown() -> [KindBreakdownBucket] {
        [
            KindBreakdownBucket(kind: .pdf, fileCount: 64, chunkCount: 1_512),
            KindBreakdownBucket(kind: .code, fileCount: 142, chunkCount: 1_920),
            KindBreakdownBucket(kind: .markdown, fileCount: 38, chunkCount: 610),
            KindBreakdownBucket(kind: .imageOCR, fileCount: 14, chunkCount: 184),
            KindBreakdownBucket(kind: .table, fileCount: 8, chunkCount: 126)
        ]
    }
}
