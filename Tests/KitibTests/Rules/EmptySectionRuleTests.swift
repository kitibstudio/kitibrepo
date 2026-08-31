import XCTest

/// Tests for EmptySectionRule (specs/rules-engine.md criterion 8).
/// Failure mode 4 is the centrepiece: table-only, fence-only, image-only and
/// subheadings-only sections are NOT empty.
final class EmptySectionRuleTests: XCTestCase {

    func testDefectFixtureReportsTheEmptySection() {
        guard let doc = RulesFixtures.load("empty-section-defect") else { return }
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].ruleID, "empty-section")
        XCTAssertEqual(diagnostics[0].severity, .warning)
        XCTAssertEqual(diagnostics[0].message, "Section is empty")
        XCTAssertEqual(String(doc[diagnostics[0].range]), "## Empty\n")
    }

    /// The clean twin holds every "looks empty but is not" shape: subheadings
    /// only, table only, fence only, image only, and a trailing section with
    /// content. Failure mode 4.
    func testCleanFixtureReportsNothing() {
        guard let doc = RulesFixtures.load("empty-section-clean") else { return }
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testAdjacentHeadingsAreBothEmpty() {
        let doc = "# A\n# B\n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 2)
    }

    func testTrailingHeadingWithNoContentIsEmpty() {
        let doc = "## X\n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(String(doc[diagnostics[0].range]), "## X\n")
    }

    /// A heading whose only content is subheadings is NOT empty, but the
    /// subheading itself, with nothing under it, IS.
    func testSubheadingOnlySectionIsNotEmptyButSubheadingMayBe() {
        let doc = "## A\n### B\n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(String(doc[diagnostics[0].range]), "### B\n")
    }

    func testWhitespaceOnlyContentIsEmpty() {
        let doc = "## A\n   \n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 1)
    }

    func testHeadingWithContentIsNotEmpty() {
        let doc = "## A\ncontent\n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testNoHeadingsProducesNothing() {
        let doc = "plain text only\n"
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testDisabledRuleProducesNothing() {
        var config = RuleConfiguration()
        config.disable("empty-section")
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection("## X\n"),
                                         configuration: config)
        XCTAssertEqual(diagnostics, [])
    }

    func testSeverityOverrideApplies() {
        var config = RuleConfiguration()
        config.setSeverity(.error, for: "empty-section")
        let diagnostics = RuleEngine.run(rules: [EmptySectionRule()],
                                         on: makeProjection("## X\n"),
                                         configuration: config)
        XCTAssertEqual(diagnostics.map(\.severity), [.error])
    }
}
