import SwiftUI

/// Cross-platform smart-folder panel: lists saved searches, lets the user
/// add/edit/delete them, and shows live results for the selected folder.
/// Clicking a result opens the file in the editor.
struct SmartFolderPanel: View {
    @ObservedObject var state: AppState
    var onClose: (() -> Void)?

    @State private var showFormSheet = false
    @State private var editingFolder: SmartFolder?
    @State private var hoveredFolderID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            if state.smartFolders.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    folderList
                        .frame(width: 210)
                    Divider().opacity(0.5)
                    resultsPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if let onClose {
                Divider().opacity(0.5)
                HStack {
                    Spacer()
                    Button("Done", action: onClose)
                        .keyboardShortcut(.escape)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .sheet(isPresented: $showFormSheet) {
            SmartFolderForm(
                isEditing: editingFolder != nil,
                initialName: editingFolder?.name ?? "",
                initialQuery: editingFolder?.query ?? "",
                matchCount: { state.searchSmartFolder($0).count },
                onCancel: { showFormSheet = false },
                onCommit: { name, query in
                    if let folder = editingFolder {
                        state.updateSmartFolder(id: folder.id, name: name, query: query)
                    } else {
                        state.addSmartFolder(name: name, query: query)
                    }
                    showFormSheet = false
                }
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Smart Folders")
                .font(.system(.headline, design: .rounded))
            if !state.smartFolders.isEmpty {
                Text("\(state.smartFolders.count)")
                    .font(.system(.caption, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(SwiftUI.Color.primary.opacity(0.07)))
            }
            Spacer(minLength: 0)
            Button(action: beginAdd) {
                Label("New", systemImage: "plus")
                    .font(.callout)
                    .foregroundStyle(SwiftUI.Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("New smart folder")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No smart folders yet")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
            Text("Save a search once and return to it in a click.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button(action: beginAdd) {
                Label("New Smart Folder", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: Folder list

    private var folderList: some View {
        List {
            ForEach(state.smartFolders) { folder in
                folderRow(folder)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    #if os(iOS)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            state.deleteSmartFolder(id: folder.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { beginEdit(folder) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(SwiftUI.Color.accentColor)
                    }
                    #endif
            }
        }
        .listStyle(.sidebar)
    }

    private func folderRow(_ folder: SmartFolder) -> some View {
        let isActive = state.activeSmartFolderID == folder.id
        let isHovered = hoveredFolderID == folder.id
        let count = state.searchSmartFolder(folder.query).count

        return HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? SwiftUI.Color.accentColor : SwiftUI.Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.name)
                    .lineLimit(1)
                Text(folder.query)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // The count is the honest signal that a saved search still works.
            // It is replaced by the actions on hover so the row never grows.
            if isHovered {
                Menu {
                    Button("Edit…") { beginEdit(folder) }
                    Button("Duplicate") {
                        state.addSmartFolder(name: folder.name + " copy",
                                             query: folder.query)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        state.deleteSmartFolder(id: folder.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            } else if count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? SwiftUI.Color.accentColor.opacity(0.16)
                               : SwiftUI.Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { state.activeSmartFolderID = folder.id }
        .onHover { inside in
            hoveredFolderID = inside ? folder.id
                                     : (hoveredFolderID == folder.id ? nil : hoveredFolderID)
        }
        .contextMenu {
            Button("Edit…") { beginEdit(folder) }
            Button("Duplicate") {
                state.addSmartFolder(name: folder.name + " copy", query: folder.query)
            }
            Divider()
            Button("Delete", role: .destructive) {
                state.deleteSmartFolder(id: folder.id)
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsPane: some View {
        if let folder = state.smartFolders.first(where: { $0.id == state.activeSmartFolderID }) {
            let results = state.activeSmartFolderResults

            VStack(spacing: 0) {
                // Query bar — the query is editable from where it is read.
                HStack(spacing: 8) {
                    Text(folder.query)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(SwiftUI.Color.primary.opacity(0.06))
                        )
                    Spacer(minLength: 4)
                    Text(results.isEmpty
                         ? "No matches"
                         : "\(results.count) match\(results.count == 1 ? "" : "es")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button("Edit") { beginEdit(folder) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(SwiftUI.Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().opacity(0.5)

                if results.isEmpty {
                    noResults(for: folder)
                } else {
                    List(results, id: \.id) { hit in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.title ?? hit.id)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            snippetText(hit.snippet)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { state.openSearchHit(hit) }
                    }
                    .listStyle(.inset)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Pick a smart folder")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Empty results are ambiguous — a query can also be malformed — so this
    /// says which one it is rather than leaving the writer to guess.
    @ViewBuilder
    private func noResults(for folder: SmartFolder) -> some View {
        VStack(spacing: 8) {
            if let term = QueryLint.bareHyphenatedTerm(in: folder.query) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("“\(term)” needs quotes")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                Text("A hyphen has a meaning of its own in a query.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button("Fix the query") {
                    state.updateSmartFolder(
                        id: folder.id,
                        name: folder.name,
                        query: QueryLint.quoting(term, in: folder.query)
                    )
                }
                .padding(.top, 2)
            } else {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No matches")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Nothing in this folder contains those words.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button("Edit the query") { beginEdit(folder) }
                    .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    /// Renders the FTS5 snippet, converting <b>…</b> markers to bold runs.
    private func snippetText(_ snippet: String) -> Text {
        var result = Text("")
        let parts = snippet.components(separatedBy: "<b>")
        for (i, part) in parts.enumerated() {
            if i == 0 {
                result = result + Text(part)
            } else {
                let boldSplit = part.components(separatedBy: "</b>")
                result = result + Text(boldSplit.first ?? "").bold()
                if boldSplit.count > 1 {
                    result = result + Text(boldSplit[1])
                }
            }
        }
        return result.font(.caption).foregroundColor(.secondary)
    }

    // MARK: Form entry points

    private func beginAdd() {
        editingFolder = nil
        showFormSheet = true
    }

    private func beginEdit(_ folder: SmartFolder) {
        editingFolder = folder
        showFormSheet = true
    }
}

// MARK: - Add / edit form

/// Its own view so that typing a query re-renders the form only — the folder
/// list runs a search per row, and it should not run one per keystroke.
private struct SmartFolderForm: View {
    let isEditing: Bool
    let matchCount: (String) -> Int
    let onCancel: () -> Void
    let onCommit: (String, String) -> Void

    @State private var name: String
    @State private var query: String

    init(isEditing: Bool,
         initialName: String,
         initialQuery: String,
         matchCount: @escaping (String) -> Int,
         onCancel: @escaping () -> Void,
         onCommit: @escaping (String, String) -> Void) {
        self.isEditing = isEditing
        self.matchCount = matchCount
        self.onCancel = onCancel
        self.onCommit = onCommit
        _name = State(initialValue: initialName)
        _query = State(initialValue: initialQuery)
    }

    /// Deliberately about writing, not about any one trade — the panel is for
    /// whoever is holding it.
    private static let examples: [(pattern: String, meaning: String)] = [
        ("draft revision",      "both words"),
        ("draft OR outline",    "either word"),
        ("chapter NOT appendix", "leave a word out"),
        ("\"opening paragraph\"", "that exact phrase")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "Edit Smart Folder" : "New Smart Folder")
                .font(.system(.headline, design: .rounded))

            field("Name", text: $name, prompt: "Chapters in progress")
            field("Search for", text: $query, prompt: "draft revision")

            status

            examplesSection

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Button(isEditing ? "Save" : "Add") {
                    onCommit(trimmedName, trimmedQuery)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty || trimmedQuery.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
    }

    private func field(_ label: String,
                       text: Binding<String>,
                       prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
        }
    }

    /// One quiet line that answers "will this find anything?" while typing —
    /// and only mentions hyphens when there is a hyphen to mention.
    @ViewBuilder
    private var status: some View {
        if trimmedQuery.isEmpty {
            statusLine("magnifyingglass",
                       "Matches appear here as you type.",
                       tone: .tertiary)
        } else if let term = QueryLint.bareHyphenatedTerm(in: trimmedQuery) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 10, weight: .semibold))
                Text("Put “\(term)” in quotes — a hyphen means something else here.")
                    .font(.caption)
                Button("Add quotes") {
                    query = QueryLint.quoting(term, in: query)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(SwiftUI.Color.accentColor)
            }
            .foregroundStyle(.secondary)
        } else {
            let n = matchCount(trimmedQuery)
            statusLine(n > 0 ? "checkmark.circle" : "circle.dashed",
                       n > 0
                         ? "\(n) match\(n == 1 ? "" : "es") right now"
                         : "Nothing matches this yet.",
                       tone: .secondary)
        }
    }

    private func statusLine(_ icon: String,
                            _ text: String,
                            tone: HierarchicalShapeStyle) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tone)
    }

    /// Tappable, because an example you can use is worth more than one you
    /// have to retype.
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Try")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ForEach(Self.examples, id: \.pattern) { example in
                Button {
                    query = example.pattern
                } label: {
                    HStack(spacing: 10) {
                        Text(example.pattern)
                            .font(.caption.monospaced())
                            .foregroundStyle(SwiftUI.Color.primary)
                            // Fixed column so the meanings line up instead of
                            // stepping raggedly across the sheet.
                            .frame(width: 170, alignment: .leading)
                        Text(example.meaning)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }
}
