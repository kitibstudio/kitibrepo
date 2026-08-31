import SwiftUI
import UniformTypeIdentifiers

/// Shared app shell. The detail pane is provided per-platform by `DetailView`
/// (see macOS/DetailView_macOS.swift and iOS/DetailView_iOS.swift).
///
/// File navigation splits by form factor: macOS and iPad use the two-column
/// split view with the `SidebarView` outline, while iPhone (compact width) uses
/// the push-navigation browser in iOS/FileBrowser_iOS.swift — the nested
/// outline doesn't fit a phone. `AdaptiveShell` makes that choice.
struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        shell
        .sheet(isPresented: $state.showHelp) { helpSheet }
        .sheet(isPresented: $state.showAbout) { AboutView() }
        .preferredColorScheme(state.colorScheme)
        .fileImporter(
            isPresented: $state.showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                state.openFolder(url)
            }
        }
        #if os(macOS)
        .onChange(of: state.goalCelebration) { n in
            if n > 0 { FireworksController.shared.celebrate() }
        }
        #endif
    }

    /// `HelpView` declares no size of its own: macOS gets a resizable window
    /// whose size is remembered, iOS gets detents (D49). The difference lives
    /// here, at the presentation site, not inside the shared view.
    @ViewBuilder
    private var helpSheet: some View {
        #if os(macOS)
        HelpView()
            .resizableSheet(
                storageKey: "helpSheet",
                minWidth: 460,
                minHeight: 420,
                defaultWidth: 700,
                defaultHeight: 640
            )
        #else
        HelpView()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        #endif
    }

    @ViewBuilder
    private var shell: some View {
        #if os(iOS)
        AdaptiveShell(state: state)
        #else
        NavigationSplitView {
            SidebarView(state: state)
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 380)
        } detail: {
            DetailView(state: state)
        }
        #endif
    }
}

// MARK: - Shared empty state

struct EditorEmptyState: View {
    @ObservedObject var state: AppState
    var onNew: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Select a file, or start something new")
                .foregroundStyle(.secondary)
            HStack {
                if state.rootURL == nil {
                    Button("Open Folder…") { state.chooseFolder() }
                        .buttonStyle(.borderedProminent)
                    if let last = state.lastFolderName {
                        Button("Reopen “\(last)”") { state.reopenLastFolder() }
                    }
                } else {
                    Button("New Document") { onNew() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared template picker

struct TemplatePicker: View {
    @ObservedObject var state: AppState
    var onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("New Document")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(Templates.all) { template in
                Button {
                    state.newFile(named: template.filename, contents: template.body, in: state.newFileTarget)
                    if template.suggestedGoal > 0 { state.setWordGoal(template.suggestedGoal) }
                    onPick()
                } label: {
                    HStack {
                        Image(systemName: template.icon)
                            .frame(width: 22)
                            .foregroundStyle(.tint)
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
}
/bin/bash: line 5: /var/folders/pl/5g54201x4qv3vvysynq1v_5c0000gp/T/hermes-cwd-8d8a6973c2b0.txt: No space left on device
