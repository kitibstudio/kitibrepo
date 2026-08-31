import XCTest

/// `stripArtefacts` — spec criterion 5, failure modes 3 and 4.
///
/// Criterion 5: page numbers, running headers and running footers are removed,
/// "detected by RECURRENCE across the pasted span, never by a single-occurrence
/// pattern match".
///
/// The two failure modes pull in opposite directions and both of them read as
/// correct output:
///   FM3 — a clause number `411.3.3` eaten as a page number. The prose survives,
///         so nothing looks damaged, but the citation is unanchored.
///   FM4 — a legitimately repeated phrase (a defined term, a repeated column
///         header) deleted as a running header.
///
/// The rule that separates them, and which these tests pin down:
/// a line is furniture only if it RECURS at least `recurrenceThreshold` times
/// after digit-normalisation, is ISOLATED (blank or absent line on both sides),
/// is short, carries at least one DIGIT, and is neither structural markup nor a
/// clause citation.
final class StripArtefactsTests: XCTestCase {

    // MARK: Criterion 5 — recurrence

    /// A bare page number, repeated once per page, is furniture.
    func testRecurringPageNumbersAreRemoved() {
        let input = """
            Regulation 411.3.3 requires additional protection by RCD
            for socket-outlets rated up to 32 A in domestic premises.

            12

            The protective measure ADS requires basic insulation and
            protective equipotential bonding throughout.

            13

            Where a circuit supplies socket-outlets, an RCD having a
            rated residual operating current not exceeding 30 mA is
            required.

            14
            """
        let expected = """
            Regulation 411.3.3 requires additional protection by RCD
            for socket-outlets rated up to 32 A in domestic premises.

            The protective measure ADS requires basic insulation and
            protective equipotential bonding throughout.

            Where a circuit supplies socket-outlets, an RCD having a
            rated residual operating current not exceeding 30 mA is
            required.

            """
        XCTAssertEqual(stripArtefacts(input), expected)
    }

    /// A running header whose page number changes each time still recurs: the
    /// digit-normalised key is identical, which is what detection matches on.
    func testRecurringRunningHeaderIsRemoved() {
        let input = """
            BS 7671:2018   Chapter 41   12

            Automatic disconnection of supply is the protective
            measure most commonly used in low-voltage installations.

            BS 7671:2018   Chapter 41   13

            Protective equipotential bonding shall connect extraneous
            conductive parts to the main earthing terminal.

            BS 7671:2018   Chapter 41   14
            """
        let expected = """
            Automatic disconnection of supply is the protective
            measure most commonly used in low-voltage installations.

            Protective equipotential bonding shall connect extraneous
            conductive parts to the main earthing terminal.

            """
        XCTAssertEqual(stripArtefacts(input), expected)
    }

    /// Criterion 5, the explicit half: "never by a single-occurrence pattern
    /// match". A lone `12` is a value in a document, not page furniture.
    func testSingleOccurrenceIsNeverRemoved() {
        let input = """
            Regulation 411.3.3 requires additional protection.

            12

            Protective equipotential bonding is required.
            """
        XCTAssertEqual(stripArtefacts(input), input)
    }

    /// Two occurrences are not recurrence either. Under-stripping leaves a
    /// visible page number; over-stripping deletes content silently.
    func testTwoOccurrencesAreBelowTheRecurrenceThreshold() {
        let input = """
            Regulation 411.3.3 requires additional protection.

            12

            Protective equipotential bonding is required.

            13
            """
        XCTAssertEqual(stripArtefacts(input), input)
    }

    // MARK: Failure mode 3 — a clause number eaten as a page number

    func testIsolatedRecurringClauseCitationsAreNeverRemoved() {
        for citation in ["411.3.3", "§7.2", "Table 4-2", "Figure 3-1", "Clause 6.1"] {
            let input = """
                \(citation)

                Additional protection by RCD shall be provided for all
                socket-outlets rated up to 32 A.

                \(citation)

                The requirement applies to installations in dwellings.

                \(citation)
                """
            XCTAssertEqual(
                stripArtefacts(input), input,
                "'\(citation)' was stripped as page furniture — failure mode 3"
            )
        }
    }

    // MARK: Failure mode 4 — over-eager recurrence

    /// A line repeated inside prose is not furniture: page furniture is
    /// line-isolated by the page break that produced it. Deleting a line out of
    /// the middle of a paragraph is the worst available outcome.
    func testRepeatedLineInsideProseIsNeverRemoved() {
        let input = """
            Rated voltage 400 V
            shall be assumed for all final circuits in this section.
            Rated voltage 400 V
            shall be assumed for all final circuits in this section.
            Rated voltage 400 V
            shall be assumed for all final circuits in this section.
            """
        XCTAssertEqual(stripArtefacts(input), input)
    }

    /// A repeated defined term carries no page number, so it is not furniture
    /// however often it recurs.
    func testIsolatedRepeatedPhraseWithoutADigitSurvives() {
        let input = """
            star-delta starting

            The motor shall be started by an approved method that
            limits the starting current at the point of supply.

            star-delta starting

            The starter shall be interlocked with the main contactor.

            star-delta starting
            """
        XCTAssertEqual(stripArtefacts(input), input)
    }

    /// Structural markup is content, never furniture — even isolated and
    /// recurring, and even carrying digits.
    func testIsolatedRecurringStructuralLinesSurvive() {
        for line in ["| 1 | 11000 V |", "# Chapter 41", "- item rated 32 A", "> quoted at 12 kV"] {
            let input = """
                \(line)

                The switchboard shall be rated for the prospective
                fault current at the point of installation.

                \(line)

                Each outgoing circuit shall be individually protected.

                \(line)
                """
            XCTAssertEqual(
                stripArtefacts(input), input,
                "structural line '\(line)' was stripped as page furniture"
            )
        }
    }

    // MARK: Clean input, determinism, idempotence

    func testCleanProseIsUntouched() {
        let input = """
            The transformer is rated 1000 kVA at 40°C ambient.

            The "low-voltage" winding is connected in "star-delta".
            """
        XCTAssertEqual(stripArtefacts(input), input)
    }

    func testTrailingNewlineIsPreserved() {
        let input = "The transformer is rated 1000 kVA.\n"
        XCTAssertEqual(stripArtefacts(input), input)
    }

    func testIsDeterministicAndIdempotent() {
        let input = """
            Page 1 of 3

            The switchboard shall be rated for the prospective fault
            current at the point of installation.

            Page 2 of 3

            Each outgoing circuit shall be individually protected by a
            device having an adequate breaking capacity.

            Page 3 of 3
            """
        let once = stripArtefacts(input)
        XCTAssertEqual(once, stripArtefacts(input), "stripArtefacts is not deterministic")
        XCTAssertEqual(stripArtefacts(once), once, "stripArtefacts is not idempotent")
        XCTAssertFalse(once.contains("Page 1 of 3"), "the running footer was not stripped")
        XCTAssertTrue(once.contains("prospective fault"), "prose was lost with the footer")
    }
}
