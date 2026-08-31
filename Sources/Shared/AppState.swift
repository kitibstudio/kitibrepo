import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
import CoreServices
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - File tree model

final class FileItem: Identifiable, ObservableObject {
    let id: String
    let url: URL
    let isDirectory: Bool
    @Published var children: [FileItem]?

    var name: String { url.lastPathComponent }

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.id = url.path
        self.isDirectory = isDirectory
        self.children = isDirectory ? FileItem.loadChildren(of: url) : nil
    }

    static let textExtensions: Set<String> = ["md", "markdown", "txt", "text"]

    static func loadChildren(of url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let items: [FileItem] = urls.compactMap { child in
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                if child.pathExtension == "app" || child.lastPathComponent == ".build-app" { return nil }
                return FileItem(url: child, isDirectory: true)
            }
            guard textExtensions.contains(child.pathExtension.lowercased()) else { return nil }
            return FileItem(url: child, isDirectory: false)
        }
        return items.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

// MARK: - To-do item

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

// MARK: - Scroll sync bus

final class ScrollSync {
    var scrollEditor: ((Double) -> Void)?    // set by EditorView
    var scrollPreview: ((Double) -> Void)?   // set by PreviewView

    func editorScrolled(fraction: Double) { scrollPreview?(fraction) }
    func previewScrolled(fraction: Double) { scrollEditor?(fraction) }
}

// MARK: - App state

final class AppState: ObservableObject {
    @Published var rootURL: URL? {
        didSet {
            persistRoot()
            refreshTree()
            #if os(macOS)
            startWatchingRoot()
            #endif
        }
    }
    @Published var rootItem: FileItem?

    /// Display name of the last folder that was open, read from UserDefaults at
    /// init without touching the filesystem. Drives the "Reopen …" button; nil
    /// on a first-ever launch, when there is nothing to reopen.
    @Published private(set) var lastFolderName: String?

    @Published var selectedFileID: String?
    @Published var text: String = ""
    @Published var isDirty = false

    // Drives the SwiftUI folder importer (works on macOS and iPadOS).
    @Published var showFolderImporter = false

    // Writer settings (persisted)
    @Published var focusMode: Bool { didSet { save(focusMode, "focusMode") } }
    @Published var typewriterScrolling: Bool { didSet { save(typewriterScrolling, "typewriterScrolling") } }
    @Published var showLineNumbers: Bool { didSet { save(showLineNumbers, "showLineNumbers") } }
    @Published var printLineNumbers: Bool { didSet { save(printLineNumbers, "printLineNumbers") } }
    @Published var editorFontSize: Double { didSet { save(editorFontSize, "editorFontSize") } }
    @Published var appearance: String { didSet { save(appearance, "appearance"); applyAppearance() } }
    @Published var showPreview: Bool { didSet { save(showPreview, "showPreview") } }
    @Published var numberCaptions: Bool { didSet { save(numberCaptions, "numberCaptions") } }
    // Front matter (YAML header) visibility — both default off.
    @Published var showFrontMatterPreview: Bool { didSet { save(showFrontMatterPreview, "showFrontMatterPreview") } }
    @Published var showFrontMatterExport: Bool { didSet { save(showFrontMatterExport, "showFrontMatterExport") } }
    @Published var wordGoal: Int = 0
    @Published var celebrateGoal: Bool { didSet { save(celebrateGoal, "celebrateGoal") } }

    // Live selection stats (transient)
    @Published var selectionWords = 0
    @Published var selectionChars = 0

    @Published var goalCelebration = 0

    @Published var showHelp = false
    @Published var showAbout = false
    @Published var showTerminal = false
    @Published var showOutline: Bool { didSet { save(showOutline, "showOutline") } }
    @Published var showTodos: Bool { didSet { save(showTodos, "showTodos") } }

    // MARK: Paste healing preview

    /// When `false`, paste is raw — the preview sheet is skipped and the
    /// pipeline is never run. Persisted, default `true`.
    @Published var showPastePreview: Bool {
        didSet { save(showPastePreview, "showPastePreview") }
    }

    /// The raw paste text captured by the paste hook. Non-nil when the
    /// preview sheet is active; nil otherwise.
    @Published var pastePreviewText: String?

    /// The healed version of `pastePreviewText`, or nil when no preview
    /// is active. Computed so the sheet always reads the current state.
    var pastePreviewHealed: String? {
        guard let raw = pastePreviewText else { return nil }
        return PasteHealer.heal(raw)
    }

