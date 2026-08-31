import XCTest

/// Smart folder persistence + query execution.
/// Spec: specs/smart-folders.md.
final class SmartFolderTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: SmartFolderStore!
    private let suiteName = "SmartFolderTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SmartFolderStore(defaults: defaults, key: "smartFolders")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Store CRUD

    func testStartsEmpty() {
        XCTAssertEqual(store.folders.count, 0)
    }

    func testAddAppendsAndPersists() {
        let f = store.add(name: "Earth faults", query: "earth-fault")
        XCTAssertEqual(store.folders.count, 1)
        XCTAssertEqual(store.folders[0].id, f.id)
        XCTAssertEqual(store.folders[0].name, "Earth faults")
        XCTAssertEqual(store.folders[0].query, "earth-fault")
    }

    func testOrderPreservedAcrossReload() {
        store.add(name: "First", query: "alpha")
        store.add(name: "Second", query: "beta")
        store.add(name: "Third", query: "gamma")

        // New store instance over the same defaults — simulates relaunch.
        let reloaded = SmartFolderStore(defaults: defaults, key: "smartFolders")
        XCTAssertEqual(reloaded.folders.map(\.name), ["First", "Second", "Third"])
    }

    func testRenameById() {
        let f = store.add(name: "Old", query: "x")
        store.rename(id: f.id, to: "New")
        XCTAssertEqual(store.folders[0].name, "New")
    }

    func testRenameUnknownIdIsNoOp() {
        store.add(name: "Keep", query: "x")
        store.rename(id: UUID(), to: "Should Not Appear")
        XCTAssertEqual(store.folders.map(\.name), ["Keep"])
    }

    func testUpdateNameAndQuery() {
        let f = store.add(name: "Old", query: "alpha")
        store.update(id: f.id, name: "New", query: "beta")
        XCTAssertEqual(store.folders[0].name, "New")
        XCTAssertEqual(store.folders[0].query, "beta")
    }

    func testUpdateUnknownIdIsNoOp() {
        store.add(name: "Keep", query: "alpha")
        store.update(id: UUID(), name: "X", query: "Y")
        XCTAssertEqual(store.folders[0].name, "Keep")
        XCTAssertEqual(store.folders[0].query, "alpha")
    }

    func testDeleteById() {
        let a = store.add(name: "A", query: "a")
        _ = store.add(name: "B", query: "b")
        store.delete(id: a.id)
        XCTAssertEqual(store.folders.map(\.name), ["B"])
    }

    func testDeleteUnknownIdIsNoOp() {
        store.add(name: "A", query: "a")
        store.delete(id: UUID())
        XCTAssertEqual(store.folders.count, 1)
    }

    func testCorruptBlobYieldsEmpty() {
        // Write garbage bytes where a JSON array is expected.
        defaults.set(Data([0xFF, 0x00, 0xAB]), forKey: "smartFolders")
        XCTAssertEqual(store.folders.count, 0)
    }

    // MARK: - Query execution against SearchIndex

    func testSavedQueryReturnsRankedHits() throws {
        let idx = try SearchIndex()
        try idx.index(id: "/a.md", title: "Alpha", content: "The motor starter is star-delta rated.")
        try idx.index(id: "/b.md", title: "Beta", content: "Earth fault protection shall be provided.")
        try idx.index(id: "/c.md", title: "Gamma", content: "Cable schedule with earth fault loops.")

        // "fault" is a single clean token — hyphenated terms are split by
        // FTS5's tokenizer (spec failure mode 1), so avoid them in this test.
        let folder = store.add(name: "Faults", query: "fault")
        let results = try idx.search(folder.query)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.id == "/b.md" })
        XCTAssertTrue(results.contains { $0.id == "/c.md" })
    }

    func testEmptyQueryReturnsNoHits() throws {
        let idx = try SearchIndex()
        try idx.index(id: "/a.md", title: "A", content: "Some content.")

        let folder = store.add(name: "Empty", query: "   ")
        let results = try idx.search(folder.query)
        XCTAssertEqual(results.count, 0)
    }

    func testNoMatchReturnsNoHits() throws {
        let idx = try SearchIndex()
        try idx.index(id: "/a.md", title: "A", content: "Some content.")

        let folder = store.add(name: "Miss", query: "nonexistentterm")
        let results = try idx.search(folder.query)
        XCTAssertEqual(results.count, 0)
    }
}
