import XCTest

// MARK: - Failure-mode tests

final class OutlineParserFailureModeTests: XCTestCase {

    /// Headings inside fenced code blocks must not be parsed as real headings.
    func testHeadingsInsideFencedCodeBlocksIgnored() {
        let text = """
        # Real Heading

        ```
        ## Not a heading
        ### Also not
        ```

        ## Another Real
        """

        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 2, "Should only parse headings outside fences")
        XCTAssertEqual(headings[0].text, "Real Heading")
        XCTAssertEqual(headings[1].text, "Another Real")
    }

    /// Tilde-fenced code blocks also hide headings.
    func testHeadingsInsideTildeFencesIgnored() {
        let text = """
        # Top

        ~~~
        ## Hidden
        ~~~

        ## Visible
        """
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 2)
    }

    /// Nested fences: a heading between fence pairs should be caught.
    func testNestedFenceBlocks() {
        let text = """
        # A
        ```
        ## B
        ```
        ## C
        ```
        ### D
        ```
        # E
        """
        let headings = OutlineParser.parseHeadings(from: text)
        let texts = headings.map(\.text)
        XCTAssertEqual(texts, ["A", "C", "E"])
    }

    /// Moving a section into itself must be rejected.
    func testMoveIntoOwnSectionReturnsNil() {
        let text = """
        # H1
        content one

        ## H2
        content two

        # H3
        content three
        """
        let headings = OutlineParser.parseHeadings(from: text)
        // Move H1 (index 0) to position 1 — inserts before H2, which is
        // inside H1's own section
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 1
        )
        XCTAssertNil(result, "Moving a section into itself must return nil")
    }

    /// Moving a section to the same position is a no-op.
    func testMoveToSamePositionReturnsNil() {
        let text = "# A\n\na\n\n# B\n\nb\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertNil(SectionMover.move(text: text, headings: headings,
                                        sourceIndex: 0, destinationIndex: 0))
        XCTAssertNil(SectionMover.move(text: text, headings: headings,
                                        sourceIndex: 0, destinationIndex: 1))
    }
}

// MARK: - Acceptance-criteria tests

final class OutlineParserTests: XCTestCase {

    // MARK: parseHeadings

    func testEmptyDocumentReturnsNoHeadings() {
        XCTAssertTrue(OutlineParser.parseHeadings(from: "").isEmpty)
    }

    func testDocumentWithNoHeadingsReturnsEmpty() {
        let text = "Just some text.\n\nNo headings here.\n"
        XCTAssertTrue(OutlineParser.parseHeadings(from: text).isEmpty)
    }

    func testSingleH1Heading() {
        let text = "# Introduction\n\nContent.\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[0].text, "Introduction")
        XCTAssertEqual(headings[0].lineNumber, 1)
    }

