import Foundation

// MARK: - Alignment

enum TableAlignment: String, CaseIterable, Equatable {
    case left
    case center
    case right

    /// Parse from a delimiter cell like `---`, `:---`, `:---:`, or `---:`.
    init(delimiterCell: String) {
        let t = delimiterCell.trimmingCharacters(in: .whitespaces)
        let hasLeft = t.hasPrefix(":")
        let hasRight = t.hasSuffix(":")
        if hasLeft && hasRight { self = .center }
        else if hasRight { self = .right }
        else { self = .left }
    }

    /// Render as a delimiter cell (always 3 dashes wide).
    var delimiterCell: String {
        switch self {
        case .left:   return "---"
        case .center: return ":---:"
        case .right:  return "---:"
        }
    }
}

// MARK: - MarkdownTable

/// An editable model of a Markdown pipe table.
///
/// Holds headers, per-column alignment, and data rows. The delimiter row is NOT
/// stored separately — it is reconstructed from `alignments` on serialization.
struct MarkdownTable: Equatable {

    var headers: [String]
    var alignments: [TableAlignment]
    var rows: [[String]]

    var columnCount: Int { headers.count }

    // MARK: - Init

    init(headers: [String], alignments: [TableAlignment], rows: [[String]]) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
    }

    // MARK: - Cell editing

    mutating func setCell(row: Int, col: Int, text: String) {
        guard row >= 0, row < rows.count,
              col >= 0, col < columnCount else { return }
        rows[row][col] = text
    }

    // MARK: - Row mutations

    mutating func insertRow(at index: Int, cells: [String]? = nil) {
        let idx = max(0, min(index, rows.count))
        let newRow = cells.map { padOrTrim($0) } 
            ?? Array(repeating: "", count: columnCount)
        rows.insert(newRow, at: idx)
    }

    mutating func deleteRow(at index: Int) {
        guard index >= 0, index < rows.count else { return }
        rows.remove(at: index)
    }

    // MARK: - Column mutations

    mutating func insertColumn(at index: Int, alignment: TableAlignment = .left) {
        let idx = max(0, min(index, columnCount))
        headers.insert("", at: idx)
        alignments.insert(alignment, at: idx)
        for i in rows.indices {
            rows[i].insert("", at: idx)
        }
    }

    mutating func deleteColumn(at index: Int) {
        guard columnCount > 1,
              index >= 0, index < columnCount else { return }
        headers.remove(at: index)
        alignments.remove(at: index)
        for i in rows.indices {
            rows[i].remove(at: index)
        }
    }

    mutating func moveRow(from source: Int, to destination: Int) {
        guard source >= 0, source < rows.count,
              destination >= 0, destination <= rows.count else { return }
        let row = rows.remove(at: source)
        let dest = destination > source ? destination - 1 : destination
        rows.insert(row, at: dest)
    }

    mutating func moveColumn(from source: Int, to destination: Int) {
        guard source >= 0, source < columnCount,
              destination >= 0, destination <= columnCount else { return }
        let header = headers.remove(at: source)
        let alignment = alignments.remove(at: source)
        for i in rows.indices {
            let cell = rows[i].remove(at: source)
            rows[i].insert(cell, at: 0) // placeholder; reinsert correctly below
        }
        let dest = destination > source ? destination - 1 : destination
        headers.insert(header, at: dest)
        alignments.insert(alignment, at: dest)
        for i in rows.indices {
            let cell = rows[i].removeFirst()
            rows[i].insert(cell, at: dest)
        }
    }

    // MARK: - Serialization

    /// Renders the table as fenced Markdown (leading and trailing pipes).
    func serialize() -> String {
        var lines: [String] = []

        // Header row
        lines.append(serializeRow(headers))

        // Delimiter row
        lines.append(serializeDelimiter())

        // Data rows
        for row in rows {
            lines.append(serializeRow(row))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func serializeRow(_ cells: [String]) -> String {
        "| " + cells.map { $0.isEmpty ? " " : $0 }.joined(separator: " | ") + " |"
    }

    private func serializeDelimiter() -> String {
        "| " + alignments.map { $0.delimiterCell }.joined(separator: " | ") + " |"
    }

    // MARK: - Helpers

    private func padOrTrim(_ cells: [String]) -> [String] {
        var result = cells
        while result.count < columnCount { result.append("") }
        while result.count > columnCount { result.removeLast() }
        return result
    }
}

// MARK: - Parser

enum MarkdownTableParser {

    /// Extracts the first Markdown pipe table from `raw`. Returns the text
    /// before the table, the parsed table, and the text after. Returns `nil`
    /// if no valid table is found.
    static func parse(_ raw: String) -> (
        before: String, table: MarkdownTable, after: String
    )? {
        let lines = raw.components(separatedBy: "\n")

        // Find the delimiter row — must contain both `|` and `---`.
        guard let delimIdx = lines.firstIndex(where: { isDelimiterRow($0) }) else {
            return nil
        }

        // The line before the delimiter must be a table row (the header).
        guard delimIdx > 0, isTableRow(lines[delimIdx - 1]) else {
            return nil
        }
        let headerIdx = delimIdx - 1

        // Parse headers and alignments.
        let headerCells = extractCells(lines[headerIdx])
        let delimCells = extractCells(lines[delimIdx])
        guard headerCells.count >= 1, headerCells.count == delimCells.count else {
            return nil
        }
        let alignments = delimCells.map { TableAlignment(delimiterCell: $0) }

        // Collect data rows after the delimiter.
        var dataRows: [[String]] = []
        var dataEnd = delimIdx + 1
        while dataEnd < lines.count, isTableRow(lines[dataEnd]) {
            let cells = extractCells(lines[dataEnd])
            // Pad or truncate to match header column count.
            var padded = cells
            while padded.count < headerCells.count { padded.append("") }
            while padded.count > headerCells.count { padded.removeLast() }
            dataRows.append(padded)
            dataEnd += 1
        }

        let table = MarkdownTable(
            headers: headerCells,
            alignments: alignments,
            rows: dataRows
        )

        let before = lines[0..<headerIdx].joined(separator: "\n")
        let afterStart = dataEnd < lines.count ? dataEnd : lines.count
        let after = lines[afterStart...].joined(separator: "\n")

        return (before, table, after)
    }

    // MARK: - Private helpers

    private static func isDelimiterRow(_ line: String) -> Bool {
        let cells = extractCells(line)
        guard cells.count >= 1 else { return false }
        return cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: .whitespaces)
            // Must contain at least one dash, and consist only of dashes,
            // colons, and whitespace.
            guard t.contains("-") else { return false }
            return t.allSatisfy { "-: \t".contains($0) }
        }
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.contains("|")
    }

    /// Extracts cells from a single table row, handling fenced and unfenced
    /// styles uniformly.
    static func extractCells(_ line: String) -> [String] {
        var s = line
        // Strip a single leading pipe (fenced style).
        if s.hasPrefix("|") { s.removeFirst() }
        // Strip a single trailing pipe.
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Table-range detection

    /// Returns the `NSRange` of the Markdown pipe table that contains
    /// `cursorPosition` in `text`, or `nil` when the cursor is not inside
    /// a valid pipe table.
    ///
    /// `cursorPosition` is a UTF-16 code-unit offset, as used by
    /// `NSTextView.selectedRange().location` and
    /// `UITextView.selectedRange.location`.
    static func findTableRange(in text: String, cursorPosition: Int) -> NSRange? {
        let nsText = text as NSString
        guard cursorPosition >= 0, cursorPosition <= nsText.length else { return nil }

        let lines = text.components(separatedBy: "\n")
        // Map cursor to line index.
        var charCount = 0
        var cursorLineIdx: Int?
        for (i, line) in lines.enumerated() {
            let lineLen = line.count + 1 // +1 for the newline
            if cursorPosition < charCount + lineLen {
                cursorLineIdx = i
                break
            }
            charCount += lineLen
        }
        // Cursor past the last newline — on the implicit empty last line.
        if cursorLineIdx == nil { cursorLineIdx = lines.count - 1 }

        guard let cursorIdx = cursorLineIdx else { return nil }

        // The cursor line must contain a pipe.
        guard lines[cursorIdx].contains("|") else { return nil }

        // Walk upward to find the delimiter row, then the header above it.
        var delimIdx: Int?
        var headerIdx: Int?
        for i in stride(from: cursorIdx, through: 0, by: -1) {
            if isDelimiterRow(lines[i]) {
                delimIdx = i
                if i > 0, isTableRow(lines[i - 1]) {
                    headerIdx = i - 1
                }
                break
            }
        }
        // If walking upward didn't find a delimiter, walk downward from cursor —
        // the cursor was on a header row above the delimiter.
        if delimIdx == nil {
            for i in cursorIdx..<lines.count {
                if isDelimiterRow(lines[i]) {
                    delimIdx = i
                    if i > 0, isTableRow(lines[i - 1]) {
                        headerIdx = i - 1
                    }
                    break
                }
            }
        }

        guard let dIdx = delimIdx, let hIdx = headerIdx else { return nil }

        // Walk downward from delimiter to collect all data rows.
        var lastRowIdx = dIdx
        for i in (dIdx + 1)..<lines.count {
            if isTableRow(lines[i]) {
                lastRowIdx = i
            } else {
                break
            }
        }

        // Compute NSRange using the actual text for correct offsets
        // regardless of whether the string ends with a newline.
        let startOffset: Int = {
            var count = 0
            for i in 0..<hIdx {
                count += lines[i].count + 1 // line + newline
            }
            return count
        }()
        let endOffset: Int = {
            var count = 0
            for i in 0...lastRowIdx {
                count += lines[i].count
            }
            count += lastRowIdx // inter-line newlines (one fewer than line count)
            return count
        }()

        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
}
