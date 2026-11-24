import Foundation
import VaultMindCore

@main
struct VaultMindToolsMain {
    static func main() async {
        do {
            let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let docsDir = root.appendingPathComponent("docs", isDirectory: true)
            let screenshotsDir = docsDir.appendingPathComponent("screenshots", isDirectory: true)
            let graphsDir = docsDir.appendingPathComponent("graphs", isDirectory: true)
            let assetsDir = docsDir.appendingPathComponent("assets", isDirectory: true)
            let iconsetDir = root.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)

            print("[VaultMindTools] Generating macOS AppIcon set...")
            try VaultIconGenerator.generateIconSet(
                iconsetURL: iconsetDir,
                docsIconURL: assetsDir.appendingPathComponent("icon.png")
            )

            print("[VaultMindTools] Rendering SwiftUI Retina screenshots...")
            try await MainActor.run {
                try VaultScreenshotRenderer.renderAll(outputDir: screenshotsDir)
            }

            print("[VaultMindTools] Running Apple Silicon Local RAG & Multi-Format Analyst benchmarks...")
            let report = try await VaultBenchmarkRunner.runFullSuite(scaleLevels: [1_000, 5_000, 10_000, 25_000])

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(report)
            try jsonData.write(to: docsDir.appendingPathComponent("benchmarks.json"))

            print("[VaultMindTools] Rendering benchmark graphs & architecture SVG...")
            try VaultGraphRenderer.renderAll(report: report, outputDir: graphsDir)

            let summary = makeBenchmarkMarkdown(report: report)
            try summary.write(to: docsDir.appendingPathComponent("benchmark-summary.md"), atomically: true, encoding: .utf8)

            print("[VaultMindTools] Complete!")
            print(summary)
        } catch {
            fputs("[VaultMindTools] ERROR: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func makeBenchmarkMarkdown(report: VaultBenchmarkReport) -> String {
        var rows = ""
        for pt in report.scalePoints {
            let mb = Double(pt.databaseBytes) / (1024.0 * 1024.0)
            rows += String(
                format: "| %d chunks | %.2f MB | %.0f B | **%.2f ms** | **%.2f ms** |\n",
                pt.chunkCount, mb, pt.bytesPerChunk, pt.searchP50Ms, pt.searchP95Ms
            )
        }

        return """
        ### Measured Benchmarks (\(report.hostArchitecture) · \(report.osVersion))

        - **SHA-256 Incremental Re-Scan:** `\(String(format: "%.2f ms", report.incrementalRescanSkipMs))` vs `\(String(format: "%.1f ms", report.initialCorpusIndexMs))` initial full extract (**`\(String(format: "%.0fx", report.rescanSpeedupFactor))` speedup**)
        - **Cross-Document Analyst Synthesis:** **`\(String(format: "%.2f ms", report.crossDocSynthesisMs))`** · Multi-page `PDFKit` page citation (**\(report.pdfMultiPageVerified ? "PASS" : "FAIL")**) · `Vision` OCR receipt (**\(report.visionOCRVerified ? "PASS" : "FAIL")**) · Auto lowest-quote match (**\(report.crossDocLowestPriceVerified ? "PASS" : "FAIL")**)

        | Indexed Chunks | SQLite WAL Size | Bytes / Chunk | Hybrid Search p50 | Hybrid Search p95 |
        | ---: | ---: | ---: | ---: | ---: |
        \(rows)
        """
    }
}
