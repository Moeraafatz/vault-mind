@preconcurrency import CoreServices
import Foundation

public struct FolderIndexStats: Sendable {
    public let filesScanned: Int
    public let filesIndexed: Int
    public let filesSkippedUnchanged: Int
    public let chunksWritten: Int
    public let durationMs: Double

    public init(filesScanned: Int, filesIndexed: Int, filesSkippedUnchanged: Int, chunksWritten: Int, durationMs: Double) {
        self.filesScanned = filesScanned
        self.filesIndexed = filesIndexed
        self.filesSkippedUnchanged = filesSkippedUnchanged
        self.chunksWritten = chunksWritten
        self.durationMs = durationMs
    }
}

private enum FSEventsTrampoline {
    nonisolated(unsafe) static var onEvent: (@Sendable ([String]) -> Void)?
}

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    let cfArray = unsafeBitCast(eventPaths, to: NSArray.self)
    var paths: [String] = []
    paths.reserveCapacity(numEvents)
    for item in cfArray {
        if let str = item as? String {
            paths.append(str)
        }
    }
    if !paths.isEmpty {
        FSEventsTrampoline.onEvent?(paths)
    }
}

/// Native macOS `FSEvents` live directory watcher + SHA-256 incremental vault indexer.
/// Zero polling CPU burn, skips unchanged files & build artifacts (`.git`, `node_modules`, `DerivedData`).
public actor FolderWatcher {
    private let store: VaultStore
    private var config: VaultConfig
    private var streamRef: FSEventStreamRef?
    private let fsQueue = DispatchQueue(label: "com.moeraafatz.vaultmind.fsevents", qos: .utility)

    public init(store: VaultStore, config: VaultConfig = .default) {
        self.store = store
        self.config = config
    }

    public func updateConfig(_ newConfig: VaultConfig) {
        self.config = newConfig
    }

    public func startWatching(folders: [String], onIndexedChange: (@Sendable () -> Void)? = nil) {
        stopWatching()
        let existing = folders.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return }

        FSEventsTrampoline.onEvent = { [weak self] changedPaths in
            Task { [weak self] in
                guard let self else { return }
                var changedAny = false
                for p in changedPaths {
                    let url = URL(fileURLWithPath: p)
                    if await self.processSingleFileChange(url: url) {
                        changedAny = true
                    }
                }
                if changedAny {
                    onIndexedChange?()
                }
            }
        }

        let cfPaths = existing as CFArray
        var ctx = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &ctx,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.4,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, fsQueue)
        FSEventStreamStart(stream)
        self.streamRef = stream
    }

    public func stopWatching() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
        FSEventsTrampoline.onEvent = nil
    }

    @discardableResult
    public func indexFolder(at folderURL: URL) async throws -> FolderIndexStats {
        let start = CFAbsoluteTimeGetCurrent()
        let ignoredSet = Set(config.ignoredDirectoryNames)
        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var scanned = 0
        var indexed = 0
        var skipped = 0
        var chunksWritten = 0

        while let item = enumerator?.nextObject() as? URL {
            let name = item.lastPathComponent
            if ignoredSet.contains(name) {
                enumerator?.skipDescendants()
                continue
            }
            guard let kind = DocumentKind.detect(from: item), isKindEnabled(kind) else { continue }
            scanned += 1

            guard let currentHash = try? DocumentExtractor.sha256Hex(of: item) else { continue }
            if let existingHash = try? await store.storedHash(forFilePath: item.path),
               existingHash == currentHash {
                skipped += 1
                continue
            }

            if let extracted = try? DocumentExtractor.extract(url: item) {
                let chunks = DocumentExtractor.chunk(extracted)
                if !chunks.isEmpty {
                    try await store.replaceDocument(filePath: item.path, chunks: chunks)
                    indexed += 1
                    chunksWritten += chunks.count
                }
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        return FolderIndexStats(
            filesScanned: scanned,
            filesIndexed: indexed,
            filesSkippedUnchanged: skipped,
            chunksWritten: chunksWritten,
            durationMs: elapsed
        )
    }

    private func processSingleFileChange(url: URL) async -> Bool {
        let ignoredSet = Set(config.ignoredDirectoryNames)
        if url.pathComponents.contains(where: { ignoredSet.contains($0) }) {
            return false
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? await store.removeDocument(filePath: url.path)
            return true
        }
        guard let kind = DocumentKind.detect(from: url), isKindEnabled(kind) else { return false }
        guard let hash = try? DocumentExtractor.sha256Hex(of: url) else { return false }
        if let existing = try? await store.storedHash(forFilePath: url.path), existing == hash {
            return false
        }
        guard let doc = try? DocumentExtractor.extract(url: url) else { return false }
        let chunks = DocumentExtractor.chunk(doc)
        guard !chunks.isEmpty else { return false }
        try? await store.replaceDocument(filePath: url.path, chunks: chunks)
        return true
    }

    private func isKindEnabled(_ kind: DocumentKind) -> Bool {
        switch kind {
        case .pdf: return config.indexPDFs
        case .imageOCR: return config.indexImagesOCR
        case .markdown, .code, .table: return config.indexCodeAndNotes
        }
    }
}
