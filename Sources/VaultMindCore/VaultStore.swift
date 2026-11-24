import Foundation
import SQLite3

private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum VaultStoreError: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "SQLite open failed: \(m)"
        case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
        case .executionFailed(let m): return "SQLite exec failed: \(m)"
        }
    }
}

private final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite error"
            if let db { sqlite3_close_v2(db) }
            throw VaultStoreError.openFailed(msg)
        }
        guard let opened = db else { throw VaultStoreError.openFailed("nil db handle") }
        self.pointer = opened
    }

    deinit {
        sqlite3_close_v2(pointer)
    }
}

public actor VaultStore {
    public let databaseURL: URL
    private let handle: SQLiteHandle

    public static func defaultDatabaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("VaultMind", isDirectory: true).appendingPathComponent("vault.sqlite")
    }

    public init(databaseURL: URL = VaultStore.defaultDatabaseURL()) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.handle = try SQLiteHandle(path: databaseURL.path)
        try Self.bootstrap(db: handle.pointer)
    }

    private static func bootstrap(db: OpaquePointer) throws {
        let sql = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA temp_store = MEMORY;
        PRAGMA cache_size = -16000;

        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            kind TEXT NOT NULL,
            location_label TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            sha256 TEXT NOT NULL,
            modified_at REAL NOT NULL,
            text TEXT NOT NULL,
            embedding BLOB NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_chunks_file_path ON chunks(file_path);
        CREATE INDEX IF NOT EXISTS idx_chunks_kind ON chunks(kind);
        CREATE INDEX IF NOT EXISTS idx_chunks_modified ON chunks(modified_at DESC);

        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
            file_name,
            location_label,
            text,
            content='chunks',
            content_rowid='id',
            tokenize='porter unicode61'
        );

        CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
            INSERT INTO chunks_fts(rowid, file_name, location_label, text)
            VALUES (new.id, new.file_name, new.location_label, new.text);
        END;

        CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
            INSERT INTO chunks_fts(chunks_fts, rowid, file_name, location_label, text)
            VALUES ('delete', old.id, old.file_name, old.location_label, old.text);
        END;
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "schema init failed"
            sqlite3_free(errMsg)
            throw VaultStoreError.executionFailed(msg)
        }
    }

    public func storedHash(forFilePath path: String) throws -> String? {
        let sql = "SELECT sha256 FROM chunks WHERE file_path = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, path)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return columnString(stmt, 0)
    }

    public func replaceDocument(filePath: String, chunks: [DocumentChunk]) throws {
        try exec("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try deleteChunks(forFilePath: filePath)
            for chunk in chunks {
                let emb = VectorIndex.encode(VectorIndex.embed("\(chunk.fileName) \(chunk.text)"))
                try insertChunk(chunk, embeddingData: emb)
            }
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    @discardableResult
    public func insertBatch(_ chunks: [DocumentChunk]) throws -> Int {
        guard !chunks.isEmpty else { return 0 }
        try exec("BEGIN IMMEDIATE TRANSACTION;")
        do {
            for chunk in chunks {
                let emb = VectorIndex.encode(VectorIndex.embed("\(chunk.fileName) \(chunk.text)"))
                try insertChunk(chunk, embeddingData: emb)
            }
            try exec("COMMIT;")
            return chunks.count
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    public func removeDocument(filePath: String) throws {
        try deleteChunks(forFilePath: filePath)
    }

    public func hybridSearch(
        query: String,
        kindFilter: DocumentKind? = nil,
        limit: Int = 20
    ) throws -> [VaultSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokens = extractTokens(from: trimmed)
        let queryVec = VectorIndex.embed(trimmed)
        var candidates: [Int64: (chunk: DocumentChunk, lexical: Double, semantic: Double)] = [:]

        // Stage 1: FTS5 lexical BM25 retrieval (strict AND -> relaxed OR fallback)
        if !tokens.isEmpty {
            let andExpr = tokens.map { "\"\($0)\"*" }.joined(separator: " ")
            var ftsHits = try runFTS(matchExpr: andExpr, kindFilter: kindFilter, limit: 60)
            if ftsHits.count < 6 && tokens.count > 1 {
                let orExpr = tokens.map { "\"\($0)\"*" }.joined(separator: " OR ")
                let extra = try runFTS(matchExpr: orExpr, kindFilter: kindFilter, limit: 60)
                var seen = Set(ftsHits.map(\.chunk.id))
                for item in extra where seen.insert(item.chunk.id).inserted {
                    ftsHits.append(item)
                }
            }
            for item in ftsHits {
                let sem = Double(VectorIndex.cosineSimilarity(queryVec, item.embedding))
                candidates[item.chunk.id] = (item.chunk, item.lexical, sem)
            }
        }

        // Stage 2: vDSP semantic vector scan over recent chunks to catch conceptual matches
        let recent = try fetchRecentEmbeddings(kindFilter: kindFilter, limit: 500)
        var semTop: [(id: Int64, score: Double)] = []
        semTop.reserveCapacity(24)
        for row in recent where candidates[row.id] == nil {
            let sim = Double(VectorIndex.cosineSimilarity(queryVec, row.embedding))
            if sim >= 0.16 {
                semTop.append((row.id, sim))
            }
        }
        semTop.sort { $0.score > $1.score }
        for m in semTop.prefix(20) {
            if let chunk = try fetchChunk(id: m.id) {
                candidates[chunk.id] = (chunk, 0.0, m.score)
            }
        }

        // Stage 3: Weighted hybrid rank fusion
        let hits: [VaultSearchHit] = candidates.values.map { item in
            let combined = (0.60 * item.lexical) + (0.40 * item.semantic)
            let snippet = makeSnippet(from: item.chunk.text, tokens: tokens)
            return VaultSearchHit(
                chunk: item.chunk,
                snippet: snippet,
                lexicalScore: item.lexical,
                semanticScore: item.semantic,
                combinedScore: combined
            )
        }
        .sorted { $0.combinedScore > $1.combinedScore }

        return Array(hits.prefix(limit))
    }

    public func kindBreakdown() throws -> [KindBreakdownBucket] {
        let sql = """
        SELECT kind, COUNT(DISTINCT file_path) AS files, COUNT(*) AS chunks
        FROM chunks
        GROUP BY kind
        ORDER BY chunks DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        var out: [KindBreakdownBucket] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let kind = DocumentKind(rawValue: columnString(stmt, 0)) {
                out.append(KindBreakdownBucket(
                    kind: kind,
                    fileCount: Int(sqlite3_column_int64(stmt, 1)),
                    chunkCount: Int(sqlite3_column_int64(stmt, 2))
                ))
            }
        }
        return out
    }

    public func totals() throws -> (files: Int, chunks: Int) {
        let sql = "SELECT COUNT(DISTINCT file_path), COUNT(*) FROM chunks;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return (0, 0) }
        return (Int(sqlite3_column_int64(stmt, 0)), Int(sqlite3_column_int64(stmt, 1)))
    }

    public func checkpoint() throws {
        try exec("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    public func wipeAll() throws {
        try exec("DELETE FROM chunks; VACUUM;")
    }

    public func databaseFileSizeBytes() -> Int64 {
        let paths = [databaseURL.path, databaseURL.path + "-wal", databaseURL.path + "-shm"]
        var total: Int64 = 0
        for p in paths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
               let sz = attrs[.size] as? NSNumber {
                total += sz.int64Value
            }
        }
        return total
    }

    // MARK: - Private SQLite Helpers

    private func deleteChunks(forFilePath path: String) throws {
        let sql = "DELETE FROM chunks WHERE file_path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, path)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VaultStoreError.executionFailed(lastError())
        }
    }

    private func insertChunk(_ chunk: DocumentChunk, embeddingData: Data) throws {
        let sql = """
        INSERT INTO chunks (file_path, file_name, kind, location_label, chunk_index, sha256, modified_at, text, embedding)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, chunk.filePath)
        bindText(stmt, 2, chunk.fileName)
        bindText(stmt, 3, chunk.kind.rawValue)
        bindText(stmt, 4, chunk.locationLabel)
        sqlite3_bind_int64(stmt, 5, Int64(chunk.chunkIndex))
        bindText(stmt, 6, chunk.sha256)
        sqlite3_bind_double(stmt, 7, chunk.modifiedAt.timeIntervalSince1970)
        bindText(stmt, 8, chunk.text)
        _ = embeddingData.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 9, raw.baseAddress, Int32(embeddingData.count), SQLITE_TRANSIENT_DESTRUCTOR)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VaultStoreError.executionFailed(lastError())
        }
    }

    private func runFTS(
        matchExpr: String,
        kindFilter: DocumentKind?,
        limit: Int
    ) throws -> [(chunk: DocumentChunk, lexical: Double, embedding: [Float])] {
        var clauses = ["chunks_fts MATCH ?"]
        if kindFilter != nil { clauses.append("c.kind = ?") }
        let sql = """
        SELECT c.id, c.file_path, c.file_name, c.kind, c.location_label, c.chunk_index, c.sha256, c.modified_at, c.text, c.embedding,
               bm25(chunks_fts, 2.5, 1.0, 1.0) AS rank_score
        FROM chunks_fts
        JOIN chunks c ON c.id = chunks_fts.rowid
        WHERE \(clauses.joined(separator: " AND "))
        ORDER BY rank_score ASC
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        var idx: Int32 = 1
        bindText(stmt, idx, matchExpr); idx += 1
        if let kindFilter { bindText(stmt, idx, kindFilter.rawValue); idx += 1 }
        sqlite3_bind_int64(stmt, idx, Int64(limit))

        var out: [(DocumentChunk, Double, [Float])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chunk = readChunk(stmt)
            let emb = readEmbedding(stmt, col: 9)
            let bm25 = sqlite3_column_double(stmt, 10)
            let norm = max(0.05, min(1.0, 1.0 - (1.0 / (1.0 + abs(bm25) * 0.45))))
            out.append((chunk, norm, emb))
        }
        return out
    }

    private func fetchRecentEmbeddings(kindFilter: DocumentKind?, limit: Int) throws -> [(id: Int64, embedding: [Float])] {
        let whereSQL = kindFilter == nil ? "" : "WHERE kind = ?"
        let sql = "SELECT id, embedding FROM chunks \(whereSQL) ORDER BY modified_at DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        if let kindFilter { bindText(stmt, idx, kindFilter.rawValue); idx += 1 }
        sqlite3_bind_int64(stmt, idx, Int64(limit))

        var list: [(Int64, [Float])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append((sqlite3_column_int64(stmt, 0), readEmbedding(stmt, col: 1)))
        }
        return list
    }

    private func fetchChunk(id: Int64) throws -> DocumentChunk? {
        let sql = "SELECT id, file_path, file_name, kind, location_label, chunk_index, sha256, modified_at, text FROM chunks WHERE id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw VaultStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return readChunk(stmt)
    }

    private func readChunk(_ stmt: OpaquePointer) -> DocumentChunk {
        DocumentChunk(
            id: sqlite3_column_int64(stmt, 0),
            filePath: columnString(stmt, 1),
            fileName: columnString(stmt, 2),
            kind: DocumentKind(rawValue: columnString(stmt, 3)) ?? .markdown,
            locationLabel: columnString(stmt, 4),
            chunkIndex: Int(sqlite3_column_int64(stmt, 5)),
            sha256: columnString(stmt, 6),
            modifiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)),
            text: columnString(stmt, 8)
        )
    }

    private func readEmbedding(_ stmt: OpaquePointer, col: Int32) -> [Float] {
        guard let bytes = sqlite3_column_blob(stmt, col) else {
            return [Float](repeating: 0, count: VectorIndex.dimensions)
        }
        let len = Int(sqlite3_column_bytes(stmt, col))
        return VectorIndex.decode(Data(bytes: bytes, count: len))
    }

    private func extractTokens(from query: String) -> [String] {
        query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "_" }
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    private func makeSnippet(from text: String, tokens: [String], maxLen: Int = 185) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " · ")
        guard flat.count > maxLen else { return flat }
        let lower = flat.lowercased()
        for tok in tokens {
            if let r = lower.range(of: tok) {
                let idx = flat.distance(from: flat.startIndex, to: r.lowerBound)
                let startOff = max(0, idx - 44)
                let start = flat.index(flat.startIndex, offsetBy: startOff)
                let endOff = min(flat.count, startOff + maxLen)
                let end = flat.index(flat.startIndex, offsetBy: endOff)
                return (startOff > 0 ? "…" : "") + String(flat[start..<end]) + (endOff < flat.count ? "…" : "")
            }
        }
        return String(flat.prefix(maxLen)) + "…"
    }

    private func bindText(_ stmt: OpaquePointer, _ idx: Int32, _ val: String) {
        sqlite3_bind_text(stmt, idx, val, -1, SQLITE_TRANSIENT_DESTRUCTOR)
    }

    private func columnString(_ stmt: OpaquePointer, _ idx: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, idx) else { return "" }
        return String(cString: c)
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle.pointer, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "sqlite exec failed"
            sqlite3_free(errMsg)
            throw VaultStoreError.executionFailed(msg)
        }
    }

    private func lastError() -> String {
        String(cString: sqlite3_errmsg(handle.pointer))
    }
}
