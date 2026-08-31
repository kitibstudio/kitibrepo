import Foundation

/// A whitespace-aligned table needs this many rows before it is one.
///
/// Two lines that happen to share a column offset are a coincidence; three are
/// a table. Same asymmetry as everywhere else in this pipeline (D30): columns
/// left as text are visibly unhealed, whereas prose marked up as a table is a
/// structural claim the writer never made.
private let minimumAlignedRows = 3

/// A table needs at least this many columns. One column is a list.
private let minimumColumns = 2

/// Turn whitespace- or rule-aligned columns into a valid Markdown table.
///
/// Spec: specs/paste-healing.md criterion 7. Fifth in the locked pipeline
/// order (D20), after `unwrapLines` — which refuses to rejoin any line
/// containing a column gap, so the columns are still standing when this runs
/// (failure mode 2: a table flattened into a paragraph keeps all its
/// information and loses the structure that WAS the information).
///
/// Two shapes are recognised, and nothing else:
///
/// * **Whitespace-aligned.** Three or more consecutive lines, none of them
///   structural or indented, each splitting into the same number of cells on
///   runs of two or more spaces, with every cell starting at the same column on
///   every line. Text that merely contains multiple spaces — a double space
///   after a full stop — does not align, and is left alone. That is criterion
///   7's second clause.
/// * **Rule-aligned.** Two or more consecutive lines that all contain `|` and
///   all split into the same number of cells. These are already table rows;
///   the only thing missing is the delimiter row that makes Markdown render
///   them as a table, so that row is inserted and the writer's own rows are
///   left exactly as typed.
///
/// A block that already has a delimiter row is a valid Markdown table and is
/// returned untouched, which is what makes the transform idempotent: its own
/// output is a table it will not touch again.
///
/// - Parameter input: text with glyphs repaired, furniture stripped, lines unwrapped
/// - Returns: text with aligned columns marked up as Markdown tables
public func detectTables(_ input: String) -> String {
    let hadTrailingNewline = input.hasSuffix("\n")
    var lines = input.components(separatedBy: "\n")
    if hadTrailingNewline { lines.removeLast() }

    var output: [String] = []
    var insideFence = false
    var index = 0
    while index < lines.count {
        let line = lines[index]

        if isFenceDelimiter(line) {
            insideFence.toggle()
            output.append(line)
            index += 1
            continue
        }
        if insideFence || isBlankLine(line) {
            output.append(line)
            index += 1
            continue
        }

        var end = index
        while end < lines.count, !isBlankLine(lines[end]), !isFenceDelimiter(lines[end]) {
            end += 1
        }
        output.append(contentsOf: tableBlock(Array(lines[index..<end])))
        index = end
    }

    var result = output.joined(separator: "\n")
    if hadTrailingNewline { result += "\n" }
    return result
}

/// One run of consecutive non-blank lines, as a table if it is one.
private func tableBlock(_ block: [String]) -> [String] {
    guard block.count >= 2 else { return block }

    // An indented block is code. Marking it up would change what it means.
    guard !block.contains(where: { $0.hasPrefix("    ") || $0.hasPrefix("\t") }) else {
        return block
    }

    if block.allSatisfy({ $0.contains("|") }) { return ruleAlignedBlock(block) }

    guard block.count >= minimumAlignedRows else { return block }
    guard block.allSatisfy({ !LineShape.isStructural($0) }) else { return block }
    return whitespaceAlignedBlock(block)
}

/// Rows that already use `|`. The only edit is the delimiter row, if missing.
private func ruleAlignedBlock(_ block: [String]) -> [String] {
    guard !block.contains(where: isDelimiterRow) else { return block }

    let counts = block.map(pipeCellCount)
    guard let columns = counts.first,
          columns >= minimumColumns,
          counts.allSatisfy({ $0 == columns }) else { return block }

    return [block[0], delimiterRow(matching: block[0], columns: columns)]
        + block.dropFirst()
}

/// Columns held apart by runs of spaces, aligned on every row.
private func whitespaceAlignedBlock(_ block: [String]) -> [String] {
    let rows = block.map(columnCells)
    guard let header = rows.first, header.count >= minimumColumns else { return block }
    guard rows.allSatisfy({ $0.count == header.count }) else { return block }

    // The alignment itself: every cell starts at the same column on every row.
    // This is what separates a table from prose containing double spaces.
    let aligned = rows.allSatisfy { row in
        zip(row, header).allSatisfy { cell, headerCell in cell.offset == headerCell.offset }
    }
    guard aligned else { return block }

    var out = [
        markdownRow(header.map { $0.text }),
        markdownDelimiterRow(columns: header.count),
    ]
    out += rows.dropFirst().map { row in markdownRow(row.map { $0.text }) }
    return out
}

/// Splits a line on runs of two or more spaces, keeping each cell's start
/// column. Single spaces stay inside a cell: `1000 kVA` is one value.
private func columnCells(_ line: String) -> [(offset: Int, text: String)] {
    let characters = Array(line)
    var cells: [(offset: Int, text: String)] = []
    var index = 0
    while index < characters.count {
        while index < characters.count, characters[index] == " " { index += 1 }
        guard index < characters.count else { break }

        let start = index
        var text = ""
        while index < characters.count {
            if characters[index] == " " {
                var run = index
                while run < characters.count, characters[run] == " " { run += 1 }
                if run - index >= 2 || run == characters.count {
                    index = run
                    break
                }
                text.append(" ")
                index = run
            } else {
                text.append(characters[index])
                index += 1
            }
        }
        cells.append((start, text))
    }
    return cells
}

private func markdownRow(_ cells: [String]) -> String {
    "| " + cells.joined(separator: " | ") + " |"
}

private func markdownDelimiterRow(columns: Int) -> String {
    "| " + Array(repeating: "---", count: columns).joined(separator: " | ") + " |"
}

/// A delimiter row in the same style as the row above it — edge pipes only if
/// the writer used them.
private func delimiterRow(matching row: String, columns: Int) -> String {
    let trimmed = row.trimmingCharacters(in: .whitespaces)
    let dashes = Array(repeating: "---", count: columns).joined(separator: " | ")
    if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") { return "| " + dashes + " |" }
    return dashes
}

/// `| --- | :---: |` — the row that makes Markdown treat pipes as a table.
private func isDelimiterRow(_ line: String) -> Bool {
    let cells = pipeCells(line)
    guard !cells.isEmpty else { return false }
    return cells.allSatisfy { cell in
        var body = cell.trimmingCharacters(in: .whitespaces)
        if body.hasPrefix(":") { body.removeFirst() }
        if body.hasSuffix(":") { body.removeLast() }
        return !body.isEmpty && body.allSatisfy { $0 == "-" }
    }
}

private func pipeCellCount(_ line: String) -> Int {
    pipeCells(line).count
}

/// Cells of a pipe row, ignoring the empty strings that edge pipes produce.
private func pipeCells(_ line: String) -> [String] {
    var cells = line.trimmingCharacters(in: .whitespaces).components(separatedBy: "|")
    if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
    if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
    return cells
}

private func isFenceDelimiter(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
}
