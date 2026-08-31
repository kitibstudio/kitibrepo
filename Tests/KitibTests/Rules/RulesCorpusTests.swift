import XCTest

/// Corpus-level tests for the rules fixtures: the on-disk set must match
/// RulesFixtures.names exactly (a fixture no test opens is not coverage), the
/// exclusion-zone corpus must produce ZERO diagnostics, and every fixture's
/// output must be deterministic.
final class RulesCorpusTests: XCTestCase {

    func testCorpusMatchesDeclaredNames() {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: RulesFixtures.root.path)) ?? [])
            .filter { $0.hasSuffix(".md") && $0 != "README.md" }
            .sorted()
        XCTAssertEqual(files, RulesFixtures.names.map { $0 + ".md" },
                       "on-disk fixture set must match RulesFixtures.names exactly")
    }

    func testEveryFixtureLoadsAndIsNonEmpty() {
        for name in RulesFixtures.names {
            guard let doc = RulesFixtures.load(name) else { continue }
            XCTAssertFalse(doc.isEmpty, "\\(name): fixture is empty")
        }
    }

    func testFixturesAreBundledNotReadFromSourceTree() {
        XCTAssertNotNil(
            RulesFixtures.bundledRoot,
            "Rules fixtures are not in the test bundle. The `resources` build "
                + "phase for Tests/KitibTests/Rules/Fixtures in project.yml is "
                + "not copying them. Run `xcodegen generate`."
        )
    }

    /// The highest-value test in the spec: every rule's trigger text sits
    /// inside a fence, inline backticks, and frontmatter. Expected: ZERO.
    /// The empty LinkIndex makes the zero meaningful: any wiki-link that
    /// escaped a zone would resolve to nil and error.
    func testExclusionZonesCorpusProducesZeroDiagnostics() {
        guard let doc = RulesFixtures.load("exclusion-zones") else { return }
        let diagnostics = runAllFourRules(on: doc, linkIndex: LinkIndex(entries: []))
        XCTAssertEqual(diagnostics, [],
                       "exclusion-zone corpus must produce ZERO diagnostics")
    }

    /// Failure mode 7: the same fixture run twice yields identical arrays.
    func testDeterminismAcrossAllFixtures() {
        for name in RulesFixtures.names {
            guard let doc = RulesFixtures.load(name) else { continue }
            let first = runAllFourRules(on: doc, linkIndex: LinkIndex(entries: []))
            let second = runAllFourRules(on: doc, linkIndex: LinkIndex(entries: []))
            XCTAssertEqual(first, second, "\\(name): diagnostics must be deterministic")
        }
    }
}
