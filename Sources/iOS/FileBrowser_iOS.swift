import SwiftUI

//  FileBrowser_iOS.swift
//  iPhone (compact width) file navigation.
//
//  The shared `SidebarView` outline is built for a wide column and a pointer:
//  nested DisclosureGroups indent past the edge of a phone screen, and rename /
//  duplicate / delete hide behind long-press menus. On compact width this
//  replaces it with the Files.app model — tap a folder to push into it, with a
//  breadcrumb to climb back out, recursive search, and swipe actions.
//
//  Navigation is by *path string*, never by `FileItem` reference: every
//  mutation calls `AppState.refreshTree()`, which rebuilds the entire tree, so
//  a held `FileItem` is detached the moment the user creates or renames
//  anything. Each screen re-resolves its directory from `state.rootItem` on
//  every render instead.

// MARK: - Routes

enum BrowserRoute: Hashable {
    case folder(String)   // absolute directory path
    case document         // the editor
}

// MARK: - Adaptive shell

/// Picks the navigation model for the current size class: push-navigation on
/// iPhone, the two-column split view (with the outline sidebar) on iPad.
struct AdaptiveShell: View {
    @ObservedObject var state: AppState
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var path: [BrowserRoute] = []

    var body: some View {
        if hSize == .compact {
            NavigationStack(path: $path) {
                FileBrowser(state: state, directory: state.rootURL, path: $path)
                    .navigationDestination(for: BrowserRoute.self) { route in
                        switch route {
                        case .folder(let dir):
                            FileBrowser(state: state,
                                        directory: URL(fileURLWithPath: dir),
                                        path: $path)
                        case .document:
                            DetailView(state: state)
                        }
                    }
            }
            // Opening a different root invalidates every pushed screen.
            .onChange(of: state.rootURL) { _ in path = [] }
        } else {
            NavigationSplitView {
                SidebarView(state: state)
            } detail: {
                DetailView(state: state)
            }
        }
    }
}

// MARK: - Browser

struct FileBrowser: View {
    @ObservedObject var state: AppState
    let directory: URL?
    @Binding var path: [BrowserRoute]

    @State private var search = ""
    @State private var renamingItem: FileItem?
    @State private var renameText = ""
    @State private var deletingItem: FileItem?
    @State private var newFolderName = ""
    @State private var showNewFolder = false

    // MARK: Derived state

    private var isRoot: Bool {
        directory?.standardizedFileURL.path == state.rootURL?.standardizedFileURL.path
    }

    /// Re-resolved every render — see the note at the top of this file.
    private var current: FileItem? {
        guard let directory else { return nil }
        return Self.find(path: directory.standardizedFileURL.path, in: state.rootItem)
    }

    private var children: [FileItem] { current?.children ?? [] }

    private var query: String {
        search.trimmingCharacters(in: .whitespaces)
    }

    private var searching: Bool { !query.isEmpty }

