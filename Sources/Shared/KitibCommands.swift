import SwiftUI

/// The menu bar, shared by macOS and iPadOS.
///
/// This was macOS-only until D78. iPadOS builds a real menu bar from `.commands`
/// exactly as macOS does — it appears on a hardware keyboard and in the ⌘ HUD —
/// but the type lived in `Sources/macOS/`, which the iOS target does not
/// compile, so iPad fell back to the system default: File → Close Window and
/// nothing else. No New Document, no Open Folder.
///
/// Anything genuinely macOS-only is behind `#if os(macOS)`:
/// - **Print** — `Exporter.printDocument` is declared in Exporter+macOS.swift
///   only; iOS exports through its own share-sheet path.
/// - **Terminal** — `AppState.openTerminal` is `#if os(macOS)` (SwiftTerm).
struct KitibCommands: Commands {
    @ObservedObject var state: AppState

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Kitib") { state.showAbout = true }
        }
        CommandGroup(replacing: .newItem) {
            Button("New Document") { state.newFile(named: "Untitled", contents: "", in: state.newFileTarget) }
                .keyboardShortcut("n")
            Button("Open Folder…") { state.chooseFolder() }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { state.saveCurrentFile() }
                .keyboardShortcut("s")
            #if os(macOS)
            Divider()
            Button("Print…") {
                state.saveCurrentFile()
                Exporter.printDocument(
                    markdown: state.text,
                    title: state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Document",
                    baseDir: state.currentFileURL?.deletingLastPathComponent(),
                    withLineNumbers: state.printLineNumbers,
                    numbered: state.numberCaptions,
                    showFrontMatter: state.showFrontMatterExport
                )
            }
            .keyboardShortcut("p")
            .disabled(state.currentFileURL == nil)
            #endif
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find…") { state.find(.find) }
                .keyboardShortcut("f")
            Button("Find and Replace…") { state.find(.replace) }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Button("Find Next") { state.find(.next) }
                .keyboardShortcut("g")
            Button("Find Previous") { state.find(.previous) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Use Selection for Find") { state.find(.useSelection) }
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
            Toggle("Show Front Matter in Preview", isOn: $state.showFrontMatterPreview)
                .keyboardShortcut("y", modifiers: [.command, .shift])
            #if os(macOS)
            Toggle("Terminal", isOn: Binding(
                get: { state.showTerminal },
                set: { on in if on { state.openTerminal() } else { state.showTerminal = false } }
            ))
            .keyboardShortcut("`", modifiers: [.control])
            #endif
            Toggle("To-Do List", isOn: $state.showTodos)
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Toggle("Outline", isOn: $state.showOutline)
                .keyboardShortcut("o", modifiers: [.command, .shift])
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
            Toggle("Include Front Matter in Print / Export", isOn: $state.showFrontMatterExport)
        }
        CommandGroup(replacing: .help) {
            Button("Kitib Help") { state.showHelp = true }
                .keyboardShortcut("/")
        }
    }
}
