import XCTest

/// Tests for the inverted dehyphenate rule (human ruling 2026-08-11):
/// a hyphen is removed ONLY when the joined form is a known word.
///
/// Before this ruling, `dehyphenate` fused whenever the leading fragment
/// was not in `CommonWords` — a default that over-healed.  The new
/// `RejoinableWords` lexicon requires positive evidence, so an unknown
/// word takes the safe branch and keeps its hyphen.
///
/// None of these tests modify `DehyphenateTests` — every existing test
/// must still pass unchanged.  The inverted rule was chosen precisely
/// because it breaks none of them.
final class DehyphenateLexiconTests: XCTestCase {

    // MARK: - Compounds that MUST keep their hyphen (the safe branch)

    /// From the golden document round-trip finding (PARKED.md 2026-08-11):
    /// five compounds whose joined forms are not known words and must
    /// therefore survive.
    func testGoldenDocumentCompoundsKeepHyphen() {
        for compound in ["socket-outlets", "project-specific",
                         "factory-fitted", "Direct-on-line",
                         "reduced-voltage"] {
            let line = "This uses \(compound) in service."
            XCTAssertEqual(
                dehyphenate(line), line,
                "'\(compound)' was fused — unknown joined form must keep hyphen"
            )
        }
    }

    /// Two compounds the golden corpus does not contain, to show the fix
    /// is general and not five words bolted on.
    func testOtherUnknownCompoundsKeepHyphen() {
        for compound in ["vendor-supplied", "pressure-tested"] {
            let line = "The \(compound) unit is acceptable."
            XCTAssertEqual(
                dehyphenate(line), line,
                "'\(compound)' was fused — unknown joined form must keep hyphen"
            )
        }
    }

    /// A genuine compound whose leading fragment IS in CommonWords and
    /// whose joined form is NOT in RejoinableWords — so CommonWords now
    /// works as the secondary guard it always was, and RejoinableWords is
    /// the primary gate.  Without RejoinableWords this would fuse; with
    /// it, the hyphen survives.
    func testCommonWordCompoundWithUnknownJoinKeepsHyphen() {
        // "three" is in CommonWords; "threephase" is not in RejoinableWords.
        let line = "A three-phase device is required."
        XCTAssertEqual(dehyphenate(line), line)
    }

    // MARK: - Splits that MUST still fuse (positive evidence)

    func testSplitWordInLexiconFuses() {
        XCTAssertEqual(
            dehyphenate("The transfor-mer is rated 1000 kVA."),
            "The transformer is rated 1000 kVA."
        )
    }

    func testEverySplitInLineWithLexiconWordsFuses() {
        XCTAssertEqual(
            dehyphenate("The opera-tor shall test the transfor-mer windings."),
            "The operator shall test the transformer windings."
        )
    }

    func testConfigurationSplitFuses() {
        XCTAssertEqual(
            dehyphenate("The configu-ration is shown on the drawing."),
            "The configuration is shown on the drawing."
        )
    }

    func testDistributionSplitFuses() {
        XCTAssertEqual(
            dehyphenate("A distri-bution board feeds the circuit."),
            "A distribution board feeds the circuit."
        )
    }

    func testSplitWithTrailingPunctuationFuses() {
        // The trailing "." is stripped before lexicon lookup.
        XCTAssertEqual(
            dehyphenate("Isolate the transfor-mer."),
            "Isolate the transformer."
        )
    }

    /// Plural: "transfor-mers" — joined form "transformers" not in lexicon,
    /// but "transformer" (singular) is, so the -s inflection resolves.
    func testPluralSplitFuses() {
        XCTAssertEqual(
            dehyphenate("Two transfor-mers are installed."),
            "Two transformers are installed."
        )
    }

    // MARK: - Idempotence and determinism

    func testUnknownCompoundsAreDeterministicAndIdempotent() {
        for compound in ["socket-outlets", "vendor-supplied"] {
            let line = "The \(compound) unit."
            XCTAssertEqual(
                dehyphenate(line), dehyphenate(line),
                "'\(compound)' is not deterministic"
            )
            let once = dehyphenate(line)
            XCTAssertEqual(
                dehyphenate(once), once,
                "'\(compound)' is not idempotent"
            )
        }
    }

    func testLexiconSplitsAreDeterministicAndIdempotent() {
        for line in ["The transfor-mer is here.",
                     "The opera-tor and configu-ration."] {
            XCTAssertEqual(
                dehyphenate(line), dehyphenate(line),
                "'\(line)' is not deterministic"
            )
            let once = dehyphenate(line)
            XCTAssertEqual(
                dehyphenate(once), once,
                "'\(line)' is not idempotent"
            )
        }
    }
}
