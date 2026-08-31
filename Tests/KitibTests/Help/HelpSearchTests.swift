import XCTest

/// Criterion 2 and 5: the search, and the state where it finds nothing.
final class HelpSearchTests: XCTestCase {

    // MARK: - Fixtures

    private let sample: [HelpEntry] = [
        HelpEntry(id: "a", lane: .cheatsheet, title: "Table",
                  summary: "A header row, then a row of dashes.",
                  example: HelpExample("| A | B |"), keywords: ["grid", "columns"]),
        HelpEntry(id: "b", lane: .guides, title: "I don't want to line up table pipes",
                  summary: "Edit any table as a grid.",
                  steps: ["Put the caret in a table.", "Click the grid icon."],
                  keywords: ["spreadsheet"]),
        HelpEntry(id: "c", lane: .shortcuts, title: "Find in document",
                  summary: "⌘F", shortcut: "⌘F", keywords: ["search"]),
        HelpEntry(id: "d", lane: .cheatsheet, title: "Café notes",
                  summary: "Diacritics in a heading.", example: HelpExample("# Café")),
    ]

    // MARK: - Basics

    func testEmptyQueryReturnsEverythingUnchanged() {
        XCTAssertEqual(HelpSearch.results(for: "", in: sample).map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(HelpSearch.results(for: "   ", in: sample).map(\.id), ["a", "b", "c", "d"])
    }

    func testFindsAcrossTitleSummaryStepsAndExample() {
        XCTAssertEqual(HelpSearch.results(for: "dashes", in: sample).map(\.id), ["a"])      // summary
        XCTAssertEqual(HelpSearch.results(for: "caret", in: sample).map(\.id), ["b"])       // a step
        XCTAssertEqual(HelpSearch.results(for: "spreadsheet", in: sample).map(\.id), ["b"]) // keyword
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(HelpSearch.results(for: "TABLE", in: sample).map(\.id),
                       HelpSearch.results(for: "table", in: sample).map(\.id))
    }

    func testMatchingIsDiacriticInsensitiveInBothDirections() {
        XCTAssertEqual(HelpSearch.results(for: "cafe", in: sample).map(\.id), ["d"])
        XCTAssertEqual(HelpSearch.results(for: "Café", in: sample).map(\.id), ["d"])
    }

    // MARK: - Criterion 2: title matches outrank body matches

    func testTitleMatchesRankAboveBodyMatches() {
        // "Table" is the title of a; b only mentions tables in its own title and
        // steps — but a's title match is the stronger reason to show it first.
        let ids = HelpSearch.results(for: "table", in: sample).map(\.id)
        XCTAssertEqual(ids.first, "a", "an entry titled for the query must come first")
        XCTAssertTrue(ids.contains("b"))
    }

    func testAKeywordOnlyMatchStillRanksBelowATitleMatch() {
        let entries = [
            HelpEntry(id: "body", lane: .guides, title: "Something else",
                      summary: "mentions diagram in passing", steps: ["one", "two"]),
            HelpEntry(id: "titled", lane: .cheatsheet, title: "Diagram",
                      summary: "A drawn diagram.", example: HelpExample("```mermaid")),
        ]
        XCTAssertEqual(HelpSearch.results(for: "diagram", in: entries).map(\.id).first, "titled")
    }

    // MARK: - Multiple words narrow

    func testEveryTokenMustMatch() {
        // "table" alone reaches both table entries…
        XCTAssertEqual(HelpSearch.results(for: "table", in: sample).map(\.id).sorted(), ["a", "b"])
        // …and a second word narrows it to the one that also mentions the caret.
        XCTAssertEqual(HelpSearch.results(for: "table caret", in: sample).map(\.id), ["b"])
        XCTAssertTrue(HelpSearch.results(for: "table unicorn", in: sample).isEmpty,
                      "a token that matches nothing must exclude the entry, not be ignored")
    }

    // MARK: - Punctuation is searchable, because half the syntax IS punctuation

    func testPunctuationSurvivesTokenisation() {
        let entries = [
            HelpEntry(id: "bold", lane: .cheatsheet, title: "Bold",
                      summary: "Two asterisks either side.",
                      example: HelpExample("**Friday**"), keywords: ["**"]),
        ]
        XCTAssertEqual(HelpSearch.results(for: "**", in: entries).map(\.id), ["bold"])
    }

    func testAShortcutCanBeFoundByItsKeys() {
        XCTAssertEqual(HelpSearch.results(for: "⌘F", in: sample).map(\.id), ["c"])
    }

    func testPunctuationOnlyQueryDoesNotCrash() {
        _ = HelpSearch.results(for: "?!", in: sample)
        _ = HelpSearch.results(for: "\\", in: sample)
        _ = HelpSearch.suggestions(for: "?!", in: sample)
    }

    // MARK: - Criterion: one field, all three lanes

    func testOneQueryReachesEveryLane() {
        let lanes = Set(HelpSearch.results(for: "table", in: sample).map(\.lane))
        XCTAssertTrue(lanes.contains(.cheatsheet))
        XCTAssertTrue(lanes.contains(.guides))
    }

    func testLaneCountsReportWhereTheMatchesAre() {
        let counts = HelpSearch.laneCounts(for: "table", in: sample)
        XCTAssertEqual(counts[.cheatsheet], 1)
        XCTAssertEqual(counts[.guides], 1)
        XCTAssertNil(counts[.shortcuts])
    }

    // MARK: - Criterion 5: the empty state must not be blank

    func testATypoIsOfferedTheWordItWasReachingFor() {
        XCTAssertTrue(HelpSearch.results(for: "tabel", in: sample).isEmpty)
        XCTAssertTrue(HelpSearch.suggestions(for: "tabel", in: sample).contains("table"),
                      "a one-transposition typo must be recognised as a near miss")
    }

    func testAPartialWordIsOfferedTheWholeOne() {
        XCTAssertTrue(HelpSearch.suggestions(for: "colum", in: sample).contains("columns"))
    }

    func testSomethingTheAppCannotDoOffersNothing() {
        // The distinction that matters: "you mistyped" vs "this app does not do
        // that". Offering a bad guess for the second collapses them back together.
        XCTAssertTrue(HelpSearch.suggestions(for: "xylophone", in: sample).isEmpty)
    }

    func testSuggestionsAreCapped() {
        XCTAssertLessThanOrEqual(HelpSearch.suggestions(for: "tabl", in: HelpContent.all).count, 3)
    }

    func testVeryShortQueriesAreNotGuessed() {
        // Two letters are not enough evidence to guess at, and everything is
        // within two edits of everything.
        XCTAssertTrue(HelpSearch.suggestions(for: "ta", in: sample).isEmpty)
    }

    // MARK: - Against the real corpus

    func testTheThingsReadersActuallySearchForAllLand() {
        let expected: [String: String] = [
            "pdf":          "guide.paste-healing",
            "paste":        "guide.paste-healing",
            "formula":      "cs.formula-inline",
            "equation":     "guide.formulas",
            "latex":        "cs.formula-inline",
            "diagram":      "cs.mermaid",
            "mermaid":      "cs.mermaid",
            "link":         "cs.link",
            "image":        "cs.image",
            "front matter": "cs.frontmatter",
            "smart folder": "guide.smart-folders",
            "export":       "guide.export",
            "dark mode":    "guide.appearance",
            "word count":   "guide.goals",
        ]
        for (query, expectedID) in expected {
            let ids = HelpSearch.results(for: query).map(\.id)
            XCTAssertFalse(ids.isEmpty, "“\(query)” finds nothing at all")
            XCTAssertTrue(ids.prefix(3).contains(expectedID),
                          "“\(query)” does not put \(expectedID) in the top three — got \(ids.prefix(3))")
        }
    }

    func testResultsAreDeterministic() {
        let once = HelpSearch.results(for: "table").map(\.id)
        let twice = HelpSearch.results(for: "table").map(\.id)
        XCTAssertEqual(once, twice, "ranking must not depend on dictionary order")
    }

    // MARK: - Edit distance

    func testTypoDistanceCountsATranspositionAsOneEdit() {
        XCTAssertEqual(HelpSearch.typoDistance("table", "table"), 0)
        XCTAssertEqual(HelpSearch.typoDistance("tabel", "table"), 1, "swapped adjacent letters are one mistake")
        XCTAssertEqual(HelpSearch.typoDistance("diagrm", "diagram"), 1)
        XCTAssertEqual(HelpSearch.typoDistance("export", "expotr"), 1)
        XCTAssertEqual(HelpSearch.typoDistance("", "abc"), 3)
        XCTAssertEqual(HelpSearch.typoDistance("abc", ""), 3)
        XCTAssertEqual(HelpSearch.typoDistance("table", "xylophone"), 8)
    }
}
