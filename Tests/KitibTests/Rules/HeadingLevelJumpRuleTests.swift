import XCTest

/// Tests for HeadingLevelJumpRule (specs/rules-engine.md criterion 7).
/// Failure modes: 5 (moved-section shapes), and the range-accuracy half of 3
/// (the range covers the marker, not the line).
final class HeadingLevelJumpRuleTests: XCTestCase {

    func testDefectFixtureReportsTwoJumps() {
        guard let doc = RulesFixtures.load("heading-jump-defect") else { return }
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(diagnostics.map(\.ruleID), ["heading-level-jump", "heading-level-jump"])
        XCTAssertEqual(diagnostics.map(\.severity), [.warning, .warning])
        XCTAssertEqual(diagnostics.map(\.message),
                       ["Heading jumps from level 2 to level 4",
                        "Heading jumps from level 4 to level 6"])
        // The range covers the offending marker, nothing else (criterion 5).
        XCTAssertEqual(String(doc[diagnostics[0].range]), "####")
        XCTAssertEqual(String(doc[diagnostics[1].range]), "######")
        XCTAssertLessThan(diagnostics[0].range.lowerBound, diagnostics[1].range.lowerBound)
    }

    func testCleanFixtureReportsNothing() {
        guard let doc = RulesFixtures.load("heading-jump-clean") else { return }
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testFirstHeadingIsNeverFlagged() {
        let doc = "# Only\n"
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testAscendingAndSameLevelNeverFlagged() {
        let doc = "# A\n## B\n## C\n# D\n"
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    /// Failure mode 5: a SectionMover-shaped document. The comparison is
    /// pairwise against the PREVIOUS heading's level: `### B` after `# A`
    /// is a real jump and is flagged; the surrounding ascents are not.
    func testMovedSectionShapeFlagsRealJumpsOnly() {
        let doc = "# A\n### B\n# C\n## D\n"
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(String(doc[diagnostics[0].range]), "###")
        XCTAssertEqual(diagnostics[0].message, "Heading jumps from level 1 to level 3")
    }

    func testHeadingsInsideFencesAreIgnored() {
        let doc = "# A\n```\n#### B\n```\n"
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    func testDisabledRuleProducesNothing() {
        let doc = "## A\n#### B\n"
        var config = RuleConfiguration()
        config.disable("heading-level-jump")
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc),
                                         configuration: config)
        XCTAssertEqual(diagnostics, [])
    }

    func testSeverityOverrideApplies() {
        let doc = "## A\n#### B\n"
        var config = RuleConfiguration()
        config.setSeverity(.error, for: "heading-level-jump")
        let diagnostics = RuleEngine.run(rules: [HeadingLevelJumpRule()],
                                         on: makeProjection(doc),
                                         configuration: config)
        XCTAssertEqual(diagnostics.map(\.severity), [.error])
    }
}
