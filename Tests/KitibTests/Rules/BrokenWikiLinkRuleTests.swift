import XCTest

/// Tests for BrokenWikiLinkRule (specs/rules-engine.md criterion 9).
/// Failure mode 6 is the centrepiece: nil index vs empty index are different
/// states and only the latter flags links.
final class BrokenWikiLinkRuleTests: XCTestCase {

    private let presentIndex = LinkIndex(entries: [
        LinkIndex.Entry(path: "/docs/present.md", title: "present"),
    ])

    func testDefectFixtureReportsTheBrokenLink() {
        guard let doc = RulesFixtures.load("broken-link-defect") else { return }
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: presentIndex))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].ruleID, "broken-wiki-link")
        XCTAssertEqual(diagnostics[0].severity, .error)
        XCTAssertEqual(diagnostics[0].message, "Broken wiki-link: [[missing]]")
        XCTAssertEqual(String(doc[diagnostics[0].range]), "[[missing]]")
    }

    /// The clean twin also proves case-insensitive resolution: [[Present]]
    /// and [[PRESENT]] resolve against title "present".
    func testCleanFixtureReportsNothing() {
        guard let doc = RulesFixtures.load("broken-link-clean") else { return }
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: presentIndex))
        XCTAssertEqual(diagnostics, [])
    }

    /// Failure mode 6: no index supplied. An error storm on every document
    /// is worse than no rule at all.
    func testNoIndexSuppliedProducesNothing() {
        guard let doc = RulesFixtures.load("broken-link-defect") else { return }
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: nil))
        XCTAssertEqual(diagnostics, [])
    }

    /// An empty index is "the index says no", a different state: every link
    /// is broken.
    func testEmptyIndexFlagsEveryLink() {
        let doc = "See [[a]] and [[b]]."
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: LinkIndex(entries: [])))
        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(diagnostics.map(\.message),
                       ["Broken wiki-link: [[a]]", "Broken wiki-link: [[b]]"])
    }

    func testMultipleBrokenLinksSortedByRange() {
        let doc = "[[b]] then [[a]]"
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: LinkIndex(entries: [])))
        XCTAssertEqual(diagnostics.map(\.message),
                       ["Broken wiki-link: [[b]]", "Broken wiki-link: [[a]]"])
    }

    /// The extractWikiLinks exclusion is the sole authority (criterion 9):
    /// links inside fences and inline backticks never reach this rule, so
    /// even an empty index cannot flag them.
    func testLinksInFencesAndBackticksAreNeverFlagged() {
        let doc = "`[[x]]`\n\n```\n[[y]]\n```\n"
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection(doc, linkIndex: LinkIndex(entries: [])))
        XCTAssertEqual(diagnostics, [])
    }

    func testDisabledRuleProducesNothing() {
        var config = RuleConfiguration()
        config.disable("broken-wiki-link")
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection("[[x]]", linkIndex: LinkIndex(entries: [])),
                                         configuration: config)
        XCTAssertEqual(diagnostics, [])
    }

    func testSeverityOverrideApplies() {
        var config = RuleConfiguration()
        config.setSeverity(.info, for: "broken-wiki-link")
        let diagnostics = RuleEngine.run(rules: [BrokenWikiLinkRule()],
                                         on: makeProjection("[[x]]", linkIndex: LinkIndex(entries: [])),
                                         configuration: config)
        XCTAssertEqual(diagnostics.map(\.severity), [.info])
    }
}
