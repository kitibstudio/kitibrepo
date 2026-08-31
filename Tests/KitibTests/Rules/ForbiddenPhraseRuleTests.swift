import XCTest

/// Tests for ForbiddenPhraseRule (specs/rules-engine.md criterion 10).
/// Failure mode 2 (frontmatter as prose) and the delimiter-row exclusion are
/// the centrepieces.
final class ForbiddenPhraseRuleTests: XCTestCase {

    private let phrases = [
        ForbiddenPhraseRule.Phrase(pattern: "draft", message: "No drafts", severity: .warning),
        ForbiddenPhraseRule.Phrase(pattern: "todo", message: "No TODOs", severity: .info),
    ]

    private func run(_ doc: String) -> [Diagnostic] {
        RuleEngine.run(rules: [ForbiddenPhraseRule(phrases: phrases)],
                       on: makeProjection(doc))
    }

    /// Exact counts, ranges, messages and per-phrase severities. "TODO"
    /// (info) precedes "Draft" (warning) by range start.
    func testDefectFixtureReportsExactDiagnostics() {
        guard let doc = RulesFixtures.load("forbidden-defect") else { return }
        let diagnostics = run(doc)
        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(diagnostics.map(\.ruleID), ["forbidden-phrase", "forbidden-phrase"])
        XCTAssertEqual(diagnostics.map(\.message), ["No TODOs", "No drafts"])
        XCTAssertEqual(diagnostics.map(\.severity), [.info, .warning])
        XCTAssertEqual(String(doc[diagnostics[0].range]), "TODO")
        XCTAssertEqual(String(doc[diagnostics[1].range]), "Draft")
    }

    func testCleanFixtureReportsNothing() {
        guard let doc = RulesFixtures.load("forbidden-clean") else { return }
        XCTAssertEqual(run(doc), [])
    }

    func testMatchingIsCaseInsensitive() {
        let diagnostics = run("DRAFT copy\n")
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].message, "No drafts")
    }

    func testMultipleOccurrences() {
        let doc = "draft draft\n"
        let diagnostics = run(doc)
        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(String(doc[diagnostics[0].range]), "draft")
        XCTAssertEqual(String(doc[diagnostics[1].range]), "draft")
    }

    func testPhraseInsideFenceIsIgnored() {
        XCTAssertEqual(run("```\nDraft\n```\n"), [])
    }

    func testPhraseInsideInlineCodeIsIgnored() {
        XCTAssertEqual(run("`Draft`\n"), [])
    }

    /// Failure mode 2: frontmatter is metadata, not prose.
    func testPhraseInsideFrontmatterIsIgnored() {
        XCTAssertEqual(run("---\ntitle: Draft\n---\n# H\n"), [])
    }

    /// A phrase matching a table's delimiter row (here "--") must not fire:
    /// the delimiter row is structure, not prose (criterion 10).
    func testPhraseInDelimiterRowIsIgnored() {
        let doc = "| a | b |\n|---|---|\n| c | d |\n"
        let diagnostics = RuleEngine.run(
            rules: [ForbiddenPhraseRule(phrases: [
                ForbiddenPhraseRule.Phrase(pattern: "--", message: "no dashes", severity: .warning),
            ])],
            on: makeProjection(doc))
        XCTAssertEqual(diagnostics, [])
    }

    /// A table data cell IS prose: a phrase there is flagged.
    func testPhraseInTableDataCellIsFlagged() {
        let doc = "| h |\n|---|\n| draft |\n"
        let diagnostics = run(doc)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(String(doc[diagnostics[0].range]), "draft")
    }

    /// Two patterns matching at the same offset must stay in phrase-list
    /// order across runs (determinism, failure mode 7).
    func testOverlappingPatternsAreDeterministic() {
        let doc = "abc\n"
        let diagnostics = RuleEngine.run(
            rules: [ForbiddenPhraseRule(phrases: [
                ForbiddenPhraseRule.Phrase(pattern: "ab", message: "first", severity: .warning),
                ForbiddenPhraseRule.Phrase(pattern: "abc", message: "second", severity: .info),
            ])],
            on: makeProjection(doc))
        XCTAssertEqual(diagnostics.map(\.message), ["first", "second"])
    }

    /// An empty pattern must be ignored, not loop forever.
    func testEmptyPatternIsIgnored() {
        let diagnostics = RuleEngine.run(
            rules: [ForbiddenPhraseRule(phrases: [
                ForbiddenPhraseRule.Phrase(pattern: "", message: "empty", severity: .warning),
            ])],
            on: makeProjection("anything\n"))
        XCTAssertEqual(diagnostics, [])
    }

    /// Severity is per phrase and survives without a configuration override
    /// (D81). An override flattens everything.
    func testSeverityOverrideFlattensAll() {
        var config = RuleConfiguration()
        config.setSeverity(.error, for: "forbidden-phrase")
        let diagnostics = RuleEngine.run(rules: [ForbiddenPhraseRule(phrases: phrases)],
                                         on: makeProjection("Draft TODO\n"),
                                         configuration: config)
        XCTAssertEqual(diagnostics.map(\.severity), [.error, .error])
    }

    func testEmptyPhraseListProducesNothing() {
        let diagnostics = RuleEngine.run(rules: [ForbiddenPhraseRule(phrases: [])],
                                         on: makeProjection("Draft TODO\n"))
        XCTAssertEqual(diagnostics, [])
    }

    func testDisabledRuleProducesNothing() {
        var config = RuleConfiguration()
        config.disable("forbidden-phrase")
        let diagnostics = RuleEngine.run(rules: [ForbiddenPhraseRule(phrases: phrases)],
                                         on: makeProjection("Draft\n"),
                                         configuration: config)
        XCTAssertEqual(diagnostics, [])
    }
}
