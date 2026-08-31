import XCTest

final class UniqueNameTests: XCTestCase {

    /// Builds an `isTaken` predicate from a fixed set of occupied names.
    private func taken(_ names: String...) -> (String) -> Bool {
        let set = Set(names)
        return { set.contains($0) }
    }

    // MARK: - Criterion 1: a free name is returned unchanged

    func testFreeNameIsReturnedUnchanged() {
        XCTAssertEqual(UniqueName.next(base: "New Folder", isTaken: taken()),
                       "New Folder")
    }

    // MARK: - Criterion 2: a taken name gets the first free suffix

    func testTakenBaseGetsSuffixTwo() {
        XCTAssertEqual(UniqueName.next(base: "New Folder", isTaken: taken("New Folder")),
                       "New Folder 2")
    }

    func testRunOfTakenNamesSkipsToFirstFree() {
        XCTAssertEqual(
            UniqueName.next(base: "New Folder",
                            isTaken: taken("New Folder", "New Folder 2", "New Folder 3")),
            "New Folder 4")
    }

    /// Fills a gap rather than always appending past the highest number —
    /// pressing the button after deleting "New Folder 2" reuses that name.
    func testGapIsFilled() {
        XCTAssertEqual(
            UniqueName.next(base: "New Folder",
                            isTaken: taken("New Folder", "New Folder 3")),
            "New Folder 2")
    }

    // MARK: - Failure mode: base already ends in a number

    /// "Section 2" must become "Section 2 2", never "Section 3" — the number
    /// is part of the user's name, not a suffix this function owns.
    func testBaseEndingInDigitsIsNotIncremented() {
        XCTAssertEqual(UniqueName.next(base: "Section 2", isTaken: taken("Section 2")),
                       "Section 2 2")
    }

    // MARK: - Failure mode: empty and whitespace bases

    func testEmptyBaseIsReturnedUnchanged() {
        XCTAssertEqual(UniqueName.next(base: "", isTaken: taken()), "")
    }

    func testWhitespaceOnlyBaseIsReturnedUnchanged() {
        XCTAssertEqual(UniqueName.next(base: "   ", isTaken: taken()), "   ")
    }

    // MARK: - Failure mode: names that differ only by case

    /// The predicate owns case policy (a case-insensitive filesystem supplies a
    /// case-insensitive `isTaken`); this test proves the function honours it.
    func testCaseInsensitivePredicateIsHonoured() {
        let occupied: Set<String> = ["new folder"]
        let name = UniqueName.next(base: "New Folder") { candidate in
            occupied.contains(candidate.lowercased())
        }
        XCTAssertEqual(name, "New Folder 2")
    }

    // MARK: - Failure mode: non-termination

    /// An `isTaken` that never yields must not hang. The function gives up at
    /// its cap and returns a name the caller can still use.
    func testAlwaysTakenTerminatesWithADistinctName() {
        let name = UniqueName.next(base: "New Folder", isTaken: { _ in true })
        XCTAssertTrue(name.hasPrefix("New Folder "), "got \(name)")
        XCTAssertNotEqual(name, "New Folder")
        XCTAssertNotEqual(name, "New Folder 2")
    }

    /// Two give-up names must not collide with each other either.
    func testAlwaysTakenProducesDistinctNamesAcrossCalls() {
        let first = UniqueName.next(base: "New Folder", isTaken: { _ in true })
        let second = UniqueName.next(base: "New Folder", isTaken: { _ in true })
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Determinism

    func testRepeatedCallsWithSameInputsAgree() {
        let predicate = taken("New Folder", "New Folder 2")
        XCTAssertEqual(UniqueName.next(base: "New Folder", isTaken: predicate),
                       UniqueName.next(base: "New Folder", isTaken: predicate))
    }

    // MARK: - The predicate sees exactly the candidate names

    func testPredicateReceivesCandidatesInOrder() {
        var seen: [String] = []
        _ = UniqueName.next(base: "New Folder") { candidate in
            seen.append(candidate)
            return candidate != "New Folder 3"
        }
        XCTAssertEqual(seen, ["New Folder", "New Folder 2", "New Folder 3"])
    }
}
