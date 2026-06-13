import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var showTemplates = false

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 380)
        } detail: {
            VStack(spacing: 0) {
                VSplitView {
                    Group {
                        if state.currentFileURL != nil {
                            HSplitView {
                                EditorView(state: state)
                                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                                if state.showPreview {
                                    PreviewView(state: state)
                                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                                }
                                if state.showTodos {
                                    TodoPanel(state: state)
                                        .frame(minWidth: 200, idealWidth: 250, maxWidth: 400)
                                }
                            }
                        } else {
                            emptyState
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
                    .layoutPriority(1)

                    if state.showTerminal {
                        TerminalPanel(state: state)
                            .frame(minHeight: 100, idealHeight: 220, maxHeight: 500)
                    }
                }
                if state.currentFileURL != nil {
                    Divider()
                    StatsBar(state: state)
                }
            }
        }
        // Fire the celebration in a floating panel above the AppKit editor.
        .onChange(of: state.goalCelebration) { n in
            if n > 0 { FireworksController.shared.celebrate() }
        }
        .navigationTitle(state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Kitib")
        .sheet(isPresented: $state.showHelp) { HelpView() }
        .sheet(isPresented: $state.showAbout) { AboutView() }
        .navigationSubtitle(state.rootURL?.lastPathComponent ?? "")
        .toolbar {
            ToolbarItemGroup {
                Button { showTemplates = true } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("New from template (⌘N)")
                .popover(isPresented: $showTemplates) { templatePicker }

                Button { state.focusMode.toggle() } label: {
                    Image(systemName: state.focusMode ? "eye.fill" : "eye")
                        .foregroundStyle(state.focusMode ? Color.accentColor : Color.primary)
                }
                .help("Focus mode — dims everything but the current paragraph (⌘⇧F)")

                Button { state.typewriterScrolling.toggle() } label: {
                    Image(systemName: "keyboard")
                        .foregroundStyle(state.typewriterScrolling ? Color.accentColor : Color.primary)
                }
                .help("Typewriter scrolling — keeps the caret centered (⌘⇧T)")

                Button { state.showLineNumbers.toggle() } label: {
                    Image(systemName: "list.number")
                        .foregroundStyle(state.showLineNumbers ? Color.accentColor : Color.primary)
                }
                .help("Line numbers (⌘⇧L)")

                Button { state.showPreview.toggle() } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .foregroundStyle(state.showPreview ? Color.accentColor : Color.primary)
                }
                .help("Split preview — rendered view beside your Markdown (⌘⇧P)")

                Button { state.toggleTerminal() } label: {
                    Image(systemName: "terminal")
                        .foregroundStyle(state.showTerminal ? Color.accentColor : Color.primary)
                }
                .help("Integrated terminal below the writing area (⌃`)")

                Button { state.showTodos.toggle() } label: {
                    Image(systemName: "checklist")
                        .foregroundStyle(state.showTodos ? Color.accentColor : Color.primary)
                }
                .help("To-do list for this document (⌘⇧D)")

                Button { state.showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Help — Markdown guide & shortcuts (⌘/)")

                Menu {
                    Button("Export as HTML…") { exportHTML() }
                    Button("Export as PDF…") { exportPDF() }
                    Button("Copy as Rich Text") { Exporter.copyAsRichText(markdown: state.text) }
                    Divider()
                    Toggle("Print with Line Numbers", isOn: $state.printLineNumbers)
                    Button("Print… (⌘P)") { printDoc() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export / print")
                .disabled(state.currentFileURL == nil)
            }
        }
    }

    private var docTitle: String {
        state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Document"
    }

    private var baseDir: URL? { state.currentFileURL?.deletingLastPathComponent() }

    func exportHTML() {
        state.saveCurrentFile()
        Exporter.exportHTML(markdown: state.text, title: docTitle, baseDir: baseDir, numbered: state.numberCaptions)
    }
    func exportPDF() {
        state.saveCurrentFile()
        Exporter.exportPDF(markdown: state.text, title: docTitle, baseDir: baseDir, withLineNumbers: state.printLineNumbers, numbered: state.numberCaptions)
    }
    func printDoc() {
        state.saveCurrentFile()
        Exporter.printDocument(markdown: state.text, title: docTitle, baseDir: baseDir, withLineNumbers: state.printLineNumbers, numbered: state.numberCaptions)
    }

    // MARK: Template picker

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("New Document")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(Templates.all) { template in
                Button {
                    showTemplates = false
                    state.newFile(named: template.filename, contents: template.body)
                    if template.suggestedGoal > 0 { state.setWordGoal(template.suggestedGoal) }
                } label: {
                    HStack {
                        Image(systemName: template.icon)
                            .frame(width: 22)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(template.name)
                            if template.suggestedGoal > 0 {
                                Text("~\(template.suggestedGoal) words")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 230)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Select a file, or start something new")
                .foregroundStyle(.secondary)
            HStack {
                if state.rootURL == nil {
                    Button("Open Folder…") { state.chooseFolder() }
                } else {
                    Button("New Document") { showTemplates = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
