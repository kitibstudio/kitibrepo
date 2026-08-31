import XCTest

final class LinkIndexTests: XCTestCase {

    // MARK: - Index building

    private let sampleEntries: [LinkIndex.Entry] = [
        .init(path: "/docs/design.md", id: "uuid-1",
              title: "Design Note", aliases: ["design", "dn"]),
        .init(path: "/docs/cable-schedule.md", id: "uuid-2",
              title: "Cable Schedule", aliases: ["cables"]),
        .init(path: "/docs/protection.md", id: "uuid-3",
              title: "Protection Study"),
        .init(path: "/docs/bs7671-notes.md", id: "uuid-4",
              title: "BS 7671:2018 Notes", aliases: ["7671", "regs"]),
        .init(path: "/docs/readme.md", id: "uuid-5",
              title: nil, aliases: []),
    ]

    private lazy var index = LinkIndex(entries: sampleEntries)

    // MARK: - Criterion 1: title match

    func testTitleMatch() {
        XCTAssertEqual(index.resolve("Design Note"), "/docs/design.md")
        XCTAssertEqual(index.resolve("Cable Schedule"), "/docs/cable-schedule.md")
    }

    func testTitleWithSpecialCharacters() {
        XCTAssertEqual(index.resolve("BS 7671:2018 Notes"), "/docs/bs7671-notes.md")
    }

    // MARK: - Criterion 2: alias match

    func testAliasMatch() {
        XCTAssertEqual(index.resolve("design"), "/docs/design.md")
        XCTAssertEqual(index.resolve("dn"), "/docs/design.md")
        XCTAssertEqual(index.resolve("cables"), "/docs/cable-schedule.md")
    }

    // MARK: - Criterion 3: filename-stem fallback

    func testFilenameStemFallback() {
        // No title or alias for readme.md — stem "readme" should resolve.
        XCTAssertEqual(index.resolve("readme"), "/docs/readme.md")
    }

    func testStemFallbackUsedWhenTitleDoesNotMatch() {
        // "protection" is NOT a title or alias, but "protection" stem exists.
        XCTAssertEqual(index.resolve("protection"), "/docs/protection.md")
    }

    // MARK: - Criterion 4: case-insensitive

    func testCaseInsensitiveTitle() {
        XCTAssertEqual(index.resolve("design note"), "/docs/design.md")
        XCTAssertEqual(index.resolve("DESIGN NOTE"), "/docs/design.md")
        XCTAssertEqual(index.resolve("cable schedule"), "/docs/cable-schedule.md")
    }

    func testCaseInsensitiveAlias() {
        XCTAssertEqual(index.resolve("DESIGN"), "/docs/design.md")
        XCTAssertEqual(index.resolve("DN"), "/docs/design.md")
    }

    // MARK: - Criterion 5: broken link

    func testBrokenLinkReturnsNil() {
        XCTAssertNil(index.resolve("Nonexistent Document"))
        XCTAssertNil(index.resolve(""))
    }

    // MARK: - Priority: title > alias > stem

    func testTitleBeatsAlias() {
        // "design" is both a title match and an alias — title wins.
        // Wait, "design" matches alias, not title. Title is "Design Note".
        // Let me test: create entries where title and alias collide.
        let idx = LinkIndex(entries: [
            .init(path: "/a.md", title: "alpha"),
            .init(path: "/b.md", aliases: ["alpha"]),
        ])
        XCTAssertEqual(idx.resolve("alpha"), "/a.md",
                       "title match should beat alias match")
    }

    func testAliasBeatsStem() {
        let idx = LinkIndex(entries: [
            .init(path: "/a.md", aliases: ["readme"]),
            .init(path: "/b.md"),  // stem "b", no title/alias
        ])
        XCTAssertEqual(idx.resolve("readme"), "/a.md",
                       "alias match should beat stem fallback")
    }

    // MARK: - Determinism + first-wins

    func testFirstEntryWinsOnDuplicateKeys() {
        let idx = LinkIndex(entries: [
            .init(path: "/first.md", title: "My Doc"),
            .init(path: "/second.md", title: "My Doc"),
        ])
        XCTAssertEqual(idx.resolve("My Doc"), "/first.md")
    }