    /// Inserts the healed text at the caret and dismisses the preview.
    func acceptPastePreview() {
        guard let healed = pastePreviewHealed else { return }
        insert(text: healed)
        pastePreviewText = nil
    }

    /// Inserts the raw text at the caret and dismisses the preview.
    func rejectPastePreview() {
        guard let raw = pastePreviewText else { return }
        insert(text: raw)
        pastePreviewText = nil
    }

    /// Dismisses the preview without inserting anything.
    func dismissPastePreview() {
        pastePreviewText = nil
    }

    // MARK: Smart folders (saved searches)

    /// Persisted smart folders, loaded from the store at init.
    @Published var smartFolders: [SmartFolder] = []

    /// The folder currently being viewed in the smart-folder panel.
    @Published var activeSmartFolderID: UUID?

    /// Whether the smart-folder panel is presented.
    @Published var showSmartFolders = false

    private let smartFolderStore = SmartFolderStore()

    /// In-memory FTS5 index over every Markdown file under the open root.
    private var searchIndex: SearchIndex?

    /// Coalesces index rebuilds (D73). A rebuild reads every Markdown file
    /// under the root, so it must never run once per file operation.
    private var indexWorkItem: DispatchWorkItem?

    /// How long a burst of file activity must settle before re-indexing.
    /// Results can therefore trail the disk by up to this long, by decision.
    private let indexCoalesceDelay: TimeInterval = 1.0

