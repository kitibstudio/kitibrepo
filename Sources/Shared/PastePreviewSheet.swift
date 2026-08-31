import SwiftUI

// MARK: - PastePreviewSheet

/// Side-by-side diff sheet: raw paste on the left, healed on the right.
/// Lines that differ are color-coded (red = removed, green = added).
struct PastePreviewSheet: View {
    let raw: String
    let healed: String
    var onAccept: () -> Void
    var onReject: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Raw Paste")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Healed")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Diff body
            ScrollView {
                LazyVStack(spacing: 0) {
                    let diff = computeDiff(raw: raw, healed: healed)
                    ForEach(Array(diff.enumerated()), id: \.offset) { _, entry in
                        DiffRow(
                            status: entry.0,
                            rawText: entry.1,
                            healedText: entry.2,
                            colorScheme: colorScheme
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Keep Raw") { onReject() }
                    .keyboardShortcut(.return, modifiers: [.shift])

                Button("Paste Healed") { onAccept() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 280)
        #endif
    }
}

// MARK: - DiffRow

private struct DiffRow: View {
    let status: DiffLine
    let rawText: String?
    let healedText: String?
    let colorScheme: ColorScheme

    private var font: Font { .system(size: 11, design: .monospaced) }

    var body: some View {
        HStack(spacing: 0) {
            // Raw (left) column
            diffCell(
                text: rawText ?? "",
                isRemoved: status == .removed
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Healed (right) column
            diffCell(
                text: healedText ?? "",
                isAdded: status == .added
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 18)
    }

    @ViewBuilder
    private func diffCell(text: String, isRemoved: Bool = false, isAdded: Bool = false) -> some View {
        let bg: SwiftUI.Color? = {
            if isRemoved { return SwiftUI.Color.red.opacity(0.15) }
            if isAdded { return SwiftUI.Color.green.opacity(0.15) }
            return nil
        }()

        Text(text.isEmpty ? " " : text)
            .font(font)
            .strikethrough(isRemoved)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(bg)
    }
}
