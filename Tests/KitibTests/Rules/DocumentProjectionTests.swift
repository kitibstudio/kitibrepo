import XCTest

/// Tests for DocumentProjection: the spine built once from the four
/// authorised sources (spec "The tripwire"), and the exclusion-zone scanner
/// (failure modes 1, 2, 3 at the level where they live in Session 1).
final class DocumentProjectionTests: XCTestCase {

    // MARK: - Assembly (criterion 6: projection built once)

    func testBuildCarriesTextAndLinkIndex() {
        let p = DocumentProjection.build(from: "hello", linkIndex: nil)
        XCTAssertEqual(p.text, "hello")
        XCTAssertNil(p.linkIndex)

        let index = LinkIndex(entries: [LinkIndex.Entry(path: "/a.md", title: "A")])
        let p2 = DocumentProjection.build(from: "hello", linkIndex: index)
        XCTAssertNotNil(p2.linkIndex)
    }

    func testBuildParsesHeadings() {
        let p = makeProjection("# One\n\n## Two\n\n### Three\n")
        XCTAssertEqual(p.headings.map(\.level), [1, 2, 3])
        XCTAssertEqual(p.headings.map(\.text), ["One", "Two", "Three"])
    }

    func testBuildSkipsHeadingsInsideFences() {
        let p = makeProjection("# Real\n\n```\n# Fake\n```\n")
        XCTAssertEqual(p.headings.map(\.text), ["Real"])
    }

    func testBuildComputesSectionRanges() {
        let doc = "## A\nx\n### B\ny\n## C\nz\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.sections.count, 3)
        let a = p.range(fromNSRange: p.sections[0].sectionRange)!
        XCTAssertEqual(String(doc[a]), "## A\nx\n### B\ny\n")
        let b = p.range(fromNSRange: p.sections[1].sectionRange)!
        XCTAssertEqual(String(doc[b]), "### B\ny\n")
        let c = p.range(fromNSRange: p.sections[2].sectionRange)!
        XCTAssertEqual(String(doc[c]), "## C\nz\n")
    }

    func testBuildCarriesWikiLinks() {
        let p = makeProjection("See [[alpha]] and [[beta]].")
        XCTAssertEqual(p.wikiLinks.map(\.target), ["alpha", "beta"])
    }

    func testBuildCarriesTableRanges() {
        let doc = "| A | B |\n|---|---|\n| 1 | 2 |\n\n| C |\n|---|\n| 3 |\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.tableRanges.count, 2)
        // findTableRange's endOffset counts inter-line newlines only, so a
        // table range stops before the last row's trailing newline.
        XCTAssertEqual(String(doc[p.tableRanges[0]]), "| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(String(doc[p.tableRanges[1]]), "| C |\n|---|\n| 3 |")
    }

    // MARK: - Fenced code spans (failure mode 1, scanner level)

    func testFencedCodeSpanDetected() {
        let doc = "before\n```\ncode\n```\nafter\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.fencedCodeSpans[0]]), "```\ncode\n```\n")
    }

    func testTildeFenceDetected() {
        let doc = "~~~\ncode\n~~~\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.fencedCodeSpans[0]]), "~~~\ncode\n~~~\n")
    }

    func testFenceWithInfoString() {
        let doc = "```swift\nlet x = 1\n```\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.fencedCodeSpans[0]]), doc)
    }

    func testUnterminatedFenceExtendsToEndOfDocument() {
        let doc = "```\ncode\nnever closed\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.fencedCodeSpans[0]]), doc)
    }

    func testTwoSeparateFencesProduceTwoSpans() {
        let doc = "```\na\n```\n\n```\nb\n```\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 2)
    }

    func testHeadingsInsideFenceNotInHeadingsButFenceSpanCoversThem() {
        let doc = "# Real\n```\n# Fake\n```\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.headings.count, 1)
        XCTAssertEqual(String(doc[p.fencedCodeSpans[0]]), "```\n# Fake\n```\n")
    }

    // MARK: - Inline code spans (failure mode 1, scanner level)

    func testInlineCodeSpanDetected() {
        let doc = "Use `x = 1` here."
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "`x = 1`")
    }

