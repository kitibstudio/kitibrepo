import SwiftUI
import UIKit

/// iOS detail pane — editor with optional preview / to-do list, a touch toolbar
/// (the macOS menu bar's actions), stats bar, and the goal fireworks overlay.
/// On regular width (iPad) preview and to-dos sit side by side with the editor;
/// on compact width (iPhone) preview swaps full-screen and to-dos appear in a
/// sheet. The integrated terminal is macOS-only and omitted here.
struct DetailView: View {
    @ObservedObject var state: AppState
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var showTemplates = false
    @State private var shareItem: ShareItem?
    @State private var preparingExport = false

    // Compact width (iPhone) has no room for the side panel, so to-dos are
    // presented as a sheet instead. iPad keeps the inline panel.
    @State private var showTodoSheet = false
    @State private var todoDetent: PresentationDetent = .medium

    private var isRegular: Bool { hSize == .regular }
    private var todosVisible: Bool { isRegular ? state.showTodos : showTodoSheet }
    private var docTitle: String {
        state.currentFileURL?.deletingPathExtension().lastPathComponent ?? "Document"
    }
    private var baseDir: URL? { state.currentFileURL?.deletingLastPathComponent() }

    var body: some View {
        Group {
            if state.currentFileURL != nil {
                content
            } else {
                EditorEmptyState(state: state) { showTemplates = true }
            }
        }
        .navigationTitle(docTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay {
            FireworksOverlay(trigger: state.goalCelebration)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if preparingExport {
                ProgressView("Preparing…")
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showTemplates) {
            NavigationStack {
                TemplatePicker(state: state) { showTemplates = false }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showTemplates = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showTodoSheet) {
            TodoPanel(state: state,
                      onClose: { showTodoSheet = false },
                      onBeginAdding: { todoDetent = .large })
                .presentationDetents([.medium, .large], selection: $todoDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { state.editingTable != nil },
            set: { if !$0 {
                // Commit on any dismiss — Done button or swipe-down.
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
                // Fills the sheet instead of floating in the middle of it, and
                // opens at full height: a table needs the room, and the grid
                // brings its own padding.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $state.showOutline) {
            OutlinePanel(
                flatNodes: state.outlineNodes,
                onSelect: { range in state.scrollToHeading?(range) },
                onMove: { from, to in state.moveOutlineSection(from: from, to: to) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
                .presentationDetents([.medium, .large])
            }
        }
        // Leaving compact width (rotation, Split View, iPhone → iPad handoff of
        // state) shouldn't strand the sheet over the now-available side panel.
        .onChange(of: isRegular) { regular in
            if regular && showTodoSheet {
                showTodoSheet = false
                state.showTodos = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if state.showPreview && isRegular {
                HStack(spacing: 0) {
                    EditorView(state: state)
                    Divider()
                    PreviewView(state: state)
                    if state.showTodos { Divider(); TodoPanel(state: state).frame(width: 280) }
                }
            } else if state.showPreview {
                PreviewView(state: state)
            } else {
                HStack(spacing: 0) {
                    EditorView(state: state)
                    if state.showTodos && isRegular { Divider(); TodoPanel(state: state).frame(width: 280) }
                }
            }
            Divider()
            StatsBar(state: state)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { showTemplates = true } label: {
                Image(systemName: "doc.badge.plus")
            }

            Button { state.focusMode.toggle() } label: {
                Image(systemName: state.focusMode ? "eye.fill" : "eye")
            }

            Button { state.showLineNumbers.toggle() } label: {
                Image(systemName: "list.number")
                    .foregroundStyle(state.showLineNumbers ? Color.accentColor : Color.primary)
            }

            Button { state.showPreview.toggle() } label: {
                Image(systemName: "rectangle.split.2x1")
                    .foregroundStyle(state.showPreview ? Color.accentColor : Color.primary)
            }

            Button {
                if isRegular {
                    state.showTodos.toggle()
                } else {
                    todoDetent = .medium
                    showTodoSheet.toggle()
                }
            } label: {
                Image(systemName: "checklist")
                    .foregroundStyle(todosVisible ? Color.accentColor : Color.primary)
            }

            if state.cursorInTable {
                Button {
                    state.openTableGrid?()
                } label: {
                    Image(systemName: "tablecells")
                        .foregroundStyle(state.editingTable != nil ? Color.accentColor : Color.primary)
                }
            }

            Button { state.showPastePreview.toggle() } label: {
                Image(systemName: "bandage")
                    .foregroundStyle(state.showPastePreview ? Color.accentColor : Color.primary)
            }

            Button { state.showOutline.toggle() } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(state.showOutline ? Color.accentColor : Color.primary)
            }

            Menu {
                Button { exportPDF() } label: { Label("Export as PDF…", systemImage: "doc.richtext") }
                Button { exportHTML() } label: { Label("Export as HTML…", systemImage: "chevron.left.forwardslash.chevron.right") }
                Button { Exporter.copyAsRichText(markdown: state.text) } label: { Label("Copy as Rich Text", systemImage: "doc.on.clipboard") }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(state.currentFileURL == nil)

            Menu {
                Picker("Appearance", selection: $state.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Section("Text size") {
                    Button { state.editorFontSize = min(28, state.editorFontSize + 1) } label: { Label("Bigger", systemImage: "textformat.size.larger") }
                    Button { state.editorFontSize = max(11, state.editorFontSize - 1) } label: { Label("Smaller", systemImage: "textformat.size.smaller") }
                }
                Toggle("Typewriter Scrolling", isOn: $state.typewriterScrolling)
                Toggle("Number Figures, Tables & Equations", isOn: $state.numberCaptions)
                Toggle("Celebrate Goal with Fireworks", isOn: $state.celebrateGoal)
                Divider()
                Menu {
                    Button("A Sentence") { state.insert(text: LoremIpsum.sentence() + " ") }
                    Button("A Paragraph") { state.insert(text: LoremIpsum.paragraph(canonicalStart: true) + "\n\n") }
                    Button("3 Paragraphs") { state.insert(text: LoremIpsum.paragraphs(3) + "\n\n") }
                    Button("5 Paragraphs") { state.insert(text: LoremIpsum.paragraphs(5) + "\n\n") }
                } label: { Label("Insert Lorem Ipsum", systemImage: "text.append") }
                .disabled(state.currentFileURL == nil)
                Divider()
                Button { state.showHelp = true } label: { Label("Help", systemImage: "questionmark.circle") }
                Button { state.showAbout = true } label: { Label("About Kitib", systemImage: "info.circle") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Export

    private func exportPDF() {
        state.saveCurrentFile()
        preparingExport = true
        Exporter.makePDF(markdown: state.text, title: docTitle, baseDir: baseDir,
                         withLineNumbers: state.printLineNumbers, numbered: state.numberCaptions) { url in
            preparingExport = false
            if let url { shareItem = ShareItem(url: url) }
        }
    }

    private func exportHTML() {
        state.saveCurrentFile()
        if let url = Exporter.makeHTMLFile(markdown: state.text, title: docTitle,
                                           baseDir: baseDir, numbered: state.numberCaptions) {
            shareItem = ShareItem(url: url)
        }
    }
}

// MARK: - Share sheet

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
