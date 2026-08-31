import SwiftUI
import UniformTypeIdentifiers

// MARK: - Cell identifier for FocusState

/// `row == -1` identifies a header cell; `row >= 0` identifies a data cell.
private struct CellID: Hashable {
    let row: Int
    let col: Int
    var isHeader: Bool { row == -1 }
}

// MARK: - Drop delegates

private struct RowDropDelegate: DropDelegate {
    let rowIdx: Int
    @Binding var table: MarkdownTable
    @Binding var dragSource: Int?

    func performDrop(info: DropInfo) -> Bool {
        guard let source = dragSource, source != rowIdx else { return false }
        var t = table
        t.moveRow(from: source, to: rowIdx)
        table = t
        dragSource = nil
        return true
    }

    func dropEntered(info: DropInfo) {}
    func dropUpdated(info: DropInfo) -> DropProposal {
        DropProposal(operation: .move)
    }
}

private struct ColDropDelegate: DropDelegate {
    let colIdx: Int
    @Binding var table: MarkdownTable
    @Binding var dragSource: Int?

    func performDrop(info: DropInfo) -> Bool {
        guard let source = dragSource, source != colIdx else { return false }
        var t = table
        t.moveColumn(from: source, to: colIdx)
        table = t
        dragSource = nil
        return true
    }

    func dropEntered(info: DropInfo) {}
    func dropUpdated(info: DropInfo) -> DropProposal {
        DropProposal(operation: .move)
    }
}

// MARK: - Metrics

/// One place for every number the grid is drawn with, so the header row, the
/// data rows and the gutter cannot drift apart by a pixel.
private enum Metrics {
    static let gutterWidth: CGFloat = 34
    static let cellHPadding: CGFloat = 10
    static let cellVPadding: CGFloat = 7
    /// Width of one monospaced character at the body size, near enough to size a
    /// column from its content. Over-estimating costs a little slack; under-
    /// estimating truncates, which is the thing being fixed.
    static let characterWidth: CGFloat = 8
    static let minColumnWidth: CGFloat = 96
    static let maxColumnWidth: CGFloat = 340
    static let hairline: CGFloat = 1
    static let gridInset: CGFloat = 16
}

// MARK: - TableGridEditor

