import XCTest

/// `unwrapLines` — spec criterion 1, failure modes 2 and 5.
///
/// Criterion 1: "Lines hard-wrapped at a source column width rejoin into single
/// paragraphs. Genuine paragraph breaks, list items, and table rows do NOT
/// rejoin."
///
/// The two failure modes this has to survive:
///   FM2 — a table flattened by unwrap. The rows rejoin into one ragged
///         paragraph; the information is present, the structure is gone.
///   FM5 — a genuine paragraph break swallowed because the first paragraph
///         ended near the wrap column. Reads as one longer paragraph.
///
/// The rules these tests pin down:
///   * a block only unwraps if it actually LOOKS hard-wrapped — at least three
///     lines sitting within 20% of the block's longest line;
///   * a line ending a sentence never continues onto the next line;
///   * blank lines, structure (headings, lists, quotes, fences, pipes,
///     whitespace-aligned columns) and clause citations all stop a rejoin;
///   * a line ending in `-` rejoins with NO space, so a compound split across a
///     line break stays byte-identical for the lexicon (criterion 3) and for
///     `dehyphenate` (T3).
final class UnwrapLinesTests: XCTestCase {

    // MARK: Criterion 1 — the rejoin itself

    func testHardWrappedParagraphRejoinsIntoOneLine() {
        let input = """
            The protective conductor shall be connected to the main
            earthing terminal by means of a conductor complying with
            the requirements of Chapter 54 of this standard, and
            shall be identified.
            """
        let expected = "The protective conductor shall be connected to the main earthing "
            + "terminal by means of a conductor complying with the requirements of "
            + "Chapter 54 of this standard, and shall be identified."
        XCTAssertEqual(unwrapLines(input), expected)
    }

