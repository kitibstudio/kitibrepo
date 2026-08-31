import XCTest

/// `PasteHealer.heal` — the entry point, composing all six transforms in the
/// D20-locked order.
///
/// The per-transform suites test each stage in isolation. These tests are the
/// ones that matter for the document: they run a whole pasted span end to end
/// and check the named failure modes on the output a writer would actually see.
final class PasteHealerTests: XCTestCase {

    /// A standards paste, hard-wrapped at roughly column 55, with a protected
    /// compound split exactly at a line break.
    private let wrappedPasteSplittingACompound = """
        The motor starter shall be of the reduced voltage star-
        delta type and shall be rated for the duty cycle of
        the connected load without exceeding the temperature
        limits given in the manufacturer's data sheet.
        """

    /// A paginated standards paste: a running header repeated on every page,
    /// with clause citations in the body.
    private let paginatedPaste = """
        BS 7671:2018 Chapter 41 Page 1

        411.3.3 Additional protection shall be provided by an
        RCD with a rated residual operating current not
        exceeding 30 mA and an operating time not exceeding
        40 ms at a residual current of 5 times the rating.

        BS 7671:2018 Chapter 41 Page 2

        Where the requirements of Regulation 411.3.3 are not
        met, supplementary equipotential bonding shall be
        installed in accordance with Regulation 415.2 of the
        same chapter, and the result shall be recorded.

        BS 7671:2018 Chapter 41 Page 3
        """

    /// Well-formed Markdown, as this app writes it. Paragraphs are single
    /// lines, which is what the editor produces — a document hard-wrapped by
    /// hand is not "clean input" for criterion 10's purposes.
    private let cleanMarkdown = """
        # Design Note

        The transformer is rated 1000 kVA and uses star-delta starting.

        - Primary: 11 kV
        - Secondary: 415 V

        | Parameter | Value |
        | --- | --- |
        | Impedance | 5.75% |

        > Ratings are quoted at 40 C ambient.

        1. Isolate the supply.
        2. Prove the circuit dead.

        """

    // MARK: - The locked order (D20)

    func testHealAppliesTheSixTransformsInTheLockedOrder() {
        for raw in [wrappedPasteSplittingACompound, paginatedPaste, cleanMarkdown] {
            let composed = preserveClauseNumbers(
                detectTables(
                    dehyphenate(
                        unwrapLines(
                            stripArtefacts(
                                repairGlyphs(raw)
                            )
                        )
                    )
                )
            )
            XCTAssertEqual(
                PasteHealer.heal(raw), composed,
                "heal does not apply repairGlyphs → stripArtefacts → unwrapLines → "
                    + "dehyphenate → detectTables → preserveClauseNumbers"
            )
        }
    }

    // MARK: - Failure mode 1: a rejoined compound

    func testProtectedCompoundSplitAtALineBreakSurvivesTheWholePipeline() {
        let healed = PasteHealer.heal(wrappedPasteSplittingACompound)
        XCTAssertTrue(
            healed.contains("reduced voltage star-delta type"),
            "the compound did not survive rejoining: \(healed)"
        )
        XCTAssertFalse(healed.contains("stardelta"), "star-delta was dehyphenated")
        XCTAssertFalse(healed.contains("star- delta"), "star-delta gained a space")
    }

    func testEveryProtectedCompoundSurvivesHealing() {
        for compound in ProtectedCompounds.compounds {
            let paste = "The unit is specified with \(compound) throughout."
            XCTAssertEqual(
                PasteHealer.heal(paste), paste,
                "protected compound '\(compound)' was altered by heal"
            )
        }
    }

    // MARK: - Failure mode 3: a clause number eaten as a page number

    func testRunningHeaderIsStrippedAndClauseNumbersSurvive() {
        let healed = PasteHealer.heal(paginatedPaste)
        XCTAssertFalse(healed.contains("BS 7671:2018 Chapter 41"),
                       "the running header survived: \(healed)")
        XCTAssertTrue(healed.contains("411.3.3 Additional protection"),
                      "the clause number was eaten as page furniture: \(healed)")
        XCTAssertTrue(healed.contains("Regulation 411.3.3"),
                      "an in-line citation was lost: \(healed)")
        XCTAssertTrue(healed.contains("Regulation 415.2"),
                      "an in-line citation was lost: \(healed)")
    }

    func testClauseNumberStartsItsOwnLineAfterHealing() {
        let healed = PasteHealer.heal(paginatedPaste)
        let startsAClause = healed
            .components(separatedBy: "\n")
            .contains { $0.hasPrefix("411.3.3 Additional protection") }
        XCTAssertTrue(startsAClause,
                      "the clause number was pulled into the previous line: \(healed)")
    }

    // MARK: - Failure mode 6: numbered list versus clause number

    func testNumberedListSurvivesHealingAsAList() {
        let list = "1. Isolate the supply.\n2. Prove the circuit dead.\n3. Apply the earth.\n"
        XCTAssertEqual(PasteHealer.heal(list), list)
    }

    func testClauseHeaderIsNotRenderedAsAListItem() {
        XCTAssertEqual(
            PasteHealer.heal("411. Protection for safety\n"),
            "411\\. Protection for safety\n"
        )
    }

    // MARK: - Criterion 10: clean input is a no-op

    func testWellFormedMarkdownPassesThroughByteIdentical() {
        XCTAssertEqual(PasteHealer.heal(cleanMarkdown), cleanMarkdown)
    }

    func testEmptyInputSurvives() {
        XCTAssertEqual(PasteHealer.heal(""), "")
    }

    // MARK: - Criteria 8 and 9, and failure mode 7

    func testHealIsDeterministic() {
        for raw in [wrappedPasteSplittingACompound, paginatedPaste, cleanMarkdown] {
            XCTAssertEqual(PasteHealer.heal(raw), PasteHealer.heal(raw),
                           "heal is not deterministic")
        }
    }

    func testHealIsIdempotent() {
        for raw in [wrappedPasteSplittingACompound, paginatedPaste, cleanMarkdown] {
            let once = PasteHealer.heal(raw)
            XCTAssertEqual(
                PasteHealer.heal(once), once,
                "heal(heal(x)) != heal(x) — healing an already-healed paste damaged it"
            )
        }
    }
}