/// Fully editable grid: click any cell, add/delete rows and columns, drag to
/// reorder them. Cmd+Return commits and closes.
///
/// The layout is deliberately quiet. An earlier version put a drag handle and a
/// delete button inside every header cell and every row, which read as clutter
/// and — worse — ate the width the content needed, so columns truncated at
/// `Descrip…` while two icons per row sat in the space. Those commands now live
/// in a menu on the row gutter and the column header: reachable in one click,
/// invisible until wanted, and costing no horizontal space.
///
/// Zero platform conditionals (spec criterion 4). `onHover` simply never fires
/// on a touch-only device, where the menus are reached by their buttons instead.
struct TableGridEditor: View {
    @Binding var table: MarkdownTable
    let onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedCell: CellID?
    @State private var dragSourceRow: Int? = nil
    @State private var dragSourceCol: Int? = nil
    @State private var hoveredRow: Int? = nil
    @State private var hoveredColumn: Int? = nil
    /// Width of the scroll view's viewport, so the columns can share out the
    /// room the window actually has.
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            gridScroll
        }
        .background(SwiftUI.Color.gridSurface)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Table Editor")
                    .font(.headline)
                Text(sizeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Menu {
                Button("Insert Above") { addRow(above: true) }
                Button("Insert Below") { addRow(above: false) }
            } label: {
                Label("Row", systemImage: "plus")
            }
            .menuStyle(.button)
            .fixedSize()

            Menu {
                Button("Insert Left") { addColumn(left: true) }
                Button("Insert Right") { addColumn(left: false) }
            } label: {
                Label("Column", systemImage: "plus")
            }
            .menuStyle(.button)
            .fixedSize()

            Button("Done") {
                onCommit()
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sizeSummary: String {
        let rows = table.rows.count
        let cols = table.columnCount
        return "\(rows) \(rows == 1 ? "row" : "rows") × \(cols) \(cols == 1 ? "column" : "columns")"
    }

    // MARK: - Grid

    private var gridScroll: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIdx, _ in
                    dataRow(rowIdx: rowIdx)
                        .onDrag {
                            dragSourceRow = rowIdx
                            return NSItemProvider(object: "\(rowIdx)" as NSString)
                        }
                        .onDrop(of: [.text],
                                delegate: RowDropDelegate(
                                    rowIdx: rowIdx,
                                    table: $table,
                                    dragSource: $dragSourceRow
                                ))
                }
            }
            .padding(Metrics.gridInset)
        }
        .background {
            GeometryReader { proxy in
                SwiftUI.Color.clear
                    .preference(key: ViewportWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(ViewportWidthKey.self) { viewportWidth = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A column is as wide as its widest cell, within bounds. Fixed 90–250pt
    /// columns were what truncated `Description` to `Descrip…` no matter how
    /// much room the window had.
    private func intrinsicColumnWidth(_ col: Int) -> CGFloat {
        var longest = col < table.headers.count ? table.headers[col].count : 0
        for row in table.rows where col < row.count {
            longest = max(longest, row[col].count)
        }
        let measured = CGFloat(longest) * Metrics.characterWidth + Metrics.cellHPadding * 2
        return min(max(measured, Metrics.minColumnWidth), Metrics.maxColumnWidth)
    }

    /// The width a column is actually drawn at: its intrinsic width plus an
    /// equal share of whatever room is left over, so a narrow table fills the
    /// window instead of huddling in the left third of it. Slack is shared
    /// equally rather than proportionally — proportional sharing makes a wide
    /// column run away with the space — and no column grows past its maximum,
    /// so a single-column table does not become one enormous field.
    private func columnWidth(_ col: Int) -> CGFloat {
        let base = intrinsicColumnWidth(col)
        guard viewportWidth > 0, table.columnCount > 0 else { return base }
        let intrinsicTotal = (0..<table.columnCount).reduce(0) { $0 + intrinsicColumnWidth($1) }
        let available = viewportWidth - Metrics.gutterWidth - Metrics.gridInset * 2
        guard available > intrinsicTotal else { return base }
        let slack = (available - intrinsicTotal) / CGFloat(table.columnCount)
        return min(base + slack, Metrics.maxColumnWidth)
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(spacing: 0) {
            cornerCell
            ForEach(Array(table.headers.enumerated()), id: \.offset) { colIdx, _ in
                headerCell(col: colIdx)
            }
        }
        .background(SwiftUI.Color.headerFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SwiftUI.Color.headerRule)
                .frame(height: Metrics.hairline)
        }
    }

    /// Height 1, not unconstrained: `Color.clear` is greedy, and left to itself
    /// it stretches the header row to the full height of the sheet with the
    /// header text stranded in the middle of it.
    private var cornerCell: some View {
        SwiftUI.Color.clear
            .frame(width: Metrics.gutterWidth, height: 1)
    }

    private func headerCell(col: Int) -> some View {
        let cellID = CellID(row: -1, col: col)
        return cellBox(col: col, isFocused: focusedCell == cellID) {
            HStack(spacing: 6) {
                TextField("", text: headerBinding(forCol: col))
                    .font(.system(.body, design: .monospaced).bold())
                    .textFieldStyle(.plain)
                    .focused($focusedCell, equals: cellID)
                    .onSubmit { focusedCell = nextCell(after: cellID) }
                    .modifier(tabMod(for: cellID))

                if hoveredColumn == col || focusedCell?.col == col {
                    columnMenu(col: col)
                } else {
                    Image(systemName: table.alignments[col].indicatorSymbol)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .help(table.alignments[col].indicatorLabel)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hoveredColumn = $0 ? col : (hoveredColumn == col ? nil : hoveredColumn) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in DispatchQueue.main.async { focusedCell = cellID } }
        )
        .onDrag {
            dragSourceCol = col
            return NSItemProvider(object: "col-\(col)" as NSString)
        }
        .onDrop(of: [.text],
                delegate: ColDropDelegate(
                    colIdx: col,
                    table: $table,
                    dragSource: $dragSourceCol
                ))
        .contextMenu { columnCommands(col: col) }
    }

    private func columnMenu(col: Int) -> some View {
        Menu {
            columnCommands(col: col)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Column actions")
    }

    @ViewBuilder
    private func columnCommands(col: Int) -> some View {
        Button("Insert Column Left") { insertColumn(at: col) }
        Button("Insert Column Right") { insertColumn(at: col + 1) }
        Divider()
        Button("Move Left") { moveColumn(from: col, to: col - 1) }
            .disabled(col == 0)
        Button("Move Right") { moveColumn(from: col, to: col + 1) }
            .disabled(col >= table.columnCount - 1)
        Divider()
        Button("Delete Column", role: .destructive) { deleteColumn(at: col) }
            .disabled(table.columnCount <= 1)
    }

    // MARK: - Data rows

    private func dataRow(rowIdx: Int) -> some View {
        HStack(spacing: 0) {
            rowGutter(rowIdx: rowIdx)
            ForEach(Array(table.rows[rowIdx].enumerated()), id: \.offset) { colIdx, _ in
                dataCell(row: rowIdx, col: colIdx)
            }
        }
        .background(rowIdx.isMultiple(of: 2) ? SwiftUI.Color.clear : SwiftUI.Color.rowStripe)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SwiftUI.Color.gridRule)
                .frame(height: Metrics.hairline)
        }
        .onHover { hoveredRow = $0 ? rowIdx : (hoveredRow == rowIdx ? nil : hoveredRow) }
    }

    /// Row number, replaced by the row's menu when the pointer is over it or a
    /// cell in it holds focus. Same footprint either way, so nothing shifts.
    private func rowGutter(rowIdx: Int) -> some View {
        Group {
            if hoveredRow == rowIdx || focusedCell?.row == rowIdx {
                Menu {
                    rowCommands(rowIdx: rowIdx)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Row actions")
            } else {
                Text("\(rowIdx + 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: Metrics.gutterWidth, alignment: .center)
        .padding(.vertical, Metrics.cellVPadding)
        .contentShape(Rectangle())
        .contextMenu { rowCommands(rowIdx: rowIdx) }
    }

    @ViewBuilder
    private func rowCommands(rowIdx: Int) -> some View {
        Button("Insert Row Above") { insertRow(at: rowIdx) }
        Button("Insert Row Below") { insertRow(at: rowIdx + 1) }
        Divider()
        Button("Move Up") { moveRow(from: rowIdx, to: rowIdx - 1) }
            .disabled(rowIdx == 0)
        Button("Move Down") { moveRow(from: rowIdx, to: rowIdx + 1) }
            .disabled(rowIdx >= table.rows.count - 1)
        Divider()
        Button("Delete Row", role: .destructive) { deleteRow(at: rowIdx) }
    }

    private func dataCell(row: Int, col: Int) -> some View {
        let cellID = CellID(row: row, col: col)
        return cellBox(col: col, isFocused: focusedCell == cellID) {
            TextField("", text: dataBinding(forRow: row, col: col))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($focusedCell, equals: cellID)
                .onSubmit { focusedCell = nextCell(after: cellID) }
                .modifier(tabMod(for: cellID))
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in DispatchQueue.main.async { focusedCell = cellID } }
        )
    }

    // MARK: - Cell box

    private func cellBox<Content: View>(
        col: Int,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, Metrics.cellHPadding)
            .padding(.vertical, Metrics.cellVPadding)
            .frame(width: columnWidth(col), alignment: table.alignments[col].swiftAlignment)
            .background {
                if isFocused {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SwiftUI.Color.accentColor.opacity(0.12))
                        .padding(1)
                }
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(SwiftUI.Color.gridRule)
                    .frame(width: Metrics.hairline)
                    .allowsHitTesting(false)
            }
    }

    // MARK: - Mutations

    private func addRow(above: Bool) {
        let idx: Int
        if let cell = focusedCell, !cell.isHeader {
            idx = above ? cell.row : cell.row + 1
        } else if above {
            idx = 0
        } else {
            idx = table.rows.count
        }
        insertRow(at: idx)
    }

    private func insertRow(at idx: Int) {
        var t = table
        t.insertRow(at: idx)
        table = t
    }

    private func deleteRow(at idx: Int) {
        var t = table
        t.deleteRow(at: idx)
        table = t
        if focusedCell?.row == idx { focusedCell = nil }
    }

    private func moveRow(from: Int, to: Int) {
        guard to >= 0, to < table.rows.count else { return }
        var t = table
        t.moveRow(from: from, to: to)
        table = t
    }

    private func addColumn(left: Bool) {
        let idx: Int
        if let cell = focusedCell {
            idx = left ? cell.col : cell.col + 1
        } else if left {
            idx = 0
        } else {
            idx = table.columnCount
        }
        insertColumn(at: idx)
    }

    private func insertColumn(at idx: Int) {
        var t = table
        t.insertColumn(at: idx)
        table = t
    }

    private func deleteColumn(at idx: Int) {
        guard table.columnCount > 1 else { return }
        var t = table
        t.deleteColumn(at: idx)
        table = t
        if focusedCell?.col == idx { focusedCell = nil }
    }

    private func moveColumn(from: Int, to: Int) {
        guard to >= 0, to < table.columnCount else { return }
        var t = table
        t.moveColumn(from: from, to: to)
        table = t
    }

    // MARK: - Bindings

    private func headerBinding(forCol col: Int) -> Binding<String> {
        Binding(
            get: { col < table.headers.count ? table.headers[col] : "" },
            set: { newValue in
                var t = table
                if col < t.headers.count { t.headers[col] = newValue }
                table = t
            }
        )
    }

    private func dataBinding(forRow row: Int, col: Int) -> Binding<String> {
        Binding(
            get: {
                guard row < table.rows.count, col < table.rows[row].count else { return "" }
                return table.rows[row][col]
            },
            set: { newValue in
                var t = table
                t.setCell(row: row, col: col, text: newValue)
                table = t
            }
        )
    }

    // MARK: - Tab modifier

    private func tabMod(for cell: CellID) -> TabNavigationModifier {
        TabNavigationModifier {
            focusedCell = nextCell(after: cell)
        } onShiftTab: {
            focusedCell = prevCell(before: cell)
        }
    }

    // MARK: - Navigation

    private func nextCell(after cell: CellID) -> CellID? {
        if cell.isHeader {
            if cell.col + 1 < table.columnCount {
                return CellID(row: -1, col: cell.col + 1)
            }
            if !table.rows.isEmpty {
                return CellID(row: 0, col: 0)
            }
            return nil
        }
        if cell.col + 1 < table.columnCount {
            return CellID(row: cell.row, col: cell.col + 1)
        }
        if cell.row + 1 < table.rows.count {
            return CellID(row: cell.row + 1, col: 0)
        }
        return nil
    }

    private func prevCell(before cell: CellID) -> CellID? {
        if cell.isHeader {
            if cell.col - 1 >= 0 {
                return CellID(row: -1, col: cell.col - 1)
            }
            return nil
        }
        if cell.col - 1 >= 0 {
            return CellID(row: cell.row, col: cell.col - 1)
        }
        if cell.row - 1 >= 0 {
            return CellID(row: cell.row - 1, col: table.columnCount - 1)
        }
        return CellID(row: -1, col: table.columnCount - 1)
    }
}

// MARK: - Viewport width

private struct ViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Tab navigation modifier

private struct TabNavigationModifier: ViewModifier {
    let onTab: () -> Void
    let onShiftTab: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content.onKeyPress { press in
                guard press.key == .tab else { return .ignored }
                if press.modifiers.contains(.shift) {
                    onShiftTab()
                } else {
                    onTab()
                }
                return .handled
            }
        } else {
            content
        }
    }
}

// MARK: - Palette

/// Greys built from the label colour rather than named platform colours, so the
/// grid keeps one appearance on both platforms and follows light/dark with no
/// conditionals.
private extension SwiftUI.Color {
    static let gridSurface = SwiftUI.Color.primary.opacity(0.02)
    static let headerFill = SwiftUI.Color.primary.opacity(0.06)
    static let rowStripe = SwiftUI.Color.primary.opacity(0.025)
    static let gridRule = SwiftUI.Color.primary.opacity(0.09)
    /// Heavier than the ordinary rules: it separates the headers from the data,
    /// which is the one line in the grid that carries meaning.
    static let headerRule = SwiftUI.Color.primary.opacity(0.25)
}

// MARK: - TableAlignment extension

private extension TableAlignment {
    var swiftAlignment: Alignment {
        switch self {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }

    /// Criterion 1 — alignment is visible per column, without spending a
    /// control's worth of width on it.
    var indicatorSymbol: String {
        switch self {
        case .left:   return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right:  return "text.alignright"
        }
    }

    var indicatorLabel: String {
        switch self {
        case .left:   return "Left aligned"
        case .center: return "Centre aligned"
        case .right:  return "Right aligned"
        }
    }
}
