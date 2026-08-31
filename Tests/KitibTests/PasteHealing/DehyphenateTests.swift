import XCTest

/// Criterion 2 (lexicon-guarded dehyphenation) and failure mode 1 — the
/// signature failure of this whole feature: `star-delta` rejoined to
/// `stardelta`, a valid-looking word one character from the truth.
///
/// The asymmetry that sets every threshold here: a hyphen wrongly kept leaves
/// `transfor-mer` visible on screen, which the writer fixes in one keystroke.
/// A hyphen wrongly removed produces a word that reads as correct and is not.
/// So every guard errs towards keeping the hyphen.
final class DehyphenateTests: XCTestCase {

    // MARK: - Criterion 2, the case the transform exists for

    func testSplitWordRejoins() {
        XCTAssertEqual(
            dehyphenate("The transfor-mer is rated 1000 kVA."),
            "The transformer is rated 1000 kVA."
        )
    }

    func testEverySplitInALineRejoins() {
        XCTAssertEqual(
            dehyphenate("The opera-tor shall test the transfor-mer windings."),
            "The operator shall test the transformer windings."
        )
    }

    func testSplitWordWithTrailingPunctuationRejoins() {
        XCTAssertEqual(
            dehyphenate("Isolate the transfor-mer."),
            "Isolate the transformer."
        )
    }

    // MARK: - Failure mode 1: the protected compounds

    func testProtectedCompoundsSurviveByteIdentical() {
        for compound in ProtectedCompounds.compounds {
            let sentence = "The unit uses \(compound) in service."
            XCTAssertEqual(
                dehyphenate(sentence), sentence,
                "protected compound '\(compound)' was altered"
            )
        }
    }

    func testProtectedCompoundSurvivesInsideQuotesAndCapitalised() {
        let line = "\"Low-voltage\" \"star-delta\" starting is specified."
        XCTAssertEqual(dehyphenate(line), line)
    }

    // MARK: - Criterion 2's second clause: a valid leading word keeps its hyphen

    func testCompoundWhoseLeadingFragmentIsAWordDoesNotRejoin() {
        for compound in ["three-phase", "short-circuit", "self-contained",
                         "high-voltage", "cross-sectional", "over-current"] {
            let line = "A \(compound) device is required."
            XCTAssertEqual(
                dehyphenate(line), line,
                "'\(compound)' rejoined — its leading fragment is a word"
            )
        }
    }

    func testAcronymLeadingFragmentDoesNotRejoin() {
        let line = "Cable PVC-sheathed to BS 6004."
        XCTAssertEqual(dehyphenate(line), line)
    }

    func testSingleLetterLeadingFragmentDoesNotRejoin() {
        let line = "Send an e-mail to the engineer."
        XCTAssertEqual(dehyphenate(line), line)
    }

    // MARK: - Shapes that are not a split word at all

    func testUppercaseContinuationDoesNotRejoin() {
        // Em dashes normalised to "-" by repairGlyphs (D24) land here as
        // "spec-XLPE/SWA/PVC-must". Rejoining any of it is corruption.
        let line = "Cable spec-XLPE/SWA/PVC-must be used."
        XCTAssertEqual(dehyphenate(line), line)
    }

    func testTokenContainingDigitsDoesNotRejoin() {
        for line in ["Model-T-1000-K-rated 1000 kVA at 40C.",
                     "See Table 4-2 for rating factors.",
                     "Supply 11kV/415V at 50 Hz."] {
            XCTAssertEqual(dehyphenate(line), line, "'\(line)' was altered")
        }
    }

    func testHyphenSurroundedBySpacesDoesNotRejoin() {
        let line = "Cooling -ONAN- with N+1 fan redundancy."
        XCTAssertEqual(dehyphenate(line), line)
    }

    /// A split spanning a line break is `unwrapLines`' decision, not this one.
    /// If unwrap declined to rejoin the block, this transform does not overrule
    /// it — that would be healing the writer never asked for.
    func testSplitAcrossALineBreakIsLeftAlone() {
        let text = "The transfor-\nmer is rated.\n"
        XCTAssertEqual(dehyphenate(text), text)
    }

    // MARK: - Structure preservation

    func testLineStructureAndTrailingNewlineSurvive() {
        let text = "The transfor-mer is rated.\nCooling is ONAN.\n"
        XCTAssertEqual(dehyphenate(text), "The transformer is rated.\nCooling is ONAN.\n")
    }

    func testColumnGapsSurvive() {
        let line = "Rating      1000 kVA"
        XCTAssertEqual(dehyphenate(line), line)
    }

    func testEmptyInputSurvives() {
        XCTAssertEqual(dehyphenate(""), "")
    }

    // MARK: - Criteria 8 and 9

    func testIsDeterministicAndIdempotent() {
        for line in ["The transfor-mer and the star-delta starter.",
                     "A three-phase supply at 11kV/415V.",
                     "Cable spec-XLPE/SWA/PVC-must be used."] {
            XCTAssertEqual(dehyphenate(line), dehyphenate(line), "'\(line)' is not deterministic")
            let once = dehyphenate(line)
            XCTAssertEqual(dehyphenate(once), once, "'\(line)' is not idempotent")
        }
    }
}
