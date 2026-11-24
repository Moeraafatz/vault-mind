import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
@preconcurrency import PDFKit
@preconcurrency import Vision

public enum DocumentExtractor {
    public static func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return sha256Hex(of: data)
    }

    public static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func extract(url: URL) throws -> ExtractedDocument? {
        guard let kind = DocumentKind.detect(from: url) else { return nil }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let modDate = (attrs[.modificationDate] as? Date) ?? Date()

        let rawData = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = sha256Hex(of: rawData)
        var sections: [ExtractedSection] = []

        switch kind {
        case .pdf:
            if let doc = PDFDocument(data: rawData) {
                for pageIdx in 0..<doc.pageCount {
                    if let text = doc.page(at: pageIdx)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !text.isEmpty {
                        sections.append(ExtractedSection(locationLabel: "p. \(pageIdx + 1)", text: text))
                    }
                }
            }

        case .imageOCR:
            if let src = CGImageSourceCreateWithData(rawData as CFData, nil),
               let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                let text = try recognizeText(in: cg)
                if !text.isEmpty {
                    sections.append(ExtractedSection(locationLabel: "OCR", text: text))
                }
            }

        case .markdown, .code, .table:
            if let str = String(data: rawData, encoding: .utf8) ?? String(data: rawData, encoding: .isoLatin1) {
                let lines = str.components(separatedBy: .newlines)
                let blockLines = 24
                var start = 0
                while start < lines.count {
                    let end = min(lines.count, start + blockLines)
                    let block = lines[start..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !block.isEmpty {
                        sections.append(ExtractedSection(locationLabel: "L\(start + 1)–L\(end)", text: block))
                    }
                    start = end
                }
            }
        }

        guard !sections.isEmpty else { return nil }
        return ExtractedDocument(
            filePath: url.path,
            fileName: url.lastPathComponent,
            kind: kind,
            sha256: hash,
            fileSizeBytes: sizeBytes,
            modifiedAt: modDate,
            sections: sections
        )
    }

    public static func chunk(_ doc: ExtractedDocument, maxChunkChars: Int = 560, overlapChars: Int = 80) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var idx = 0

        for section in doc.sections {
            let text = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if text.count <= maxChunkChars {
                chunks.append(DocumentChunk(
                    filePath: doc.filePath,
                    fileName: doc.fileName,
                    kind: doc.kind,
                    locationLabel: section.locationLabel,
                    chunkIndex: idx,
                    sha256: doc.sha256,
                    modifiedAt: doc.modifiedAt,
                    text: text
                ))
                idx += 1
            } else {
                let chars = Array(text)
                var pos = 0
                while pos < chars.count {
                    let end = min(chars.count, pos + maxChunkChars)
                    let slice = String(chars[pos..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !slice.isEmpty {
                        chunks.append(DocumentChunk(
                            filePath: doc.filePath,
                            fileName: doc.fileName,
                            kind: doc.kind,
                            locationLabel: section.locationLabel,
                            chunkIndex: idx,
                            sha256: doc.sha256,
                            modifiedAt: doc.modifiedAt,
                            text: slice
                        ))
                        idx += 1
                    }
                    if end >= chars.count { break }
                    pos = max(pos + 1, end - overlapChars)
                }
            }
        }
        return chunks
    }

    public static func recognizeText(in image: CGImage) throws -> String {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([req])
        return (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