    /// Every descendant of the current folder whose name matches, folders first.
    private var matches: [FileItem] {
        guard let current else { return [] }
        var found: [FileItem] = []
        func walk(_ item: FileItem) {
            for child in item.children ?? [] {
                if child.name.localizedCaseInsensitiveContains(query) { found.append(child) }
                if child.isDirectory { walk(child) }
            }
        }
        walk(current)
        return found.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var title: String {
        directory?.lastPathComponent ?? "Kitib"
    }

    // MARK: Body

    var body: some View {
        Group {
            if state.rootURL == nil {
                noFolder
            } else {
                list
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .searchable(text: $search, prompt: "Search this folder")
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
        .alert("Delete?", isPresented: Binding(
            get: { deletingItem != nil },
            set: { if !$0 { deletingItem = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = deletingItem { state.delete(item: item) }
                deletingItem = nil
            }
            Button("Cancel", role: .cancel) { deletingItem = nil }
        } message: {
            // iOS has no Trash — Platform.delete() removes outright.
            Text("“\(deletingItem?.name ?? "")” will be deleted. This can't be undone.")
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { state.newFolder(named: name, in: directory) }
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        List {
            if searching {
                if matches.isEmpty {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Results") {
                        ForEach(matches) { item in
                            row(for: item, showingLocation: true)
                        }
                    }
                }
            } else {
                if isRoot, !state.recentFiles.isEmpty {
                    Section("Recents") {
                        ForEach(state.recentFiles, id: \.path) { url in
                            recentRow(url)
                        }
                    }
                }
                Section {
                    if children.isEmpty {
                        Text("Empty folder")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(children) { item in
                            row(for: item, showingLocation: false)
                        }
                    }
                } header: {
                    // Only worth a header when it has to be told apart from Recents.
                    if isRoot && !state.recentFiles.isEmpty { Text("Folder") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isRoot && !searching { breadcrumb }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(for item: FileItem, showingLocation: Bool) -> some View {
        Group {
            if item.isDirectory {
                NavigationLink(value: BrowserRoute.folder(item.url.path)) {
                    rowLabel(item, showingLocation: showingLocation)
                }
            } else {
                Button {
                    state.open(file: item)
                    path.append(.document)
                } label: {
                    rowLabel(item, showingLocation: showingLocation)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deletingItem = item } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                renameText = item.name
                renamingItem = item
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.indigo)
            Button {
                state.duplicate(item: item)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.gray)
        }
        .contextMenu {
            rowMenu(for: item, state: state, renamingItem: $renamingItem,
                    renameText: $renameText, deletingItem: $deletingItem)
        }
    }

    private func rowLabel(_ item: FileItem, showingLocation: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.text")
                .font(.system(size: 17))
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .foregroundStyle(.primary)
                if showingLocation, let where_ = relativeParent(of: item.url) {
                    Text(where_)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func recentRow(_ url: URL) -> some View {
        Button {
            state.open(path: url.path)
            path.append(.document)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.lastPathComponent)
                        .foregroundStyle(.primary)
                    if let where_ = relativeParent(of: url) {
                        Text(where_)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Breadcrumb

    /// Root → … → current, as (display name, absolute path) pairs.
    private var trail: [(name: String, path: String)] {
        guard let root = state.rootURL?.standardizedFileURL,
              let dir = directory?.standardizedFileURL else { return [] }
        var out: [(String, String)] = [(root.lastPathComponent, root.path)]
        let rootComps = root.pathComponents
        let dirComps = dir.pathComponents
        guard dirComps.count > rootComps.count else { return out }
        var acc = root
        for comp in dirComps[rootComps.count...] {
            acc.appendPathComponent(comp)
            out.append((comp, acc.path))
        }
        return out
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(trail.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        // Crumb 0 is the root (empty stack); each subsequent
                        // crumb maps 1:1 onto a pushed .folder route.
                        path = trail.dropFirst().prefix(index).map { BrowserRoute.folder($0.path) }
                    } label: {
                        Text(crumb.name)
                            .font(.system(size: 13, weight: index == trail.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == trail.count - 1 ? Color.primary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == trail.count - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: Empty root

    private var noFolder: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No folder open")
                .foregroundStyle(.secondary)
            Button("Open Folder…") { state.chooseFolder() }
                .buttonStyle(.borderedProminent)
            if let last = state.lastFolderName {
                Button("Reopen “\(last)”") { state.reopenLastFolder() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    state.newFile(named: "Untitled", contents: "", in: directory)
                    path.append(.document)
                } label: { Label("New Document", systemImage: "doc.badge.plus") }

                Button {
                    newFolderName = "New Folder"
                    showNewFolder = true
                } label: { Label("New Folder…", systemImage: "folder.badge.plus") }

                if isRoot {
                    Divider()
                    Button {
                        state.chooseFolder()
                    } label: { Label("Open Another Folder…", systemImage: "folder") }

                    if !state.recentFiles.isEmpty {
                        Button(role: .destructive) {
                            state.clearRecents()
                        } label: { Label("Clear Recents", systemImage: "clock.badge.xmark") }
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .disabled(state.rootURL == nil)
        }
    }

    // MARK: Helpers

    /// Path of `url`'s parent relative to the open root, for search/recent
    /// subtitles. Nil when the parent *is* the root (no useful context to add).
    private func relativeParent(of url: URL) -> String? {
        guard let root = state.rootURL?.standardizedFileURL else { return nil }
        let parent = url.standardizedFileURL.deletingLastPathComponent()
        guard parent.path != root.path else { return nil }
        let rootCount = root.pathComponents.count
        let comps = parent.pathComponents
        guard comps.count > rootCount else { return nil }
        return comps[rootCount...].joined(separator: " › ")
    }

    static func find(path: String, in item: FileItem?) -> FileItem? {
        guard let item else { return nil }
        if item.url.standardizedFileURL.path == path { return item }
        for child in item.children ?? [] where child.isDirectory {
            if let found = find(path: path, in: child) { return found }
        }
        return nil
    }
}
