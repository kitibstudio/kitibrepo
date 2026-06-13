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

    var body: some View {
        VStack(spacing: 0) {
            if let root = state.rootItem {
                HStack {
                    Text(root.name.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { state.newFile(named: "Untitled", contents: "") } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New file")
                    Button { state.newFolder(named: "New Folder") } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New folder")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(rootTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
                .onDrop(of: [.plainText], isTargeted: $rootTargeted) { providers in
                    acceptDrop(providers, into: root.url, state: state)
                }

                List(selection: Binding(
                    get: { state.selectedFileID },
                    set: { id in
                        if let id, let item = findItem(id: id, in: state.rootItem) {
                            if !item.isDirectory { state.open(file: item) }
                        }
                    }
                )) {
                    OutlineRows(items: root.children ?? [], state: state,
                                renamingItem: $renamingItem, renameText: $renameText,
                                deletingItem: $deletingItem)
                }
                .listStyle(.sidebar)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No folder open")
                        .foregroundStyle(.secondary)
                    Button("Open Folder…") { state.chooseFolder() }
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
    @Binding var renamingItem: FileItem?
    @Binding var renameText: String
    @Binding var deletingItem: FileItem?

    var body: some View {
        ForEach(items) { item in
            if item.isDirectory {
                FolderRow(item: item, state: state,
                          renamingItem: $renamingItem, renameText: $renameText,
                          deletingItem: $deletingItem)
            } else {
                Label {
                    Text(item.name)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(state.selectedFileID == item.id ? Color.accentColor : Color.secondary)
                }
                .tag(item.id)
                .contentShape(Rectangle())
                // Open from an explicit tap rather than relying solely on the
                // List selection binding: `.onDrag` frequently swallows the
                // mouse-down on a quick click, so selection-driven opening was
                // unreliable. This fires on any click for a file that isn't
                // already open, regardless of selection state.
                .simultaneousGesture(TapGesture().onEnded {
                    if state.selectedFileID != item.id { state.open(file: item) }
                })
                .onDrag { NSItemProvider(object: item.url.path as NSString) }
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
    @Binding var renamingItem: FileItem?
    @Binding var renameText: String
    @Binding var deletingItem: FileItem?
    @State private var isTargeted = false

    var body: some View {
        DisclosureGroup {
            OutlineRows(items: item.children ?? [], state: state,
                        renamingItem: $renamingItem, renameText: $renameText,
                        deletingItem: $deletingItem)
        } label: {
            Label(item.name, systemImage: "folder")
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isTargeted ? Color.accentColor.opacity(0.22) : Color.clear)
                )
                .contentShape(Rectangle())
                .onDrag { NSItemProvider(object: item.url.path as NSString) }
                .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
                    acceptDrop(providers, into: item.url, state: state)
                }
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
        Button("Open in Terminal") { state.openTerminal(at: item.url) }
        Divider()
    }
    Button("Rename…") {
        renameText.wrappedValue = item.name
        renamingItem.wrappedValue = item
    }
    Button("Reveal in Finder") { state.revealInFinder(item: item) }
    Divider()
    Button("Move to Trash", role: .destructive) { deletingItem.wrappedValue = item }
}