    func testMultipleInlineSpansOnOneLine() {
        let doc = "`a` and `b`"
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 2)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "`a`")
        XCTAssertEqual(String(doc[p.inlineCodeSpans[1]]), "`b`")
    }

    func testDoubleBacktickSpanIsOneSpan() {
        let doc = "``x`y``"
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "``x`y``")
    }

    func testBacktickSpanAcrossLines() {
        let doc = "`span\ncontinues`"
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "`span\ncontinues`")
    }

    func testUnclosedBacktickSpanEndsAtParagraphBoundary() {
        let doc = "`open span\ntext\n\nnew paragraph\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "`open span\ntext\n")
    }

    func testUnclosedBacktickSpanAtEndOfDocument() {
        let doc = "`open\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.inlineCodeSpans.count, 1)
        XCTAssertEqual(String(doc[p.inlineCodeSpans[0]]), "`open\n")
    }

    func testBackticksInsideFenceAreNotInlineSpans() {
        let doc = "```\n`not code`\n```\n"
        let p = makeProjection(doc)
        XCTAssertEqual(p.fencedCodeSpans.count, 1)
        XCTAssertEqual(p.inlineCodeSpans.count, 0)
    }

    // MARK: - Frontmatter (failure mode 2, scanner level)

    func testFrontmatterDetected() {
        let doc = "---\ntitle: Draft\n---\n# Heading\n"
        let p = makeProjection(doc)
        XCTAssertNotNil(p.frontmatterRange)
        XCTAssertEqual(String(doc[p.frontmatterRange!]), "---\ntitle: Draft\n---\n")
    }

    func testFrontmatterWithEllipsisCloser() {
        let doc = "---\ntitle: Draft\n...\n# Heading\n"
        let p = makeProjection(doc)
        XCTAssertNotNil(p.frontmatterRange)
        XCTAssertEqual(String(doc[p.frontmatterRange!]), "---\ntitle: Draft\n...\n")
    }

    func testSingleHorizontalRuleIsNotFrontmatter() {
        let doc = "---\n# Heading\n"
        let p = makeProjection(doc)
        XCTAssertNil(p.frontmatterRange)
    }

    func testBackticksInsideFrontmatterIgnored() {
        let doc = "---\nnote: `x`\n---\n# Heading\n"
        let p = makeProjection(doc)
        XCTAssertNotNil(p.frontmatterRange)
        XCTAssertEqual(p.inlineCodeSpans.count, 0)
        XCTAssertEqual(p.fencedCodeSpans.count, 0)
    }

    // MARK: - Exclusion queries

    func testIsInsideFence() {
        let doc = "a\n```\nb\n```\nc\n"
        let p = makeProjection(doc)
        let inside = p.range(fromNSRange: NSRange(location: 6, length: 1))!
        XCTAssertTrue(p.isInsideFence(inside))
        let outside = p.range(fromNSRange: NSRange(location: 0, length: 1))!
        XCTAssertFalse(p.isInsideFence(outside))
        // The fence lines themselves are part of the excluded span.
        let fenceLine = p.range(fromNSRange: NSRange(location: 2, length: 4))!
        XCTAssertTrue(p.isInsideFence(fenceLine))
    }

    func testIsInsideInlineCode() {
        let doc = "x `y` z"
        let p = makeProjection(doc)
        let inside = p.range(fromNSRange: NSRange(location: 3, length: 1))!
        XCTAssertTrue(p.isInsideInlineCode(inside))
        let outside = p.range(fromNSRange: NSRange(location: 0, length: 1))!
        XCTAssertFalse(p.isInsideInlineCode(outside))
        // A range exactly equal to the span counts as inside.
        let whole = p.range(fromNSRange: NSRange(location: 2, length: 3))!
        XCTAssertTrue(p.isInsideInlineCode(whole))
    }

    func testIsInsideFrontmatter() {
        let doc = "---\na\n---\nbody\n"
        let p = makeProjection(doc)
        let inside = p.range(fromNSRange: NSRange(location: 4, length: 1))!
        XCTAssertTrue(p.isInsideFrontmatter(inside))
        let outside = p.range(fromNSRange: NSRange(location: 10, length: 1))!
        XCTAssertFalse(p.isInsideFrontmatter(outside))
    }

    // MARK: - Range validity (criterion 5, failure mode 3)

    func testAllProjectionRangesAreValidAndNonEmpty() {
        let doc = kitchenSink()
        let p = makeProjection(doc)
        var ranges: [Range<String.Index>] = []
        ranges += p.fencedCodeSpans
        ranges += p.inlineCodeSpans
        ranges += p.tableRanges
        if let f = p.frontmatterRange { ranges.append(f) }
        for node in p.sections {
            if let r = p.range(fromNSRange: node.sectionRange) { ranges.append(r) }
        }
        for h in p.headings {
            if let r = p.range(fromNSRange: h.range) { ranges.append(r) }
        }
        XCTAssertFalse(ranges.isEmpty, "the kitchen-sink document must produce ranges")
        for r in ranges {
            XCTAssertLessThan(r.lowerBound, r.upperBound, "range must be non-empty")
            XCTAssertTrue(doc.startIndex <= r.lowerBound && r.upperBound <= doc.endIndex,
                          "range must lie within the document")
        }
    }

    func testHeadingRangeCoversHeadingLine() {
        let doc = "## Two\n"
        let p = makeProjection(doc)
        let r = p.range(fromNSRange: p.headings[0].range)!
        XCTAssertEqual(String(doc[r]), "## Two\n")
    }

    func testOutOfBoundsNSRangeConvertsToNil() {
        let p = makeProjection("abc")
        XCTAssertNil(p.range(fromNSRange: NSRange(location: 0, length: 4)))
        XCTAssertNil(p.range(fromNSRange: NSRange(location: 3, length: 1)))
        XCTAssertNil(p.range(fromNSRange: NSRange(location: NSNotFound, length: 0)))
        XCTAssertNotNil(p.range(fromNSRange: NSRange(location: 0, length: 3)))
    }

    // MARK: - Determinism (failure mode 7)

    func testBuildIsDeterministic() {
        let doc = kitchenSink()
        let a = makeProjection(doc)
        let b = makeProjection(doc)
        XCTAssertEqual(a.text, b.text)
        XCTAssertEqual(a.headings.map(\.level), b.headings.map(\.level))
        XCTAssertEqual(a.headings.map(\.text), b.headings.map(\.text))
        XCTAssertEqual(a.sections.map { $0.sectionRange }, b.sections.map { $0.sectionRange })
        XCTAssertEqual(a.wikiLinks.map(\.target), b.wikiLinks.map(\.target))
        XCTAssertEqual(a.tableRanges, b.tableRanges)
        XCTAssertEqual(a.fencedCodeSpans, b.fencedCodeSpans)
        XCTAssertEqual(a.inlineCodeSpans, b.inlineCodeSpans)
        XCTAssertEqual(a.frontmatterRange, b.frontmatterRange)
    }

    // MARK: - Kitchen sink

    /// A document exercising every projection source at once. Used by the
    /// range-validity and determinism tests. Deliberately contains trigger
    /// text (heading markers, wiki-links, code) inside exclusion zones.
    private func kitchenSink() -> String {
        """
        ---
        title: Kitchen Sink
        ---
        # Top

        Some prose with `inline code` and a [[wiki-link]].

        ## Section

        | H1 | H2 |
        |---|---|
        | a | b |

        ```swift
        # not a heading
        `not code`
        ```

        ### Sub

        ~~~text
        [[not-a-link]]
        ~~~

        More [[links]] here.
        """
    }
}
