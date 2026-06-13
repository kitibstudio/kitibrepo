import SwiftUI
import AppKit
import Combine

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

/// Lightweight channel between the editor and the split preview so the two
/// panes scroll together. Each side registers a receiver closure; loop
/// protection lives on the receiving side (a suppress flag in the editor,
/// a `__progScroll` guard in the preview's JS).
final class ScrollSync {
    var scrollEditor: ((Double) -> Void)?    // set by EditorView
    var scrollPreview: ((Double) -> Void)?   // set by PreviewView

    func editorScrolled(fraction: Double) { scrollPreview?(fraction) }
    func previewScrolled(fraction: Double) { scrollEditor?(fraction) }
}

// MARK: - App state

final class AppState: ObservableObject {
    @Published var rootURL: URL? { didSet { persistRoot(); refreshTree() } }
    @Published var rootItem: FileItem?
    @Published var selectedFileID: String?
    @Published var text: String = ""
    @Published var isDirty = false

    // Writer settings (persisted)
    @Published var focusMode: Bool { didSet { save(focusMode, "focusMode") } }
    @Published var typewriterScrolling: Bool { didSet { save(typewriterScrolling, "typewriterScrolling") } }
    @Published var showLineNumbers: Bool { didSet { save(showLineNumbers, "showLineNumbers") } }
    @Published var printLineNumbers: Bool { didSet { save(printLineNumbers, "printLineNumbers") } }
    @Published var editorFontSize: Double { didSet { save(editorFontSize, "editorFontSize") } }
    @Published var appearance: String { didSet { save(appearance, "appearance"); applyAppearance() } }
    @Published var showPreview: Bool { didSet { save(showPreview, "showPreview") } }
    @Published var numberCaptions: Bool { didSet { save(numberCaptions, "numberCaptions") } }
    @Published var wordGoal: Int = 0
    @Published var celebrateGoal: Bool { didSet { save(celebrateGoal, "celebrateGoal") } }

    // Live selection stats (transient — driven by the editor, not persisted)
    @Published var selectionWords = 0
    @Published var selectionChars = 0

    /// Bumped each time the word count crosses the goal. ContentView hosts the
    /// fireworks overlay (above the AppKit editor) and watches this counter.
    @Published var goalCelebration = 0

    @Published var showHelp = false
    @Published var showAbout = false
    @Published var showTerminal = false
    @Published var showTodos: Bool { didSet { save(showTodos, "showTodos") } }

    // MARK: To-do lists (per document, persisted)

    @Published var todos: [TodoItem] = [] { didSet { persistTodos() } }
    private var allTodos: [String: [TodoItem]] = [:]   // file path -> items

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

    let scrollSync = ScrollSync()
    let terminal = TerminalSession()

    /// Set by the editor; inserts text at the caret with undo support.
    var insertAtCaret: ((String) -> Void)?

    /// Set by the editor; drives the native find bar (find / replace / next…).
    var performFind: ((NSTextFinder.Action) -> Void)?

    func find(_ action: NSTextFinder.Action) { performFind?(action) }

    func insert(text snippet: String) {
        if let insertAtCaret {
            insertAtCaret(snippet)
        } else {
            text += snippet
            isDirty = true
        }
    }

    // MARK: Integrated terminal

    /// Opens (or reveals) the terminal panel. With a directory it starts the
    /// shell there — or, if already running, just cd's into it.
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

    func applyAppearance() {
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil   // follow system
        }
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    var currentFileURL: URL? {
        guard let id = selectedFileID else { return nil }
        return URL(fileURLWithPath: id)
    }

    private var saveDebounce: AnyCancellable?
    private var goals: [String: Int] = [:]   // path -> word goal

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
        celebrateGoal = d.object(forKey: "celebrateGoal") as? Bool ?? true
        showTodos = d.bool(forKey: "showTodos")
        goals = (d.dictionary(forKey: "wordGoals") as? [String: Int]) ?? [:]
        loadAllTodos()
        if let path = d.string(forKey: "rootPath"),
           FileManager.default.fileExists(atPath: path) {
            rootURL = URL(fileURLWithPath: path)
            refreshTree()   // didSet doesn't fire during init
        }
        saveDebounce = $text
            .dropFirst()
            .debounce(for: .seconds(1.2), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveCurrentFile() }
    }

    private func persistRoot() {
        UserDefaults.standard.set(rootURL?.path, forKey: "rootPath")
    }

    func refreshTree() {
        guard let root = rootURL else { rootItem = nil; return }
        rootItem = FileItem(url: root, isDirectory: true)
    }

    // MARK: Folder / file selection

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Open Folder"
        panel.message = "Choose the folder that holds your writing"
        if panel.runModal() == .OK, let url = panel.url {
            saveCurrentFile()
            selectedFileID = nil
            text = ""
            rootURL = url
        }
    }

    func open(file: FileItem) {
        guard !file.isDirectory else { return }
        saveCurrentFile()
        selectedFileID = file.id
        text = (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
        isDirty = false
        wordGoal = goals[file.id] ?? 0
        todos = allTodos[file.id] ?? []
    }

    func saveCurrentFile() {
        guard let url = currentFileURL, isDirty else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
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
    }

    func newFolder(named name: String, in folder: URL? = nil) {
        guard let dir = folder ?? rootURL else { return }
        let target = dir.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
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
        } catch { NSSound.beep() }
    }

    /// Moves a file or folder (identified by its path) into `destinationDir`.
    /// Used by sidebar drag-and-drop. Guards against no-ops and against moving
    /// a folder into itself or one of its own descendants, and never clobbers
    /// an existing item at the destination.
    func move(itemID: String, to destinationDir: URL) {
        let src = URL(fileURLWithPath: itemID)
        let srcStd = src.standardizedFileURL.path
        let destDirStd = destinationDir.standardizedFileURL.path

        // Already living in the destination → nothing to do.
        if src.deletingLastPathComponent().standardizedFileURL.path == destDirStd { return }
        // Can't move a folder inside itself or its own subtree.
        if destDirStd == srcStd || destDirStd.hasPrefix(srcStd + "/") { NSSound.beep(); return }

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

            // Keep the open document selected if it (or its containing folder) moved.
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
        } catch { NSSound.beep() }
    }

    func delete(item: FileItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
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

    func revealInFinder(item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Duplicates a file or folder alongside the original, appending " copy"
    /// (and a number if needed) so the original is never clobbered.
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
        } catch { NSSound.beep() }
    }
}
