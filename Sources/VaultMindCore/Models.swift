import Foundation

public enum DocumentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case pdf = "PDF"
    case imageOCR = "OCR"
    case markdown = "Notes"
    case code = "Code"
    case table = "CSV"

    public var id: String { rawValue }

    public static func detect(from url: URL) -> DocumentKind? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "heic", "tiff", "webp":
            return .imageOCR
        case "md", "markdown", "txt", "rtf", "org":
            return .markdown
        case "swift", "py", "ts", "tsx", "js", "jsx", "rs", "go", "sql", "json", "yaml", "yml", "toml", "sh":
            return .code
        case "csv", "tsv":
            return .table
        default:
            return nil
        }
    }
}

public struct ExtractedSection: Codable, Hashable, Sendable {
    public let locationLabel: String
    public let text: String

    public init(locationLabel: String, text: String) {
        self.locationLabel = locationLabel
        self.text = text
    }
}

public struct ExtractedDocument: Sendable {
    public let filePath: String
    public let fileName: String
    public let kind: DocumentKind
    public let sha256: String
    public let fileSizeBytes: Int64
    public let modifiedAt: Date
    public let sections: [ExtractedSection]

    public init(
        filePath: String,
        fileName: String,
        kind: DocumentKind,
        sha256: String,
        fileSizeBytes: Int64,
        modifiedAt: Date,
        sections: [ExtractedSection]
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.kind = kind
        self.sha256 = sha256
        self.fileSizeBytes = fileSizeBytes
        self.modifiedAt = modifiedAt
        self.sections = sections
    }
}

public struct DocumentChunk: Identifiable, Hashable, Codable, Sendable {
    public let id: Int64
    public let filePath: String
    public let fileName: String
    public let kind: DocumentKind
    public let locationLabel: String
    public let chunkIndex: Int
    public let sha256: String
    public let modifiedAt: Date
    public let text: String

    public init(
        id: Int64 = 0,
        filePath: String,
        fileName: String,
        kind: DocumentKind,
        locationLabel: String,
        chunkIndex: Int,
        sha256: String,
        modifiedAt: Date = Date(),
        text: String
    ) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.kind = kind
        self.locationLabel = locationLabel
        self.chunkIndex = chunkIndex
        self.sha256 = sha256
        self.modifiedAt = modifiedAt
        self.text = text
    }

    public var citationTag: String {
        "\(fileName) · \(locationLabel)"
    }
}

public struct VaultSearchHit: Identifiable, Hashable, Sendable {
    public let chunk: DocumentChunk
    public let snippet: String
    public let lexicalScore: Double
    public let semanticScore: Double
    public let combinedScore: Double

    public var id: Int64 { chunk.id }

    public init(
        chunk: DocumentChunk,
        snippet: String,
        lexicalScore: Double,
        semanticScore: Double,
        combinedScore: Double
    ) {
        self.chunk = chunk
        self.snippet = snippet
        self.lexicalScore = lexicalScore
        self.semanticScore = semanticScore
        self.combinedScore = combinedScore
    }
}

public struct ComparisonRow: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let citationIndex: Int
    public let fileName: String
    public let filePath: String
    public let locationLabel: String
    public let kind: DocumentKind
    public let extractedValueLabel: String
    public let numericAmountUSD: Double?
    public let termsSummary: String
    public let keyClause: String
    public let relevancePercent: Int
    public let isHighlightedBest: Bool

    public init(
        id: UUID = UUID(),
        citationIndex: Int,
        fileName: String,
        filePath: String,
        locationLabel: String,
        kind: DocumentKind,
        extractedValueLabel: String,
        numericAmountUSD: Double? = nil,
        termsSummary: String,
        keyClause: String,
        relevancePercent: Int,
        isHighlightedBest: Bool = false
    ) {
        self.id = id
        self.citationIndex = citationIndex
        self.fileName = fileName
        self.filePath = filePath
        self.locationLabel = locationLabel
        self.kind = kind
        self.extractedValueLabel = extractedValueLabel
        self.numericAmountUSD = numericAmountUSD
        self.termsSummary = termsSummary
        self.keyClause = keyClause
        self.relevancePercent = relevancePercent
        self.isHighlightedBest = isHighlightedBest
    }
}

public struct AnalystAnswer: Sendable {
    public let question: String
    public let executiveSummary: String
    public let citations: [VaultSearchHit]
    public let comparisonRows: [ComparisonRow]
    public let markdownReport: String
    public let csvComparison: String
    public let durationMs: Double

    public init(
        question: String,
        executiveSummary: String,
        citations: [VaultSearchHit],
        comparisonRows: [ComparisonRow],
        markdownReport: String,
        csvComparison: String,
        durationMs: Double
    ) {
        self.question = question
        self.executiveSummary = executiveSummary
        self.citations = citations
        self.comparisonRows = comparisonRows
        self.markdownReport = markdownReport
        self.csvComparison = csvComparison
        self.durationMs = durationMs
    }
}

public struct WatchedFolderInfo: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let path: String
    public var displayName: String
    public var indexedFiles: Int
    public var indexedChunks: Int
    public var isWatching: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        displayName: String,
        indexedFiles: Int = 0,
        indexedChunks: Int = 0,
        isWatching: Bool = true
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.indexedFiles = indexedFiles
        self.indexedChunks = indexedChunks
        self.isWatching = isWatching
    }
}

public struct KindBreakdownBucket: Identifiable, Hashable, Sendable {
    public let kind: DocumentKind
    public let fileCount: Int
    public let chunkCount: Int

    public var id: String { kind.rawValue }

    public init(kind: DocumentKind, fileCount: Int, chunkCount: Int) {
        self.kind = kind
        self.fileCount = fileCount
        self.chunkCount = chunkCount
    }
}

public struct VaultConfig: Codable, Sendable, Equatable {
    public var indexPDFs: Bool
    public var indexImagesOCR: Bool
    public var indexCodeAndNotes: Bool
    public var enableLoopbackOllama: Bool
    public var ollamaModel: String
    public var ignoredDirectoryNames: [String]

    public static let defaultIgnoredDirectories: [String] = [
        ".git", "node_modules", ".build", "DerivedData", ".Trash", "Pods", "__pycache__", ".venv"
    ]

    public static let `default` = VaultConfig(
        indexPDFs: true,
        indexImagesOCR: true,
        indexCodeAndNotes: true,
        enableLoopbackOllama: false,
        ollamaModel: "qwen2.5:7b-instruct",
        ignoredDirectoryNames: defaultIgnoredDirectories
    )

    public init(
        indexPDFs: Bool = true,
        indexImagesOCR: Bool = true,
        indexCodeAndNotes: Bool = true,
        enableLoopbackOllama: Bool = false,
        ollamaModel: String = "qwen2.5:7b-instruct",
        ignoredDirectoryNames: [String] = defaultIgnoredDirectories
    ) {
        self.indexPDFs = indexPDFs
        self.indexImagesOCR = indexImagesOCR
        self.indexCodeAndNotes = indexCodeAndNotes
        self.enableLoopbackOllama = enableLoopbackOllama
        self.ollamaModel = ollamaModel
        self.ignoredDirectoryNames = ignoredDirectoryNames
    }
}