    func testDeterministicResolution() {
        for _ in 0..<100 {
            XCTAssertEqual(index.resolve("Design Note"), "/docs/design.md")
        }
    }

    // MARK: - Whitespace in target

    func testTargetWithSurroundingWhitespace() {
        // Trailing whitespace trimmed.
        XCTAssertEqual(index.resolve("  Design Note  "), "/docs/design.md")
    }
}

// MARK: - Wiki-link extraction

final class ExtractWikiLinksTests: XCTestCase {

    // MARK: - Basic extraction

    func testSingleLink() {
        let doc = "See [[Design Note]] for details."
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "Design Note")
        XCTAssertEqual(doc[links[0].range], "[[Design Note]]")
    }

    func testMultipleLinksOnOneLine() {
        let doc = "[[alpha]] and [[beta]] together."
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].target, "alpha")
        XCTAssertEqual(links[1].target, "beta")
    }

    func testMultipleLinksAcrossLines() {
        let doc = "Line one [[first]].\nLine two [[second]].\n"
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].target, "first")
        XCTAssertEqual(links[1].target, "second")
    }

    func testLinkInsideHeading() {
        let doc = "## See [[Cable Schedule]] below\n"
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "Cable Schedule")
    }

    func testAdjacentLinks() {
        let doc = "[[a]][[b]]"
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].target, "a")
        XCTAssertEqual(links[1].target, "b")
    }

    func testLinkWithSpecialCharacters() {
        let doc = "See [[BS 7671:2018 Notes]] for reference."
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "BS 7671:2018 Notes")
    }

    // MARK: - Criterion 8: code-fence immunity

    func testLinkInsideCodeFenceNotExtracted() {
        let doc = """
            Prose [[visible]].

            ```
            [[hidden link]]
            ```

            More [[visible2]].
            """
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].target, "visible")
        XCTAssertEqual(links[1].target, "visible2")
    }

    func testLinkInsideNestedFences() {
        let doc = """
            [[outer]]

            ```
            [[hidden]]
            ```

            [[middle]]

            ```
            [[also hidden]]
            ```

            [[end]]
            """
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 3)
        XCTAssertEqual(links.map(\.target), ["outer", "middle", "end"])
    }

    func testLinkInsideInlineBacktickNotExtracted() {
        let doc = "See `[[not a link]]` for code."
        let links = extractWikiLinks(doc)
        XCTAssertTrue(links.isEmpty, "link inside backtick should not be extracted")
    }

    func testLinkMixedWithBackticksOnSameLine() {
        let doc = "`[[code]]` and [[real]] and `[[more code]]`."
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "real")
    }

    // MARK: - Empty + edge cases

    func testEmptyDocument() {
        XCTAssertTrue(extractWikiLinks("").isEmpty)
    }

    func testNoLinks() {
        let doc = "Plain text with no wiki syntax.\n"
        XCTAssertTrue(extractWikiLinks(doc).isEmpty)
    }

    func testEmptyLinkBrackets() {
        // `[[]]` has empty content between brackets — skip it.
        let doc = "[[]] and [[real]]"
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "real")
    }

    func testUnclosedLinkNotExtracted() {
        let doc = "[[unclosed link"
        XCTAssertTrue(extractWikiLinks(doc).isEmpty)
    }

    func testSingleOpenBracketNotALink() {
        let doc = "[not a link]] and [[real]]"
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "real")
    }

    // MARK: - Fence tracking edge cases

    func testTildeFenceDoesNotToggle() {
        // ~~~ is not a code fence in our parser — only ``` is.
        let doc = """
            [[before]]

            ~~~
            [[visible]]
            ~~~

            [[after]]
            """
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 3,
                       "~~~ is not treated as a fence — all links visible")
    }

    func testIndentedFenceStillToggles() {
        let doc = """
            [[before]]
              ```
            [[hidden]]
              ```
            [[after]]
            """
        let links = extractWikiLinks(doc)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].target, "before")
        XCTAssertEqual(links[1].target, "after")
    }
}
