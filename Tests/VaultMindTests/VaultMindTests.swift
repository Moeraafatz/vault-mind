import Foundation
import VaultMindCore
import XCTest

final class VaultMindTests: XCTestCase {
    func testMultiPagePDFExtractionAndIncrementalSHA256Skip() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vm-test-\(UUID().uuidString)")
        let docs = dir.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let pdfURL = docs.appendingPathComponent("acme-quote.pdf")
        try VaultBenchmarkRunner.makePDF(pages: [
            ["Acme Enterprise Proposal — Cover Page"],
            ["Annual Subscription: $18,400 USD per year. Payment Terms: Net-30 with 99.95% SLA."]
        ]).write(to: pdfURL)

        let store = try VaultStore(databaseURL: dir.appendingPathComponent("vault.sqlite"))
        let watcher = FolderWatcher(store: store)

        let pass1 = try await watcher.indexFolder(at: docs)
        XCTAssertEqual(pass1.filesIndexed, 1)
        XCTAssertEqual(pass1.filesSkippedUnchanged, 0)
        XCTAssertGreaterThanOrEqual(pass1.chunksWritten, 2)

        // Second pass over unmodified file must skip 100% via SHA-256
        let pass2 = try await watcher.indexFolder(at: docs)
        XCTAssertEqual(pass2.filesIndexed, 0)
        XCTAssertEqual(pass2.filesSkippedUnchanged, 1)

        let hits = try await store.hybridSearch(query: "18400 Net-30 SLA", limit: 5)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.chunk.locationLabel, "p. 2")
    }

    func testCrossDocAnalystIdentifiesCheapestQuoteAndExportsMarkdownAndCSV() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vm-analyst-\(UUID().uuidString)")
        let docs = dir.appendingPathComponent("quotes", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try VaultBenchmarkRunner.makePDF(pages: [
            ["Vendor A Quote", "Annual Cloud Plan: $19,200 USD Net-30 99.9% SLA"]
        ]).write(to: docs.appendingPathComponent("vendor-a.pdf"))

        try VaultBenchmarkRunner.makePDF(pages: [
            ["Vendor B Quote", "Annual Cloud Plan: $12,800 USD Net-30 99.99% SLA 15-day notice"]
        ]).write(to: docs.appendingPathComponent("vendor-b.pdf"))

        let store = try VaultStore(databaseURL: dir.appendingPathComponent("vault.sqlite"))
        let watcher = FolderWatcher(store: store)
        _ = try await watcher.indexFolder(at: docs)

        let hits = try await store.hybridSearch(query: "annual cloud quote Net-30 SLA", limit: 10)
        let answer = CrossDocAnalyst.analyze(question: "Compare quotes and find lowest annual price", hits: hits)

        XCTAssertEqual(answer.comparisonRows.count, 2)
        let best = try XCTUnwrap(answer.comparisonRows.first(where: \.isHighlightedBest))
        XCTAssertEqual(best.fileName, "vendor-b.pdf")
        XCTAssertEqual(best.numericAmountUSD, 12_800.0)
        XCTAssertTrue(answer.markdownReport.contains("vendor-b.pdf"))
        XCTAssertTrue(answer.csvComparison.contains("YES"))
    }

    func testVisionOCRIngestionAndVectorCosineSanity() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vm-ocr-\(UUID().uuidString)")
        let docs = dir.appendingPathComponent("scans", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let imgURL = docs.appendingPathComponent("receipt.png")
        try VaultBenchmarkRunner.writeSyntheticReceiptPNG(lines: [
            "Kestrel Annual Quote",
            "Total $16200 USD Net-30"
        ], to: imgURL)

        let store = try VaultStore(databaseURL: dir.appendingPathComponent("vault.sqlite"))
        let watcher = FolderWatcher(store: store)
        let stats = try await watcher.indexFolder(at: docs)
        XCTAssertEqual(stats.filesIndexed, 1)

        let hits = try await store.hybridSearch(query: "Kestrel 16200 Net-30", limit: 5)
        XCTAssertEqual(hits.first?.chunk.kind, .imageOCR)

        let vA = VectorIndex.embed("sqlite fts5 hybrid local search")
        let vB = VectorIndex.embed("sqlite fts5 local document search")
        let vC = VectorIndex.embed("banana pineapple tropical smoothie")
        XCTAssertGreaterThan(VectorIndex.cosineSimilarity(vA, vB), VectorIndex.cosineSimilarity(vA, vC))
    }
}
