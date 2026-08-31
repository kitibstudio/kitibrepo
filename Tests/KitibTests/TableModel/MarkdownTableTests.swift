import XCTest

final class MarkdownTableTests: XCTestCase {

    /// Parses and returns the table, failing the test if no valid table found.
    private func parse(_ md: String, file: StaticString = #file, line: UInt = #line) -> MarkdownTable {
        let result = MarkdownTableParser.parse(md)
        let unwrapped = try? XCTUnwrap(result)
        XCTAssertNotNil(unwrapped, "expected a valid table", file: file, line: line)
        return unwrapped!.table
    }

    /// Parses and returns the full result tuple.
    private func parseFull(_ md: String) -> (before: String, table: MarkdownTable, after: String)? {
        MarkdownTableParser.parse(md)
    }

    // MARK: - Criterion 1: parse fenced table

    func testParseFencedTable() {
        let table = parse("""
            | Name    | Value | Unit |
            | ------- | ----- | ---- |
            | Voltage | 11    | kV   |
            | Current | 300   | A    |
            """)
        XCTAssertEqual(table.headers, ["Name", "Value", "Unit"])
        XCTAssertEqual(table.columnCount, 3)
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0], ["Voltage", "11", "kV"])
        XCTAssertEqual(table.rows[1], ["Current", "300", "A"])
    }

    // MARK: - Criterion 2: unfenced table

    func testParseUnfencedTable() {
        let table = parse("""
            Name | Value | Unit
            ---- | ----- | ----
            Voltage | 11 | kV
            Current | 300 | A
            """)
        XCTAssertEqual(table.headers, ["Name", "Value", "Unit"])
        XCTAssertEqual(table.rows.count, 2)
    }

    func testParseMixedFenceStyles() {
        let table = parse("""
            | Name    | Value |
            | ------- | ----- |
            Voltage   | 11
            Current   | 300
            """)
        XCTAssertEqual(table.headers, ["Name", "Value"])
        XCTAssertEqual(table.rows.count, 2)
    }

    // MARK: - Criterion 3: alignment

    func testAlignmentParsing() {
        let table = parse("""
            | Left | Center | Right |
            | :--- | :----: | ----: |
            | a    | b      | c     |
            """)
        XCTAssertEqual(table.alignments, [.left, .center, .right])
    }

    func testDefaultAlignmentIsLeft() {
        let table = parse("""
            | Col |
            | --- |
            | val |
            """)
        XCTAssertEqual(table.alignments, [.left])
    }

    // MARK: - Criterion 4: edit cell

    func testEditCell() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            """)
        table.setCell(row: 0, col: 1, text: "updated")
        let s = table.serialize()
        XCTAssertTrue(s.contains("| updated"))
    }

    // MARK: - Criterion 5: insert row

    func testInsertRowAtStart() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            """)
        table.insertRow(at: 0, cells: ["x", "y"])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0], ["x", "y"])
    }

    func testInsertRowAtEnd() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            """)
        table.insertRow(at: 99, cells: ["x", "y"])
        XCTAssertEqual(table.rows.last, ["x", "y"])
    }

    // MARK: - Criterion 6: delete row

    func testDeleteRow() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            | 3 | 4 |
            """)
        table.deleteRow(at: 0)
        XCTAssertEqual(table.rows.count, 1)
        XCTAssertEqual(table.rows[0], ["3", "4"])
    }

    func testDeleteAllRowsLeavesEmptyTable() {
        var table = parse("""
            | A |
            | - |
            | 1 |
            """)
        table.deleteRow(at: 0)
        XCTAssertEqual(table.rows.count, 0)
        let s = table.serialize()
        XCTAssertTrue(s.contains("| A |"), "headers survive")
        XCTAssertTrue(s.contains("---"), "delimiter survives")
    }

    // MARK: - Criterion 7: insert column

    func testInsertColumnAtStart() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            """)
        table.insertColumn(at: 0, alignment: .center)
        XCTAssertEqual(table.columnCount, 3)
        XCTAssertEqual(table.headers[0], "")
        XCTAssertEqual(table.alignments[0], TableAlignment.center)
        XCTAssertEqual(table.rows[0][0], "")
        XCTAssertEqual(table.rows[0][1], "1")
    }

    func testInsertColumnAtEnd() {
        var table = parse("""
            | A |
            | - |
            | 1 |
            """)
        table.insertColumn(at: 99)
        XCTAssertEqual(table.columnCount, 2)
        XCTAssertEqual(table.headers[1], "")
    }

    // MARK: - Criterion 8: delete column

    func testDeleteColumn() {
        var table = parse("""
            | A | B | C |
            | - | - | - |
            | 1 | 2 | 3 |
            """)
        table.deleteColumn(at: 1)
        XCTAssertEqual(table.columnCount, 2)
        XCTAssertEqual(table.headers, ["A", "C"])
        XCTAssertEqual(table.rows[0], ["1", "3"])
    }

    func testCannotDeleteLastColumn() {
        var table = parse("""
            | A |
            | - |
            | 1 |
            """)
        table.deleteColumn(at: 0)
        XCTAssertEqual(table.columnCount, 1, "last column must not be deleted")
    }

    // MARK: - Criterion 9: round-trip

    func testRoundTripThroughSerializeAndReparse() {
        let t1 = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            """)
        let s1 = t1.serialize()
        let t2 = parse(s1)
        XCTAssertEqual(t1.headers, t2.headers)
        XCTAssertEqual(t1.alignments, t2.alignments)
        XCTAssertEqual(t1.rows, t2.rows)
    }

    // MARK: - Criterion 10: surrounding text

    func testSurroundingTextPreserved() {
        let md = """
            Some intro text.

            | A | B |
            | - | - |
            | 1 | 2 |

            More text after.
            """
        let result = parseFull(md)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.before.contains("Some intro text"),
                      "before should contain intro text, got: \(result!.before)")
        XCTAssertTrue(result!.after.contains("More text after"),
                      "after should contain trailing text")
    }

    func testNoSurroundingText() {
        let result = parseFull("""
            | A |
            | - |
            | 1 |
            """)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.before, "")
        XCTAssertEqual(result!.after, "")
    }

    // MARK: - Edge cases

    func testEmptyCells() {
        let table = parse("""
            | A | B |
            | - | - |
            |   | 2 |
            """)
        XCTAssertEqual(table.rows[0], ["", "2"])
    }

    func testSingleColumnTable() {
        let table = parse("""
            | Value |
            | ----- |
            | 100   |
            """)
        XCTAssertEqual(table.columnCount, 1)
        XCTAssertEqual(table.rows[0], ["100"])
    }

    func testSingleRowTable() {
        let table = parse("""
            | A | B |
            | - | - |
            """)
        XCTAssertEqual(table.headers, ["A", "B"])
        XCTAssertEqual(table.rows.count, 0)
    }

    func testNoTableReturnsNil() {
        XCTAssertNil(MarkdownTableParser.parse("Just some text."))
        XCTAssertNil(MarkdownTableParser.parse(""))
    }

    func testHeaderWithoutDelimiterReturnsNil() {
        XCTAssertNil(MarkdownTableParser.parse("| A | B |\nJust text."))
    }

    // MARK: - Failure mode 1: column-count mismatch

    func testDataRowWithFewerColumnsIsPadded() {
        let table = parse("""
            | A | B | C |
            | - | - | - |
            | 1 | 2 |
            """)
        XCTAssertEqual(table.rows[0], ["1", "2", ""])
    }

    func testDataRowWithMoreColumnsIsTruncated() {
        let table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 | 3 |
            """)
        XCTAssertEqual(table.rows[0], ["1", "2"])
    }

    // MARK: - Alignment serialization

    func testAlignmentPreservedThroughSerialize() {
        let table = parse("""
            | L | C | R |
            | :--- | :---: | ---: |
            | a | b | c |
            """)
        let s = table.serialize()
        XCTAssertTrue(s.contains(":---"), "left alignment marker")
        XCTAssertTrue(s.contains(":---:"), "center alignment marker")
        XCTAssertTrue(s.contains("---:"), "right alignment marker")
    }

    // MARK: - Round-trip with mutations

    func testFullMutationRoundTrip() {
        var table = parse("""
            | Name    | Value |
            | ------- | ----- |
            | Voltage | 11    |
            """)

        table.setCell(row: 0, col: 1, text: "400")
        table.insertRow(at: 1, cells: ["Current", "300"])
        table.insertColumn(at: 2, alignment: .center)
        table.setCell(row: 0, col: 2, text: "kV")
        table.setCell(row: 1, col: 2, text: "A")

        let s = table.serialize()
        let reparsed = parse(s)
        XCTAssertEqual(table, reparsed)
    }

    // MARK: - moveRow / moveColumn

    func testMoveRowDown() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            | 3 | 4 |
            """)
        table.moveRow(from: 0, to: 2)
        XCTAssertEqual(table.rows[0], ["3", "4"])
        XCTAssertEqual(table.rows[1], ["1", "2"])
    }

    func testMoveRowUp() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            | 3 | 4 |
            """)
        table.moveRow(from: 1, to: 0)
        XCTAssertEqual(table.rows[0], ["3", "4"])
        XCTAssertEqual(table.rows[1], ["1", "2"])
    }

    func testMoveRowToEnd() {
        var table = parse("""
            | A | B |
            | - | - |
            | 1 | 2 |
            | 3 | 4 |
            | 5 | 6 |
            """)
        table.moveRow(from: 0, to: 3)
        // Row 0 ("1","2") moved to end; other rows shift up
        XCTAssertEqual(table.rows[0], ["3", "4"])
        XCTAssertEqual(table.rows[1], ["5", "6"])
        XCTAssertEqual(table.rows[2], ["1", "2"])
    }

    func testMoveColumnRight() {
        var table = parse("""
            | A | B | C |
            | - | - | - |
            | 1 | 2 | 3 |
            """)
        table.moveColumn(from: 0, to: 3)
        XCTAssertEqual(table.headers, ["B", "C", "A"])
        XCTAssertEqual(table.rows[0], ["2", "3", "1"])
    }

    func testMoveColumnLeft() {
        var table = parse("""
            | A | B | C |
            | - | - | - |
            | 1 | 2 | 3 |
            """)
        table.moveColumn(from: 2, to: 0)
        XCTAssertEqual(table.headers, ["C", "A", "B"])
        XCTAssertEqual(table.rows[0], ["3", "1", "2"])
    }

    func testMoveColumnPreservesAlignment() {
        var table = parse("""
            | L | C | R |
            | :--- | :---: | ---: |
            | a | b | c |
            """)
        table.moveColumn(from: 0, to: 3)
        XCTAssertEqual(table.alignments, [.center, .right, .left])
    }

    // MARK: - findTableRange

    func testFindTableRangeCursorInHeader() {
        let md = """
            Some text.

            | A | B |
            | - | - |
            | 1 | 2 |

            More text.
            """
        let range = MarkdownTableParser.findTableRange(in: md, cursorPosition: 15)
        XCTAssertNotNil(range)
        let tableText = (md as NSString).substring(with: range!)
        XCTAssertTrue(tableText.contains("| A | B |"))
        XCTAssertTrue(tableText.contains("| 1 | 2 |"))
        XCTAssertFalse(tableText.contains("Some text"))
        XCTAssertFalse(tableText.contains("More text"))
    }

    func testFindTableRangeCursorInDataRow() {
        let md = """
            | A | B |
            | - | - |
            | 1 | 2 |
            """
        let range = MarkdownTableParser.findTableRange(in: md, cursorPosition: 25)
        XCTAssertNotNil(range)
        let tableText = (md as NSString).substring(with: range!)
        XCTAssertTrue(tableText.contains("| A | B |"))
    }

    func testFindTableRangeCursorOnDelimiterRow() {
        let md = """
            | A | B |
            | - | - |
            | 1 | 2 |
            """
        let range = MarkdownTableParser.findTableRange(in: md, cursorPosition: 12)
        XCTAssertNotNil(range)
    }

    func testFindTableRangeCursorOutsideTable() {
        let md = """
            Some text.

            | A | B |
            | - | - |
            | 1 | 2 |

            More text.
            """
        XCTAssertNil(MarkdownTableParser.findTableRange(in: md, cursorPosition: 2))
    }

    func testFindTableRangeCursorInSurroundingText() {
        let md = """
            Intro paragraph.

            | A | B |
            | - | - |
            | 1 | 2 |

            Trailing paragraph.
            """
        // Cursor in the trailing paragraph — after the table.
        let trailingOffset = (md as NSString).length - 5
        XCTAssertNil(MarkdownTableParser.findTableRange(in: md, cursorPosition: trailingOffset))
    }

    func testFindTableRangeTableAtStart() {
        let md = """
            | A | B |
            | - | - |
            | 1 | 2 |
            """
        let range = MarkdownTableParser.findTableRange(in: md, cursorPosition: 0)
        XCTAssertNotNil(range)
    }

    func testFindTableRangeTableAtEnd() {
        let md = """
            | A | B |
            | - | - |
            | 1 | 2 |
            """
        let range = MarkdownTableParser.findTableRange(in: md, cursorPosition: 27)
        XCTAssertNotNil(range)
    }
}