    /// Requests a rebuild, collapsing a burst of file operations into one.
    ///
    /// A single save previously cost two whole-vault passes on the main thread:
    /// the autosave rebuilt directly, then the app's own write woke the FSEvents
    /// watcher, which called `refreshTree()`, which rebuilt again.
    func scheduleIndexRebuild() {
        // No index yet — the first query must not come back empty, so pay the
        // cost now. Only reachable on root change, where a pause is expected.
        guard searchIndex != nil else {
            rebuildSearchIndex()
            return
        }
        indexWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.rebuildSearchIndex() }
        indexWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + indexCoalesceDelay, execute: item)
    }

    /// Rebuilds the search index from the current file tree. Prefer
    /// `scheduleIndexRebuild()` — this walks and reads the whole tree.
    func rebuildSearchIndex() {
        guard let root = rootItem else {
            searchIndex = nil
            return
        }
        guard let index = try? SearchIndex() else {
            searchIndex = nil
            return
        }
        func walk(_ item: FileItem) {
            if item.isDirectory {
                for child in item.children ?? [] { walk(child) }
            } else {
                guard let content = try? String(contentsOf: item.url, encoding: .utf8)
                else { return }
                try? index.index(
                    id: item.id,
                    title: item.url.deletingPathExtension().lastPathComponent,
                    content: content
                )
            }
        }
        walk(root)
        searchIndex = index
    }

    /// Runs a smart-folder query against the current index.
    func searchSmartFolder(_ query: String) -> [SearchHit] {
        guard let index = searchIndex else { return [] }
        return (try? index.search(query)) ?? []
    }

    /// Hits for the active folder, recomputed from the live index.
    var activeSmartFolderResults: [SearchHit] {
        guard let id = activeSmartFolderID,
              let folder = smartFolders.first(where: { $0.id == id })
        else { return [] }
        return searchSmartFolder(folder.query)
    }

    func addSmartFolder(name: String, query: String) {
        let folder = smartFolderStore.add(name: name, query: query)
        smartFolders = smartFolderStore.folders
        activeSmartFolderID = folder.id
    }

    func updateSmartFolder(id: UUID, name: String, query: String) {
        smartFolderStore.update(id: id, name: name, query: query)
        smartFolders = smartFolderStore.folders
    }

    func deleteSmartFolder(id: UUID) {
        smartFolderStore.delete(id: id)
        smartFolders = smartFolderStore.folders
        if activeSmartFolderID == id { activeSmartFolderID = nil }
    }

    /// Opens a smart folder's results and selects the folder.
    func openSmartFolder(id: UUID) {
        activeSmartFolderID = id
        showSmartFolders = true
    }

    /// Opens the file a search hit points at.
    func openSearchHit(_ hit: SearchHit) {
        open(path: hit.id)
        showSmartFolders = false
    }

    /// SwiftUI ColorScheme override derived from the appearance setting.
    /// Both platforms apply this via `.preferredColorScheme`.
    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: To-do lists (per document, persisted)

    @Published var todos: [TodoItem] = [] { didSet { persistTodos() } }
    private var allTodos: [String: [TodoItem]] = [:]

    private func loadAllTodos() {
        guard let data = UserDefaults.standard.data(forKey: "todoLists"),
              let decoded = try? JSONDecoder().decode([String: [TodoItem]].self, from: data)
        else { return }
        allTodos = decoded
    }

    private func persistTodos() {
        guard let id = selectedFileID else { return }
        if todos.isEmpty { allTodos.removeValue(forKey: id) } else { allTodos[id] = todos }
        saveAllTodos()
    }

    private func saveAllTodos() {
        if let data = try? JSONEncoder().encode(allTodos) {
            UserDefaults.standard.set(data, forKey: "todoLists")
        }
    }

    // MARK: Recent files (persisted)
    //
    // Stored as plain paths. Nothing prunes the stored list on delete/rename —
    // `recentFiles` filters at read time against what's actually on disk and
    // under the open root, so stale entries simply stop showing up.

    @Published private(set) var recentPaths: [String] = []
    private let recentsLimit = 12

    /// Recently opened files that still exist and live under the open folder,
    /// most recent first.
    var recentFiles: [URL] {
        guard let root = rootURL?.standardizedFileURL.path else { return [] }
        return recentPaths.compactMap { path in
            guard path.hasPrefix(root + "/"),
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        }
    }

    private func noteRecent(_ path: String) {
        recentPaths.removeAll { $0 == path }
        recentPaths.insert(path, at: 0)
        if recentPaths.count > recentsLimit {
            recentPaths.removeLast(recentPaths.count - recentsLimit)
        }
        UserDefaults.standard.set(recentPaths, forKey: "recentFiles")
    }

    func clearRecents() {
        recentPaths = []
        UserDefaults.standard.set(recentPaths, forKey: "recentFiles")
    }

    let scrollSync = ScrollSync()

    #if os(macOS)
    let terminal = TerminalSession()
    #endif

    /// Set by the editor; inserts text at the caret with undo support.
    var insertAtCaret: ((String) -> Void)?

    /// Set by the editor; drives find/replace. Platform-neutral verbs.
    var performFind: ((FindAction) -> Void)?

    func find(_ action: FindAction) { performFind?(action) }

    func insert(text snippet: String) {
        if let insertAtCaret {
            insertAtCaret(snippet)
        } else {
            text += snippet
            isDirty = true
        }
    }

    // MARK: Table grid editor

    /// True when the cursor is inside a Markdown pipe table.
    @Published var cursorInTable = false

    /// The table being edited in the grid. Set by the editor when the user
    /// opens the table grid; nil when no grid is active.
    @Published var editingTable: MarkdownTable?

    /// The range of the table text in the editor's string. Set alongside
    /// `editingTable` so the commit callback can replace it.
    var editingTableRange: NSRange?

    /// Called by the grid editor on commit; the editor replaces the table
    /// text with this serialized string.
    var replaceTableText: ((String) -> Void)?

    /// Opens the table grid for the table at the current cursor position.
    /// Set by the editor's coordinator; called from the toolbar button.
    var openTableGrid: (() -> Void)?

    // MARK: Outline panel

    /// Flat heading nodes for the outline panel, recomputed from current
    /// document text. Empty array when no headings exist.
    var outlineNodes: [OutlineNode] {
        guard !text.isEmpty else { return [] }
        let headings = OutlineParser.parseHeadings(from: text)
        guard !headings.isEmpty else { return [] }
        return OutlineParser.computeSectionRanges(text: text, headings: headings)
    }

    /// Set by the editor; scrolls to a heading range in the text view.
    var scrollToHeading: ((NSRange) -> Void)?

    /// Called by the outline panel on Move Up / Move Down; rewrites the
    /// document text by moving a section. Uses the replaceTableText bridge
    /// (set by the editor) for undo support.
    func moveOutlineSection(from sourceIndex: Int, to destinationIndex: Int) {
        let headings = OutlineParser.parseHeadings(from: text)
        guard let result = SectionMover.move(
            text: text,
            headings: headings,
            sourceIndex: sourceIndex,
            destinationIndex: destinationIndex
        ) else { return }
        // Set the full-document range so replaceTableText replaces everything
        editingTableRange = NSRange(location: 0, length: text.utf16.count)
        replaceTableText?(result.text)
    }

    // MARK: Integrated terminal (macOS only)

    #if os(macOS)
    func openTerminal(at directory: URL? = nil) {
        let dir = directory
            ?? currentFileURL?.deletingLastPathComponent()
            ?? rootURL
            ?? FileManager.default.homeDirectoryForCurrentUser
        if terminal.isRunning {
            if directory != nil { terminal.changeDirectory(to: dir) }
        } else {
            terminal.start(in: dir)
        }
        showTerminal = true
    }

    func toggleTerminal() {
        if showTerminal { showTerminal = false } else { openTerminal() }
    }
    #endif

    func applyAppearance() {
        #if os(macOS)
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        #endif
        // iOS applies `colorScheme` through `.preferredColorScheme` on the root view.
        objectWillChange.send()
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    var currentFileURL: URL? {
        guard let id = selectedFileID else { return nil }
        return URL(fileURLWithPath: id)
    }

    private var saveDebounce: AnyCancellable?
    private var goals: [String: Int] = [:]

    #if os(macOS)
    private var fsEventStream: FSEventStreamRef?
    private var refreshWorkItem: DispatchWorkItem?
    #endif

    init() {
        let d = UserDefaults.standard
        focusMode = d.bool(forKey: "focusMode")
        typewriterScrolling = d.bool(forKey: "typewriterScrolling")
        showLineNumbers = d.bool(forKey: "showLineNumbers")
        printLineNumbers = d.bool(forKey: "printLineNumbers")
        editorFontSize = d.object(forKey: "editorFontSize") as? Double ?? 16.0
        appearance = d.string(forKey: "appearance") ?? "system"
        showPreview = d.bool(forKey: "showPreview")
        numberCaptions = d.object(forKey: "numberCaptions") as? Bool ?? true
        showFrontMatterPreview = d.bool(forKey: "showFrontMatterPreview")
        showFrontMatterExport = d.bool(forKey: "showFrontMatterExport")
        celebrateGoal = d.object(forKey: "celebrateGoal") as? Bool ?? true
        showTodos = d.bool(forKey: "showTodos")
        showOutline = d.bool(forKey: "showOutline")
        showPastePreview = d.object(forKey: "showPastePreview") as? Bool ?? true
        goals = (d.dictionary(forKey: "wordGoals") as? [String: Int]) ?? [:]
        recentPaths = d.stringArray(forKey: "recentFiles") ?? []
        smartFolders = smartFolderStore.folders
        loadAllTodos()
        // Deliberately NOT restoring the root here (D77). Reading the name is a
        // UserDefaults lookup; opening the folder walks and indexes the vault,
        // and doing that inside App.init() is what bounced the dock.
        lastFolderName = d.string(forKey: "rootPath").map {
            URL(fileURLWithPath: $0).lastPathComponent
        }
        saveDebounce = $text
            .dropFirst()
            .debounce(for: .seconds(1.2), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveCurrentFile() }
    }

    // MARK: Root persistence (security-scoped bookmark)

    /// On iOS the chosen folder is only reachable through a security-scoped
    /// bookmark; on macOS a plain path also works, but a bookmark is harmless
    /// and future-proofs a sandboxed build.
    private func persistRoot() {
        guard let url = rootURL else {
            UserDefaults.standard.removeObject(forKey: "rootBookmark")
            UserDefaults.standard.removeObject(forKey: "rootPath")
            lastFolderName = nil
            return
        }
        UserDefaults.standard.set(url.path, forKey: "rootPath")
        lastFolderName = url.lastPathComponent
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        if let data = try? url.bookmarkData(options: options,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "rootBookmark")
        }
    }

    /// Reopens the folder that was last open. Called from the empty state's
    /// "Reopen …" button, never from `init()` — this walks and indexes the whole
    /// vault, and at launch that is exactly the work that must not happen (D77).
    ///
    /// Assigning `rootURL` is sufficient: its `didSet` persists the root,
    /// rebuilds the tree and starts the watcher. Calling those again here — as
    /// the old restore path did — walked and indexed the vault a second time.
    @discardableResult
    func reopenLastFolder() -> Bool {
        if let data = UserDefaults.standard.data(forKey: "rootBookmark") {
            var stale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            if let url = try? URL(resolvingBookmarkData: data, options: options,
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
                rootURL = url
                return true
            }
        }
        if let path = UserDefaults.standard.string(forKey: "rootPath"),
           FileManager.default.fileExists(atPath: path) {
            rootURL = URL(fileURLWithPath: path)
            return true
        }
        // The bookmark is stale and the path is gone — the folder was moved,
        // deleted, or is on an unmounted volume. Drop the offer rather than
        // leaving a button that does nothing.
        lastFolderName = nil
        return false
    }

    func refreshTree() {
        guard let root = rootURL else {
            rootItem = nil
            indexWorkItem?.cancel()
            rebuildSearchIndex()   // clears the index; reads nothing
            return
        }
        rootItem = FileItem(url: root, isDirectory: true)
        scheduleIndexRebuild()
    }

    // MARK: Folder / file selection

    /// Triggers the SwiftUI folder importer (presented by the root view).
    func chooseFolder() {
        showFolderImporter = true
    }

    /// Called by the importer's completion handler with the picked folder.
    func openFolder(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        saveCurrentFile()
        selectedFileID = nil
        text = ""
        rootURL = url
    }

    /// Moves the root up one level to the current root's parent folder.
    ///
    /// On macOS the app is not sandboxed, so a plain path to the parent just
    /// works. On iOS the document-picker grant covers the picked folder and
    /// its descendants only; a parent is normally out of scope, so when access
    /// cannot be obtained the picker is re-presented instead; that is the
    /// iPad-native way to grant a folder the user never picked. The filesystem
    /// root is the ceiling: its parent is itself, so the guard below is the
    /// backstop behind the sidebar's disabled button.
    ///
    /// The save/clear happens only after a real upward move is confirmed, so a
    /// cancelled iPad picker does not disturb the open document.
    func navigateUp() {
        guard let root = rootURL else { return }
        let parent = root.deletingLastPathComponent()
        guard parent.standardizedFileURL.path != root.standardizedFileURL.path else { return }

        #if os(iOS)
        if !parent.startAccessingSecurityScopedResource() {
            chooseFolder()
            return
        }
        #endif

        saveCurrentFile()
        selectedFileID = nil
        text = ""
        rootURL = parent
    }

    func open(file: FileItem) {
        guard !file.isDirectory else { return }
        saveCurrentFile()
        selectedFileID = file.id
        text = (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
        isDirty = false
        wordGoal = goals[file.id] ?? 0
        todos = allTodos[file.id] ?? []
        noteRecent(file.id)
    }

    /// Opens by path — used by the iPhone browser, whose navigation is
    /// path-based because `refreshTree()` replaces every `FileItem`.
    func open(path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        open(file: FileItem(url: url, isDirectory: false))
    }

    func saveCurrentFile() {
        guard let url = currentFileURL, isDirty else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
        scheduleIndexRebuild()
    }

    func textChanged(_ newText: String) {
        text = newText
        isDirty = true
    }

    func setWordGoal(_ goal: Int) {
        wordGoal = goal
        guard let id = selectedFileID else { return }
        if goal > 0 { goals[id] = goal } else { goals.removeValue(forKey: id) }
        UserDefaults.standard.set(goals, forKey: "wordGoals")
    }

    // MARK: File operations

    /// Where the menu-bar and template-picker new-file commands should create.
    /// SidebarView registers this (it owns the List selection); on iPhone
    /// there is no sidebar, so the provider stays nil and `newFileTarget`
    /// falls back to the root. Spec: specs/new-file-in-folder.md.
    var newFileTargetProvider: (() -> URL?)?

    /// Resolves the creation target for commands that do not see the
    /// sidebar's selection: the selected folder, the selected file's parent,
    /// or the root. Falls back to the root when nothing is selected or no
    /// provider is registered.
    var newFileTarget: URL? {
        newFileTargetProvider?() ?? rootURL
    }

    func newFile(named name: String, contents: String, in folder: URL? = nil) {
        guard let dir = folder ?? rootURL else { return }
        var candidate = dir.appendingPathComponent(name)
        if candidate.pathExtension.isEmpty {
            candidate = candidate.appendingPathExtension("md")
        }
        var final = candidate
        var n = 2
        while FileManager.default.fileExists(atPath: final.path) {
            let base = candidate.deletingPathExtension().lastPathComponent
            final = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(candidate.pathExtension)
            n += 1
        }
        try? contents.write(to: final, atomically: true, encoding: .utf8)
        refreshTree()
        saveCurrentFile()
        selectedFileID = final.path
        text = contents
        isDirty = false
        wordGoal = 0
        todos = []
        noteRecent(final.path)
    }

    func newFolder(named name: String, in folder: URL? = nil) {
        guard let dir = folder ?? rootURL else { return }
        // `createDirectory(withIntermediateDirectories: true)` succeeds without
        // error when the directory already exists, so without uniquing every
        // press after the first was a silent no-op.
        let fm = FileManager.default
        let unique = UniqueName.next(base: name) { candidate in
            fm.fileExists(atPath: dir.appendingPathComponent(candidate).path)
        }
        let target = dir.appendingPathComponent(unique)
        try? fm.createDirectory(at: target, withIntermediateDirectories: true)
        refreshTree()
    }

    func rename(item: FileItem, to newName: String) {
        var name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !item.isDirectory && (name as NSString).pathExtension.isEmpty {
            name += ".\(item.url.pathExtension)"
        }
        let dest = item.url.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            if selectedFileID == item.id { selectedFileID = dest.path }
            if let moved = allTodos.removeValue(forKey: item.id) {
                allTodos[dest.path] = moved
                saveAllTodos()
            }
            refreshTree()
        } catch { Platform.beep() }
    }

    func move(itemID: String, to destinationDir: URL) {
        let src = URL(fileURLWithPath: itemID)
        let srcStd = src.standardizedFileURL.path
        let destDirStd = destinationDir.standardizedFileURL.path

        if src.deletingLastPathComponent().standardizedFileURL.path == destDirStd { return }
        if destDirStd == srcStd || destDirStd.hasPrefix(srcStd + "/") { Platform.beep(); return }

        var dest = destinationDir.appendingPathComponent(src.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            let base = dest.deletingPathExtension().lastPathComponent
            let ext = dest.pathExtension
            var n = 2
            repeat {
                let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
                dest = destinationDir.appendingPathComponent(name)
                n += 1
            } while FileManager.default.fileExists(atPath: dest.path)
        }

        do {
            try FileManager.default.moveItem(at: src, to: dest)
            if let sel = selectedFileID {
                if sel == itemID {
                    selectedFileID = dest.path
                } else if sel.hasPrefix(srcStd + "/") {
                    selectedFileID = dest.path + String(sel.dropFirst(srcStd.count))
                }
            }
            if let movedTodos = allTodos.removeValue(forKey: itemID) {
                allTodos[dest.path] = movedTodos
                saveAllTodos()
            }
            if let movedGoal = goals.removeValue(forKey: itemID) {
                goals[dest.path] = movedGoal
                UserDefaults.standard.set(goals, forKey: "wordGoals")
            }
            refreshTree()
        } catch { Platform.beep() }
    }

    func delete(item: FileItem) {
        Platform.delete(at: item.url)
        allTodos.removeValue(forKey: item.id)
        saveAllTodos()
        if selectedFileID == item.id || (selectedFileID?.hasPrefix(item.url.path + "/") ?? false) {
            todos = []
            selectedFileID = nil
            text = ""
            isDirty = false
        }
        refreshTree()
    }

    #if os(macOS)
    func revealInFinder(item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    #endif

    func duplicate(item: FileItem) {
        let dir = item.url.deletingLastPathComponent()
        let ext = item.url.pathExtension
        let base = item.url.deletingPathExtension().lastPathComponent

        func candidate(_ suffix: String) -> URL {
            let name = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
            return dir.appendingPathComponent(name)
        }

        var dest = candidate(" copy")
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = candidate(" copy \(n)")
            n += 1
        }

        do {
            try FileManager.default.copyItem(at: item.url, to: dest)
            refreshTree()
            if !item.isDirectory {
                selectedFileID = dest.path
            }
        } catch { Platform.beep() }
    }

    // MARK: - File system watcher (macOS only)

    #if os(macOS)
    private func startWatchingRoot() {
        stopWatchingRoot()
        guard let url = rootURL else { return }

        let pathsToWatch = [url.path] as CFArray
        let latency: CFTimeInterval = 0.8

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let info = clientCallBackInfo else { return }
            let state = Unmanaged<AppState>.fromOpaque(info).takeUnretainedValue()
            state.scheduleRefresh()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes |
                           kFSEventStreamCreateFlagFileEvents |
                           kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        fsEventStream = stream
    }

    private func stopWatchingRoot() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    private func scheduleRefresh() {
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.refreshTree() }
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    deinit { stopWatchingRoot() }
    #endif
}