    func testMultipleHeadingsAtMixedLevels() {
        let text = """
        # H1
        h1 content

        ## H2
        h2 content

        ### H3
        h3 content

        ## Another H2
        more content

        # Final H1
        end
        """
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 5)
        XCTAssertEqual(headings.map(\.level), [1, 2, 3, 2, 1])
        XCTAssertEqual(headings.map(\.text), [
            "H1", "H2", "H3", "Another H2", "Final H1"
        ])
    }

    func testHeadingsWithClosingHashCharacters() {
        let text = "## Section ##\n\ncontent\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].text, "Section")
    }

    func testHeadingsWithInlineFormatting() {
        let text = """
        # **Bold** heading
        ## `code` and *italic*
        ### [link](target) heading
        """
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 3)
        XCTAssertEqual(headings[0].text, "**Bold** heading")
        XCTAssertEqual(headings[1].text, "`code` and *italic*")
        XCTAssertEqual(headings[2].text, "[link](target) heading")
    }

    func testHashWithoutSpaceNotAHeading() {
        let text = "#not-a-heading\n\n##also not\n\n###   real ###\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].text, "real")
    }

    func testSevenHashCharactersNotAHeading() {
        let text = "####### not a heading\n\n## real heading\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].text, "real heading")
    }

    func testLineNumbersAreCorrect() {
        let text = "text\n\n# First\n\nmore\n\n## Second\n\nend\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertEqual(headings.count, 2)
        XCTAssertEqual(headings[0].lineNumber, 3)
        XCTAssertEqual(headings[1].lineNumber, 7)
    }

    // MARK: buildHierarchy

    func testFlatHierarchyAllSameLevel() {
        let text = "# A\n\na\n\n# B\n\nb\n\n# C\n\nc\n"
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)
        let roots = OutlineParser.buildHierarchy(from: nodes)

        XCTAssertEqual(roots.count, 3)
        roots.forEach { XCTAssertTrue($0.children.isEmpty) }
    }

    func testNestedHierarchy() {
        let text = """
        # H1
        a
        ## H2
        b
        ### H3
        c
        """
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)
        let roots = OutlineParser.buildHierarchy(from: nodes)

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].heading.text, "H1")
        XCTAssertEqual(roots[0].children.count, 1)
        XCTAssertEqual(roots[0].children[0].heading.text, "H2")
        XCTAssertEqual(roots[0].children[0].children.count, 1)
        XCTAssertEqual(roots[0].children[0].children[0].heading.text, "H3")
    }

    func testSiblingGroups() {
        let text = """
        # H1
        ## H2a
        ## H2b
        # H1b
        ## H2c
        """
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)
        let roots = OutlineParser.buildHierarchy(from: nodes)

        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0].children.count, 2)
        XCTAssertEqual(roots[0].children[0].heading.text, "H2a")
        XCTAssertEqual(roots[0].children[1].heading.text, "H2b")
        XCTAssertEqual(roots[1].children.count, 1)
        XCTAssertEqual(roots[1].children[0].heading.text, "H2c")
    }

    func testLevelSkip() {
        // H2 after H4 — H2 should be a child of H1 (nearest level < 2),
        // not a child of H4
        let text = """
        # H1
        #### H4
        ## H2
        """
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)
        let roots = OutlineParser.buildHierarchy(from: nodes)

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].heading.text, "H1")
        // H4 and H2 are both children of H1
        XCTAssertEqual(roots[0].children.count, 2)
        XCTAssertEqual(roots[0].children[0].heading.text, "H4")
        XCTAssertEqual(roots[0].children[1].heading.text, "H2")
    }

    // MARK: sectionRange

    func testSectionRangeTopLevel() {
        let text = "# First\n\nfirst content\n\n# Second\n\nsecond content\n"
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)

        XCTAssertEqual(nodes.count, 2)
        // First section: from "First" heading to before "Second" heading
        let firstSection = (text as NSString).substring(with: nodes[0].sectionRange)
        XCTAssertTrue(firstSection.hasPrefix("# First"))
        XCTAssertFalse(firstSection.contains("# Second"))

        // Second section: from "Second" heading to end
        let secondSection = (text as NSString).substring(with: nodes[1].sectionRange)
        XCTAssertTrue(secondSection.hasPrefix("# Second"))
        XCTAssertTrue(secondSection.hasSuffix("content\n"))
    }

    func testSectionRangeNestedSubsectionsIncluded() {
        let text = """
        # H1
        h1 text
        ## H2
        h2 text
        # H1again
        end
        """
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)

        // H1 section includes H2
        let h1Section = (text as NSString).substring(with: nodes[0].sectionRange)
        XCTAssertTrue(h1Section.contains("## H2"))
        XCTAssertFalse(h1Section.contains("# H1again"))
    }

    func testSectionRangeLastHeadingToEnd() {
        let text = "preamble\n\n# Only\n\ncontent\n\nmore content\n"
        let headings = OutlineParser.parseHeadings(from: text)
        let nodes = OutlineParser.computeSectionRanges(text: text, headings: headings)

        XCTAssertEqual(nodes.count, 1)
        let section = (text as NSString).substring(with: nodes[0].sectionRange)
        XCTAssertTrue(section.hasSuffix("more content\n"))
    }
}

// MARK: - SectionMover tests

final class SectionMoverTests: XCTestCase {

