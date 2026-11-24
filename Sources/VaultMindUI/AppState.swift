import AppKit
import Foundation
import Observation
import VaultMindCore

public enum VaultTab: String, CaseIterable, Identifiable, Sendable {
    case ask = "Ask"
    case compare = "Compare"
    case folders = "Folders"
    case privacy = "Privacy"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .ask: return "brain.head.profile"
        case .compare: return "tablecells.badge.ellipsis"
        case .folders: return "folder.badge.gearshape"
        case .privacy: return "lock.shield.fill"
        }
    }

    public var shortcut: String {
        switch self {
        case .ask: return "⌘1"
        case .compare: return "⌘2"
        case .folders: return "⌘3"
        case .privacy: return "⌘4"
        }
    }
}

@MainActor
@Observable
public final class VaultAppState {
    public var selectedTab: VaultTab = .ask
    public var questionInput: String = "Compare Q4 vendor quotes and find lowest annual price"
    public var kindFilter: DocumentKind? = nil
    public var currentAnswer: AnalystAnswer?
    public var watchedFolders: [WatchedFolderInfo] = []
    public var kindBreakdown: [KindBreakdownBucket] = []
    public var totalFiles: Int = 0
    public var totalChunks: Int = 0
    public var databaseBytes: Int64 = 0
    public var isIndexing: Bool = false
    public var config: VaultConfig = .default
    public var statusToast: String? = nil
    public let isPreviewSnapshot: Bool

    private let store: VaultStore?
    private let watcher: FolderWatcher?

    public init(store: VaultStore? = nil, isPreviewSnapshot: Bool = false) {
        self.store = store
        self.isPreviewSnapshot = isPreviewSnapshot
        if let store {
            self.watcher = FolderWatcher(store: store, config: .default)
        } else {
            self.watcher = nil
        }
        self.watchedFolders = VaultSampleData.demoFolders()
    }

    public static func demo(tab: VaultTab = .ask) -> VaultAppState {
        let state = VaultAppState(store: nil, isPreviewSnapshot: true)
        state.selectedTab = tab
        state.currentAnswer = VaultSampleData.demoAnswer()
        state.watchedFolders = VaultSampleData.demoFolders()
        state.kindBreakdown = VaultSampleData.demoKindBreakdown()
        state.totalFiles = 266
        state.totalChunks = 4_352
        state.databaseBytes = 5_112_832
        return state
    }

    public func bootstrap() async {
        guard !isPreviewSnapshot else { return }
        await reloadStats()
        if let store {
            let counts = (try? await store.totals()) ?? (0, 0)
            if counts.chunks == 0 {
                currentAnswer = VaultSampleData.demoAnswer()
            } else {
                await runAnalystQuery()
            }
        }
    }

    public func runAnalystQuery() async {
        guard !isPreviewSnapshot, let store else {
            currentAnswer = VaultSampleData.demoAnswer()
            return
        }
        let q = questionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        if let hits = try? await store.hybridSearch(query: q, kindFilter: kindFilter, limit: 24) {
            currentAnswer = CrossDocAnalyst.analyze(question: q, hits: hits)
        }
    }

    public func addAndIndexFolder() {
        guard !isPreviewSnapshot else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch & Index Folder"
        if panel.runModal() == .OK, let url = panel.url {
            let folder = WatchedFolderInfo(path: url.path, displayName: url.lastPathComponent)
            if !watchedFolders.contains(where: { $0.path == url.path }) {
                watchedFolders.insert(folder, at: 0)
            }
            Task { await indexFolder(url: url) }
        }
    }

    public func indexFolder(url: URL) async {
        guard let watcher else { return }
        isIndexing = true
        defer { isIndexing = false }
        if let stats = try? await watcher.indexFolder(at: url) {
            await reloadStats()
            let paths = watchedFolders.map { ($0.path as NSString).expandingTildeInPath }
            await watcher.startWatching(folders: paths) { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.reloadStats()
                }
            }
            showToast(String(format: "Indexed %d files (%d unchanged skipped) in %.0f ms", stats.filesIndexed, stats.filesSkippedUnchanged, stats.durationMs))
        }
    }

    public func reloadStats() async {
        guard !isPreviewSnapshot, let store else { return }
        if let t = try? await store.totals() {
            totalFiles = t.files
            totalChunks = t.chunks
        }
        if let bd = try? await store.kindBreakdown() {
            kindBreakdown = bd
        }
        databaseBytes = await store.databaseFileSizeBytes()
    }

    public func copyMarkdownReport() {
        guard let md = currentAnswer?.markdownReport else { return }
        if !isPreviewSnapshot {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(md, forType: .string)
        }
        showToast("Copied cited Markdown report")
    }

    public func copyCSVMatrix() {
        guard let csv = currentAnswer?.csvComparison else { return }
        if !isPreviewSnapshot {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(csv, forType: .string)
        }
        showToast("Copied comparison CSV matrix")
    }

    public func revealFile(_ path: String) {
        guard !isPreviewSnapshot else { return }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func wipeVault() {
        guard let store else {
            totalFiles = 0
            totalChunks = 0
            return
        }
        Task {
            try? await store.wipeAll()
            await reloadStats()
            showToast("Local vault index wiped")
        }
    }

    public func showToast(_ msg: String) {
        statusToast = msg
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if statusToast == msg { statusToast = nil }
        }
    }
}
