import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct VaultScalePoint: Codable, Sendable {
    public let chunkCount: Int
    public let databaseBytes: Int64
    public let bytesPerChunk: Double
    public let searchP50Ms: Double
    public let searchP95Ms: Double

    public init(chunkCount: Int, databaseBytes: Int64, bytesPerChunk: Double, searchP50Ms: Double, searchP95Ms: Double) {
        self.chunkCount = chunkCount
        self.databaseBytes = databaseBytes
        self.bytesPerChunk = bytesPerChunk
        self.searchP50Ms = searchP50Ms
        self.searchP95Ms = searchP95Ms
    }
}

public struct VaultBenchmarkReport: Codable, Sendable {
    public let generatedAtISO8601: String
    public let hostArchitecture: String
    public let osVersion: String
    public let initialCorpusIndexMs: Double
    public let incrementalRescanSkipMs: Double
    public let rescanSpeedupFactor: Double
    public let pdfMultiPageVerified: Bool
    public let visionOCRVerified: Bool
    public let crossDocLowestPriceVerified: Bool
    public let crossDocSynthesisMs: Double
    public let scalePoints: [VaultScalePoint]

    public init(
        generatedAtISO8601: String,
        hostArchitecture: String,
        osVersion: String,
        initialCorpusIndexMs: Double,
        incrementalRescanSkipMs: Double,
        rescanSpeedupFactor: Double,
        pdfMultiPageVerified: Bool,
        visionOCRVerified: Bool,
        crossDocLowestPriceVerified: Bool,
        crossDocSynthesisMs: Double,
        scalePoints: [VaultScalePoint]
    ) {
        self.generatedAtISO8601 = generatedAtISO8601
        self.hostArchitecture = hostArchitecture
        self.osVersion = osVersion
        self.initialCorpusIndexMs = initialCorpusIndexMs
        self.incrementalRescanSkipMs = incrementalRescanSkipMs
        self.rescanSpeedupFactor = rescanSpeedupFactor
        self.pdfMultiPageVerified = pdfMultiPageVerified
        self.visionOCRVerified = visionOCRVerified
        self.crossDocLowestPriceVerified = crossDocLowestPriceVerified
        self.crossDocSynthesisMs = crossDocSynthesisMs
        self.scalePoints = scalePoints
    }
}

