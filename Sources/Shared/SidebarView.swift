import SwiftUI
import UniformTypeIdentifiers

/// Loads the dragged item's path from the pasteboard providers and moves it
/// into `dir`. Shared by folder rows and the root header.
@discardableResult
func acceptDrop(_ providers: [NSItemProvider], into dir: URL, state: AppState) -> Bool {
    var handled = false
    for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
        handled = true
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let path = object as? String else { return }
            DispatchQueue.main.async { state.move(itemID: path, to: dir) }
        }
    }
    return handled
}

struct SidebarView: View {
    @ObservedObject var state: AppState
    @State private var renamingItem: FileItem?
    @State private var renameText = ""
    @State private var deletingItem: FileItem?
    @State private var rootTargeted = false

    /// The List's own selection. It has to be real storage: a binding whose
    /// setter discards the value leaves SwiftUI's selection and the model
    /// disagreeing, and the next click on another row is dropped.
    @State private var selectedRowID: String?

    /// Which folders are open, by path. Held here rather than left to
    /// `DisclosureGroup`'s implicit state, because that is keyed on view
    /// identity and `refreshTree()` replaces every `FileItem` — which
    /// re-collapsed the whole tree on every save.
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if let root = state.rootItem {
                HStack {
                    Button { state.navigateUp() } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Up one level")
                    .accessibilityLabel("Up one level")
                    .disabled(!canNavigateUp)

                    // Folder navigation lives in one place: climb with the
                    // chevron, jump anywhere with the picker. iPad has no menu
                    // bar, so without this there is no in-app route to another
                    // folder at all.
                    Button { state.chooseFolder() } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Open another folder")
                    .accessibilityLabel("Open another folder")

                    Text(root.name.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { state.newFile(named: "Untitled", contents: "", in: newFileTargetFolder) } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New file")
                    Button { state.newFolder(named: "New Folder", in: newFileTargetFolder) } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New folder")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(rootTargeted ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear))
                // The menu bar and template picker cannot see the List
                // selection; they resolve it through this provider
                // (specs/new-file-in-folder.md). Re-registered on every
                // appearance; the closure reads the selection at call time.
                .onAppear {
                    state.newFileTargetProvider = { [weak state] in
                        guard let state else { return nil }
                        let item = selectedRowID.flatMap { findItem(id: $0, in: state.rootItem) }
                        return NewFileTarget.target(selectedURL: item?.url,
                                                    selectedIsDirectory: item?.isDirectory,
                                                    rootURL: state.rootURL)
                    }
                }
                #if os(macOS)
                .onDrop(of: [.plainText], isTargeted: $rootTargeted) { providers in
                    acceptDrop(providers, into: root.url, state: state)
                }
                #endif

                List(selection: $selectedRowID) {
                    OutlineRows(items: root.children ?? [], state: state,
                                selectedRowID: $selectedRowID,
                                expandedFolders: $expandedFolders,
                                renamingItem: $renamingItem, renameText: $renameText,
                                deletingItem: $deletingItem)
                }
                .listStyle(.sidebar)
                // Selecting a file row opens it; selecting a folder row only
                // highlights it. Guarded on identity so re-selecting the open
                // file does not reload it from disk under the writer.
                .onChange(of: selectedRowID) { id in
                    guard let id, id != state.selectedFileID,
                          let item = findItem(id: id, in: state.rootItem),
                          !item.isDirectory
                    else { return }
                    state.open(file: item)
                }
                // Keep the highlight honest when a file is opened from
                // elsewhere — recents, wiki-link, the iPhone browser.
                .onChange(of: state.selectedFileID) { id in
                    if let id, id != selectedRowID { selectedRowID = id }
                }

                // Smart folders — saved searches, listed as sidebar folders.
                Divider()
                HStack {
                    Text("SMART FOLDERS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { state.showSmartFolders = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New smart folder")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if state.smartFolders.isEmpty {
                    Text("No saved searches")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(state.smartFolders) { folder in
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(folder.name)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { state.openSmartFolder(id: folder.id) }
                        }
                    }
                    .padding(.bottom, 8)
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No folder open")
                        .foregroundStyle(.secondary)
                    Button("Open Folder…") { state.chooseFolder() }
                        .buttonStyle(.borderedProminent)
                    if let last = state.lastFolderName {
                        Button("Reopen “\(last)”") { state.reopenLastFolder() }
                    }
                }
                Spacer()
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { renamingItem != nil },
            set: { if !$0 { renamingItem = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let item = renamingItem { state.rename(item: item, to: renameText) }
                renamingItem = nil
            }
            Button("Cancel", role: .cancel) { renamingItem = nil }
        }
        .alert("Move to Trash?", isPresented: Binding(
            get: { deletingItem != nil },
            set: { if !$0 { deletingItem = nil } }
        )) {
            Button("Move to Trash", role: .destructive) {
                if let item = deletingItem { state.delete(item: item) }
                deletingItem = nil
            }
            Button("Cancel", role: .cancel) { deletingItem = nil }
        } message: {
            Text("“\(deletingItem?.name ?? "")” will be moved to the Trash.")
        }
        .sheet(isPresented: $state.showSmartFolders) {
            SmartFolderPanel(state: state) {
                state.showSmartFolders = false
            }
            .padding()
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 340)
            #else
            .presentationDetents([.medium, .large])
            #endif
        }
    }

    /// The root can move up unless it is already at the filesystem root,
    /// whose parent is itself. False when no folder is open.
    private var canNavigateUp: Bool {
        guard let root = state.rootURL else { return false }
        return root.deletingLastPathComponent().standardizedFileURL.path
            != root.standardizedFileURL.path
    }

    /// Where a new file/folder lands: the selected folder, the selected
    /// file's parent, or the root when nothing is selected
    /// (specs/new-file-in-folder.md). Resolved against the live tree so a
    /// stale selection falls back to the root.
    private var newFileTargetFolder: URL? {
        let item = selectedRowID.flatMap { findItem(id: $0, in: state.rootItem) }
        return NewFileTarget.target(selectedURL: item?.url,
                                    selectedIsDirectory: item?.isDirectory,
                                    rootURL: state.rootURL)
    }

    private func findItem(id: String, in item: FileItem?) -> FileItem? {
        guard let item else { return nil }
        if item.id == id { return item }
        for child in item.children ?? [] {
            if let found = findItem(id: id, in: child) { return found }
        }
        return nil
    }
}

// MARK: - Recursive rows

struct OutlineRows: View {
    let items: [FileItem]
    @ObservedObject var state: AppState
    @Binding var selectedRowID: String?
    @Binding var expandedFolders: Set<String>
    @Binding var renamingItem: FileItem?
    @Binding var renameText: String
    @Binding var deletingItem: FileItem?

