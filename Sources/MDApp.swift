import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var state: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppDelegate.state?.saveCurrentFile()
        AppDelegate.state?.terminal.stop()
        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.state?.applyAppearance()
        // Load our icon explicitly — Launch Services often keeps a stale
        // generic icon cached for rebuilt, ad-hoc-signed bundles. Setting it
        // here fixes the Dock and the About panel regardless of the cache.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct KitibApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state: AppState

    init() {
        let s = AppState()
        _state = StateObject(wrappedValue: s)
        AppDelegate.state = s
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Kitib") { state.showAbout = true }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    state.newFile(named: "Untitled", contents: "")
                }
                .keyboardShortcut("n")
                Button("Open Folder…") { state.chooseFolder() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { state.saveCurrentFile() }
                    .keyboardShortcut("s")
                Divider()
                Button("Print…") {
                    state.saveCurrentFile()
                    Exporter.printDocument(
                        markdown: state.text,
                        title: state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Document",
                        baseDir: state.currentFileURL?.deletingLastPathComponent(),
                        withLineNumbers: state.printLineNumbers,
                        numbered: state.numberCaptions
                    )
                }
                .keyboardShortcut("p")
                .disabled(state.currentFileURL == nil)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { state.find(.showFindInterface) }
                    .keyboardShortcut("f")
                Button("Find and Replace…") { state.find(.showReplaceInterface) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") { state.find(.nextMatch) }
                    .keyboardShortcut("g")
                Button("Find Previous") { state.find(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { state.find(.setSearchString) }
                    .keyboardShortcut("e")
            }
            CommandMenu("Writer") {
                Toggle("Focus Mode", isOn: $state.focusMode)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Toggle("Typewriter Scrolling", isOn: $state.typewriterScrolling)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Toggle("Line Numbers", isOn: $state.showLineNumbers)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Toggle("Split Preview", isOn: $state.showPreview)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Toggle("Terminal", isOn: Binding(
                    get: { state.showTerminal },
                    set: { on in if on { state.openTerminal() } else { state.showTerminal = false } }
                ))
                .keyboardShortcut("`", modifiers: [.control])
                Toggle("To-Do List", isOn: $state.showTodos)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Divider()
                Picker("Appearance", selection: $state.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Divider()
                Button("Bigger Text") { state.editorFontSize = min(28, state.editorFontSize + 1) }
                    .keyboardShortcut("+")
                Button("Smaller Text") { state.editorFontSize = max(11, state.editorFontSize - 1) }
                    .keyboardShortcut("-")
                Toggle("Number Figures, Tables & Equations", isOn: $state.numberCaptions)
                Toggle("Celebrate Word Goal with Fireworks", isOn: $state.celebrateGoal)
                Button("Test Fireworks") { state.goalCelebration += 1 }
                Divider()
                Menu("Insert Lorem Ipsum") {
                    Button("A Sentence") { state.insert(text: LoremIpsum.sentence() + " ") }
                    Button("A Paragraph") { state.insert(text: LoremIpsum.paragraph(canonicalStart: true) + "\n\n") }
                    Button("3 Paragraphs") { state.insert(text: LoremIpsum.paragraphs(3) + "\n\n") }
                    Button("5 Paragraphs") { state.insert(text: LoremIpsum.paragraphs(5) + "\n\n") }
                }
                .disabled(state.currentFileURL == nil)
                Divider()
                Toggle("Print with Line Numbers", isOn: $state.printLineNumbers)
            }
            CommandGroup(replacing: .help) {
                Button("Kitib Help") { state.showHelp = true }
                    .keyboardShortcut("/")
            }
        }
    }
}
