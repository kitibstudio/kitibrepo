import XCTest

final class SearchIndexTests: XCTestCase {

    private var idx: SearchIndex!

    override func setUp() {
        super.setUp()
        idx = try! SearchIndex()
    }

    override func tearDown() {
        idx = nil
        super.tearDown()
    }

    // MARK: - Criterion 1: indexing

    func testIndexAndBasicSearch() throws {
        try idx.index(id: "1", title: "Design Note",
                      content: "The transformer is rated 1000 kVA.")
        try idx.index(id: "2", title: "Cable Schedule",
                      content: "All feeders shall be XLPE insulated.")

        let results = try idx.search("transformer")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "1")
        XCTAssertEqual(results[0].title, "Design Note")
    }

    func testSearchAcrossMultipleDocuments() throws {
        try idx.index(id: "a", title: nil, content: "voltage drop in cables")
        try idx.index(id: "b", title: nil, content: "voltage rating of transformer")
        try idx.index(id: "c", title: nil, content: "cable sizing for feeders")

        let results = try idx.search("voltage")
        XCTAssertEqual(results.count, 2)
        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids, ["a", "b"])
    }

    // MARK: - Criterion 3: phrase search

    func testPhraseSearch() throws {
        try idx.index(id: "1", title: nil,
                      content: "The voltage drop shall not exceed 5%.")
        try idx.index(id: "2", title: nil,
                      content: "Voltage and drop are separate words here.")

        let results = try idx.search("\"voltage drop\"")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "1")
    }

    // MARK: - Criterion 4: implicit AND

    func testImplicitAND() throws {
        try idx.index(id: "1", title: nil, content: "cable and schedule together")
        try idx.index(id: "2", title: nil, content: "cable only here")
        try idx.index(id: "3", title: nil, content: "schedule only here")

        let results = try idx.search("cable schedule")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "1")
    }

    // MARK: - Criterion 5: OR

    func testOR() throws {
        try idx.index(id: "1", title: nil, content: "cable only")
        try idx.index(id: "2", title: nil, content: "schedule only")
        try idx.index(id: "3", title: nil, content: "neither word here")

        let results = try idx.search("cable OR schedule")
        XCTAssertEqual(results.count, 2)
        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids, ["1", "2"])
    }

    // MARK: - Criterion 6: NOT

    func testNOT() throws {
        try idx.index(id: "1", title: nil,
                      content: "cable sizing for LV distribution")
        try idx.index(id: "2", title: nil,
                      content: "cable sizing for HV transmission")

        let results = try idx.search("cable NOT HV")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "1")
    }

    // MARK: - Criterion 7: case-insensitive

    func testCaseInsensitive() throws {
        try idx.index(id: "1", title: nil, content: "Transformer rating")

        let lower = try idx.search("transformer")
        let upper = try idx.search("TRANSFORMER")
        let mixed = try idx.search("Transformer")
        XCTAssertEqual(lower.count, 1)
        XCTAssertEqual(upper.count, 1)
        XCTAssertEqual(mixed.count, 1)
    }

    // MARK: - Criterion 8: snippets

    func testSnippetContainsMatch() throws {
        try idx.index(id: "1", title: nil,
                      content: "The main transformer shall be rated for 1000 kVA "
                              + "continuous duty at 40 C ambient temperature.")

        let results = try idx.search("transformer")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].snippet.contains("<b>transformer</b>"),
                      "snippet should highlight the matched term: \(results[0].snippet)")
    }

    func testSnippetIsNotTheEntireDocument() throws {
        let long = String(repeating: "word ", count: 200) + "transformer " 
                 + String(repeating: "more ", count: 200)
        try idx.index(id: "1", title: nil, content: long)

        let results = try idx.search("transformer")
        XCTAssertEqual(results.count, 1)
        XCTAssertLessThan(results[0].snippet.count, 500,
                          "snippet should be much shorter than the full document")
    }

    // MARK: - Criterion 9: update

    func testReindexReplacesContent() throws {
        try idx.index(id: "1", title: nil, content: "original content about cables")
        try idx.index(id: "1", title: nil, content: "updated content about transformers")

        let old = try idx.search("cables")
        XCTAssertTrue(old.isEmpty, "old content should no longer be searchable")

        let new = try idx.search("transformers")
        XCTAssertEqual(new.count, 1)
        XCTAssertEqual(new[0].id, "1")
    }

    func testReindexPreservesTitle() throws {
        try idx.index(id: "1", title: "Original Title", content: "first version")
        try idx.index(id: "1", title: "Updated Title", content: "second version")

        let results = try idx.search("second")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Updated Title")
    }

    // MARK: - Criterion 10: remove

    func testRemoveMakesDocumentUnsearchable() throws {
        try idx.index(id: "1", title: nil, content: "cable schedule")
        try idx.index(id: "2", title: nil, content: "protection study")

        try idx.remove(id: "1")

        let results = try idx.search("cable")
        XCTAssertTrue(results.isEmpty)
    }

    func testRemoveNonexistentIsNoOp() throws {
        try idx.remove(id: "nonexistent")   // must not throw
        try idx.index(id: "1", title: nil, content: "cable")
        let results = try idx.search("cable")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Edge cases

    func testEmptyQueryReturnsEmpty() throws {
        try idx.index(id: "1", title: nil, content: "cable")
        let results = try idx.search("")
        XCTAssertTrue(results.isEmpty)
    }

    func testWhitespaceOnlyQueryReturnsEmpty() throws {
        try idx.index(id: "1", title: nil, content: "cable")
        let results = try idx.search("   ")
        XCTAssertTrue(results.isEmpty)
    }

    func testEmptyIndexReturnsEmpty() throws {
        let results = try idx.search("anything")
        XCTAssertTrue(results.isEmpty)
    }

    func testDocumentWithNilTitle() throws {
        try idx.index(id: "1", title: nil, content: "cable schedule")
        let results = try idx.search("cable")
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results[0].title)
    }

    func testSearchTitleField() throws {
        try idx.index(id: "1", title: "Protection Study", content: "some body text")
        try idx.index(id: "2", title: "Cable Schedule", content: "other body text")

        let results = try idx.search("Protection")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "1")
    }

    func testSpecialCharactersInContentAreSearchable() throws {
        try idx.index(id: "1", title: nil, content: "rated 11 kV")
        // FTS5 default tokeniser may split "11kV" into "11" and "kv" or drop digits.
        // "11 kV" with a space should be tokenised as "11" and "kv".
        let results = try idx.search("11")
        XCTAssertEqual(results.count, 1, "numeric tokens should be searchable")
    }

    func testMultipleMatchesInOneDocumentReturnsOneResult() throws {
        try idx.index(id: "1", title: nil,
                      content: "cable cable cable cable cable")
        let results = try idx.search("cable")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Ranking

    func testMoreRelevantDocumentRanksHigher() throws {
        try idx.index(id: "rare", title: nil,
                      content: "transformer efficiency and transformer losses")
        try idx.index(id: "common", title: nil,
                      content: "transformer " + String(repeating: "filler ", count: 100))

        let results = try idx.search("transformer")
        XCTAssertEqual(results.count, 2)
        // The document with two occurrences in a short body should rank higher.
        XCTAssertEqual(results[0].id, "rare")
    }

    // MARK: - Failure mode 4: update atomicity

    func testUpdateIsAtomicNoStaleTokens() throws {
        try idx.index(id: "1", title: nil, content: "cable schedule for LV")
        try idx.index(id: "1", title: nil, content: "protection study for MV")

        // "cable" should no longer find this document.
        let staleResults = try idx.search("cable")
        XCTAssertTrue(staleResults.isEmpty,
                      "stale tokens from previous version should not match")
    }
}
