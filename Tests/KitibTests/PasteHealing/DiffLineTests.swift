import XCTest

/// LCS diff algorithm used by `PastePreviewSheet`.
/// Spec: specs/paste-preview-toggle.md, failure mode 6.
final class DiffLineTests: XCTestCase {

    /// Convenience: runs `computeDiff` and returns counts per status.
    private func diffCounts(_ raw: String, _ healed: String) -> (added: Int, removed: Int, equal: Int) {
        let result = computeDiff(raw: raw, healed: healed)
        var added = 0, removed = 0, equal = 0
        for (status, _, _) in result {
            switch status {
            case .equal:   equal += 1
            case .added:   added += 1
            case .removed: removed += 1
            }
        }
        return (added, removed, equal)
    }

    func testIdenticalStringsAllEqual() {
        let r = diffCounts("a\nb\nc", "a\nb\nc")
        XCTAssertEqual(r.equal, 3)
        XCTAssertEqual(r.added, 0)
        XCTAssertEqual(r.removed, 0)
    }

    func testOneAddedLine() {
        let r = diffCounts("a\nb", "a\nb\nc")
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(r.removed, 0)
        XCTAssertEqual(r.equal, 2)
    }

    func testOneRemovedLine() {
        let r = diffCounts("a\nb\nc", "a\nb")
        XCTAssertEqual(r.removed, 1)
        XCTAssertEqual(r.added, 0)
        XCTAssertEqual(r.equal, 2)
    }

    func testSingleLineChange() {
        let r = diffCounts("hello", "world")
        XCTAssertEqual(r.removed, 1)
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(r.equal, 0)
    }

    func testCompletelyDifferentTexts() {
        let r = diffCounts("a\nb", "x\ny\nz")
        XCTAssertEqual(r.removed, 2)
        XCTAssertEqual(r.added, 3)
        XCTAssertEqual(r.equal, 0)
    }

    func testEmptyRawNonEmptyHealed() {
        // Empty raw produces one empty-string line from components(separatedBy:).
        // LCS matches nothing → 1 removed + N added.
        let r = diffCounts("", "a\nb")
        XCTAssertEqual(r.removed, 1)
        XCTAssertEqual(r.added, 2)
        XCTAssertEqual(r.equal, 0)
    }

    func testNonEmptyRawEmptyHealed() {
        let r = diffCounts("a\nb", "")
        XCTAssertEqual(r.removed, 2)
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(r.equal, 0)
    }

    func testAlignmentPreservedInOrder() {
        // "a" and "b" should match (equal); "x" is added; "d" is removed.
        // LCS alignment: equal("a"), added("x"), equal("b"), removed("d") = 4 entries.
        let counts = diffCounts("a\nb\nd", "a\nx\nb")
        XCTAssertEqual(counts.equal, 2)
        XCTAssertEqual(counts.added, 1)
        XCTAssertEqual(counts.removed, 1)
    }
}
