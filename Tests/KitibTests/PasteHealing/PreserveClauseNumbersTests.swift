import XCTest

/// Criterion 6 (clause numbers preserved, not consumed) and failure mode 6 —
/// a numbered list mistaken for clause numbers, or the reverse.
///
/// Both directions matter and they pull against each other:
///
/// * `411. Protection for safety` is a CITATION. Markdown reads `411.` as an
///   ordered-list marker and renders it as `1.` — the number the citation is
///   made of is destroyed on screen while the prose looks perfect.
/// * `1. Isolate the supply.` is a LIST. Escaping it would turn working markup
///   into literal text.
///
/// The discriminator is the marker's width. A three-digit marker is a clause
/// number in every standard this app is for; an ordered list that reaches 100
/// items barely exists, and if one does, its first 99 items are untouched and
/// item 100 renders as the text "100." — visually what it was. A two-digit
/// marker is left alone: `41.` is ambiguous, and under-healing is the safe
/// direction.
final class PreserveClauseNumbersTests: XCTestCase {

    // MARK: - Criterion 6: citations survive as text

    func testDottedClauseNumberSurvivesUnchanged() {
        let line = "411.3.3 Additional protection shall be provided."
        XCTAssertEqual(preserveClauseNumbers(line), line)
    }

    func testSectionSymbolCitationSurvivesUnchanged() {
        let line = "§7.2 Requirements for isolation."
        XCTAssertEqual(preserveClauseNumbers(line), line)
    }

    func testTableAndFigureCitationsSurviveUnchanged() {
        for line in ["Table 4-2 Rating factors for grouping.",
                     "Figure 3.1 Typical star-delta starter.",
                     "Annex A Informative guidance.",
                     "Regulation 415.2 Supplementary bonding."] {
            XCTAssertEqual(preserveClauseNumbers(line), line, "'\(line)' was altered")
        }
    }

    // MARK: - Failure mode 6, first direction: a clause number rendered as "1."

    func testThreeDigitClauseHeaderIsProtectedFromListMarkup() {
        XCTAssertEqual(
            preserveClauseNumbers("411. Protection for safety"),
            "411\\. Protection for safety"
        )
    }

    func testThreeDigitClauseHeaderWithBracketMarkerIsProtected() {
        XCTAssertEqual(
            preserveClauseNumbers("543) Protective conductors"),
            "543\\) Protective conductors"
        )
    }

    func testIndentationOfAProtectedClauseHeaderSurvives() {
        XCTAssertEqual(
            preserveClauseNumbers("  411. Protection for safety"),
            "  411\\. Protection for safety"
        )
    }

    // MARK: - Failure mode 6, second direction: a real list stays a list

    func testGenuineNumberedListIsUntouched() {
        let list = """
            1. Isolate the supply.
            2. Prove the circuit dead.
            3. Apply the earth connection.
            """
        XCTAssertEqual(preserveClauseNumbers(list), list)
    }

    func testTwoDigitOrderedItemIsUntouched() {
        let line = "41. Protection against electric shock"
        XCTAssertEqual(preserveClauseNumbers(line), line)
    }

    func testBulletListIsUntouched() {
        let list = "- Primary: 11 kV\n- Secondary: 415 V"
        XCTAssertEqual(preserveClauseNumbers(list), list)
    }

    // MARK: - Places markup may not be rewritten

    func testContentInsideACodeFenceIsUntouched() {
        let fenced = "```\n411. Protection for safety\n```"
        XCTAssertEqual(preserveClauseNumbers(fenced), fenced)
    }

    func testHeadingsAndProseAreUntouched() {
        let text = "# Design Note\n\nThe transformer is rated 1000 kVA.\n"
        XCTAssertEqual(preserveClauseNumbers(text), text)
    }

    func testTrailingNewlineSurvives() {
        XCTAssertEqual(
            preserveClauseNumbers("411. Protection for safety\n"),
            "411\\. Protection for safety\n"
        )
    }

    func testEmptyInputSurvives() {
        XCTAssertEqual(preserveClauseNumbers(""), "")
    }

    // MARK: - Criteria 8 and 9

    func testIsDeterministicAndIdempotent() {
        for text in ["411. Protection for safety",
                     "411.3.3 Additional protection shall be provided.",
                     "1. Isolate the supply.\n2. Prove the circuit dead."] {
            XCTAssertEqual(
                preserveClauseNumbers(text), preserveClauseNumbers(text),
                "not deterministic"
            )
            let once = preserveClauseNumbers(text)
            XCTAssertEqual(
                preserveClauseNumbers(once), once,
                "not idempotent — a second pass escaped its own output again"
            )
        }
    }
}
