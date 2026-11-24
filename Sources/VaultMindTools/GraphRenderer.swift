import CoreGraphics
import CoreText
import Foundation
import VaultMindCore

enum VaultGraphRenderer {
    static func renderAll(report: VaultBenchmarkReport, outputDir: URL) throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try VaultIconGenerator.writePNG(
            renderHybridLatencyChart(report: report),
            to: outputDir.appendingPathComponent("hybrid-search-latency.png")
        )
        try VaultIconGenerator.writePNG(
            renderIngestionSpeedChart(report: report),
            to: outputDir.appendingPathComponent("ingestion-speed.png")
        )
        try VaultIconGenerator.writePNG(
            renderStorageFootprintChart(report: report),
            to: outputDir.appendingPathComponent("storage-footprint.png")
        )
        try makeArchitectureSVG(report: report).write(
            to: outputDir.appendingPathComponent("architecture.svg"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Chart 1: Hybrid FTS5 + vDSP 128-d Vector Search Latency (1K -> 25K Chunks)

    private static func renderHybridLatencyChart(report: VaultBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 660
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "MEASURED ON \(report.hostArchitecture.uppercased())",
            title: "Hybrid Local RAG Search Latency (FTS5 BM25 + Accelerate vDSP Vectors)",
            subtitle: "64 timed cross-file queries across 1,000 to 25,000 indexed document chunks"
        )

        let plot = CGRect(x: 110, y: 110, width: 1050, height: 390)
        let maxLat = max(15.0, (report.scalePoints.map(\.searchP95Ms).max() ?? 10.0) * 1.45)
        let yMax = ceil(maxLat / 5.0) * 5.0

        for i in 0...5 {
            let frac = CGFloat(i) / 5.0
            let y = plot.minY + frac * plot.height
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: i == 0 ? 0.22 : 0.08))
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: plot.minX, y: y))
            ctx.addLine(to: CGPoint(x: plot.maxX, y: y))
            ctx.strokePath()
            drawText(ctx, String(format: "%.0f ms", (Double(i) / 5.0) * yMax), x: 34, y: y - 6, size: 15, weight: .regular, r: 0.65, g: 0.70, b: 0.78)
        }

        let count = max(report.scalePoints.count, 1)
        let groupW = plot.width / CGFloat(count)
        let barW: CGFloat = min(68, groupW * 0.28)
        let gap: CGFloat = 14

        for (idx, pt) in report.scalePoints.enumerated() {
            let cx = plot.minX + groupW * (CGFloat(idx) + 0.5)
            let p50H = max(8, CGFloat(pt.searchP50Ms / yMax) * plot.height)
            let p95H = max(8, CGFloat(pt.searchP95Ms / yMax) * plot.height)

            let p50Rect = CGRect(x: cx - barW - gap / 2, y: plot.minY, width: barW, height: p50H)
            let p95Rect = CGRect(x: cx + gap / 2, y: plot.minY, width: barW, height: p95H)

            fillRoundedRect(ctx, rect: p50Rect, radius: 8, r: 0.40, g: 0.83, b: 0.81, a: 0.94)
            fillRoundedRect(ctx, rect: p95Rect, radius: 8, r: 0.44, g: 0.43, b: 0.96, a: 0.94)

            drawText(ctx, String(format: "%.1fms", pt.searchP50Ms), x: p50Rect.minX + 6, y: p50Rect.maxY + 10, size: 15, weight: .bold, r: 0.40, g: 0.83, b: 0.81)
            drawText(ctx, String(format: "%.1fms", pt.searchP95Ms), x: p95Rect.minX + 6, y: p95Rect.maxY + 10, size: 15, weight: .bold, r: 0.55, g: 0.56, b: 1.0)

            drawText(ctx, "\(pt.chunkCount / 1_000)K chunks", x: cx - 44, y: plot.minY - 34, size: 16, weight: .bold, r: 0.92, g: 0.95, b: 0.98)
            let dbMB = Double(pt.databaseBytes) / (1024.0 * 1024.0)
            drawText(ctx, String(format: "DB: %.1f MB", dbMB), x: cx - 42, y: plot.minY - 56, size: 13, weight: .regular, r: 0.56, g: 0.62, b: 0.72)
        }

        fillRoundedRect(ctx, rect: CGRect(x: 840, y: 556, width: 18, height: 18), radius: 5, r: 0.40, g: 0.83, b: 0.81, a: 0.95)
        drawText(ctx, "p50 Median", x: 868, y: 558, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)
        fillRoundedRect(ctx, rect: CGRect(x: 995, y: 556, width: 18, height: 18), radius: 5, r: 0.44, g: 0.43, b: 0.96, a: 0.95)
        drawText(ctx, "p95 Tail", x: 1023, y: 558, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)

        return ctx.makeImage()!
    }

    // MARK: - Chart 2: Incremental SHA-256 Re-Scan Speedup & Analyst Verification

    private static func renderIngestionSpeedChart(report: VaultBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 560
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "REAL MULTI-FORMAT VAULT INGESTION",
            title: "SHA-256 Incremental Re-Scan Speedup & Cross-Doc Analyst Checks",
            subtitle: "Multi-page PDFKit quotes + Apple Vision OCR receipt PNG + 12 Markdown files"
        )

        let left = CGRect(x: 52, y: 72, width: 540, height: 345)
        fillRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "Incremental Re-Scan Speedup", x: left.minX + 24, y: left.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)
        drawText(ctx, String(format: "%.0fx", report.rescanSpeedupFactor), x: left.minX + 24, y: left.maxY - 120, size: 58, weight: .bold, r: 0.19, g: 0.82, b: 0.35)
        drawText(ctx, "faster on unchanged corpus via CryptoKit SHA-256 skip gate", x: left.minX + 24, y: left.maxY - 150, size: 15, weight: .regular, r: 0.68, g: 0.74, b: 0.82)

        let barW = left.width - 48
        drawText(ctx, String(format: "Initial Full Extract (PDFKit + Vision OCR + MD): %.1f ms", report.initialCorpusIndexMs), x: left.minX + 24, y: left.minY + 122, size: 13.5, weight: .bold, r: 0.55, g: 0.56, b: 1.0)
        fillRoundedRect(ctx, rect: CGRect(x: left.minX + 24, y: left.minY + 98, width: barW, height: 14), radius: 7, r: 0.44, g: 0.43, b: 0.96, a: 0.90)

        drawText(ctx, String(format: "Incremental SHA-256 Skip Re-Scan: %.2f ms", report.incrementalRescanSkipMs), x: left.minX + 24, y: left.minY + 56, size: 13.5, weight: .bold, r: 0.19, g: 0.82, b: 0.35)
        let skipFrac = max(0.03, min(1.0, report.incrementalRescanSkipMs / max(report.initialCorpusIndexMs, 1.0)))
        fillRoundedRect(ctx, rect: CGRect(x: left.minX + 24, y: left.minY + 32, width: barW, height: 14), radius: 7, r: 1, g: 1, b: 1, a: 0.08)
        fillRoundedRect(ctx, rect: CGRect(x: left.minX + 24, y: left.minY + 32, width: barW * CGFloat(skipFrac), height: 14), radius: 7, r: 0.19, g: 0.82, b: 0.35, a: 0.95)

        let right = CGRect(x: 620, y: 72, width: 568, height: 345)
        fillRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "Live Cross-File Analyst Verification", x: right.minX + 24, y: right.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)

        let checks: [(String, String, Bool)] = [
            ("Multi-Page PDFKit Citation (p. 2)", report.pdfMultiPageVerified ? "VERIFIED" : "FAIL", report.pdfMultiPageVerified),
            ("Apple Vision OCR Receipt Ingestion", report.visionOCRVerified ? "VERIFIED" : "FAIL", report.visionOCRVerified),
            ("Auto-Lowest Vendor Quote Detection", report.crossDocLowestPriceVerified ? "VERIFIED" : "FAIL", report.crossDocLowestPriceVerified),
            ("Cross-File Retrieval + Matrix + CSV", String(format: "%.2f ms", report.crossDocSynthesisMs), true)
        ]

        for (idx, item) in checks.enumerated() {
            let y = right.maxY - 108 - CGFloat(idx) * 64
            let rowRect = CGRect(x: right.minX + 22, y: y - 10, width: right.width - 44, height: 48)
            fillRoundedRect(ctx, rect: rowRect, radius: 10, r: 1, g: 1, b: 1, a: 0.05)
            drawText(ctx, item.0, x: rowRect.minX + 16, y: rowRect.minY + 16, size: 15, weight: .bold, r: 0.92, g: 0.95, b: 0.99)
            drawText(ctx, item.1, x: rowRect.maxX - 108, y: rowRect.minY + 16, size: 14.5, weight: .bold, r: item.2 ? 0.19 : 1.0, g: item.2 ? 0.82 : 0.27, b: item.2 ? 0.35 : 0.23)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 3: SQLite Vault Storage Footprint Scaling (1K -> 25K Chunks)

    private static func renderStorageFootprintChart(report: VaultBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 560
        let ctx = makeCanvas(width: width, height: height)

        let avgBytes = report.scalePoints.last?.bytesPerChunk ?? 1200.0
        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: String(format: "COMPACT %.0f BYTES / INDEXED CHUNK", avgBytes),
            title: "Local SQLite WAL + FTS5 + 128-d Vector Storage Scaling",
            subtitle: "Zero duplicate file copies stored — single inspectable SQLite file under ~/Library/Application Support/VaultMind"
        )

        let maxMB = max(report.scalePoints.map { Double($0.databaseBytes) / (1024.0 * 1024.0) }.max() ?? 20.0, 5.0)
        let barLeft: CGFloat = 340
        let barMaxW: CGFloat = 580
        let startY: CGFloat = 355
        let stepY: CGFloat = 86

        for (i, pt) in report.scalePoints.prefix(4).enumerated() {
            let y = startY - CGFloat(i) * stepY
            let mb = Double(pt.databaseBytes) / (1024.0 * 1024.0)
            drawText(ctx, "\(pt.chunkCount / 1_000)K Indexed Chunks", x: 52, y: y + 18, size: 18, weight: .bold, r: 0.94, g: 0.96, b: 0.99)
            drawText(ctx, String(format: "%.0f B/chunk · p50 %.1f ms", pt.bytesPerChunk, pt.searchP50Ms), x: 52, y: y - 4, size: 13.5, weight: .regular, r: 0.60, g: 0.66, b: 0.75)

            fillRoundedRect(ctx, rect: CGRect(x: barLeft, y: y + 4, width: barMaxW, height: 28), radius: 9, r: 1, g: 1, b: 1, a: 0.07)
            let frac = max(0.04, min(1.0, mb / maxMB))
            fillRoundedRect(ctx, rect: CGRect(x: barLeft, y: y + 4, width: barMaxW * CGFloat(frac), height: 28), radius: 9, r: 0.40, g: 0.83, b: 0.81, a: 0.92)
            drawText(ctx, String(format: "%.2f MB", mb), x: barLeft + barMaxW + 20, y: y + 11, size: 17, weight: .bold, r: 0.40, g: 0.83, b: 0.81)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 4: Crisp Vector Architecture Diagram (SVG)

    private static func makeArchitectureSVG(report: VaultBenchmarkReport) -> String {
        let p50 = String(format: "%.1f ms", report.scalePoints.last?.searchP50Ms ?? 12.0)
        let speedup = String(format: "%.0fx skip", report.rescanSpeedupFactor)
        let synMs = String(format: "%.1f ms", report.crossDocSynthesisMs)

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="390" viewBox="0 0 1200 390">
          <defs>
            <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#090B16"/>
              <stop offset="100%" stop-color="#04050B"/>
            </linearGradient>
            <linearGradient id="indigoBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#1A1A3D"/>
              <stop offset="100%" stop-color="#101026"/>
            </linearGradient>
            <linearGradient id="mintBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#102C2E"/>
              <stop offset="100%" stop-color="#091A1C"/>
            </linearGradient>
            <linearGradient id="greenBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#10291B"/>
              <stop offset="100%" stop-color="#091810"/>
            </linearGradient>
            <marker id="arrowMint" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#66D4CF"/>
            </marker>
            <marker id="arrowGreen" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#30D158"/>
            </marker>
          </defs>

          <rect width="1200" height="390" rx="20" fill="url(#bg)" stroke="#FFFFFF" stroke-opacity="0.14"/>

          <text x="40" y="48" fill="#66D4CF" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="13" font-weight="700" letter-spacing="1.4">LOCAL MULTI-FILE RAG ARCHITECTURE · ZERO CLOUD EMBEDDINGS</text>
          <text x="40" y="78" fill="#F5F8FC" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="24" font-weight="700">Vault Mind Pipeline — Live FSEvents → Hybrid SQLite → Cited Matrix</text>

          <!-- Node 1 -->
          <rect x="40" y="120" width="190" height="125" rx="14" fill="url(#indigoBox)" stroke="#5E5CE6" stroke-opacity="0.65"/>
          <text x="58" y="150" fill="#8C8AFF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">1. LIVE WATCHER</text>
          <text x="58" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">macOS FSEvents +</text>
          <text x="58" y="198" fill="#66D4CF" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">SHA-256 (\(speedup))</text>
          <text x="58" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Skips .git/node_modules</text>

          <line x1="230" y1="182" x2="262" y2="182" stroke="#66D4CF" stroke-width="2.2" marker-end="url(#arrowMint)"/>

          <!-- Node 2 -->
          <rect x="270" y="120" width="190" height="125" rx="14" fill="url(#mintBox)" stroke="#66D4CF" stroke-opacity="0.55"/>
          <text x="288" y="150" fill="#66D4CF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">2. EXTRACT &amp; CHUNK</text>
          <text x="288" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">PDFKit + Vision OCR</text>
          <text x="288" y="200" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="14" font-weight="600">+ Code/MD/CSV</text>
          <text x="288" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Preserves p. N &amp; L1–L24</text>

          <line x1="460" y1="182" x2="492" y2="182" stroke="#66D4CF" stroke-width="2.2" marker-end="url(#arrowMint)"/>

          <!-- Node 3 -->
          <rect x="500" y="120" width="195" height="125" rx="14" fill="url(#indigoBox)" stroke="#5E5CE6" stroke-opacity="0.65"/>
          <text x="518" y="150" fill="#8C8AFF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">3. HYBRID VAULT</text>
          <text x="518" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">SQLite WAL + FTS5</text>
          <text x="518" y="204" fill="#66D4CF" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">p50 \(p50) @ 25K</text>
          <text x="518" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">+ 128-d vDSP Vectors</text>

          <line x1="695" y1="182" x2="727" y2="182" stroke="#66D4CF" stroke-width="2.2" marker-end="url(#arrowMint)"/>

          <!-- Node 4 -->
          <rect x="735" y="120" width="195" height="125" rx="14" fill="url(#mintBox)" stroke="#FFD60A" stroke-opacity="0.55"/>
          <text x="753" y="150" fill="#FFD60A" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">4. ANALYST ENGINE</text>
          <text x="753" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">CrossDocAnalyst</text>
          <text x="753" y="204" fill="#FFD60A" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">~\(synMs) synthesis</text>
          <text x="753" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Prices, SLAs, Best Quote</text>

          <line x1="930" y1="182" x2="962" y2="182" stroke="#30D158" stroke-width="2.2" marker-end="url(#arrowGreen)"/>

          <!-- Node 5 -->
          <rect x="970" y="120" width="190" height="125" rx="14" fill="url(#greenBox)" stroke="#30D158" stroke-opacity="0.65"/>
          <text x="988" y="150" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">5. CITED EXPORTS</text>
          <text x="988" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">Matrix · MD · CSV</text>
          <text x="988" y="204" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">⌥⇧B Floating HUD</text>
          <text x="988" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">1-click Finder reveal</text>

          <!-- Bottom guarantee strip -->
          <rect x="40" y="286" width="1120" height="64" rx="12" fill="#FFFFFF" fill-opacity="0.04" stroke="#FFFFFF" stroke-opacity="0.1"/>
          <text x="66" y="324" fill="#66D4CF" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ EXACT PAGE &amp; LINE CITATIONS</text>
          <text x="372" y="324" fill="#FFD60A" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ AUTO COMPARISON MATRICES</text>
          <text x="670" y="324" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ ZERO CLOUD RAG FEES</text>
          <text x="955" y="324" fill="#E5ECF4" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ MIT LICENSE</text>
        </svg>
        """
    }

    // MARK: - CoreGraphics Primitives

    private enum FontWeight { case regular, bold }

    private static func makeCanvas(width: Int, height: Int) -> CGContext {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let bg = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.040, green: 0.046, blue: 0.088, alpha: 1.0),
                CGColor(red: 0.016, green: 0.020, blue: 0.042, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        return ctx
    }

    private static func drawCardFrame(_ ctx: CGContext, width: Int, height: Int, badge: String, title: String, subtitle: String) {
        let outer = CGRect(x: 16, y: 16, width: width - 32, height: height - 32)
        strokeRoundedRect(ctx, rect: outer, radius: 22, r: 1, g: 1, b: 1, a: 0.14)
        drawText(ctx, badge, x: 52, y: CGFloat(height) - 62, size: 13, weight: .bold, r: 0.40, g: 0.83, b: 0.81)
        drawText(ctx, title, x: 52, y: CGFloat(height) - 98, size: 26, weight: .bold, r: 0.96, g: 0.98, b: 1.0)
        drawText(ctx, subtitle, x: 52, y: CGFloat(height) - 126, size: 15, weight: .regular, r: 0.62, g: 0.68, b: 0.77)
    }

    private static func fillRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil)
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func strokeRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.setLineWidth(1.5)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: FontWeight, r: CGFloat, g: CGFloat, b: CGFloat) {
        let fontName = (weight == .bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString
        let font = CTFontCreateWithName(fontName, size, nil)
        let color = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }
}
