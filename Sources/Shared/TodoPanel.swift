import SwiftUI

/// Collapsible right-hand panel: a small to-do list scoped to the open
/// document. Items persist per file and survive renames.
struct TodoPanel: View {
    @ObservedObject var state: AppState

    /// Overrides the header's close action. The side panel (macOS/iPad) leaves
    /// this nil and simply hides itself; the iPhone sheet uses it to dismiss.
    var onClose: (() -> Void)? = nil
    /// Fired when the user taps into the "add" field — lets a sheet presenter
    /// grow to a taller detent so the keyboard doesn't cover the field.
    var onBeginAdding: (() -> Void)? = nil

    @State private var newText = ""
    @FocusState private var addFocused: Bool

    private var doneCount: Int { state.todos.filter(\.done).count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.todos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach($state.todos) { $item in
                            TodoRow(item: $item) {
                                state.todos.removeAll { $0.id == item.id }
                            }
                        }
                    }
                    .padding(8)
                }
            }
            Divider()
            addBar
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("To-Do")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if !state.todos.isEmpty {
                Text("\(doneCount)/\(state.todos.count)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if doneCount > 0 {
                Button("Clear done") { state.todos.removeAll(where: \.done) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .help("Remove all crossed-off items")
            }
            Button {
                if let onClose { onClose() } else { state.showTodos = false }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: Metrics.hit, height: Metrics.hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Hide to-do panel (⌘⇧D)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Metrics.touch ? 2 : 8)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No to-dos for this document")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            TextField("Add a to-do…", text: $newText)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.text))
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit {
                    let text = newText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    state.todos.append(TodoItem(text: text))
                    newText = ""
                    addFocused = true
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Metrics.touch ? 12 : 8)
        .onChange(of: addFocused) { focused in
            if focused { onBeginAdding?() }
        }
    }
}

// MARK: - Platform metrics
//
// The panel is shared between the Mac (pointer, dense) and iOS (touch, needs
// ~44pt targets). These constants keep the branching in one place.

private enum Metrics {
    #if os(iOS)
    static let touch = true
    static let hit: CGFloat = 44
    static let text: CGFloat = 15
    static let icon: CGFloat = 17
    static let rowPad: CGFloat = 4
    static let rowAlignment: VerticalAlignment = .center
    #else
    static let touch = false
    static let hit: CGFloat = 18
    static let text: CGFloat = 12
    static let icon: CGFloat = 13
    static let rowPad: CGFloat = 4
    static let rowAlignment: VerticalAlignment = .firstTextBaseline
    #endif
}

// MARK: - Row

private struct TodoRow: View {
    @Binding var item: TodoItem
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: Metrics.rowAlignment, spacing: 8) {
            Button {
                item.done.toggle()
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: Metrics.icon))
                    .foregroundStyle(item.done ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: Metrics.hit, height: Metrics.hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.done ? "Mark as not done" : "Cross off")

            if item.done {
                Text(item.text)
                    .font(.system(size: Metrics.text))
                    .strikethrough()
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TextField("", text: $item.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: Metrics.text))
            }

            // On touch there is no hover, so the button must always be visible
            // or deletion is impossible.
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: Metrics.touch ? 15 : 10))
                    .foregroundStyle(.secondary)
                    .frame(width: Metrics.hit, height: Metrics.hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(Metrics.touch || hovering ? 1 : 0)
            .help("Delete")
        }
        .padding(.vertical, Metrics.rowPad)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? AnyShapeStyle(.primary.opacity(0.05)) : AnyShapeStyle(.clear))
        )
        .onHover { hovering = $0 }
    }
}
