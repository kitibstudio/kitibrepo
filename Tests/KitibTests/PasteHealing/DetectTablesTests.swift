import XCTest

/// Criterion 7 (table detection) and failure mode 2 — a table whose rows have
/// been flattened into prose. The information survives a flattening, so a quick
/// read says "fine"; the structure, which is the meaning, is gone.
///
/// Same asymmetry as everywhere else in this pipeline: text left as text is
/// visibly unhealed and costs a keystroke, whereas prose wrongly marked up as a
/// table is a structural claim the writer never made.
final class DetectTablesTests: XCTestCase {

    /// Three lines whose column gaps start at the same offset on every line.
    private let alignedColumns = """
        Rating      Value
        1000 kVA    5.75%
        630 kVA     4.75%
        """

    private let expectedTable = """
        | Rating | Value |
        | --- | --- |
        | 1000 kVA | 5.75% |
        | 630 kVA | 4.75% |
        """

    // MARK: - Criterion 7, first clause: aligned columns become a table

    func testWhitespaceAlignedColumnsBecomeAMarkdownTable() {
        XCTAssertEqual(detectTables(alignedColumns), expectedTable)
    }

    func testSurroundingTextIsUntouched() {
        let input = "Ratings follow.\n\n" + alignedColumns + "\n\nAll at 40 C ambient.\n"
        let expected = "Ratings follow.\n\n" + expectedTable + "\n\nAll at 40 C ambient.\n"
        XCTAssertEqual(detectTables(input), expected)
    }

    // MARK: - Criterion 7, second clause: multiple spaces alone are not a table

    func testProseContainingDoubleSpacesIsNotATable() {
        let prose = """
            The transformer is rated.  Ambient is 40 C.
            Cooling is ONAN.  Fan redundancy is N+1.
            Impedance is 5.75%.  Vector group is Dyn11.
            """
        XCTAssertEqual(detectTables(prose), prose)
    }

    func testMisalignedColumnsAreNotATable() {
        let ragged = """
            Rating      Value
            1000 kVA       5.75%
            630 kVA     4.75%
            """
        XCTAssertEqual(detectTables(ragged), ragged)
    }

    func testDifferingColumnCountsAreNotATable() {
        let uneven = """
            Rating      Value
            1000 kVA    5.75%     ONAN
            630 kVA     4.75%
            """
        XCTAssertEqual(detectTables(uneven), uneven)
    }

    func testTwoAlignedLinesAreNotATable() {
        let pair = """
            Rating      Value
            1000 kVA    5.75%
            """
        XCTAssertEqual(detectTables(pair), pair)
    }

    func testSingleLineIsNotATable() {
        let line = "Rating      Value"
        XCTAssertEqual(detectTables(line), line)
    }

    // MARK: - Rule-aligned columns

    func testPipeRowsGainTheDelimiterRowTheyLack() {
        let input = """
            Rating | Value
            1000 kVA | 5.75%
            """
        let expected = """
            Rating | Value
            --- | ---
            1000 kVA | 5.75%
            """
        XCTAssertEqual(detectTables(input), expected)
    }

    func testFencedPipeRowsGainAFencedDelimiterRow() {
        let input = """
            | Rating | Value |
            | 1000 kVA | 5.75% |
            """
        let expected = """
            | Rating | Value |
            | --- | --- |
            | 1000 kVA | 5.75% |
            """
        XCTAssertEqual(detectTables(input), expected)
    }

    /// Criterion 10 in miniature: a table that is already valid Markdown is
    /// passed through byte-identical.
    func testValidMarkdownTableIsUnchanged() {
        let table = """
            | Rating | Value |
            | --- | --- |
            | 1000 kVA | 5.75% |
            """
        XCTAssertEqual(detectTables(table), table)
    }

    func testAlignmentColonsCountAsADelimiterRow() {
        let table = """
            | Rating | Value |
            |:--- | ---:|
            | 1000 kVA | 5.75% |
            """
        XCTAssertEqual(detectTables(table), table)
    }

    // MARK: - Places a table may not be invented

    func testAlignedColumnsInsideACodeFenceAreUntouched() {
        let fenced = "```\n" + alignedColumns + "\n```"
        XCTAssertEqual(detectTables(fenced), fenced)
    }

    func testIndentedBlockIsUntouched() {
        let indented = """
                Rating      Value
                1000 kVA    5.75%
                630 kVA     4.75%
            """
        XCTAssertEqual(detectTables(indented), indented)
    }

    func testTrailingNewlineSurvives() {
        XCTAssertEqual(detectTables(alignedColumns + "\n"), expectedTable + "\n")
    }

    func testEmptyInputSurvives() {
        XCTAssertEqual(detectTables(""), "")
    }

    // MARK: - Criteria 8 and 9

    func testIsDeterministicAndIdempotent() {
        for text in [alignedColumns, expectedTable, "Rating | Value\n1000 kVA | 5.75%"] {
            XCTAssertEqual(detectTables(text), detectTables(text), "not deterministic")
            let once = detectTables(text)
            XCTAssertEqual(
                detectTables(once), once,
                "not idempotent — a second pass re-marked its own output"
            )
        }
    }
}