    func testMoveHeadingToEarlierPosition() {
        let text = "# A\n\na\n\n# B\n\nb\n\n# C\n\nc\n"
        // Move C (index 2) to before A (index 0)
        let headings = OutlineParser.parseHeadings(from: text)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 2, destinationIndex: 0
        )
        XCTAssertNotNil(result)
        let newHeadings = OutlineParser.parseHeadings(from: result!.text)
        XCTAssertEqual(newHeadings.map(\.text), ["C", "A", "B"])
    }

    func testMoveHeadingToLaterPosition() {
        let text = "# A\n\na\n\n# B\n\nb\n\n# C\n\nc\n"
        // Move A (index 0) to after C (destination 3 = end)
        let headings = OutlineParser.parseHeadings(from: text)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 3
        )
        XCTAssertNotNil(result)
        let newHeadings = OutlineParser.parseHeadings(from: result!.text)
        XCTAssertEqual(newHeadings.map(\.text), ["B", "C", "A"])
    }

    func testMoveHeadingToEnd() {
        let text = "# A\n\na\n\n# B\n\nb\n"
        let headings = OutlineParser.parseHeadings(from: text)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 2
        )
        XCTAssertNotNil(result)
        let newHeadings = OutlineParser.parseHeadings(from: result!.text)
        XCTAssertEqual(newHeadings.map(\.text), ["B", "A"])
    }

    func testMoveNestedSectionChildrenFollow() {
        let text = """
        # A
        a content
        ## A1
        a1 content
        # B
        b content
        """
        // Move A (with A1 nested) to after B
        let headings = OutlineParser.parseHeadings(from: text)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 3
        )
        XCTAssertNotNil(result)
        let newHeadings = OutlineParser.parseHeadings(from: result!.text)
        XCTAssertEqual(newHeadings.map(\.text), ["B", "A", "A1"])
        // Verify A1 is still inside A's section
        XCTAssertTrue(result!.text.contains("a1 content"))
    }

    func testMovePreservesSurroundingText() {
        let text = "preamble text\n\n# A\n\na\n\n# B\n\nb\n\npostamble text\n"
        let headings = OutlineParser.parseHeadings(from: text)
        // Move A to after B (destinationIndex 2 = end of headings list,
        // which places A's section at the end of the document)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 2
        )
        XCTAssertNotNil(result)
        // Preamble stays at the start; A's section moves to the very end,
        // after postamble
        XCTAssertTrue(result!.text.hasPrefix("preamble text"))
    }

    func testRoundTripParseMoveReparse() {
        let text = """
        # Introduction
        intro

        ## Background
        bg

        # Analysis
        analysis

        ## Method
        method

        # Conclusion
        end
        """
        let headings = OutlineParser.parseHeadings(from: text)

        // Move "Analysis" section (with Method nested) to top
        guard let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 2, destinationIndex: 0
        ) else {
            XCTFail("Move should succeed")
            return
        }

        let newHeadings = OutlineParser.parseHeadings(from: result.text)
        // Analysis should now be first, Method still nested under it
        XCTAssertEqual(newHeadings.map(\.text), [
            "Analysis", "Method", "Introduction", "Background", "Conclusion"
        ])

        // Verify levels are preserved
        XCTAssertEqual(newHeadings.map(\.level), [1, 2, 1, 2, 1])

        // Move "Analysis" back — insert before Conclusion (index 4 in the
        // new heading list, which puts it after Introduction+Background)
        guard let backResult = SectionMover.move(
            text: result.text, headings: newHeadings,
            sourceIndex: 0, destinationIndex: 4
        ) else {
            XCTFail("Reverse move should succeed")
            return
        }

        let finalHeadings = OutlineParser.parseHeadings(from: backResult.text)
        XCTAssertEqual(finalHeadings.map(\.text),
                       ["Introduction", "Background", "Analysis", "Method", "Conclusion"])
    }

    func testMoveStripsExtraTrailingBlankLines() {
        // Moving a section should not drag blank lines between sections
        // into the new position — at most one trailing \n remains.
        let text = "# A\n\na text\n\n\n# B\n\nb text\n"
        let headings = OutlineParser.parseHeadings(from: text)
        // Move A before B (both H1)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 2
        )
        XCTAssertNotNil(result)
        // Should not have more than one consecutive \n between sections
        let doubleBlank = result!.text.contains("\n\n\n")
        XCTAssertFalse(doubleBlank,
                       "Section move must not create triple-newline gaps")

        // Verify headings still parse correctly
        let newHeadings = OutlineParser.parseHeadings(from: result!.text)
        XCTAssertEqual(newHeadings.count, 2)
    }

    func testMovePreservesInternalBlankLines() {
        // Blank lines WITHIN a section (between paragraphs) must survive.
        let text = "# A\n\npara one\n\n\npara two\n\n# B\n\nb text\n"
        let headings = OutlineParser.parseHeadings(from: text)
        let result = SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: 2
        )
        XCTAssertNotNil(result)
        // Internal blank lines (between paragraphs) preserved
        XCTAssertTrue(result!.text.contains("para one\n\n\npara two"),
                      "Internal blank lines within section must survive")
    }

    func testEmptyHeadingListReturnsNil() {
        XCTAssertNil(SectionMover.move(
            text: "text", headings: [],
            sourceIndex: 0, destinationIndex: 0
        ))
    }

    func testOutOfBoundsSourceReturnsNil() {
        let text = "# H\n\nc\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertNil(SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 1, destinationIndex: 0
        ))
        XCTAssertNil(SectionMover.move(
            text: text, headings: headings,
            sourceIndex: -1, destinationIndex: 0
        ))
    }

    func testOutOfBoundsDestinationReturnsNil() {
        let text = "# H\n\nc\n"
        let headings = OutlineParser.parseHeadings(from: text)
        XCTAssertNil(SectionMover.move(
            text: text, headings: headings,
            sourceIndex: 0, destinationIndex: -1
        ))
    }
}
