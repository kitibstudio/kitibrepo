import XCTest

/// The behaviour these lock was measured against FTS5 directly, not assumed:
///
///     MATCH 'copy-edit'    -> error: no such column: edit
///     MATCH '"copy-edit"'  -> matches
///     MATCH 'copy edit'    -> matches
///
/// `AppState.searchSmartFolder` swallows that error with `try?`, so a
/// malformed query reaches the panel as an empty result set and is
/// indistinguishable from a genuine miss. These checks are what let the UI
/// tell the two apart.
final class QueryLintTests: XCTestCase {

    // MARK: bareHyphenatedTerm

    func testPlainQueryHasNoHyphenatedTerm() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "draft revision"))
    }

    func testEmptyQueryHasNoHyphenatedTerm() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: ""))
    }

    func testFindsBareHyphenatedTerm() {
        XCTAssertEqual(QueryLint.bareHyphenatedTerm(in: "copy-edit"), "copy-edit")
    }

    func testFindsHyphenatedTermAmongOtherWords() {
        XCTAssertEqual(QueryLint.bareHyphenatedTerm(in: "copy-edit pass"),
                       "copy-edit")
    }

    /// The whole point: a quoted hyphenated term is valid FTS5 and must not be
    /// reported as a problem.
    func testQuotedHyphenatedTermIsNotReported() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "\"copy-edit\""))
    }

    func testQuotedTermIgnoredButBareOneStillFound() {
        XCTAssertEqual(
            QueryLint.bareHyphenatedTerm(in: "\"copy-edit\" line-break"),
            "line-break"
        )
    }

    func testReturnsFirstOfSeveral() {
        XCTAssertEqual(QueryLint.bareHyphenatedTerm(in: "one-two three-four"),
                       "one-two")
    }

    func testMultipleHyphensInOneTerm() {
        XCTAssertEqual(QueryLint.bareHyphenatedTerm(in: "well-known-fact"),
                       "well-known-fact")
    }

    /// A leading or trailing hyphen is not a hyphenated *word* — quoting it
    /// would not be the right advice.
    func testLeadingHyphenIsNotATerm() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "-leading"))
    }

    func testTrailingHyphenIsNotATerm() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "trailing-"))
    }

    func testBooleanOperatorsAreNotFlagged() {
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "chapter NOT appendix"))
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: "draft OR outline"))
    }

    // MARK: quoting

    func testQuotingWrapsTheTerm() {
        XCTAssertEqual(QueryLint.quoting("copy-edit", in: "copy-edit pass"),
                       "\"copy-edit\" pass")
    }

    func testQuotingLeavesTheRestOfTheQueryAlone() {
        XCTAssertEqual(
            QueryLint.quoting("line-break", in: "draft line-break notes"),
            "draft \"line-break\" notes"
        )
    }

    func testQuotingAbsentTermIsANoOp() {
        XCTAssertEqual(QueryLint.quoting("missing-term", in: "draft revision"),
                       "draft revision")
    }

    /// Applying the offered fix must actually clear the warning — otherwise
    /// the "Add quotes" button loops.
    func testQuotingResolvesTheWarning() {
        let query = "copy-edit pass"
        guard let term = QueryLint.bareHyphenatedTerm(in: query) else {
            return XCTFail("expected a hyphenated term")
        }
        let fixed = QueryLint.quoting(term, in: query)
        XCTAssertNil(QueryLint.bareHyphenatedTerm(in: fixed))
    }
}