    func testHeadingIsNotAbsorbedIntoTheParagraphBelowIt() {
        let input = """
            ## Ratings
            The transformer is rated 1000 kVA at 40°C ambient air
            temperature and 75°C average winding rise, measured in
            accordance with the requirements of IEC 60076-2 tables.
            """
        let expected = """
            ## Ratings
            The transformer is rated 1000 kVA at 40°C ambient air temperature and \
            75°C average winding rise, measured in accordance with the requirements \
            of IEC 60076-2 tables.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    // MARK: Failure mode 5 — a genuine paragraph break swallowed

    func testBlankLineSeparatedParagraphsDoNotMerge() {
        let input = """
            The switchboard shall be rated for the prospective fault
            current at the point of installation, as calculated in
            accordance with Chapter 43 and recorded on the schedule

            Each outgoing circuit shall be individually protected by
            a device having a breaking capacity not less than the
            prospective fault current at its point of installation.
            """
        let expected = """
            The switchboard shall be rated for the prospective fault current at the \
            point of installation, as calculated in accordance with Chapter 43 and \
            recorded on the schedule

            Each outgoing circuit shall be individually protected by a device having \
            a breaking capacity not less than the prospective fault current at its \
            point of installation.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// The FM5 case with no blank line to help: the first paragraph ends with a
    /// full stop one character short of the wrap column. Sentence-terminal
    /// punctuation is the only thing standing between these two paragraphs.
    func testSentenceEndingNearTheWrapColumnDoesNotMerge() {
        let input = """
            The transformer shall be provided with an oil level gauge.
            Ratings are given in Table 4-2 of this specification, and
            the losses are measured at rated current and frequency.
            """
        let expected = """
            The transformer shall be provided with an oil level gauge.
            Ratings are given in Table 4-2 of this specification, and the losses are \
            measured at rated current and frequency.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    // MARK: Failure mode 2 — a table flattened by unwrap

    func testPipeTableRowsAreNotFlattened() {
        let input = """
            | Rating | Value |
            | --- | --- |
            | Primary | 11 kV |
            | Secondary | 415 V |
            """
        XCTAssertEqual(unwrapLines(input), input)
    }

    /// A whitespace-aligned table is still a table. `detectTables` is fifth in
    /// the locked order — if unwrap flattens the columns first, it never gets
    /// the chance to recognise them.
    func testWhitespaceAlignedColumnsAreNotFlattened() {
        let input = """
            Tap    Voltage    Current
            1      11000 V    52 A
            2      10500 V    55 A
            3      10000 V    58 A
            """
        XCTAssertEqual(unwrapLines(input), input)
    }

    func testListItemsDoNotRejoin() {
        let input = """
            The following information shall be provided at each
            distribution board, and the schedule shall record every
            item listed below for the whole of the installation:
            - a circuit chart identifying every final circuit
            - the maximum demand and the assumed diversity
            - the prospective fault current at the origin
            """
        // Prose→list transition gets a blank line so Markdown renders
        // the list correctly. Consecutive list items stay tight.
        // The multiline-string input has no trailing newline (the indented
        // closing \"\"\" strips it), so unwrapLines returns no trailing \\n.
        let expected = "The following information shall be provided at each distribution board, and the schedule shall record every item listed below for the whole of the installation:\n\n- a circuit chart identifying every final circuit\n- the maximum demand and the assumed diversity\n- the prospective fault current at the origin"
        XCTAssertEqual(unwrapLines(input), expected)
    }

    // MARK: Hyphenated splits — criterion 3 and the handover to T3

    /// A word split across the break rejoins with NO space, leaving
    /// `transfor-mer` for `dehyphenate` (T3). Joining with a space would put a
    /// space inside every compound split at a line end.
    func testWordSplitAcrossTheBreakRejoinsWithoutASpace() {
        let input = """
            The three-phase induction motor is started by a transfor-
            mer tapping arrangement that limits the starting current
            to a value acceptable to the distribution network opera-
            tor at the point of common coupling.
            """
        let expected = "The three-phase induction motor is started by a transfor-mer "
            + "tapping arrangement that limits the starting current to a value "
            + "acceptable to the distribution network opera-tor at the point of "
            + "common coupling."
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// Criterion 3, across a line break. `star-` + `delta` must come back as
    /// `star-delta` byte-identical, not `star- delta`.
    func testProtectedCompoundSplitAcrossTheBreakSurvivesByteIdentical() {
        let input = """
            The winding connection is arranged for star-
            delta starting to limit the inrush current on
            the 240 mm² cable feeding the motor circuit.
            """
        let healed = unwrapLines(input)
        XCTAssertEqual(
            healed,
            "The winding connection is arranged for star-delta starting to limit "
                + "the inrush current on the 240 mm² cable feeding the motor circuit."
        )
        XCTAssertTrue(healed.contains("star-delta"), "the protected compound did not survive")
    }

    // MARK: Clause citations keep their own line

    func testClauseCitationIsNotPulledUpIntoThePrecedingLine() {
        let input = """
            Where a socket-outlet is intended for general use it
            shall be provided with additional protection by means of
            an RCD, and the requirement is stated in the regulation
            411.3.3 which applies to all installations in dwellings.
            """
        let expected = """
            Where a socket-outlet is intended for general use it shall be provided \
            with additional protection by means of an RCD, and the requirement is \
            stated in the regulation
            411.3.3 which applies to all installations in dwellings.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    // MARK: Text that is not hard-wrapped

    /// Short fragments with no consistent right margin — a web paste. There is
    /// no wrap column to undo, so there is nothing to rejoin.
    func testFragmentsWithNoConsistentWrapColumnAreLeftAlone() {
        let input = """
            "Low-voltage" "star-delta"
            XLPE/SWA/PVC "Dyn11"
            "N+1" "11kV/415V"
            40°C 47Ω 240 mm²
            """
        XCTAssertEqual(unwrapLines(input), input)
    }

    func testTrailingNewlineIsPreserved() {
        let input = "The transformer is rated 1000 kVA.\n"
        XCTAssertEqual(unwrapLines(input), input)
    }

    // MARK: Lettered lists lifted from a standards PDF

    /// The list this whole segmenting exists for: an indented `a) … j)` list
    /// under a clause lead-in. The items wrap several columns short of the
    /// prose around them and most of them are a single short line, so measuring
    /// the block as a whole finds no margin and unwraps nothing — the paste
    /// arrives with every item still broken across the PDF's line ends.
    func testIndentedLetteredListItemsUnwrapItemByItem() {
        let input = """
            a) construction sites, exhibitions, shows,
            fairgrounds and other installations for
            temporary purposes including professional
            stage and broadcast applications;
            b) marinas;
            c) external lighting and similar installations;
            """
        let expected = """
            a) construction sites, exhibitions, shows, fairgrounds and other \
            installations for temporary purposes including professional stage \
            and broadcast applications;

            b) marinas;

            c) external lighting and similar installations;
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// Markdown has no lettered list, so consecutive `a)` items with no blank
    /// line between them render as one soft-wrapped paragraph — the items run
    /// together on screen even though the healed text looks right in the
    /// editor. The marker text itself is never rewritten: turning `j)` into
    /// `9.` would renumber the citation (failure mode 6).
    func testConsecutiveLetteredItemsAreSeparatedByABlankLine() {
        let input = """
            a) marinas;
            b) medical locations;
            j) pre-fabricated building;
            """
        let expected = """
            a) marinas;

            b) medical locations;

            j) pre-fabricated building;
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// A real Markdown list is a real list: `-` and `1.` items render as
    /// separate items already, and blank-separating them would turn a tight
    /// list into a loose one.
    func testConsecutiveMarkdownListItemsStayTight() {
        let bullets = """
            - marinas
            - medical locations
            - highway equipment
            """
        XCTAssertEqual(unwrapLines(bullets), bullets)

        let numbered = """
            1. marinas
            2. medical locations
            3. highway equipment
            """
        XCTAssertEqual(unwrapLines(numbered), numbered)
    }

    func testLetteredListPasteIsIdempotent() {
        let input = """
            a) construction sites, exhibitions, shows,
            fairgrounds and other installations for
            temporary purposes including professional
            stage and broadcast applications;
            b) marinas;
            c) external lighting and similar installations;
            """
        let once = unwrapLines(input)
        XCTAssertEqual(unwrapLines(once), once, "lettered-list unwrap is not idempotent")
    }

    // MARK: Block boundaries in a paste that has none

    /// A PDF arrives with no blank lines at all — a clause title, the paragraph
    /// under it and the next title are just consecutive lines. Markdown joins
    /// consecutive lines into one paragraph, so without a blank line the titles
    /// are swallowed and the whole clause renders as one slab of prose.
    func testUnterminatedShortLineIsATitleAndGetsItsOwnBlock() {
        let input = """
            1 SCOPE
            This Code gives the rules for the design, erection, and
            verification of electrical installations. The rules are
            intended to provide for the safety of persons, livestock
            and property against dangers.
            1.1 General
            This standard applies to the design, erection and
            verification of electrical installations such as those
            of the premises listed below.
            """
        let expected = """
            1 SCOPE

            This Code gives the rules for the design, erection, and verification \
            of electrical installations. The rules are intended to provide for \
            the safety of persons, livestock and property against dangers.

            1.1 General

            This standard applies to the design, erection and verification of \
            electrical installations such as those of the premises listed below.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// A note or a new clause after the last item of a list. Neither is part of
    /// the item, and both render inside it without a blank line.
    func testFinishedListItemDoesNotAbsorbTheNoteOrClauseBelowIt() {
        let input = """
            f) photovoltaic systems, and
            g) low-voltage generating sets.
            NOTE - "premises" covers the land and all facilities
            belonging to it.
            1.2 This standard include requirements for:
            """
        let expected = """
            f) photovoltaic systems, and

            g) low-voltage generating sets.

            NOTE - "premises" covers the land and all facilities
            belonging to it.

            1.2 This standard include requirements for:
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// The counter-case, and the reason the rule is evidence-based rather than
    /// "separate whatever did not rejoin": a sentence that happens to end
    /// mid-paragraph is NOT a block boundary. The lines stay adjacent and the
    /// renderer puts the paragraph back together — which is what the source
    /// said. Splitting here would be failure mode 5 committed on purpose.
    func testSentenceEndingMidParagraphIsNotSeparated() {
        let input = """
            The transformer "low-voltage" winding
            is connected in "star-delta".
            Cable type XLPE/SWA/PVC is specified
            for the "Dyn11" unit.
            Redundancy is "N+1" and the primary
            voltage is "11kV/415V".
            """
        let expected = """
            The transformer "low-voltage" winding is connected in "star-delta".
            Cable type XLPE/SWA/PVC is specified for the "Dyn11" unit.
            Redundancy is "N+1" and the primary voltage is "11kV/415V".
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// Frontmatter is short unterminated lines from top to bottom — exactly the
    /// shape signal 1 hunts for. A blank line anywhere inside it stops it
    /// parsing, so the block is left alone entirely.
    func testFrontmatterIsNeverSeparated() {
        let input = """
            ---
            title: Substation LV Distribution Design Note
            project: Kitib Works Phase 2
            author: S. Moo
            status: issued
            ---
            """
        XCTAssertEqual(unwrapLines(input), input)
    }

    func testFencedCodeIsNeverSeparated() {
        let input = """
            ```
            411. Protection for safety
            Rating      Value      Units
            1000        5.75       percent
            ```
            """
        XCTAssertEqual(unwrapLines(input), input)
    }

    /// A NOTE is set in smaller type, so its lines run LONGER than the body's.
    /// Measured with the definitions around it, its margin becomes the whole
    /// block's and every body line falls below the threshold — so nothing
    /// unwraps at all. Each definition and the note are measured separately.
    func testNoteInSmallerTypeDoesNotSuppressTheUnwrapAroundIt() {
        let input = """
            3.86 Fault Protection - Protection against electric
            shock under single fault conditions.
            NOTE - For low voltage installation, systems and equipment,
            fault protection generally corresponds to protection against
            direct contact, mainly with regards to basic insulation.
            3.87 Final Circuit - A circuit connected directly to
            current using equipment, or to socket outlets or other
            outlet points for the connection of such equipment.
            """
        let expected = """
            3.86 Fault Protection - Protection against electric shock under \
            single fault conditions.

            NOTE - For low voltage installation, systems and equipment, fault \
            protection generally corresponds to protection against direct \
            contact, mainly with regards to basic insulation.

            3.87 Final Circuit - A circuit connected directly to current using \
            equipment, or to socket outlets or other outlet points for the \
            connection of such equipment.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// A lead-in ending in a colon is its own paragraph. Without this the
    /// introduction is buried mid-sentence in the paragraph it introduces.
    func testColonLeadInIsNotMergedIntoTheParagraphItIntroduces() {
        let input = """
            1.3.1 The relationship with the Central Electricity
            Authority Regulations 2010, and Regulations made by
            the appropriate Commission is as given below:
            The legal status of this standard, including other Codes
            of Practice, is explained in sub-regulation (2) of the
            rules made by the Central Electricity Authority.
            """
        let expected = """
            1.3.1 The relationship with the Central Electricity Authority \
            Regulations 2010, and Regulations made by the appropriate \
            Commission is as given below:

            The legal status of this standard, including other Codes of \
            Practice, is explained in sub-regulation (2) of the rules made by \
            the Central Electricity Authority.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// `1.3   Installation of Premises` — the run of spaces is the tab that set
    /// the title away from its number. Two such lines in a row would be a
    /// table; one, followed by prose, is a heading.
    func testHeadingPaddedWithSpacesIsNotMergedIntoItsParagraph() {
        let input = """
            1.3   Installation of Premises Subject to Licensing
            For installation of premises over which a licensing or
            other authority exercises a statutory control, the
            requirements of that authority shall be ascertained.
            """
        let expected = """
            1.3   Installation of Premises Subject to Licensing

            For installation of premises over which a licensing or other \
            authority exercises a statutory control, the requirements of that \
            authority shall be ascertained.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// The counter-case for signal 1: justified type sets many an ordinary
    /// wrapped line a few characters short of the margin. Only a line that
    /// stops at a FRACTION of the column is a label — otherwise every
    /// definition in a glossary is split in half at its first line.
    func testWrappedLineFallingShortOfTheMarginIsNotTreatedAsALabel() {
        let input = """
            3.12 Bonding Network (BN) - A set of
            interconnected conductive parts that provide a path for
            current at frequencies from direct current (d.c.) to radio
            frequency (RF) intended to divert, block or impede the
            passage of electromagnetic energy.
            """
        XCTAssertFalse(
            unwrapLines(input).contains("A set of\n\ninterconnected"),
            "a short wrapped line was mistaken for a label and split off"
        )
    }

    // MARK: A paste that arrives with no line breaks at all

    /// The reported defect, 2026-08-13. A run of numbered definitions copied out
    /// of Word arrives as ONE line — the source's line breaks do not survive the
    /// copy at all. Every guard that gives a clause its own block
    /// (`blockSegments`, `needsBlankSeparator` signal 4) reads LINES, so with a
    /// single line there is nothing to segment and six definitions render as one
    /// undifferentiated slab. The text is all present and correctly ordered,
    /// which is exactly what makes it read as correct.
    func testUnlinedRunOfDefinitionsSplitsAtEachClauseNumber() {
        let input = "3.72 Electrical Installation (of a Building) - An assembly of "
            + "associated electrical equipment. 3.73 Electrically Independent Earth "
            + "Electrodes - Earth electrodes located at such a distance from one "
            + "another that the potential is unaffected. 3.74 Electrical Source for "
            + "Safety Services - Electrical source intended to be used as part of a "
            + "supply system for safety services."
        let expected = """
            3.72 Electrical Installation (of a Building) - An assembly of associated \
            electrical equipment.

            3.73 Electrically Independent Earth Electrodes - Earth electrodes located \
            at such a distance from one another that the potential is unaffected.

            3.74 Electrical Source for Safety Services - Electrical source intended to \
            be used as part of a supply system for safety services.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// A `NOTE` buried mid-line is the standards-document aside and is never
    /// part of the sentence in front of it.
    func testUnlinedNoteOpenerGetsItsOwnBlock() {
        let input = "b) To avoid damage to the environment and to other equipment. "
            + "NOTE - The supply system includes the source and the circuit(s) up to "
            + "the terminals of the electrical equipment. 3.76 Electrode Boiler (or "
            + "Electrode Water Heater) - Equipment for the electrical heating of water."
        let expected = """
            b) To avoid damage to the environment and to other equipment.

            NOTE - The supply system includes the source and the circuit(s) up to the \
            terminals of the electrical equipment.

            3.76 Electrode Boiler (or Electrode Water Heater) - Equipment for the \
            electrical heating of water.
            """
        XCTAssertEqual(unwrapLines(input), expected)
    }

    /// Failure mode 6, the mid-sentence half: a clause CITED inside a sentence
    /// is prose, not the start of a block. Splitting here cuts a sentence in
    /// two, which is the worse error and the reason the split needs a completed
    /// sentence in front of it.
    func testUnlinedClauseReferenceInsideASentenceIsNotSplit() {
        let input = "The disconnection times required by 411.3.2 and by 411.3.3 shall "
            + "be applied to every final circuit of the installation."
        XCTAssertEqual(unwrapLines(input), input)
    }

    /// A decimal VALUE opening a sentence is not a clause number: `0.4 s`,
    /// `1.5 mm²`. A clause number is followed by the title it names, which is
    /// capitalised; a value is followed by its unit, which is not.
    func testUnlinedDecimalValueAfterASentenceEndIsNotAClauseOpener() {
        let input = "The protective device shall operate within the required time. "
            + "0.4 s is the maximum disconnection time for a final circuit."
        XCTAssertEqual(unwrapLines(input), input)
    }

    /// Failure mode 5, applied to this split. An ordinary sentence boundary is
    /// NOT evidence of a paragraph boundary — only a block OPENER after one is.
    func testUnlinedOrdinarySentenceBoundaryIsNotSplit() {
        let input = "The switchboard shall be rated for the prospective fault current. "
            + "Each outgoing circuit shall be individually protected by a device."
        XCTAssertEqual(unwrapLines(input), input)
    }

    /// Failure mode 7. The second pass sees the blocks the first pass made and
    /// must leave them exactly as they are.
    func testUnlinedDefinitionSplitIsIdempotent() {
        let input = "3.72 Electrical Installation (of a Building) - An assembly of "
            + "associated electrical equipment. 3.73 Electrically Independent Earth "
            + "Electrodes - Earth electrodes located far apart. NOTE - The supply "
            + "system includes the source. 3.74 Electrical Source for Safety Services "
            + "- Electrical source used as part of a supply system."
        let once = unwrapLines(input)
        XCTAssertEqual(once, unwrapLines(input), "the unlined split is not deterministic")
        XCTAssertEqual(unwrapLines(once), once, "the unlined split is not idempotent")
    }

    /// The split fires on unlined input only. Text that arrived with its line
    /// breaks intact is judged by the line-structured path, whose margin
    /// evidence is better than anything a mid-line guess can offer.
    func testLineStructuredInputIsUnaffectedByTheUnlinedSplit() {
        let input = """
            The requirements of this chapter apply to every final
            circuit of the installation. Each circuit shall be
            protected by a device having an adequate breaking
            capacity for the prospective fault current.
            """
        let expected = "The requirements of this chapter apply to every final circuit "
            + "of the installation. Each circuit shall be protected by a device having "
            + "an adequate breaking capacity for the prospective fault current."
        XCTAssertEqual(unwrapLines(input), expected)
    }

    func testIsDeterministicAndIdempotent() {
        let input = """
            The protective conductor shall be connected to the main
            earthing terminal by means of a conductor complying with
            the requirements of Chapter 54 of this standard, and
            shall be identified.

            | Rating | Value |
            | --- | --- |
            | Primary | 11 kV |
            """
        let once = unwrapLines(input)
        XCTAssertEqual(once, unwrapLines(input), "unwrapLines is not deterministic")
        XCTAssertEqual(unwrapLines(once), once, "unwrapLines is not idempotent")
    }
}