public enum VaultBenchmarkRunner {
    public static func makePDF(pages: [[String]]) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }

        for pageLines in pages {
            ctx.beginPDFPage(nil)
            var y: CGFloat = 720
            for line in pageLines {
                drawLine(ctx, text: line, x: 48, y: y, size: 13)
                y -= 24
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    public static func writeSyntheticReceiptPNG(lines: [String], to url: URL) throws {
        let w = 960
        let h = 420
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var y: CGFloat = 340
        for line in lines {
            drawLine(ctx, text: line, x: 40, y: y, size: 26)
            y -= 58
        }
        let img = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }

    private static func drawLine(_ ctx: CGContext, text: String, x: CGFloat, y: CGFloat, size: CGFloat) {
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
        let color = CGColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }

    public static func runFullSuite(scaleLevels: [Int] = [1_000, 5_000, 10_000, 25_000]) async throws -> VaultBenchmarkReport {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("vm-bench-\(UUID().uuidString)")
        let corpusDir = root.appendingPathComponent("corpus", isDirectory: true)
        try FileManager.default.createDirectory(at: corpusDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 1. Build real multi-format local corpus (3 PDF vendor quotes, 1 OCR receipt PNG, 12 Markdown/Swift/CSV files)
        try makePDF(pages: [
            ["Acme Cloud Infrastructure — Q4 Enterprise Quote", "Prepared for Engineering Ops"],
            ["Annual Enterprise Tier: $18,400 USD per year.", "Billing Terms: Net-30 with 99.95% SLA and 30-day notice for cancellation."]
        ]).write(to: corpusDir.appendingPathComponent("acme-cloud-quote.pdf"))

        try makePDF(pages: [
            ["Northstar Compute — Annual Vendor Proposal", "Enterprise Dedicated Cluster"],
            ["Total Annual Subscription: $14,900 USD per year.", "Payment Terms: Net-30, 99.99% SLA, 15-day notice renewal opt-out."]
        ]).write(to: corpusDir.appendingPathComponent("northstar-quote.pdf"))

        try makePDF(pages: [
            ["Velox Hosting — Multi-Region Enterprise Quote"],
            ["Annual Contract Value: $22,800 USD per year.", "Terms: Net-60, 99.9% SLA, 60-day notice auto-renewal."]
        ]).write(to: corpusDir.appendingPathComponent("velox-quote.pdf"))

        try writeSyntheticReceiptPNG(lines: [
            "Kestrel DevOps Annual Quote",
            "Total Price $16200 USD Net-30",
            "99.95% SLA guaranteed"
        ], to: corpusDir.appendingPathComponent("kestrel-quote-scan.png"))

        for i in 0..<12 {
            let md = """
            # Architecture Note #\(i)
            SQLite WAL mode paired with FTS5 porter unicode61 keeps local document search under 15ms.
            Vendor comparison note: check annual contract renewal notice windows and Net-30 payment clauses.
            """
            try md.write(to: corpusDir.appendingPathComponent("note-\(i).md"), atomically: true, encoding: .utf8)
        }

        let corpusStore = try VaultStore(databaseURL: root.appendingPathComponent("corpus.sqlite"))
        let watcher = FolderWatcher(store: corpusStore)

        // Initial full multi-format extraction (PDFKit + Vision OCR + Markdown)
        let firstRun = try await watcher.indexFolder(at: corpusDir)
        // Second incremental re-scan: SHA-256 skip path must skip 100% of unchanged files
        let secondRun = try await watcher.indexFolder(at: corpusDir)
        let speedup = firstRun.durationMs / max(secondRun.durationMs, 0.05)

        // Cross-document comparison query over real indexed PDFs + OCR image
        let synStart = CFAbsoluteTimeGetCurrent()
        let hits = try await corpusStore.hybridSearch(query: "compare annual vendor quote price SLA Net-30", limit: 20)
        let answer = CrossDocAnalyst.analyze(question: "Compare annual vendor quotes and find lowest price", hits: hits)
        let synMs = (CFAbsoluteTimeGetCurrent() - synStart) * 1000.0

        let pdfOK = answer.comparisonRows.contains(where: { $0.fileName == "northstar-quote.pdf" && $0.locationLabel == "p. 2" })
        let ocrOK = hits.contains(where: { $0.chunk.kind == .imageOCR })
        let lowestOK = answer.comparisonRows.first(where: \.isHighlightedBest)?.fileName == "northstar-quote.pdf"

        // 2. Hybrid SQLite FTS5 + Accelerate vDSP 128-d Vector Scaling (1K -> 25K chunks)
        let scaleStore = try VaultStore(databaseURL: root.appendingPathComponent("scale.sqlite"))
        let templates: [(DocumentKind, String, String, String)] = [
            (.pdf, "vendor-quote.pdf", "p. 2", "Annual enterprise cloud quote $14,900 USD Net-30 billing 99.99% SLA with 15-day notice period."),
            (.pdf, "msa-contract.pdf", "p. 7", "Master services agreement data residency zero cloud upload indemnity cap and renewal opt-out notice."),
            (.code, "VaultStore.swift", "L40–L88", "SQLite WAL checkpoint PRAGMA synchronous NORMAL paired with FTS5 porter unicode61 and vDSP cosine dot product."),
            (.markdown, "q4-roadmap.md", "L1–L32", "Q4 Mac productivity suite ships offline Apple Silicon binaries with zero telemetry and instant cross-file citations."),
            (.table, "invoices-2026.csv", "L1–L25", "Acme Cloud,INV-2026-8841,$4200,Paid,Net-30; Northstar Labs,INV-2026-8842,$3600,Paid,Annual"),
            (.imageOCR, "whiteboard-scan.png", "OCR", "Architecture diagram: FSEvents watcher -> SHA-256 skip gate -> PDFKit + Vision OCR -> SQLite FTS5 + 128-d vector.")
        ]
        let queries = [
            "annual vendor quote lowest price Net-30",
            "renewal notice opt-out SLA contract",
            "sqlite WAL checkpoint FTS5 vDSP cosine",
            "FSEvents SHA-256 skip Vision OCR",
            "invoices paid Acme Cloud Northstar",
            "zero telemetry Apple Silicon citations"
        ]

        var scalePoints: [VaultScalePoint] = []
        var inserted = 0
        let now = Date()

        for target in scaleLevels.sorted() {
            let delta = target - inserted
            if delta > 0 {
                let step = 1_000
                var remaining = delta
                while remaining > 0 {
                    let n = min(step, remaining)
                    var batch: [DocumentChunk] = []
                    batch.reserveCapacity(n)
                    for k in 0..<n {
                        let idx = inserted + k
                        let tpl = templates[idx % templates.count]
                        batch.append(DocumentChunk(
                            filePath: "/Users/vault/docs/doc_\(idx / 5)/\(tpl.1)",
                            fileName: "\(idx / 5)-\(tpl.1)",
                            kind: tpl.0,
                            locationLabel: tpl.2,
                            chunkIndex: idx % 5,
                            sha256: "hash_\(idx / 5)",
                            modifiedAt: now.addingTimeInterval(-Double(idx) * 30.0),
                            text: "\(tpl.3) Ref #\(idx) clause_\(idx % 89)."
                        ))
                    }
                    _ = try await scaleStore.insertBatch(batch)
                    inserted += n
                    remaining -= n
                }
                try await scaleStore.checkpoint()
            }

            let dbBytes = await scaleStore.databaseFileSizeBytes()
            let bytesPerChunk = Double(dbBytes) / Double(max(inserted, 1))

            // Warmup
            _ = try await scaleStore.hybridSearch(query: queries[0], limit: 20)

            var times: [Double] = []
            times.reserveCapacity(64)
            for i in 0..<64 {
                let t0 = CFAbsoluteTimeGetCurrent()
                _ = try await scaleStore.hybridSearch(query: queries[i % queries.count], limit: 20)
                times.append((CFAbsoluteTimeGetCurrent() - t0) * 1000.0)
            }
            times.sort()
            let p50 = times[times.count / 2]
            let p95 = times[min(times.count - 1, Int(Double(times.count) * 0.95))]

            scalePoints.append(VaultScalePoint(
                chunkCount: inserted,
                databaseBytes: dbBytes,
                bytesPerChunk: bytesPerChunk,
                searchP50Ms: p50,
                searchP95Ms: p95
            ))
        }

        let iso = ISO8601DateFormatter().string(from: Date())
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let arch = "Apple Silicon (arm64)"
        #else
        let arch = "Intel (x86_64)"
        #endif

        return VaultBenchmarkReport(
            generatedAtISO8601: iso,
            hostArchitecture: arch,
            osVersion: osVer,
            initialCorpusIndexMs: firstRun.durationMs,
            incrementalRescanSkipMs: secondRun.durationMs,
            rescanSpeedupFactor: speedup,
            pdfMultiPageVerified: pdfOK,
            visionOCRVerified: ocrOK,
            crossDocLowestPriceVerified: lowestOK,
            crossDocSynthesisMs: synMs,
            scalePoints: scalePoints
        )
    }
}
