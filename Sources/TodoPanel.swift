import SwiftUI

/// Collapsible right-hand panel: a small to-do list scoped to the open
/// document. Items persist per file and survive renames.
struct TodoPanel: View {
    @ObservedObject var state: AppState
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
            Button { state.showTodos = false } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Hide to-do panel (⌘⇧D)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                .font(.system(size: 12))
                .focused($addFocused)
                .onSubmit {
                    let text = newText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    state.todos.append(TodoItem(text: text))
                    newText = ""
                    addFocused = true
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Row

private struct TodoRow: View {
    @Binding var item: TodoItem
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                item.done.toggle()
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.done ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(item.done ? "Mark as not done" : "Cross off")

            if item.done {
                Text(item.text)
                    .font(.system(size: 12))
                    .strikethrough()
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TextField("", text: $item.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Delete")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering = $0 }
    }
}