    var body: some View {
        ForEach(items) { item in
            if item.isDirectory {
                FolderRow(item: item, state: state,
                          selectedRowID: $selectedRowID,
                          expandedFolders: $expandedFolders,
                          renamingItem: $renamingItem, renameText: $renameText,
                          deletingItem: $deletingItem)
            } else {
                Label {
                    Text(item.name)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(state.selectedFileID == item.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                .tag(item.id)
                .contentShape(Rectangle())
                // macOS only: the tap gesture and the drag source are mouse
                // workarounds. On macOS `.onDrag` swallows the mouse-down on a
                // quick click, so opening and the highlight are moved into an
                // explicit tap. On iOS neither applies — `.onDrag` starts from
                // a long press, and a custom tap races the List's own selection
                // (ui-conventions §3). iOS therefore relies on the List
                // selection binding + the `.onChange(of: selectedRowID)` below,
                // the same plain path the iPhone browser proves works.
                #if os(macOS)
                .simultaneousGesture(TapGesture().onEnded {
                    selectedRowID = item.id
                    if state.selectedFileID != item.id { state.open(file: item) }
                })
                .onDrag { NSItemProvider(object: item.url.path as NSString) }
                #endif
                .contextMenu {
                    rowMenu(for: item, state: state, renamingItem: $renamingItem,
                            renameText: $renameText, deletingItem: $deletingItem)
                }
            }
        }
    }
}

// MARK: - Folder row (drop target)

/// A folder row that accepts files/folders dropped onto it and highlights
/// while a drag hovers over it.
struct FolderRow: View {
    @ObservedObject var item: FileItem
    @ObservedObject var state: AppState
    @Binding var selectedRowID: String?
    @Binding var expandedFolders: Set<String>
    @Binding var renamingItem: FileItem?
    @Binding var renameText: String
    @Binding var deletingItem: FileItem?
    @State private var isTargeted = false

    /// Keyed by path, so it survives `refreshTree()` replacing every `FileItem`.
    ///
    /// Selection is moved here rather than in the label's tap because the
    /// chevron is `DisclosureGroup`'s own control: it never reaches the label
    /// gesture, and `.onDrag` keeps it from reaching the List. This setter is
    /// the one path both ways of opening a folder go through.
    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(item.id) },
            set: { open in
                if open { expandedFolders.insert(item.id) }
                else { expandedFolders.remove(item.id) }
                selectedRowID = item.id
            }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            OutlineRows(items: item.children ?? [], state: state,
                        selectedRowID: $selectedRowID,
                        expandedFolders: $expandedFolders,
                        renamingItem: $renamingItem, renameText: $renameText,
                        deletingItem: $deletingItem)
        } label: {
            Label(item.name, systemImage: "folder")
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isTargeted ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.clear))
                )
                .contentShape(Rectangle())
                // Clicking the name opens the folder, not just the chevron.
                // The highlight rides along in the `isExpanded` setter above,
                // which is also the chevron's only path — the List cannot be
                // relied on here because `.onDrag` below swallows the
                // mouse-down, the same trap the file rows work around.
                //
                // macOS only: a tap on an iOS list row already toggles the
                // DisclosureGroup, so a second toggle here would cancel it out.
                // Safe beside `.onDrag`: the macOS drag has a 4pt threshold, so
                // the two cannot race (ui-conventions §3).
                #if os(macOS)
                .simultaneousGesture(TapGesture().onEnded {
                    isExpanded.wrappedValue.toggle()
                })
                .onDrag { NSItemProvider(object: item.url.path as NSString) }
                .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
                    acceptDrop(providers, into: item.url, state: state)
                }
                #endif
                .contextMenu {
                    rowMenu(for: item, state: state, renamingItem: $renamingItem,
                            renameText: $renameText, deletingItem: $deletingItem)
                }
        }
    }
}

// MARK: - Shared context menu

@ViewBuilder
func rowMenu(for item: FileItem, state: AppState,
             renamingItem: Binding<FileItem?>, renameText: Binding<String>,
             deletingItem: Binding<FileItem?>) -> some View {
    if item.isDirectory {
        Button("New File Here") { state.newFile(named: "Untitled", contents: "", in: item.url) }
        Button("New Folder Here") { state.newFolder(named: "New Folder", in: item.url) }
        #if os(macOS)
        Button("Open in Terminal") { state.openTerminal(at: item.url) }
        #endif
        Divider()
    }
    Button("Rename…") {
        renameText.wrappedValue = item.name
        renamingItem.wrappedValue = item
    }
    Button("Duplicate") { state.duplicate(item: item) }
    #if os(macOS)
    Button("Reveal in Finder") { state.revealInFinder(item: item) }
    #endif
    Divider()
    Button("Move to Trash", role: .destructive) { deletingItem.wrappedValue = item }
}
