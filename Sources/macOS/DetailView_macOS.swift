import SwiftUI

private extension Image {
    /// Tints the image with the accent color when `active` is true, otherwise uses primary label color.
    func activeColor(_ active: Bool) -> some View {
        if active {
            return AnyView(self.foregroundStyle(.tint))
        } else {
            return AnyView(self.foregroundStyle(.primary))
        }
    }
}

/// macOS detail pane — editor / preview / to-do split, integrated terminal,
/// stats bar, and the document toolbar. Mirrors the original ContentView.
struct DetailView: View {
    @ObservedObject var state: AppState
    @State private var showTemplates = false

    var body: some View {
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
                        EditorEmptyState(state: state) { showTemplates = true }
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
        .navigationTitle(state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Kitib")
        .navigationSubtitle(state.rootURL?.lastPathComponent ?? "")
        .sheet(isPresented: Binding(
            get: { state.editingTable != nil },
            set: { if !$0 {
                // Commit on any dismiss — Done button or X close.
                if let newText = state.editingTable?.serialize() {
                    state.replaceTableText?(newText)
                }
                state.editingTable = nil
                state.editingTableRange = nil
            }}
        )) {
            if let _ = state.editingTable {
                TableGridEditor(
                    table: Binding(
                        get: { state.editingTable ?? MarkdownTable(headers: [], alignments: [], rows: []) },
                        set: { state.editingTable = $0 }
                    ),
                    onCommit: {
                        if let newText = state.editingTable?.serialize() {
                            state.replaceTableText?(newText)
                        }
                    }
                )
                .resizableSheet(
                    storageKey: "tableEditorSheet",
                    minWidth: 480,
                    minHeight: 300,
                    defaultWidth: 820,
                    defaultHeight: 480
                )
            }
        }
        .sheet(isPresented: $state.showOutline) {
            VStack(spacing: 0) {
                OutlinePanel(
                    flatNodes: state.outlineNodes,
                    onSelect: { range in
                        state.scrollToHeading?(range)
                        state.showOutline = false
                    },
                    onMove: { from, to in state.moveOutlineSection(from: from, to: to) }
                )
                Divider().opacity(0.5)
                HStack {
                    Spacer()
                    Button("Done") { state.showOutline = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(minWidth: 300, idealWidth: 340, minHeight: 340, idealHeight: 440)
            .background(
                Button("") { state.showOutline = false }
                    .keyboardShortcut(.escape)
                    .opacity(0)
            )
        }
        .sheet(isPresented: Binding(
            get: { state.pastePreviewText != nil },
            set: { if !$0 { state.dismissPastePreview() } }
        )) {
            if let raw = state.pastePreviewText,
               let healed = state.pastePreviewHealed {
                PastePreviewSheet(
                    raw: raw,
                    healed: healed,
                    onAccept: { state.acceptPastePreview() },
                    onReject: { state.rejectPastePreview() },
                    onCancel: { state.dismissPastePreview() }
                )
                .padding()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { showTemplates = true } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("New from template (⌘N)")
                .popover(isPresented: $showTemplates) {
                    TemplatePicker(state: state) { showTemplates = false }
                }

                Button { state.focusMode.toggle() } label: {
                    Image(systemName: state.focusMode ? "eye.fill" : "eye")
                        .activeColor(state.focusMode)
                }
                .help("Focus mode — dims everything but the current paragraph (⌘⇧F)")

                Button { state.typewriterScrolling.toggle() } label: {
                    Image(systemName: "keyboard")
                        .activeColor(state.typewriterScrolling)
                }
                .help("Typewriter scrolling — keeps the caret centered (⌘⇧T)")

                Button { state.showLineNumbers.toggle() } label: {
                    Image(systemName: "list.number")
                        .activeColor(state.showLineNumbers)
                }
                .help("Line numbers (⌘⇧L)")

                Button { state.showPreview.toggle() } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .activeColor(state.showPreview)
                }
                .help("Split preview — rendered view beside your Markdown (⌘⇧P)")

                Button { state.toggleTerminal() } label: {
                    Image(systemName: "terminal")
                        .activeColor(state.showTerminal)
                }
                .help("Integrated terminal below the writing area (⌃`)")

                Button { state.showTodos.toggle() } label: {
                    Image(systemName: "checklist")
                        .activeColor(state.showTodos)
                }
                .help("To-do list for this document (⌘⇧D)")

                if state.cursorInTable {
                    Button {
                        state.openTableGrid?()
                    } label: {
                        Image(systemName: "tablecells")
                            .activeColor(state.editingTable != nil)
                    }
                    .help("Edit table as a grid — opens a resizable window")
                }

                Button { state.showPastePreview.toggle() } label: {
                    Image(systemName: "bandage")
                        .activeColor(state.showPastePreview)
                }
                .help("Paste healing preview — shows raw vs healed text before committing")

                Button { state.showOutline.toggle() } label: {
                    Image(systemName: "list.bullet")
                        .activeColor(state.showOutline)
                }
                .help("Document outline — heading list with section reordering")

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
                    Toggle("Include Front Matter", isOn: $state.showFrontMatterExport)
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
        Exporter.exportHTML(markdown: state.text, title: docTitle, baseDir: baseDir, numbered: state.numberCaptions, showFrontMatter: state.showFrontMatterExport)
    }
    func exportPDF() {
        state.saveCurrentFile()
        Exporter.exportPDF(markdown: state.text, title: docTitle, baseDir: baseDir, withLineNumbers: state.printLineNumbers, numbered: state.numberCaptions, showFrontMatter: state.showFrontMatterExport)
    }
    func printDoc() {
        state.saveCurrentFile()
        Exporter.printDocument(markdown: state.text, title: docTitle, baseDir: baseDir, withLineNumbers: state.printLineNumbers, numbered: state.numberCaptions, showFrontMatter: state.showFrontMatterExport)
    }
}
